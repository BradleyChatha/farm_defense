module engine.util.structures.bufferarray;

import stdx.allocator, stdx.allocator.mallocator;

/++
 + An array that doesn't free memory until it's destroyed.
 +
 + Useful for internal buffers.
 +
 + Only escape slices, or keep slices after buffer grows, at your own risk.
 + ++/
struct BufferArray(T, Allocator = Mallocator)
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
        {
            static if(__traits(compiles, { Allocator a; Allocator b; a = b; }))
            {
                alias AllocType = Allocator;
                Allocator _alloc;
            }
            else
            {
                alias AllocType = Allocator*;
                Allocator* _alloc;
            }
        }
    }

    ~this()
    {
        if(this._array !is null)
            this._alloc.dispose(this._array);
    }

    this()(size_t startLength)
    {
        this.length = startLength;
    }

    static if(stateSize!Allocator != 0)
    {
        this()(AllocType alloc)
        {
            this._alloc = alloc;
        }

        this()(AllocType alloc, size_t startLength)
        {
            this._alloc = alloc;
            this.length = startLength;
        }
    }

    void shrink()()
    {
        import core.memory : GC;
        import core.exception : onOutOfMemoryError;

        if(this._array is null)
            return;

        GC.removeRange(this._array.ptr);
        this._capacity = this._length;
        auto success = this._alloc.shrinkArray(this._array, (this._array.length - this._length));

        if(!success)
            onOutOfMemoryError(null);
        
        GC.addRange(this._array.ptr, this._array.length * T.sizeof, typeid(T));
    }

    void clear()(T value = T.init)
    {
        this._array[] = value;
        this.length = 0;
    }
    
    void length()(size_t newLength)
    {
        import core.exception : onOutOfMemoryError;
        import core.memory : GC;

        this._length = newLength;
        if(newLength < this._capacity)
        {
            this._array[newLength+1..this._capacity] = T.init;
            return;
        }

        bool success;

        this._capacity = newLength * 2;
        if(this._capacity < 64)
            this._capacity = 64; // Make memory thrashing less likely.

        if(this._array is null)
        {
            this._array = this._alloc.makeArray!T(this._capacity);
            success = this._array !is null;
        }
        else
        {
            GC.removeRange(this._array.ptr);
            success = this._alloc.expandArray(this._array, this._capacity - this._array.length);
        }

        if(!success)
            onOutOfMemoryError(null);

        GC.addRange(this._array.ptr, this._array.length * T.sizeof, typeid(T));
    }
    size_t length()() const { return this._length; }
    size_t opDollar() const { return this._length; }

    void opIndexAssign(T2)(T2 value, size_t index)
    {
        assert(index < this._length, "Index out of bounds.");
        this._array[index] = value;
    }

    void opSliceAssign(T2)(T2 value, size_t start, size_t end)
    if(is(T2 : T))
    {
        assert(end <= this._length, "Index out of bounds.");
        this._array[start..end] = value;
    }

    void opSliceAssign(T2)(T2[] values, size_t start, size_t end)
    if(!is(T2[] == T))
    {
        assert(end <= this._length, "Index out of bounds.");

        const count = (end - start);
        assert(values.length >= count, "Not enough values.");

        this._array[start..end] = values[0..count];
    }

    ref T opIndex()(size_t index)
    {
        assert(index < this._length, "Index out of bounds.");
        return this._array[index];
    }

    T[] opIndex()()
    {
        return this._array;
    }

    T[] opSlice()(size_t start, size_t end)
    {
        assert(end <= this._length, "Index out of bounds.");
        return this._array[start..end];
    }

    void opOpAssign(string op, T2)(T2 right)
    if(op == "~")
    {
        this.length = this.length + 1;
        this._array[this.length - 1] = right;
    }

    bool opBinary(string op, T2)(T2 right)
    if(op == "in")
    {
        import std.algorithm : any;
        return this[].any!(item => item == right);
    }
}
///
@("BufferArray")
unittest
{
    import std.algorithm : all;
    import fluent.asserts;

    alias Buffer = BufferArray!string;

    Buffer b;
    b.length = 20;
    b.length.should.equal(20);
    b._capacity.should.be.above(19);
    assert(b[].all!(str => str is null));

    b[0] = "Hello!";
    b[0].should.equal("Hello!");
    
    b[2..4] = "World!";
    b[0..3].should.equal(["Hello!", null, "World!"]);
    b[3].should.equal(b[2]);

    b.clear();
    assert(b._array[0..4].all!(str => str is null));

    b ~= "Hello, ";
    b ~= "there ";
    b ~= "World!";
    b.length.should.equal(3);
    b[0..$].should.equal(["Hello, ", "there ", "World!"]);

    b._capacity.should.equal(64);
    b.shrink();
    b._capacity.should.equal(3);
}