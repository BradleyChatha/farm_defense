module game.common.structures;

import std.experimental.allocator, std.experimental.allocator.building_blocks, std.experimental.logger;
import game.common.maths;

public import std.experimental.allocator : chooseAtRuntime;

struct BitmappedBookkeeper(size_t MaxValues = chooseAtRuntime)
{
    static if(MaxValues != chooseAtRuntime)
    {
        enum BOOKKEEPING_BYTES = amountDivideMagnitudeRounded(MaxValues, 8);
        private ubyte[BOOKKEEPING_BYTES] _bookkeeping;
    }
    else
    {
        private ubyte[] _bookkeepingBuffer;
        private ubyte[] _bookkeeping;
    }

    private bool _setup;

    @disable
    this(this){}

    void setup()
    {
        this._setup = true;
        // TODO: This is to enforce usage of `setup`, for when we actually need this function in the future.
    }

    static if(MaxValues == chooseAtRuntime)
    void setLengthInBits(size_t bitCount)
    {
        const byteCount = amountDivideMagnitudeRounded(bitCount, 8);
        if(byteCount > this._bookkeepingBuffer.length)
            this._bookkeepingBuffer.length = byteCount * 2;
        else
            this._bookkeepingBuffer[byteCount..$] = 0;

        this._bookkeeping = this._bookkeepingBuffer[0..byteCount];
    }

    void setBitRange(bool BitValue)(size_t startBit, size_t bitsToSet)
    {
        assert(this._setup, "Please call .setup() first.");
        assert(startBit < this._bookkeeping.length * 8);
        
        auto startByte = startBit / 8;
             startBit  = startBit % 8;
        auto byteI     = startByte;
        auto bitI      = startBit;
        for(auto i = 0; i < bitsToSet; i++)
        {
            static if(BitValue)
            {
                assert((this._bookkeeping[byteI] & (1 << bitI)) == 0, "Bit is already set.");
                this._bookkeeping[byteI] |= (1 << bitI++);
            }
            else
            {
                assert((this._bookkeeping[byteI] & (1 << bitI)) != 0, "Bit is already unset.");
                this._bookkeeping[byteI] &= ~(1 << bitI++);
            }

            if(bitI == 8)
            {
                bitI = 0;
                byteI++;

                assert(i == bitsToSet - 1 || byteI < this._bookkeeping.length, "Out of bounds.");
            }
        }
    }

    bool markNextNBits(ref size_t startBit, size_t n)
    {
        assert(this._setup, "Please call .setup() first.");

        size_t byteI    = 0;
        size_t bitI     = 0;
        size_t setCount = 0;

        for(auto i = byteI * 8; i < this._bookkeeping.length * 8; i++)
        {
            if((this._bookkeeping[byteI] & (1 << bitI++)) == 0)
            {
                setCount++;
                if(setCount == 1)
                    startBit = i;

                if(setCount == n)
                    break;
            }
            else
                setCount = 0;

            if(bitI == 8)
            {
                bitI = 0;
                byteI++;
                assert(i == (this._bookkeeping.length * 8) - 1 || byteI < this._bookkeeping.length, "Out of bounds.");
            }
        }

        if(setCount != n)
            return false;
        
        this.setBitRange!true(startBit, n);
        return true;
    }
}
///
@("Bookkeeper marking test")
unittest
{
    import std.format : format;

    auto keeper = BitmappedBookkeeper!64();
    keeper.setup();

    keeper.setBitRange!true(0, 4);
    assert(keeper._bookkeeping[0] == 0b00001111);

    keeper.setBitRange!false(0, 2);
    assert(keeper._bookkeeping[0] == 0b00001100);

    size_t startBit;
    assert(keeper.markNextNBits(startBit, 1));
    assert(startBit == 0, "%s".format(startBit));
    assert(keeper._bookkeeping[0] == 0b00001101);

    assert(keeper.markNextNBits(startBit, 2));
    assert(startBit == 4, "%s".format(startBit));
    assert(keeper._bookkeeping[0] == 0b00111101);

    assert(keeper.markNextNBits(startBit, 1));
    assert(startBit == 1);
    assert(keeper._bookkeeping[0] == 0b00111111);

    assert(!keeper.markNextNBits(startBit, 900));

    assert(keeper.markNextNBits(startBit, 3)); // Cross-byte marking
    assert(startBit == 6);
    assert(keeper._bookkeeping[0] == 0b11111111);
    assert(keeper._bookkeeping[1] == 0b00000001);

    assert(keeper.markNextNBits(startBit, 7)); // Fill up this byte
    assert(startBit == 9, "%s".format(startBit));

    assert(keeper.markNextNBits(startBit, 17));
    assert(startBit == 16, "%s".format(startBit));
    assert(keeper._bookkeeping[2] == 0b11111111);
    assert(keeper._bookkeeping[3] == 0b11111111);
    assert(keeper._bookkeeping[4] == 0b00000001);
}

@("Cross-byte issue")
unittest
{
    import std.format : format;

    auto keeper = BitmappedBookkeeper!16();
    keeper.setup();
    keeper._bookkeeping[0] = 0b11111111;
    keeper._bookkeeping[1] = 0b00000001;

    size_t startBit;
    assert(keeper.markNextNBits(startBit, 1));
    assert(startBit == 9, "%s".format(startBit));
}

template MemoryPoolAllocator(ObjectT, size_t ObjectsPerRegion = 100)
{
    static if(is(ObjectT == class))
    {
        alias PointerT    = ObjectT;
        enum  OBJECT_SIZE = __traits(classInstanceSize, ObjectT);
    }
    else
    {
        alias PointerT    = ObjectT*;
        enum  OBJECT_SIZE = ObjectT.sizeof;
    }

    enum BYTES_PER_REGION = OBJECT_SIZE * 100;

    // Allocator list of free lists built ontop of GC-allocated regions, each region having enough memory for ObjectsPerRegion amount of ObjectTs.
    alias MemoryPoolAllocator = AllocatorList!(
        (size_t n) => FreeList!(
            Region!GCAllocator, 
            OBJECT_SIZE, 
            max(size_t.sizeof, OBJECT_SIZE) // MaxSize must at least contain a pointer.
        )
        (Region!GCAllocator(max(n, BYTES_PER_REGION)))
    );
}

struct PooledObject(ObjectT)
{
    static if(is(ObjectT == class))
        alias FieldT = ObjectT;
    else
        alias FieldT = ObjectT*;

    FieldT value;
    alias value this;

    bool isValid() const
    {
        return this.value !is null;
    }
}

struct MemoryPool(ObjectT, size_t ObjectsPerRegion)
{
    alias AllocatorT = MemoryPoolAllocator!(ObjectT, ObjectsPerRegion);

    private AllocatorT _allocator;

    PooledObject!ObjectT makeSingle(Args...)(Args args)
    out(r; r.isValid)
    {
        return PooledObject!ObjectT(this._allocator.make!ObjectT(args));
    }

    void free(ref PooledObject!ObjectT obj)
    {
        this._allocator.dispose(obj.value);
        obj.value = null;
        assert(!obj.isValid);
    }
}