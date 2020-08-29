module game.vulkan._events;

import std.traits : Parameters;
import std.experimental.logger;
import game.vulkan;

mixin template DefineEvent(string Name, alias CallbackT)
{
    alias CallbackTParams = Parameters!CallbackT;
    alias EventCallbackT  = EventCallback!CallbackT;

    mixin("private EventArray!(CallbackT) g_"~Name~";");
    mixin("alias "~Name~"   = CallbackT;");
    mixin("alias "~Name~"Id = EventCallback!CallbackT;");
    mixin("EventCallbackT vkListen"~Name~"JAST(CallbackT func){ return g_"~Name~".insert(func); }");
    mixin("bool vkUnlistenJAST(EventCallbackT event){ return g_"~Name~".remove(event); }");
    mixin("void vkEmit"~Name~"JAST(CallbackTParams params){ g_"~Name~".emit(params); }");
}

void vkInitEventsJAST()
{
    info("Initialising vulkan event system.");
    static foreach(member; __traits(allMembers, game.vulkan._events))
    {{
        static if(member[0..2] == "g_")
            mixin("typeof("~member~").create("~member~");");
    }}
}

// START aliases //
enum INVALID_EVENT_ID = size_t.max;
mixin DefineEvent!("OnFrameChange",       void delegate(uint swapchainImageIndex));
mixin DefineEvent!("OnSwapchainRecreate", void delegate(uint swapchainImageCount));

// START types //
struct EventCallback(FuncT)
{
    private size_t id = INVALID_EVENT_ID;
    private ulong  version_;
}

struct EventArray(FuncT)
{
    alias FuncTParams = Parameters!FuncT;

    private
    {
        FuncT[] _callbacks;
        ulong[] _versions;
        size_t  _lastKnownNull;
    }

    static void create(ref typeof(this) ptr)
    {
        ptr = typeof(this).init;
        ptr.resize(32);
    }

    EventCallback!FuncT insert(FuncT callback)
    {
        size_t index = this.findNextNullIndex();
        this._callbacks[index] = callback;

        return typeof(return)(index, this._versions[index]);
    }

    bool remove(EventCallback!FuncT event)
    {
        if(event.id       >= this._callbacks.length
        || event.id       == INVALID_EVENT_ID
        || event.version_ != this._versions[event.id])
            return false;

        this._callbacks[event.id] = null;
        this._versions[event.id]++;
        this._lastKnownNull = event.id;

        return true;
    }

    void emit(FuncTParams params)
    {
        foreach(callback; this._callbacks)
        {
            if(callback !is null)
                callback(params);
        }
    }

    private size_t findNextNullIndex()
    {
        for(size_t i = this._lastKnownNull; i < this._callbacks.length; i++)
        {
            if(this._callbacks[i] is null)
            {
                this._lastKnownNull = i;
                return i;
            }
        }

        // If we get to this point, then we have no empty spaces left, so grow the array.
        this._lastKnownNull = this._callbacks.length;
        this.resize(this._callbacks.length * 2);
        return this._lastKnownNull;
    }

    private void resize(size_t newSize)
    {
        this._callbacks.length = newSize;
        this._versions.length  = newSize;
    }
}
unittest
{
    alias DummyFunc = void delegate();
    EventArray!DummyFunc array;
    EventArray!DummyFunc.create(array);

    array.resize(2);
    assert(array.findNextNullIndex == 0);
    assert(array.findNextNullIndex == 0);

    auto id = array.insert((){});
    assert(array.findNextNullIndex == 1);
    assert(id.id == 0);
    assert(id.version_ == 0);

    auto id2 = array.insert((){});
    assert(array.findNextNullIndex == 2);
    assert(id2.id == 1);
    assert(id2.version_ == 0);

    assert(array.remove(id));
    assert(array.findNextNullIndex == 0);

    id = array.insert((){});
    assert(array.findNextNullIndex == 2);
    assert(id.id == 0);
    assert(id.version_ == 1);
}