module engine.core.threading.lock;

import core.atomic, core.thread;
import engine.core.logging;

// I want busy locks for a large portion of this game, because mutexes and stuff allow the OS to suspend my threads for ages.
// I don't want each lock to potentially take up several ms per call, so I'm sure most of you reading this understand why I've done this instead.

struct SimpleLock
{
    @disable this(this){}

    private bool _lock;

    static struct RAII
    {
        private SimpleLock* _lock;
        ~this()
        {
            if(this._lock !is null)
                this._lock.unlock();
        }
    }

    @safe @nogc
    void lock() nothrow
    {
        while(!cas(&this._lock, false, true)){}
    }

    @safe @nogc
    void unlock() nothrow
    {
        while(!cas(&this._lock, true, false)){}
    }

    @safe @nogc
    RAII lockRaii() nothrow return
    {
        this.lock();
        return RAII(&this);
    }
}

struct OwnedCountingLock
{
    @disable this(this){}

    private bool _lock;
    private uint _count;
    private Thread _threadWithLock;

    static struct RAII
    {
        private OwnedCountingLock* _lock;

        ~this()
        {
            if(this._lock !is null)
                this._lock.unlock();
        } 
    }

    @safe @nogc
    void lock() nothrow
    {
        if(atomicLoad(this._threadWithLock) is Thread.getThis())
        {
            this._count++;
            return;
        }

        while(!cas(&this._lock, false, true)){}
        atomicStore(this._threadWithLock, Thread.getThis());
        this._count = 1;
    }

    @safe @nogc
    RAII lockRaii() nothrow return
    {
        this.lock();
        return RAII(&this);
    }

    @safe @nogc
    void unlock() nothrow
    {
        assert(atomicLoad(this._threadWithLock) is Thread.getThis(), "This is being called from a thread that doesn't even have the lock!");
        assert(this._count != 0, "Too many unlock calls.");

        this._count--;
        if(this._count == 0)
        {
            while(!cas(&this._lock, true, false)){}
            atomicStore(this._threadWithLock, Thread.getThis());
        }
    }
}