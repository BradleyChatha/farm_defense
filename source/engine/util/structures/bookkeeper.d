module engine.util.structures.bookkeeper;

struct Bookkeeper(size_t Bits)
{
    @disable this(this){}

    private
    {
        static if(Bits != 0)
        {
            enum Bytes = (Bits % 8 == 0) ? Bits / 8 : (Bits + (8 - (Bits % 8))) / 8;
            ubyte[Bytes] _bytes;
            enum _maxBits = Bits;
        }
        else
        {
            ubyte[] _bytes;
            size_t _maxBits;
        }
    }
}