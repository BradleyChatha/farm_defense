module engine.init._06_init_resources;

import engine.core, engine.util;

void init_06_init_resources()
{
    initPackageManager();
}

private void initPackageManager()
{
    auto guard = LuaStackGuard(g_luaState, 0);

    g_packages = new PackageManager();
    g_luaState.registerResourceLoader(g_packages);
}