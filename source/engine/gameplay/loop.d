module engine.gameplay.loop;

import std.datetime, std.datetime.stopwatch : StdStopWatch = StopWatch, StopWatchAutoStart = AutoStart;
import engine.core, engine.util, engine.gameplay, engine.vulkan;

private bool g_loopRunning;

private enum MS_PER_FRAME = 16;
private enum MAX_FPS = 60;
private enum TIME_BETWEEN_LOG_FLUSH = 5.seconds;

void loopStart()
{
    g_loopRunning = true;

    auto logFlushTimer = StdStopWatch(StopWatchAutoStart.yes);
    auto previousTime = Clock.currTime;
    size_t lag;
    while(g_loopRunning && !g_shouldThreadsStop)
    {
        const currentTime = Clock.currTime;
        const elapsed = currentTime - previousTime;
        previousTime = currentTime;
        lag += elapsed.total!"msecs";

        // TODO: Window input

        while(lag >= MS_PER_FRAME)
        {
            resourceGlobalOnFrame();
            resourcePerThreadOnFrame();
            threadMainResetKeepAlive();
            // TODO: Fixed Step Update
            const dt = GameTime(MS_PER_FRAME.msecs);
            lag -= MS_PER_FRAME;
        }

        if(logFlushTimer.peek >= TIME_BETWEEN_LOG_FLUSH)
        {
            if(logFlush())
                logFlushTimer.reset();
        }

        // TODO: Render
    }
    
    logFlush();
}

void loopStop()
{
    g_loopRunning = false;
}