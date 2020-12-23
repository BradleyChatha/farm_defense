module engine.core.profile.input;

import std.datetime : Clock, SysTime;
import std.typecons : Flag;
import engine.core.profile.globals, engine.core.profile;

alias ProfileCanRestart = Flag!"allowRestart";

private void handleRestart(string name, ProfileCanRestart canRestart)
{
    if(!canRestart)
        return;
    assert((name in g_profileActiveBlocks) is null, "Profile block '"~name~"' is already active, and `canRestart` is `no`.");
}

private ProfileBlock* getActiveBlock(string name)
{
    auto ptr = (name in g_profileActiveBlocks);
    assert(ptr !is null, "Profile block '"~name~"' isn't active.");
    return ptr;
}

private ProfileBlock getAndRemoveActiveBlock(string name)
{
    auto ptr = getActiveBlock(name);
    g_profileActiveBlocks.remove(name);

    return *ptr;
}

private void pushFinishedBlock(ProfileBlock block)
{
    block.time.end = Clock.currTime;
    if(g_profileFinishedBlocksCount >= g_profileFinishedBlocks.length)
        profileFlush();
    g_profileFinishedBlocks[g_profileFinishedBlocksCount++] = block;
}

private size_t pushValue(ProfileBlock* block, ProfileValue value)
in(block !is null, "Block is null")
{
    assert(block.valueCount < block.values.length, "Ran out of room for another value.");
    block.values[block.valueCount++] = value;
    return block.valueCount - 1;
}

private ProfileValue* getValue(ProfileBlock* block, size_t index, ProfileValue.Kind kind)
in(block !is null, "Block is null")
out(ptr; ptr !is null, "Output value was null")
{
    import std.conv : to;
    assert(index < block.valueCount, "Index out of bounds.");

    auto ptr = &block.values[index];
    assert(ptr.kind == kind, 
        "Value #"~index.to!string~" for block '"~block.name~"' is "~ptr.kind.to!string~" not "~kind.to!string
    );

    return ptr;
}

void profileInit(string threadName, bool setInitTime = false)
{
    g_profileThreadName = threadName;
    if(setInitTime)
        g_profileInitTime = Clock.currTime;
}

void profileStart(string blockName, ProfileCanRestart canRestart = ProfileCanRestart.no)
{
    version(Engine_Profile)
    {
        handleRestart(blockName, canRestart);
        auto block = ProfileBlock(blockName, ProfileStartEnd(null, Clock.currTime));
        g_profileActiveBlocks[blockName] = block;
    }
}

void profileEnd(string blockName)
{
    version(Engine_Profile)
    {
        auto block = getAndRemoveActiveBlock(blockName);
        foreach(ref value; block.values[0..block.valueCount])
        {
            if(value.isStartEnd && value.startEndValue.end == SysTime.init)
                value.startEndValue.end = Clock.currTime;
        }
        pushFinishedBlock(block);
    }
}

size_t profileStartTimer(string blockName, string timerName)
{
    version(Engine_Profile)
    {
        ProfileStartEnd timer;
        timer.start = Clock.currTime;
        timer.name = timerName;

        auto ptr = getActiveBlock(blockName);
        return pushValue(ptr, ProfileValue(timer));
    }
    else
        return size_t.max;
}

void profileEndTimer(string blockName, size_t index)
{
    version(Engine_Profile)
    {
        auto block = getActiveBlock(blockName);
        auto value = getValue(block, index, ProfileValue.Kind.startEnd);
        assert(value.startEndValue.end == SysTime.init, "Timer has already stopped?");
        value.startEndValue.end = Clock.currTime;
    }
}