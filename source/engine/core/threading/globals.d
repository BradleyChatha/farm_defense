module engine.core.threading.globals;

import core.thread;
import std.datetime.stopwatch : StopWatch;
import libasync;

__gshared bool g_shouldThreadsStop; // So infinite-loop threads have an exit condition.

__gshared Thread g_threadLogging;
__gshared EventLoop g_threadLoggingLoop;

__gshared Thread g_threadMain;
__gshared StopWatch g_keepAliveStopwatch;