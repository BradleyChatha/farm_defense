module engine.util.structures.objectpool;

import stdx.allocator, stdx.allocator.building_blocks;

struct StaticObjectPool(T, size_t capacity)
{
    @disable this(this){}

    alias FreeListT = ContiguousFreeList!(GCAllocator, stateSize!T);
    FreeListT alloc;

    static typeof(this) create()()
    {
        return typeof(this)(FreeListT(stateSize!T * capacity));
    }
}

struct DynamicObjectPool(T, size_t capacityPerStep)
{
    @disable this(this){}

    alias FreeListT = AllocatorList!((n) =>
        ContiguousFreeList!(NullAllocator, stateSize!T)(new ubyte[stateSize!T * n])
    );
    FreeListT alloc;

    auto make(Args...)(Args args)
    {
        return this.alloc.make!T(args);
    }

    static typeof(this) create()()
    {
        return typeof(this)();
    }
}

version(unittest)
{
    private alias DoesItCompile = StaticObjectPool!(size_t, 32);
    private alias DoesItCompile2ElectricBoogaloo = DynamicObjectPool!(size_t, 32);
}