module engine.core.lua.funcs.chunk_loading;

import engine.core.lua.funcs._import;

Result!void loadFile(ref LuaState lua, string file)
{
    import std.file : exists;
    
    auto guard = LuaStackGuard(lua, 1);

    if(!file.exists)
        return Result!void.failure("File '"~file~"' does not exist.");

    const result = luaL_loadfile(lua.handle, file.toStringz);
    if(result == LUA_ERRSYNTAX)
    {
        const msg = "In file '"~file~"': "~lua.toGCString(-1);
        lua.pop(1);
        guard.delta = 0;
        return Result!void.failure(msg);
    }
    
    CHECK_LUA(result);
    return Result!void.ok();
}

Result!void loadString(ref LuaState lua, const char[] str)
{
    auto guard = LuaStackGuard(lua, 1);

    const result = luaL_loadstring(lua.handle, str.toStringz);
    if(result == LUA_ERRSYNTAX)
    {
        const msg = "In code string: "~lua.toGCString(-1);
        lua.pop(1);
        guard.delta = 0;
        return Result!void.failure(msg);
    }

    CHECK_LUA(result);
    return Result!void.ok();
}