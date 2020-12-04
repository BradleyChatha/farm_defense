module engine.util.structures.bookkeeper;

import std.typecons : Nullable;
import stdx.allocator.building_blocks.null_allocator;
import engine.util.structures.bufferarray;

struct Booking
{
    size_t startByte;
    ubyte startBit;
    size_t bitCount;

    invariant(this.startBit < 8, "startBit cannot be 8 or greater.");

    bool isValid() const
    {
        return this.startByte != size_t.max;
    }

    size_t startInBits() const
    {
        return (this.startByte * 8) + this.startBit;
    }

    bool tryAddBits(size_t bits)
    {
        assert(this.isValid, "Invalid booking.");

        if(bits > this.bitCount)
            return false;

        const start = this.startInBits + bits;
        this.startByte = start / 8;
        this.startBit = start % 8;
        this.bitCount -= bits;

        return true;
    }

    static Booking invalid()
    {
        return Booking(size_t.max);
    }
}
///
@("Booking")
unittest
{
    import fluent.asserts;

    Booking b;

    b = Booking(0, 0, 16);
    b.startInBits.should.equal(0);
    b.bitCount.should.equal(16);
    
    b.tryAddBits(4).should.equal(true);
    b.startByte.should.equal(0);
    b.startBit.should.equal(4);
    b.startInBits.should.equal(4);
    b.bitCount.should.equal(12);

    b.tryAddBits(8).should.equal(true);
    b.startByte.should.equal(1);
    b.startBit.should.equal(4);
    b.startInBits.should.equal(12);
    b.bitCount.should.equal(4);

    b.tryAddBits(4).should.equal(true);
    b.startByte.should.equal(2);
    b.startBit.should.equal(0);
    b.startInBits.should.equal(16);
    b.bitCount.should.equal(0);

    b.tryAddBits(1).should.equal(false);
}

struct Bookkeeper(size_t Bits, Allocator = NullAllocator)
{
    @disable this(this){}

