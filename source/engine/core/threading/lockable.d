module engine.core.threading.lockable;

import std.traits;
import core.atomic;
import engine.core.threading;

// If `threadSafe` is false, then this is just a zero-cost abstraction with the same interface as the actual functioning abstraction.
// This is purely to make it much easier for types with optional thread-safe support to access their variables, while still being zero-cost for non-thread-safe stuff.
struct Lockable(T, LockT = SimpleLock, IsThreadSafe threadSafe = IsThreadSafe.yes)
{
    @disable this(this){}

    alias ValueT = T;

    private LockT _lock;
    private T _value;

    @nogc
    T* lock() nothrow
    {
        version(threadSafe) this._lock.lock();
        return &this._value;
    }

    @nogc 
    void unlock() nothrow
    {
        version(threadSafe) this._lock.unlock();
    }

    static if(__traits(hasMember, LockT, "lockRaii"))
    {
        static struct RAII
        {
            T* value;
            private ReturnType!(LockT.lockRaii) raii;
        }

        RAII lockRaii()()
        {
            return RAII(&this._value, this._lock.lockRaii());
        }
    }
}