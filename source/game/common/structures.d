module game.common.structures;

struct BitmappedBookkeeper(size_t MaxValues)
{
    import game.common.maths;
    enum BOOKKEEPING_BYTES = amountDivideMagnitudeRounded(MaxValues, 8);

    private ubyte[BOOKKEEPING_BYTES] _bookkeeping;

    @disable
    this(this){}

    void setBitRange(bool BitValue)(size_t startBit, size_t bitsToSet)
    {
        assert(startBit < this._bookkeeping.length * 8);
        
        auto startByte = startBit / 8;
             startBit  = startBit % 8;
        auto byteI     = startByte;
        auto bitI      = startBit;
        for(auto i = 0; i < bitsToSet; i++)
        {
            static if(BitValue)
                this._bookkeeping[byteI] |= (1 << bitI++);
            else
                this._bookkeeping[byteI] &= ~(1 << bitI++);

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
        size_t byteI      = 0;
        size_t bitI       = 0;
        size_t unsetCount = 0;
        for(auto i = 0; i < this._bookkeeping.length * 8; i++)
        {
            if((this._bookkeeping[byteI] & (1 << bitI++)) == 0)
            {
                unsetCount++;
                if(unsetCount == 1)
                    startBit = i;

                if(unsetCount == n)
                    break;
            }
            else
                unsetCount = 0;

            if(bitI == 8)
            {
                bitI = 0;
                byteI++;
                assert(i == (this._bookkeeping.length * 8) - 1 || byteI < this._bookkeeping.length, "Out of bounds.");
            }
        }

        if(unsetCount != n)
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
    keeper._bookkeeping[0] = 0b11111111;
    keeper._bookkeeping[1] = 0b00000001;

    size_t startBit;
    assert(keeper.markNextNBits(startBit, 1));
    assert(startBit == 9, "%s".format(startBit));
}