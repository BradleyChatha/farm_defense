module engine.init._12_load_packages;

import engine.core;

void init_12_load_packages()
{
    logfInfo("12. Loading packages.");
    g_packages.loadFromFile("./assets/packages/build/package.lst", "lst").enforceOk;
}