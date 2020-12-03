module engine.util.structures.bufferarray;

import stdx.allocator, stdx.allocator.mallocator;

alias t = BufferArray!(int, Mallocator);
struct BufferArray(T, Allocator)
{
    @disable this(this) {}

    private
    {
        T[]    _array;
        size_t _length;
        size_t _capacity;

        static if(stateSize!Allocator == 0)
            alias _alloc = Allocator.instance;
        else
            Allocator _alloc;
    }

    ~this()
    {
        if(this._array !is null)
            this._alloc.dispose(this._array);
    }
    
    void length(size_t newLength)
    {
        import core.exception : onOutOfMemoryError;

        this._length = newLength;
        if(newLength < this._capacity)
            return;

        bool success;

        this._capacity = newLength * 2;
        if(this._array is null)
        {
            this._array = this._alloc.makeArray!T(this._capacity);
            success = this._array !is null;
        }
        else
            success = this._alloc.expandArray(this._array, this._capacity - this._array.length);

        if(!success)
            onOutOfMemoryError(null);
    }
    size_t length() { return this._length; }
    alias opDollar = length;
}