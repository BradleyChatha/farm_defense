module engine.vulkan.resourcemanager;

import core.atomic : cas, atomicOp, atomicLoad, atomicStore;
import std.typecons : Flag;
import std.algorithm : max;
import std.meta : AliasSeq;
import stdx.allocator, stdx.allocator.building_blocks;
import engine.core.logging, engine.core.threading, engine.vulkan, engine.vulkan.types._vkhandlewrapper;

version = VObjectPoolDebug;
version = VFreeDebug;

/++ DATA TYPES ++/
private enum VRefCountedGenericSize = size_t.sizeof * 2;
private enum VRefCountedStoresPerBlock = 500;
private enum VBucketQueueNodesPerBlock = 500;
private enum VBucketQueueMaxFrameDelay = 3;

private alias VObjectPoolAlloc(T, size_t amountPerBlock) = AllocatorList!(_ => ContiguousFreeList!(NullAllocator, T.sizeof)(new ubyte[T.sizeof * amountPerBlock]));
private alias VRefCountedStoreAlloc = AllocatorList!(_ => ContiguousFreeList!(NullAllocator, VRefCountedGenericSize)(new ubyte[VRefCountedGenericSize * VRefCountedStoresPerBlock]));
private alias VBucketQueueNodeAlloc = Mallocator; // AllocatorList never fails to constantly give me annoying compiler errors, so malloc for now I guess.

struct VObjectRef(T)
{
    T* ptr;
    size_t version_;

    //invariant(this.isNull || this.isValid, "Seems this pointer has been recycled. This is invalid usage of this pointer since this is no longer the same object.");

    this(T* ptr)
    {
        assert(ptr !is null);
        this.ptr = ptr;
        this.version_ = ptr.allocVersion;
    }

    bool isNull() const
    {
        return this.ptr is null;
    }

    bool isValid() const
    {
        return this.ptr.allocVersion == this.version_;
    }

    bool isValidNotNull() const
    {
        return !this.isNull && this.isValid;
    }

    ref T value()
    {
        assert(this.isValidNotNull);
        return *this.ptr;
    }
}

private struct VObjectPool(T, size_t amountPerBlock, IsThreadSafe threadSafe)
{
    @disable this(this){}

    Lockable!(VObjectPoolAlloc!(T, amountPerBlock), OwnedCountingLock, threadSafe) _alloc;
    size_t allocVersion = 1; // The risk of this overflowing *exists*, but such a case is completely impossible for a linearly incrementing counter in a short-lived program (even at 32-bits).

    T* make(Args...)(auto ref Args args)
    {
        auto alloc = this._alloc.lock();
        auto ptr = alloc.make!T(args);
        ptr.allocVersion = this.allocVersion++;
        this._alloc.unlock();

        version(VObjectPoolDebug) logfDebug("Allocating %s at %X", T.stringof, cast(size_t)ptr);
        return ptr;
    }

    void free(T* ptr)
    in(ptr !is null)
    {
        auto alloc = this._alloc.lock();
        version(VObjectPoolDebug) logfDebug("Freeing %s at %X", T.stringof, cast(size_t)ptr);
        ptr.allocVersion = 0; // Since old pointers will always end up pointing to valid memory, they need at least one safeguard against using freed objects.
        alloc.dispose(ptr);
        this._alloc.unlock();
    }
}

struct VRefCounted(T, IsThreadSafe threadSafe)
{
    private static struct Store
    {
        T value;
        size_t refs;
    }
    static assert(Store.sizeof == VRefCountedGenericSize);

    private Store* _store;

    private VRefCountedStoreAlloc* getAlloc()
    {
        version(threadSafe)
            return g_refCountedStoreAlloc.lock();
        else
            return &tl_refCountedStoreAlloc;
    }

    private void freeAlloc()
    {
        version(threadSafe)
            g_refCountedStoreAlloc.unlock();
    }

    private void incrementRef()
    {
        version(threadSafe)
            atomicOp!"+="(this._store.refs, 1);
        else
            this._store.refs++;
    }

    private size_t decrementRef()
    {
        version(threadSafe)
            return atomicOp!"-="(this._store.refs, 1);
        else
            return --this._store.refs;
    }

    this(T value)
    {
        this._store = this.getAlloc().make!Store(value, 1);
        this.freeAlloc();
    }

