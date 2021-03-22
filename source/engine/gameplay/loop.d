module engine.gameplay.loop;

import std.functional : toDelegate;
import std.datetime, std.datetime.stopwatch : StdStopWatch = StopWatch, StopWatchAutoStart = AutoStart;
import engine.core, engine.util, engine.gameplay, engine.vulkan, engine.window;

private bool g_loopRunning;

private enum MS_PER_FRAME = 16;
private enum MAX_FPS = 60;
private enum TIME_BETWEEN_LOG_FLUSH = 5.seconds;

private g_coreEventBus.HandleT g_loopWindowEventHandle;

void loopStart()
{
    loopRegisterEvents();
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

        g_window.handleEvents();

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
    g_coreEventBus.remove(g_loopWindowEventHandle);
}

private void loopRegisterEvents()
{
    g_loopWindowEventHandle = g_coreEventBus.on(CoreEventChannel.window, CoreEventType.windowEvent, (&loopOnWindowEvent).toDelegate);
}

private void loopOnWindowEvent(CoreMessage message)
{
    import bindbc.sdl;

    auto casted = cast(CoreWindowEventMessage)message;
    assert(casted !is null, "Message was not a CoreWindowEventMessage.");

    switch(casted.event.type)
    {
        case SDL_QUIT:
            logfInfo("Window is signalling to close, stopping game loop.");
            loopStop();
            break;

        default: break;
    }
}