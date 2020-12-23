module engine.core.profile.output;

import std.datetime : SysTime;
import engine.core.profile, engine.core.profile.globals;

alias ProfileFlushSinkFactory = IProfileSink delegate();

package __gshared ProfileFlushSinkFactory[] g_profileSinks;

interface IProfileSink
{
    void start(string threadName, SysTime initTime);
    void push(ProfileBlock block);
    void end();
}

void profileAddSinkFactory(ProfileFlushSinkFactory sink)
{
    g_profileSinks ~= sink;
}

void profileFlush()
{
    // Profiling is a dev-only feature, speed isn't of importance, only data.
    version(Engine_Profile)
    {
        IProfileSink[] sinks;
        foreach(factory; g_profileSinks)
        {
            auto sink = factory();
            sink.start(g_profileThreadName, g_profileInitTime);
            sinks ~= sink;
        }

        scope(exit) foreach(sink; sinks) sink.end();

        foreach(block; g_profileFinishedBlocks[0..g_profileFinishedBlocksCount])
        {
            foreach(sink; sinks)
                sink.push(block);
        }

        g_profileFinishedBlocksCount = 0;
    }
}