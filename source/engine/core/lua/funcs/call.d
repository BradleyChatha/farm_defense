module engine.core.lua.funcs.call;

import engine.core.lua.funcs._import;

Result!void pcall(ref LuaState lua, int argCount, int resultCount, int msgh = 0)
{
    auto guard = LuaStackGuard(lua, resultCount - (argCount + 1)); // + 1 to include the function on the stack.

    const result = lua_pcall(lua.handle, argCount, resultCount, msgh);
    if(result == LUA_ERRRUN || result == LUA_ERRERR)
    {
        const msg = lua.toGCString(-1);
        lua.pop(1);
        guard.delta = -(argCount + 1);
        return Result!void.failure(msg);
    }

    CHECK_LUA(result);
    return Result!void.ok();
}

void register(ref LuaState lua, string libName, const luaL_Reg[] funcs)
{
    assert(funcs.length > 0, "No funcs.");
    assert(funcs[$-1] == luaL_Reg(null, null), "The last element must always be the sentinal value (because passing a length was too hard for the API designers).");
    luaL_register(lua.handle, libName.toStringz, funcs.ptr);
}

int error(ref LuaState lua, const(char)[] error) nothrow
{
    lua.push(error);
    return lua_error(lua.handle);
}