module engine.init._06_init_resources;

import engine.core, engine.util;

void init_06_init_resources()
{
    initPackageManager();
}

private void initPackageManager()
{
    auto guard = LuaStackGuard(g_luaState, 0);

    // TEMP
    auto manager = new PackageManager();
    g_luaState.registerResourceLoader(manager);

    manager.debugSetResource("script", new LuaScriptResource("return { name = 'monomi' }"));
    g_luaState.loadString(`
        local test = require('res:script')
        Logger.logDebug(test.name)
    `).enforceOk();
    g_luaState.pcall(0, 0).enforceOk();
    logForceFlush();
}