module engine.util.structures.objectpool;

import stdx.allocator.mallocator;
import engine.util.structures, engine.core.interfaces;

struct RecycledObjectRef(T)
{
    private void* _parent;
    T value;

    @property
    bool isValid()
    {
        // TODO: Better logic here, this is just a placeholder.
        return this._parent !is null;
    }
}

/// An object pool that outsources population of the pool to an external function.
/// This pool never personally touches/resets/modifies the data held within, so is useful for objects that need to keep state between uses.
/// This pool always passes by value, even with value types.
/// This makes this pool serve a specific niche, so the other pools may be more useful and efficient for your purposes.
/// This pool places high trust in the user code.
/// This pool was primarily designed for Vulkan resource management, hence the extreme lack of safety features and weird pass-by-value quirks.
/// Note for value types: Changes to the value will not be reflected into the array passed into .onFree
struct RecyclingObjectPool(T, size_t ObjectsPerStep_ = 32, Allocator = Mallocator)
{
    mixin IDisposableBoilerplate;

    @disable this(this){}

    alias Ref = RecycledObjectRef!T;
    enum ObjectsPerStep = ObjectsPerStep_;

    alias PopulatorFuncT = void delegate(scope Ref[] sliceToPopulate);
    alias OnAcquireFuncT = void delegate(scope Ref[] slice);
    alias OnReleaseFuncT = void delegate(scope Ref[] slice);
    alias OnFreeFuncT    = void delegate(scope Ref[] slice);

    private
    {
        // Pretty wasteful, but it's easy, and the lengths won't be overly large for what I have in mind at the moment.
        // BufferArray!(Ref, Allocator) _allObjects;
        // BufferArray!(Ref, Allocator) _inactiveObjects;
        Ref[] _allObjects;
        Ref[] _inactiveObjects;

        PopulatorFuncT _onPopulate;
        OnAcquireFuncT _onAcquire;
        OnReleaseFuncT _onRelease;
        OnFreeFuncT    _onFree;
    }

    ~this()
    {
        if(!this.isDisposed)
            this.dispose();
    }

    private void disposeImpl()
    {
        if(this._onFree !is null)
        {
            this._onFree(this._allObjects[]);
            this._onFree = null;
        }

        // this._allObjects.dispose();
        // this._inactiveObjects.dispose();
    }

    private void growObjects()
    {
        assert(this._onPopulate !is null, "No onPopulate was provided.");

        const oldSize = this._allObjects.length;
        this._allObjects.length = oldSize + ObjectsPerStep;
        auto sliceToBePopulated = this._allObjects[oldSize..$];

        this._onPopulate(sliceToBePopulated);
        foreach(ref ref_; sliceToBePopulated)
            ref_._parent = &this;

        this._inactiveObjects ~= sliceToBePopulated;
    }

    Ref allocSingle()
    {
        Ref[1] buffer;
        this.alloc(buffer[]);
        return buffer[0];
    }

    void free(ref Ref value)
    {
        Ref[1] buffer = [value];
        auto slice = buffer[];
        this.free(slice);
        value = Ref.init;
    }

    void alloc(scope Ref[] buffer)
    {
        assert(!this.isDisposed, "This object has been disposed.");
        while(buffer.length > this._inactiveObjects.length)
            this.growObjects();

        buffer[0..$] = this._inactiveObjects[0..buffer.length];
        
        const objectsLeft = this._inactiveObjects.length - buffer.length;
        //this._inactiveObjects[0..objectsLeft] = this._inactiveObjects[buffer.length..buffer.length+objectsLeft];
        // Above code crashes for whatever reason, sooooo
        foreach(i, value; this._inactiveObjects[buffer.length..$])
            this._inactiveObjects[i] = value;

        this._inactiveObjects.length = objectsLeft;

        if(this._onAcquire !is null)
            this._onAcquire(buffer);
    }

    void free(scope Ref[] buffer)
    {
        import std.algorithm : all;
        assert(buffer.all!(r => r._parent is &this), "Buffer contains references that aren't from this pool.");
        assert(!this.isDisposed, "This object has been disposed.");

        if(this._onRelease !is null)
            this._onRelease(buffer);

        this._inactiveObjects ~= buffer;
        buffer[] = Ref.init;
    }

    @property @safe @nogc
    void onPopulate(PopulatorFuncT func) nothrow
    {
        assert(func !is null);
        this._onPopulate = func;
    }

    @property @safe @nogc
    void onAcquire(OnAcquireFuncT func) nothrow
    {
        assert(func !is null);
        this._onAcquire = func;
    }

    @property @safe @nogc
    void onRelease(OnReleaseFuncT func) nothrow
    {
        assert(func !is null);
        this._onRelease = func;
    }

    @property @safe @nogc
    void onFree(OnFreeFuncT func) nothrow
    {
        assert(func !is null);
        this._onFree = func;
    }
}