    this(this)
    {
        if(this._store !is null)
            this.incrementRef();
    }

    ~this()
    {
        if(this._store !is null)
        {
            if(this.decrementRef() == 0)
            {
                auto alloc = this.getAlloc();

                version(threadSafe)
                    resourceFree(cast(shared)this._store.value);
                else
                    resourceFree(this._store.value);

                alloc.dispose(this._store);
                this.freeAlloc();
            }
        }
    }

    void opAssign()(auto ref typeof(this) rhs)
    {
        this.__xdtor();
        this._store = rhs.store;
        this.incrementRef();
    }

    @property
    bool isNull()()
    {
        return this._store !is null;
    }

    @property
    T value()()
    {
        assert(!this.isNull);
        return this._store.value;
    }
}

private struct VDeallocBucketQueue
{
    @disable this(this){}

    alias DeallocFunc = void function(void*);

    static struct Node
    {
        void* resourcePtr;
        DeallocFunc deallocFunc;
        Node* next;
    }

    static struct Bucket
    {
        Node* head;
        Node* tail;
        size_t count;
    }

    private enum _alloc = VBucketQueueNodeAlloc.instance;
    private Bucket[VBucketQueueMaxFrameDelay+1] _buckets;

    package void freeAll()
    {
        foreach(i; 0..this._buckets.length)
            this.onFrame();
    }

    void add(size_t frameDelay, void* resource, DeallocFunc deallocFunc)
    {
        version(VFreeDebug) logfDebug("Adding GENERIC (at %X) to be destroyed after %s frames.", resource, frameDelay);
        assert(frameDelay <= VBucketQueueMaxFrameDelay, "Frame delay is too high!");
        assert(deallocFunc !is null, "Deallocation function was null.");
        assert(resource !is null, "Resource was null.");
        
        scope bucket = &this._buckets[frameDelay];
        auto node = this._alloc.make!Node(resource, deallocFunc, null);

        if(bucket.head is null)
        {
            bucket.head = node;
            bucket.tail = node;
        }
        else
        {
            bucket.tail.next = node;
            bucket.tail = node;
        }
        bucket.count++;
    }

    void add(T)(size_t frameDelay, T* resource)
    {
        version(VFreeDebug) logfDebug("Adding %s (%s at %X handle %X) to be destroyed after %s frames.", T.stringof, resource.debugName, resource, resource.handle, frameDelay);
        
        static void dealloc(void* resourceAsVoid)
        {
            scope resourceFromVoid = cast(T*) resourceAsVoid;
            version(VFreeDebug) logfDebug("Freeing %s (%s at %X handle %X).", T.stringof, resourceFromVoid.debugName, resourceFromVoid, resourceFromVoid.handle);

            if(resourceFromVoid.freeImpl !is null)
                resourceFromVoid.freeImpl(resourceFromVoid);
            else
                version(VFreeDebug) logfWarning("%s (%s at %X handle %X) does not have a free function.", T.stringof, resourceFromVoid.debugName, resourceFromVoid, resourceFromVoid.handle);
            
            resourceFromVoid.freeImpl = null; // So the below .free doesn't trigger it again.
            mixin(allocNameOf!T~".free(resourceFromVoid);");
        }

        this.add(frameDelay, resource, &dealloc);
    }

    void onFrame()
    {
        scope bucket = &this._buckets[0];
        auto head = bucket.head;

        if(bucket.count > 0)
            version(VFreeDebug) logfDebug("Freeing %s resources this frame.", bucket.count);

        while(head !is null)
        {
            head.deallocFunc(head.resourcePtr);
            auto oldHead = head;
            head = head.next;
            this._alloc.dispose(oldHead);
        }

        foreach(i; 1..this._buckets.length)
            this._buckets[i-1] = this._buckets[i];
        this._buckets[$-1] = Bucket.init;
    }
}

/++ GLOBAL ++/
private __gshared Lockable!VRefCountedStoreAlloc g_refCountedStoreAlloc;
private __gshared Lockable!VDeallocBucketQueue g_deallocBucketQueue;

/++ THREAD LOCAL ++/
private VRefCountedStoreAlloc tl_refCountedStoreAlloc;
private VDeallocBucketQueue tl_deallocBucketQueue;

/++ INIT/UNINIT FUNCTIONS ++/

