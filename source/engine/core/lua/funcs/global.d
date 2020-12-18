module engine.core.lua.funcs.global;

import engine.core.lua.funcs._import;

void setGlobal(ref LuaState lua, const(char)[] name)
{
    lua_setglobal(lua.handle, name.toStringz);
}

void getGlobal(ref LuaState lua, const(char)[] name)
{
    lua_getglobal(lua.handle, name.toStringz);
}