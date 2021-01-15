module engine.core.lua.luaref;

import bindbc.lua;
import engine.core.lua;

struct LuaRef
{
    @disable this(this){}

    private
    {
        LuaState* _state; // Might need to keep in mind the possiblity of this memory being moved...
                          // And logically, any LuaRefs that exist beyond the lifetime of a LuaState are *already* in a bad state, so don't worry about that.
        int _handle = LUA_NOREF;
        int _tableIndex;
    }

    this(ref LuaState state, int tableIndex = LUA_REGISTRYINDEX)
    {
        this._state = &state;
        this._tableIndex = tableIndex;
        this._handle = luaL_ref(state.handle, tableIndex);
        assert(this._handle != LUA_REFNIL, "The stack is empty, can't create a valid reference.");
    }

    ~this()
    {
        if(this._state !is null)
            luaL_unref(this._state.handle, this._tableIndex, this._handle);
    }

    package int handle()
    {
        return this._handle;
    }
}