void resourceGlobalInit()
{

}

void resourcePerThreadInit()
{
}

void resourcePerThreadUninit()
{
    import core.thread;

    logfTrace("Unloading Vulkan Resources on thread %s", Thread.getThis().id);

    tl_deallocBucketQueue.freeAll();
}

void resourceGlobalUninit()
{
    logfTrace("Unloading global Vulkan Resources");
    g_deallocBucketQueue.lock().freeAll(); // Not unlocking, since after this point it is an error for any thread to acquire this lock.
}

void resourceGlobalOnFrame()
{
    {
        auto queue = g_deallocBucketQueue.lock();
        scope(exit) g_deallocBucketQueue.unlock();
        queue.onFrame();
    }
}

void resourcePerThreadOnFrame()
{
    tl_deallocBucketQueue.onFrame();
}

/++ MAKE FUNCS ++/
VRefCounted!(VObjectRef!T, IsThreadSafe.no) resourceMakeRefCounted(T, Args...)(auto ref Args args)
{
    return typeof(return)(resourcesMake!T(args));
}

/++ LIFETIME INFO + FUNCTION GENERATION ++/
private struct Lifetime(VType_, LTIAllocInfo AllocInfo_, alias FreeInfo_)
{
    alias VType     = VType_;
    enum  AllocInfo = AllocInfo_;
    enum  FreeInfo  = FreeInfo_;
}

private struct LTIAllocInfo
{
    size_t amountPerBlock;
    IsThreadSafe threadSafe;
}

private struct LTIDelayByFrames
{
    size_t frameCount;
}

private struct LTIImmediateFree
{
}

private alias LIFETIMES = AliasSeq!(
    Lifetime!(VImage, LTIAllocInfo(50, IsThreadSafe.yes), LTIDelayByFrames(1)),
    Lifetime!(VBuffer, LTIAllocInfo(50, IsThreadSafe.yes), LTIDelayByFrames(1))
);

private const allocNameOf(T) = "g_alloc_"~T.stringof;

private mixin template AllocFor(alias LifetimeData)
{
    mixin("private __gshared VObjectPool!(LifetimeData.VType, LifetimeData.AllocInfo.amountPerBlock, LifetimeData.AllocInfo.threadSafe) "~allocNameOf!(LifetimeData.VType)~";");
}

private mixin template MakeFor(alias LifetimeData)
{
    VObjectRef!T resourceMake(T, Args...)(auto ref Args args)
    if(is(T == LifetimeData.VType))
    {
        mixin("auto ptr = "~allocNameOf!T~".make(args);");
        return typeof(return)(ptr);
    }
}

private mixin template FreeFor(alias LifetimeData)
{
    void resourceFree(VObjectRef!(LifetimeData.VType) value)
    {
        assert(value.isValidNotNull);

        if(value.value.isMarkedForDeletion || value.value.isDisposed)
        {
            version(VFreeDebug) logfDebug("Ingoring %s (%s at %X handle %X) as it's already disposed/queued for deletion.", LifetimeData.VType.stringof, value.value.debugName, value.ptr, value.value.handle);
            return;
        }
        value.value.isMarkedForDeletion = true;

        alias FreeInfoT = typeof(LifetimeData.FreeInfo);
        static if(is(FreeInfoT == LTIDelayByFrames))
        {
            static if(LifetimeData.AllocInfo.threadSafe)
            {
                scope queue = g_deallocBucketQueue.lock();
                scope(exit) g_deallocBucketQueue.unlock();
            }
            else
                scope queue = &tl_deallocBucketQueue;
                
            queue.add(LifetimeData.FreeInfo.frameCount, value.ptr);
        }
        else static if(is(FreeInfoT == LTIImmediateFree))
        {
            value.value.freeImpl(value.ptr);
            value.value.freeImpl = null;
            mixin(allocNameOf!T~".free(value.ptr);");
        }
        else static assert(false, "Invalid free info struct: "~typeof(LifetimeData.FreeInfo).stringof);
    }
}

private mixin template CreateLifetimeFuncs(alias LifetimeData)
{
    mixin AllocFor!(LifetimeData);
    mixin MakeFor!LifetimeData;
    mixin FreeFor!LifetimeData;
}

static foreach(lifetime; LIFETIMES)
    mixin CreateLifetimeFuncs!lifetime;