module engine.core.logging.threadmain;

import std.stdio;
import core.thread;
import libasync;
import engine.core, engine.core.logging.sync, engine.core.logging.sink;

void startLoggingThread()
{
    assert(g_threadLogging is null, "Cannot create multiple logging threads.");

    auto t = new Thread(&threadMain);
    t.name = "logging";
    t.start();
    g_threadLogging = t;

    version(Engine_DebugLoggingThread)
    {
        logDebugWritefln("I'm the main thread!");
        logQueue(LogMessage.fromString("This is a test message: Logging thread has been started."));
        logFlush();
        logQueue(LogMessage.fromString("Hopefully this one won't show up until the last flush!"));
        logFlush();
        foreach(i; 0..10_000) Thread.yield();
        logQueue(LogMessage.fromString("But this should show up with another message!"));
        logFlush();
    }
}

private void threadMain()
{
    logDebugWritefln("Starting logging thread as thread %s", Thread.getThis().id);
    g_threadLoggingLoop = new EventLoop();
    scope(exit) g_threadLoggingLoop.exit();

    g_logNotifyAboutWork = new AsyncNotifier(g_threadLoggingLoop);
    g_logNotifyAboutWork.run(() => threadCatch!onDoWork);
    
    while(!g_shouldThreadsStop)
    {
        logDebugWritefln("Loop");

        // Reset state.
        g_threadUncaughtError = null;
        logThreadMainWorkDone();

        // Run the loop.
        g_threadLoggingLoop.loop(1.seconds);

        // And check if we caught anything interesting.
        if(g_threadUncaughtError !is null)
        {
            logDebugWritefln("Thread error caught.");
            writeln(
                "UNCAUGHT ", typeid(g_threadUncaughtError).toString(), " IN THREAD ", Thread.getThis().id, " (", Thread.getThis().name, ")",
                "\nMsg: ", g_threadUncaughtError.msg,
                "\n", g_threadUncaughtError.info.toString()
            );

            // If it's just a plain exception, we'll just carry on and ignore it.
            if(cast(Exception)g_threadUncaughtError is null)
                g_shouldThreadsStop = true; // If a thread has an Error then stop the program.
        }
    }
}

private void onDoWork()
{
    logDebugWritefln("START processing of log messages.");
    foreach(msg; logThreadMainGetLogs())
    {
        foreach(sink; g_logSinks)
            sink(msg);
    }
    logDebugWritefln("END processing of log messages.");
}