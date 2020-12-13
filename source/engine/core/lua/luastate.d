module engine.core.lua.luastate;

import bindbc.lua;

struct LuaState
{
    @disable this(this){}

    private
    {
        lua_State* _state;
        bool _canClose;
    }

    package this(lua_State* state, bool canClose) nothrow
    {
        assert(state !is null);
        this._state = state;
        this._canClose = canClose;
        luaL_openlibs(state);
    }

    ~this() nothrow
    {
        if(this._state !is null && this._canClose)
            lua_close(this._state);
    }

    static LuaState create() nothrow
    {
        return LuaState(luaL_newstate(), true);
    }

    static LuaState wrap(lua_State* state) nothrow
    {
        return LuaState(state, false);
    }

    lua_State* handle() nothrow
    {
        return this._state;
    }
}