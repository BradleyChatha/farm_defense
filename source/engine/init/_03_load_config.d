module engine.init._03_load_config;

import engine.core;

private const ENGINE_CONFIG_FILE = "assets/config/engine.lua";

void init_03_load_config()
{
    loadEngineConfig();
    setConfigVariables();
}

private void loadEngineConfig()
{
    g_luaState.loadFile(ENGINE_CONFIG_FILE);
    g_luaState.pcall(0, 1).enforceOk;
    g_luaState.loadLuaTableAsConfig(Config.instance).enforceOk;
}

private void setConfigVariables()
{
    bool isDebug = false;
    debug isDebug = true;
    Config.instance.set("isDebugBuild", isDebug);
}