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
        guard.delta = 0;
        return Result!void.failure(msg);
    }

    CHECK_LUA(result);
    return Result!void.ok();
}