module engine.core.lua.luastate;

import bindbc.lua;

struct LuaState
{
    @disable this(this){}

    private
    {
        lua_State* _state;
    }

    package this(lua_State* state)
    {
        assert(state !is null);
        this._state = state;
        luaL_openlibs(state);
    }

    ~this()
    {
        if(this._state !is null)
            lua_close(this._state);
    }

    static LuaState create()
    {
        return LuaState(luaL_newstate());
    }

    lua_State* handle()
    {
        return this._state;
    }
}