    private
    {        
        Booking _earliestUnsetBooking;
        static if(Bits != 0)
        {
            enum Bytes = (Bits % 8 == 0) ? Bits / 8 : (Bits + (8 - (Bits % 8))) / 8;
            ubyte[Bytes] _bytes;
            enum _maxBits = Bits;
        }
        else
        {
            static if(is(Allocator == NullAllocator))
                ubyte[] _bytes;
            else
                BufferArray!(ubyte, Allocator) _bytes;
            
            size_t _maxBits;
        }

        bool getBit(ubyte byte_, size_t bitIndex)
        {
            assert(bitIndex < 8);
            return (byte_ & (1 << bitIndex)) > 0;
        }

        bool getBit(size_t bitIndex)
        {
            return this.getBit(this._bytes[bitIndex / 8], bitIndex % 8);
        }

        size_t countEmptyConsecutiveBits(size_t startingBit, const size_t limit, ref bool hitLimit)
        {
            size_t count;

            size_t fixCount()
            {
                if(count > limit)
                    count = limit;

                if(startingBit + count > this._maxBits)
                {
                    hitLimit = true;
                    return (this._maxBits - startingBit);
                }
                else
                {
                    hitLimit = false;
                    return count;
                }
            }

            // Count start byte
            auto byte_ = this._bytes[startingBit / 8];
            bool skippedSetBits = false;
            foreach(i; startingBit % 8..8)
            {
                if(this.getBit(byte_, i) && !skippedSetBits)
                    continue;

                skippedSetBits = true;
                if(!this.getBit(byte_, i))
                {
                    count++;
                    if(count == limit)
                        return fixCount();
                }
            }

            if(this.getBit(byte_, 7)) // Check if we can't leak over into other bytes.
                return fixCount();

            // Keep counting bytes.
            for(size_t i = (startingBit / 8) + 1; i < this._bytes.length; i++)
            {
                if(count >= limit)
                    return fixCount();

                byte_ = this._bytes[i];
                if(byte_ == 0xFF)
                    break;
                else if(byte_ == 0)
                {
                    count += 8;
                    continue;
                }

                foreach(j; 0..8)
                {
                    if(!this.getBit(byte_, j))
                        count++;
                    else
                        return fixCount();
                }
            }
            
            return fixCount();
        }

        Nullable!size_t findNextUnsetBit(size_t startingBit)
        {
            size_t bitCursor = startingBit % 8;
            for(size_t i = startingBit / 8; i < this._bytes.length; i++)
            {
                const byte_ = this._bytes[i];
                if(byte_ == 0xFF)
                {
                    bitCursor = 0;
                    continue;
                }

                for(; bitCursor < 8; bitCursor++)
                {
                    if(!this.getBit(byte_, bitCursor))
                        return typeof(return)((i * 8) + bitCursor);
                }
                bitCursor = 0;
            }

            return typeof(return).init;
        }
        
        Booking nextUnsetBooking(size_t availableBits)
        {
            if(this._earliestUnsetBooking == Booking.init)
                this._earliestUnsetBooking = Booking(0, 0, this._maxBits);

            if(!this._earliestUnsetBooking.isValid || availableBits == 0)
                return Booking.invalid;

            // Fast path: Earliest unset booking has enough bits.
            if(this._earliestUnsetBooking.bitCount >= availableBits)
            {
                auto result = this._earliestUnsetBooking;
                result.bitCount = availableBits;

                const success = this._earliestUnsetBooking.tryAddBits(availableBits);
                assert(success, "Shouldn't fail here.");

                this.markBookingAs!true(result); // Otherwise nextEarliestUnsetBooking fails.
                if(this._earliestUnsetBooking.bitCount == 0)
                    this._earliestUnsetBooking = this.nextEarliestUnsetBooking();

                return result;
            }

            // Slow path: Earliest unset booking doesn't have enough bits.
            auto start = this.findNextUnsetBit(this._earliestUnsetBooking.startInBits + this._earliestUnsetBooking.bitCount);
            while(!start.isNull)
            {
                bool hitLimit;
                const count = this.countEmptyConsecutiveBits(start.get, availableBits, hitLimit);
                if(hitLimit)
                    break;

                if(count >= availableBits)
                    return Booking(start / 8, start % 8, availableBits);

                start = this.findNextUnsetBit(start.get + count);
            }

            return Booking.invalid;
        }

        Booking nextEarliestUnsetBooking()
        {
            const index = this.findNextUnsetBit(this._earliestUnsetBooking.startInBits);
            if(index.isNull)
                return Booking.invalid;
            
            bool _;
            const count = this.countEmptyConsecutiveBits(index.get, size_t.max, _);

            return Booking(index / 8, index % 8, count);
        }

        void markBookingAs(bool setUnset)(Booking booking)
        {
            import std.algorithm : min;

            const length = booking.bitCount;
            const bitsInStartByte = min(8 - booking.startBit, length);
            const bitsInEndByte = (length - bitsInStartByte) % 8;
            const emptyBytesInBetween = ((length - bitsInStartByte) - bitsInEndByte) / 8;

            static if(!setUnset)
            {
                if(booking.startInBits < this._earliestUnsetBooking.startInBits)
                {
                    // Case: If this booking is directly behind the earliestUnsetBooking, we can just combine them into one.
                    if(booking.startInBits + booking.bitCount == this._earliestUnsetBooking.startInBits)
                        booking.bitCount += this._earliestUnsetBooking.bitCount;
                    
                    this._earliestUnsetBooking = booking;
                }
            }

            ubyte makeBitMask(ubyte startBit, ubyte bitCount)
            {
                ubyte result;

                foreach(i; 0..bitCount)
                    result |= (1 << startBit) << i;

                return result;
            }

            void applyBitMask(ref ubyte to, ubyte bitMask)
            {
                static if(setUnset)
                    to |= bitMask;
                else
                    to &= ~cast(int)bitMask;
            }

            size_t byteCursor = booking.startByte;

            // Set start byte
            auto bitMask = makeBitMask(booking.startBit, cast(ubyte)bitsInStartByte);
            applyBitMask(this._bytes[byteCursor++], bitMask);

            if(length - bitsInStartByte == 0)
                return;

            // Set inbetween bytes
            if(length - bitsInStartByte > 8)
            {
                foreach(i; 0..emptyBytesInBetween)
                    applyBitMask(this._bytes[byteCursor++], 0xFF);
            }
            
            // Set end byte
            bitMask = makeBitMask(0, bitsInEndByte);
            applyBitMask(this._bytes[byteCursor], bitMask);

            // Case: The booking is directly in front of earliestUnsetBooking
            static if(!setUnset)
            {
                if(booking.startInBits == this._earliestUnsetBooking.startInBits + this._earliestUnsetBooking.bitCount)
                {
                    this._earliestUnsetBooking.bitCount += booking.bitCount;
                    
                    bool _;
                    const amount = this.countEmptyConsecutiveBits(
                        this._earliestUnsetBooking.startInBits + this._earliestUnsetBooking.bitCount, 
                        size_t.max, 
                        _
                    );

                    this._earliestUnsetBooking.bitCount += amount;
                }
            }
        }
    }

