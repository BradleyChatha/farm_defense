module engine.util.structures.objectpool;

import stdx.allocator, stdx.allocator.building_blocks;

struct StaticObjectPool(T, size_t capacity)
{
    @disable this(this){}

    alias FreeListT = ContiguousFreeList!(GCAllocator, stateSize!T);
    FreeListT instance;
    alias instance this;

    static typeof(this) create()()
    {
        return typeof(this)(FreeListT(stateSize!T * capacity));
    }
}

struct DynamicObjectPool(T, size_t capacityPerStep)
{
    @disable this(this){}

    alias FreeListT = AllocatorList!((n) =>
        ContiguousFreeList!(GCAllocator, stateSize!T)(stateSize!T * n)
    );
    FreeListT instance;
    alias instance this;

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