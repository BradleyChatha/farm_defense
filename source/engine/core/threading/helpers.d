module engine.core.threading.helpers;

import engine.core.threading.threadlocal;

void threadCatch(alias F)()
{
    try F();
    catch(Throwable e) g_threadUncaughtError = e; // Each thread or higher-level abstraction will define their own behaviour for this.
}