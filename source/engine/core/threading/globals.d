module engine.core.threading.globals;

import core.thread;
import libasync;

__gshared bool g_shouldThreadsStop; // So infinite-loop threads have an exit condition.

__gshared Thread g_threadLogging;
__gshared EventLoop g_threadLoggingLoop;