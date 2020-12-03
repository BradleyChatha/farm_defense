module engine.util.structures.bookkeeper;

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
            size_t unsetBitsInRange;
            size_t startByte;
            for(size_t i = this._earliestUnsetBooking.startByte; i < this._bytes.length; i++)
            {
                if(unsetBitsInRange >= availableBits)
                    break;

                const byte_ = this._bytes[i];
                if(byte_ == 0xFF)
                {
                    unsetBitsInRange = 0;
                    startByte = i + 1;
                    continue;
                }

                if(byte_ == 0)
                {
                    unsetBitsInRange += 8;
                    continue;
                }

                ubyte unsetBitsAtStartOfByte;
                bool skippedSetBits = false;
                foreach(i2; 0..8)
                {
                    if(unsetBitsInRange == 0)
                    {
                        if((byte_ & (1 << i2)) != 0 && !skippedSetBits)
                            continue;

                        skippedSetBits = true;
                    }
                    
                    if((byte_ & (1 << i2)) == 0)
                        unsetBitsAtStartOfByte++;
                    else
                        break;
                }

                unsetBitsInRange += unsetBitsAtStartOfByte;
                if(unsetBitsInRange < availableBits)
                {
                    startByte = i + 1;
                    unsetBitsInRange = 0;
                }
            }

            if(unsetBitsInRange < availableBits)
                return Booking.invalid;

            const byte_ = this._bytes[startByte];
            ubyte startBit;
            foreach(i; 0..8)
            {
                if((byte_ & (1 << i)) == 0)
                {
                    startBit = cast(ubyte)i;
                    break;
                }
            }

            const result = Booking(startByte, startBit, availableBits);
            return (result.startInBits + result.bitCount > this._maxBits) ? Booking.invalid : result;
        }

        Booking nextEarliestUnsetBooking()
        {
            auto earliestUnset = this.nextUnsetBooking(1); // Won't enter loop as the parent if statement should always be false in this case.

            // For the current byte, count how many bits are unset in a row from us, and more importantly, is it to the end of the byte?
            const bitsToCount = 8 - earliestUnset.startBit;
            const startByte = this._bytes[earliestUnset.startByte];
            size_t unsetBits;
            foreach(i; 0..bitsToCount)
            {
                if((startByte & (1 << (i + earliestUnset.startBit))) == 0)
                    unsetBits++;
                else
                    break;
            }

            earliestUnset.bitCount = unsetBits;
            if(unsetBits != bitsToCount)
                return earliestUnset;

            // We have the rest of the byte to ourself, meaning we can leak over into other bytes, so we need to check for that.
            size_t emptyBytes;
            ubyte semiEmptyByte = 0xFF;
            for(size_t i = earliestUnset.startByte + 1; i < this._bytes.length; i++)
            {
                const byte_ = this._bytes[i];
                if(byte_ == 0)
                {
                    emptyBytes++;
                    continue;
                }
                else if(byte_ == 0xFF)
                    break;
                else
                {
                    semiEmptyByte++;
                    break;
                }
            }

            // For the semi-empty byte, count how many on the LSB side are unset.
            unsetBits = 0;
            foreach(i; 0..8)
            {
                if((semiEmptyByte & (1 << i)) > 0)
                    break;

                unsetBits++;
            }

            earliestUnset.bitCount += (emptyBytes * 8) + unsetBits;
            if(earliestUnset.startInBits + earliestUnset.bitCount > this._maxBits)
                earliestUnset.bitCount = (this._maxBits - (earliestUnset.startInBits + earliestUnset.bitCount));

            return earliestUnset;
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
                    to &= ~bitMask;
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
                    // Esentially, all we're doing is temporarily moving our "cursor" to the end `booking`
                    // then invoking the logic to measure how much free space we have directl after the "cursor"
                    // then adding that free space into the earliestUnsetBooking.
                    this._earliestUnsetBooking.bitCount += booking.bitCount;
                    const old = this._earliestUnsetBooking;

                    const bits  = booking.startInBits + booking.bitCount;
                    this._earliestUnsetBooking = booking;
                    this._earliestUnsetBooking.startByte = bits / 8;
                    this._earliestUnsetBooking.startBit = bits % 8;
                    
                    const additionalSpace = this.nextEarliestUnsetBooking();
                    this._earliestUnsetBooking = old;
                    this._earliestUnsetBooking.bitCount += additionalSpace.bitCount;
                }
            }
        }
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
    b._earliestUnsetBooking.startInBits.should.equal(4);
    b._earliestUnsetBooking.bitCount.should.equal(4);

    // Set earliestUnsetBooking (merge before)
    b.free(booking);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(8);

    // Set earliestUnsetBooking (merge after)
    b.free(booking3);
    b._earliestUnsetBooking.startInBits.should.equal(0);
    b._earliestUnsetBooking.bitCount.should.equal(30);

    // Test bookkeeper that isn't a mulitple of 8
    Bookkeeper!30 b2;
    
    booking = b2.allocate(31);
    booking.isValid.should.not.equal(true);

    b2._earliestUnsetBooking.startInBits.should.equal(0);
    b2._earliestUnsetBooking.bitCount.should.equal(30);
}