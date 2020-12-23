module engine.init._00_init_globals;

import std.exception : enforce;
import engine.core;

private const LOGGER_CONFIG_FILE = "./assets/config/loggers.lua";

void init_00_init_globals()
{
    import core.thread : Thread;
    g_threadMain = Thread.getThis();
    g_keepAliveStopwatch.start();
    threadMainResetKeepAlive();

    profileInit("main", true);
    profileFlushAddFileSink();

    Config.instance();
    setupLua();
    setupLogging();
}

private void setupLua()
{
    globalLuaStateInit();
    g_luaState.registerConfigLibrary("Config");
    g_luaState.push(cast(void*)Config.instance);
    g_luaState.setGlobal("g_config");
}

private void setupLogging()
{
    g_luaState.pushAsLuaTable!LogMessageStyle();
    g_luaState.setGlobal("LogMessageStyle");

    g_luaState.pushAsLuaTable!LogLevel();
    g_luaState.setGlobal("LogLevel");

    g_luaState.registerLoggingLibrary("Logger");

    g_luaState.loadLuaLoggingConfigFile(LOGGER_CONFIG_FILE);

    startLoggingThread();
    logDebug("Logging started");
    logForceFlush();
}