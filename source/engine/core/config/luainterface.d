module engine.core.config.luainterface;

import engine.core.config, engine.core.lua, engine.util;

void registerConfigLibrary(ref LuaState state, string name)
{
    auto guard = LuaStackGuard(state, 0);

    auto funcs = 
    [
        luaL_Reg("setString", &luaCFuncWithContext!setString),
        luaL_Reg("getString", &luaCFuncWithContext!getString),
        luaL_Reg(null, null)
    ];
    state.register(name, funcs);
    state.pop(1);
}

private int setString(Config ctx, ref LuaState lua)
{
    lua.checkType(1, LUA_TSTRING);
    lua.checkType(2, LUA_TSTRING);
    ctx.set(lua.as!string(1), lua.as!string(2));

    return 0;
}

private int getString(Config ctx, ref LuaState lua)
{
    lua.checkType(1, LUA_TSTRING);
    lua.push(ctx.getOrDefault!string(lua.as!string(1), lua.as!string(2)));

    return 1;
}