module game.common.structures;

import stdx.allocator, stdx.allocator.building_blocks, std.experimental.logger;
import game.common.maths;

public import stdx.allocator : chooseAtRuntime;

/++
 + Generic pool allocator that works with multiple blocks of 4MB(default) memory.
 + ++/
alias PoolAllocatorBase(size_t RegionSize) = FreeTree!(
    AllocatorList!(
        n => Region!GCAllocator(RegionSize)
    )
);

/// ditto
alias PoolAllocator = PoolAllocatorBase!(1024 * 1024 * 4);

/++
 + Simple struct used to help with bookkeeping.
 + ++/
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
@("Numbers Numbers Numbers!")
unittest
{
    auto keeper = BitmappedBookkeeper!65_536();
    keeper.setup();

    size_t startBit;
    assert(keeper.markNextNBits(startBit, 7361));
    assert(startBit == 0);

    assert(keeper.markNextNBits(startBit, 7361));
    assert(startBit == 7361);

    keeper.setBitRange!false(0, 7361);
    keeper.setBitRange!false(7361, 7361);
}