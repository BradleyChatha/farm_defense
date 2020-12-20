module engine.core.threading.helpers;

import core.time;
import engine.core.threading.threadlocal, engine.core.threading.globals;

private enum TIME_UNTIL_MAIN_DEEMED_UNRESPONSIVE = 60.seconds;

void threadCatch(alias F)()
{
    try F();
    catch(Throwable e) g_threadUncaughtError = e; // Each thread or higher-level abstraction will define their own behaviour for this.
}

void threadMainResetKeepAlive()
{
    g_keepAliveStopwatch.reset();
}

bool threadIsMainResponding()
{
    static bool wasPreviousCheckAFailure = false; // Handle the edge case of where the timer's value is being written and read at the same time
                                                  // by requiring it to fail twice in a row, which should lower the possiblity of it happening to near 0 in this instance.
    
    bool failed = g_keepAliveStopwatch.peek() >= TIME_UNTIL_MAIN_DEEMED_UNRESPONSIVE;
    if(!failed)
    {
        wasPreviousCheckAFailure = false;
        return true;
    }

    if(!wasPreviousCheckAFailure)
    {
        wasPreviousCheckAFailure = true;
        return true;
    }

    return false;
}