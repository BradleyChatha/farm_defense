module engine.core.logging.sync;

import core.atomic;
import libasync;
import engine.core, engine.util;

// Multiple producer, single consumer message queueing.
//
// Goal is to make calls to logging functions fast and low-cost, while still being able to support
// multiple logging backends of varying speeds.
//
// Thread A gets the lock, uploads their lock data, then signals to the logging thread that there's work to do.
// Thread B enters a busy loop to get the lock in the meantime.
// Logging thread gets signal for work, pushes all logging data into sinks, and then releases the lock.
// Thread B now gets the lock and the cycle repeats itself.
//
// Main thing of importance is: The logging thread is responsible for releasing the lock, not the thread that got the lock in the first place.

alias LogQueue = BufferArray!LogMessage;

// Thread-global, used to communicate with the logging thread.
private __gshared bool          g_logQueueLock = true; // Set to false once the logging thread is setup.
private __gshared LogQueue      g_logQueue;
package __gshared AsyncNotifier g_logNotifyAboutWork;

// Thread-local, used to store data until we can push it to the logging thread.
private LogQueue g_logLocalQueue;

// Functions
bool logFlush()
{
    logDebugWritefln("Attempting flush.");

    // Assume we're under a use case where logging (at least in this form) isn't desired if the logging thread hasn't started up.
    if(g_threadLogging is null)
    {
        g_logLocalQueue.length = 0;
        return true;
    }

    if(!cas(&g_logQueueLock, false, true))
    {
        logDebugWritefln("Logging thread is busy.");
        return false;
    }
    logDebugWritefln("Acquired lock.");

    // We have the lock, so do whatever now.
    g_logQueue.length = g_logLocalQueue.length;
    g_logQueue[0..$] = g_logLocalQueue[0..$];
    g_logLocalQueue.length = 0;

    g_logNotifyAboutWork.trigger();

    return true;
}

void logForceFlush()
{
    while(!logFlush()){}
}

package void logQueue(LogMessage message)
{
    g_logLocalQueue ~= message;
}

package void logDebugWritefln(Args...)(string fmt, scope lazy Args args)
{
    import std.format : format;
    import std.stdio : writefln;
    import core.thread : Thread;

    version(Engine_DebugLoggingThread)
        writefln("[LogDbg] Thread %s: %s", Thread.getThis().id, fmt.format(args));
}

// Functions for logging thread.
package void logThreadMainGetQueueLock()
{
    while(!cas(&g_logQueueLock, false, true)){}
}

package void logThreadMainWorkDone()
{
    g_logQueue.length = 0;
    g_logQueueLock = false;
    logDebugWritefln("Logging thread is now free.");
}

package LogMessage[] logThreadMainGetLogs()
{
    return g_logQueue[0..$];
}