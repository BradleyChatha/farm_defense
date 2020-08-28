module game.vulkan.framefuncs;

import game.vulkan;

// START aliases //
alias OnFrameChange   = void delegate(uint swapchainImageIndex);
enum INVALID_EVENT_ID = size_t.max;

// START globals //
private static OnFrameChange[] g_onFrameChangeCallbacks;

// START funcs //
size_t vkListenOnFrameChangeJAST(OnFrameChange func)
{
    g_onFrameChangeCallbacks ~= func;
    return g_onFrameChangeCallbacks.length - 1;
}

void vkUnlistenOnFrameChangeJAST(size_t id)
{
    // TODO: I kind of want to make a certain data structure for this first.
}

void vkEmitOnFrameChangeJAST(uint swapchainImageIndex)
{
    foreach(callback; g_onFrameChangeCallbacks)
        callback(swapchainImageIndex);
}

// START types //
struct EventCallback(FuncT)
{
    private size_t id = INVALID_EVENT_ID;
    private ulong  version_;
}

struct EventArray(FuncT)
{
    private
    {
        FuncT[] _callbacks;
        ulong[] _versions;
        size_t  _lastKnownNull;
    }

    static void create(scope ref typeof(this)* ptr)
    {
        ptr = new typeof(this);
        ptr.resize(512);
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
    EventArray!DummyFunc* array;
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