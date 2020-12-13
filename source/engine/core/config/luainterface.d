module engine.core.config.luainterface;

import engine.core.config, engine.core.lua, engine.util;

void registerConfigLibrary(ref LuaState state, string name)
{
    auto funcs = 
    [
        luaL_Reg("setString", &luaCFuncFor!(setString, Config)),
        luaL_Reg("getString", &luaCFuncFor!(getString, Config)),
        luaL_Reg(null, null)
    ];
    state.register(name, funcs);
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