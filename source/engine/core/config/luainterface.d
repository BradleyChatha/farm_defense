module engine.core.config.luainterface;

import engine.core.config, engine.core.lua, engine.util;

void registerConfigLibrary(ref LuaState state, string name)
{
    auto guard = LuaStackGuard(state, 0);

    auto funcs = 
    [
        luaL_Reg("setString", &luaCFuncWithContext!setString),
        luaL_Reg("getString", &luaCFuncWithContext!getString),
        luaL_Reg("setInteger", &luaCFuncWithContext!setInteger),
        luaL_Reg("getInteger", &luaCFuncWithContext!getInteger),
        luaL_Reg("setFloating", &luaCFuncWithContext!setFloating),
        luaL_Reg("getFloating", &luaCFuncWithContext!getFloating),
        luaL_Reg("setBoolean", &luaCFuncWithContext!setBoolean),
        luaL_Reg("getBoolean", &luaCFuncWithContext!getBoolean),
        luaL_Reg("serialiseTable", &luaCFuncWithContext!tableToConfig),
        luaL_Reg(null, null)
    ];
    state.register(name, funcs);
    state.pop(1);
}

private int set(int ValueLuaT, ValueDT)(Config ctx, ref LuaState lua)
{
    lua.checkType(1, LUA_TSTRING);
    lua.checkType(2, ValueLuaT);
    ctx.set(lua.as!string(1), lua.as!ValueDT(2));

    return 0;
}

private int get(ValueDT)(Config ctx, ref LuaState lua)
{
    lua.checkType(1, LUA_TSTRING);
    lua.push(ctx.getOrDefault!ValueDT(lua.as!string(1), lua.as!ValueDT(2)));

    return 1;
}

alias setString = set!(LUA_TSTRING, string);
alias getString = get!string;

alias setInteger = set!(LUA_TNUMBER, long);
alias getInteger = get!long;

alias setFloating = set!(LUA_TNUMBER, double);
alias getFloating = get!double;

alias setBoolean = set!(LUA_TBOOLEAN, bool);
alias getBoolean = get!bool;

private int tableToConfig(Config ctx, ref LuaState lua)
{
    lua.checkType(1, LUA_TTABLE);

    auto result = lua.loadLuaTableAsConfig(ctx);
    if(!result.isOk)
        return lua.error(result.error);

    return 0;
}