module engine.util.structures.ssobufferarray;

import stdx.allocator, stdx.allocator.mallocator;
import engine.util.structures.bufferarray;

/++
 + An SSO version of BufferArray.
 +
 + Swaps to using dynamically allocated memory once all the statically allocated memory is used up.
 + ++/
struct SsoBufferArray(T, size_t SmallStorageSize = 32, Allocator = Mallocator)
{
    @disable this(this){}

    alias BufferArrayT = BufferArray!(T, Allocator);

    private
    {
        BufferArrayT        _buffer;
        T[SmallStorageSize] _sso;
        size_t              _ssoLength;
        bool                _ssoUsedUp;
    }

    static if(stateSize!Allocator > 0)
    this(Allocator alloc)
    {
        this._buffer = BufferArrayT(alloc);
    }

    void clear()(T value = T.init)
    {
        if(this._ssoUsedUp)
        {
            this._buffer.clear(value);
            return;
        }

        this._sso[] = value;
        this._ssoLength = 0;
    }
    
    void length()(size_t newLength)
    {
        if(!this._ssoUsedUp && newLength > this._sso.length)
        {
            this._ssoUsedUp = true;
            this._buffer.length = newLength;
            this._buffer[0..this._sso.length] = this._sso[0..$];
            return;
        }

        if(this._ssoUsedUp)
        {
            this._buffer.length = newLength;
            return;
        }

        this._ssoLength = newLength;

        if(this._ssoLength < this._sso.length)
            this._sso[this._ssoLength+1..$] = T.init;
    }
    size_t length()() const { return (this._ssoUsedUp) ? this._buffer.length : this._ssoLength; }
    size_t opDollar() const { return this.length; }

    void opIndexAssign(T2)(T2 value, size_t index)
    {
        if(this._ssoUsedUp)
        {
            this._buffer[index] = value;
            return;
        }

        assert(index < this._ssoLength, "Index out of bounds.");
        this._sso[index] = value;
    }

    void opSliceAssign(T2)(T2 value, size_t start, size_t end)
    {
        if(this._ssoUsedUp)
        {
            this._buffer[start..end] = value;
            return;
        }

        assert(end <= this._ssoLength, "Index out of bounds.");
        this._sso[start..end] = value;
    }

    void opSliceAssign(T2)(T2[] values, size_t start, size_t end)
    if(!is(T2[] == T))
    {
        if(this._ssoUsedUp)
        {
            this._buffer[start..end] = values;
            return;
        }

        assert(end <= this._ssoLength, "Index out of bounds.");

        const count = (end - start);
        assert(values.length >= count, "Not enough values.");

        this._array[start..end] = values[0..count];
    }

    ref T opIndex()(size_t index)
    {
        if(this._ssoUsedUp)
            return this._buffer[index];

        assert(index < this._ssoLength, "Index out of bounds.");
        return this._sso[index];
    }

    T[] opIndex()()
    {
        return (this._ssoUsedUp) ? this._buffer[] : this._sso;
    }

    T[] opSlice()(size_t start, size_t end)
    {
        if(this._ssoUsedUp)
            return this._buffer[start..end];

        assert(end <= this._ssoLength, "Index out of bounds.");
        return this._sso[start..end];
    }

    void opOpAssign(string op, T2)(T2 right)
    if(op == "~")
    {
        if(!this._ssoUsedUp && this._ssoLength == this._sso.length)
        {
            this.length = this._sso.length + 1; // Transition into using the _buffer.
            this.length = this.length - 1; // Fix the length.
        }

        if(this._ssoUsedUp)
        {
            this._buffer ~= right;
            return;
        }

        this._sso[this._ssoLength++] = right;
    }

    bool opBinary(string op, T2)(T2 right)
    if(op == "in")
    {
        if(this._ssoUsedUp)
            return right in this._buffer;

        import std.algorithm : any;
        return this[].any!(item => item == right);
    }
}
@("BufferArray")
unittest
{
    import std.algorithm : all;
    import fluent.asserts;

    alias Buffer = SsoBufferArray!(string, 4);

    Buffer b;

    void test()
    {
		b.length = 4;
		b.length.should.equal(4);
		assert(b[].all!(str => str is null));

        b[0] = "Hello!";
        b[0].should.equal("Hello!");
        
        b[2..4] = "World!";
        b[0..3].should.equal(["Hello!", null, "World!"]);
        b[3].should.equal(b[2]);

        b.clear();

        b ~= "Hello, ";
        b ~= "there ";
        b ~= "World!";
        b.length.should.equal(3);
        b[0..$].should.equal(["Hello, ", "there ", "World!"]);
    }

    b._ssoUsedUp.should.equal(false);
    test();
    b._ssoUsedUp.should.equal(false);

    b ~= "Goodbye, ";
    b ~= "World!";
    b.length.should.equal(5);
    b._ssoUsedUp.should.equal(true);
    b[0..$].should.equal(["Hello, ", "there ", "World!", "Goodbye, ", "World!"]);

    b.clear();
    b._ssoUsedUp.should.equal(true);
    test();
}