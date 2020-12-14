module engine.core.lua.globals;

import engine.core.lua;

LuaState g_luaState;

void globalLuaStateInit()
{
    g_luaState = LuaState.create();
}