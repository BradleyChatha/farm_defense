module engine.init._00_init_globals;

import engine.core;

void init_00_init_globals()
{
    Config.instance();
    setupLua();
}

private void setupLua()
{
    globalLuaStateInit();
    g_luaState.registerConfigLibrary("Config");
    g_luaState.push(cast(void*)Config.instance);
    g_luaState.setGlobal("g_config");
}