    static if(Bits == 0)
    @disable this(){}

    static if(Bits == 0)
    this(size_t bits)
    {
        this.resize(bits);
    }

    static if(Bits == 0)
    void resize(size_t bits)
    {
        if(bits == 0)
            bits = 1;

        this._maxBits = bits;
        this._bytes.length = (bits + 7) / 8;

        if(this._earliestUnsetBooking.startInBits + this._earliestUnsetBooking.bitCount > this._maxBits)
            this._earliestUnsetBooking.bitCount = (this._maxBits - this._earliestUnsetBooking.startInBits);
    }

    Booking allocate(size_t bitCount)
    {
        auto booking = this.nextUnsetBooking(bitCount);
        if(!booking.isValid)
            return Booking.invalid;

        this.markBookingAs!true(booking);
        return booking;
    }

    void free(ref Booking booking)
    {
        assert(booking.isValid, "Invalid booking");
        this.markBookingAs!false(booking);
        booking = Booking.invalid;
    }
}
@("Bookkeeper")
unittest
{
    import fluent.asserts;

    Bookkeeper!32 b;

    // Allocate from earlistUnsetBooking
    auto booking = b.allocate(4);
    booking.startInBits.should.equal(0);
    booking.bitCount.should.equal(4);
    b._earliestUnsetBooking.startInBits.should.equal(4);
    b._earliestUnsetBooking.bitCount.should.equal(28);
    b._bytes[0].should.equal(0b0000_1111);

    // Ditto, just to make sure it works right.
    auto booking2 = b.allocate(4);
    booking2.startInBits.should.equal(4);
    booking2.bitCount.should.equal(4);
    b._earliestUnsetBooking.startInBits.should.equal(8);
    b._earliestUnsetBooking.bitCount.should.equal(24);
    b._bytes[0].should.equal(0xFF);

    // Allocate size larger than earlisetUnsetBooking. Also allocate across multiple bytes.
    b.free(booking);
    booking.isValid.should.not.equal(true);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(4);
    b._bytes[0].should.equal(0b1111_0000);
    
    auto booking3 = b.allocate(22);
    booking3.startInBits.should.equal(8);
    booking3.bitCount.should.equal(22);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(4);
    b._bytes[0].should.equal(0b1111_0000);
    b._bytes[1].should.equal(b._bytes[2]);
    b._bytes[2].should.equal(0xFF);
    b._bytes[3].should.equal(0b0011_1111);

    // Allocate the entirety of earliestUnsetBooking and test that is finds the correct empty range.
    booking = b.allocate(4);
    booking.startInBits.should.equal(0);
    booking.bitCount.should.equal(4);
    b._earliestUnsetBooking.startInBits.should.equal(30);
    b._earliestUnsetBooking.bitCount.should.equal(2);
    b._bytes[0].should.equal(0xFF);

    // Allocate more than we have room for.
    b.allocate(3).isValid.should.not.equal(true);

    // Set earliestUnsetBooking (not adjacent)
    b.free(booking2);
    b._bytes[0].should.equal(0b0000_1111);
    b._bytes[1].should.equal(b._bytes[2]);
    b._bytes[2].should.equal(0xFF);
    b._bytes[3].should.equal(0b0011_1111);
    b._earliestUnsetBooking.startInBits.should.equal(4);
    b._earliestUnsetBooking.bitCount.should.equal(4);

    // Set earliestUnsetBooking (merge before)
    b.free(booking);
    b._bytes[0].should.equal(0);
    b._bytes[1].should.equal(b._bytes[2]);
    b._bytes[2].should.equal(0xFF);
    b._bytes[3].should.equal(0b0011_1111);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(8);

    // Set earliestUnsetBooking (merge after)
    b.free(booking3);
    b._bytes[0].should.equal(0);
    b._bytes[1].should.equal(0);
    b._bytes[2].should.equal(0);
    b._bytes[3].should.equal(0);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(32);

    // Test bookkeeper that isn't a mulitple of 8
    Bookkeeper!30 b2;
    
    booking = b2.allocate(31);
    booking.isValid.should.not.equal(true);

    b2._earliestUnsetBooking.startInBits.should.equal(0);
    b2._earliestUnsetBooking.bitCount.should.equal(30);
}