module commands.test;

import std.stdio;
import jcli, engine.core;
import common, globals;

@Command("test")
struct TestCommand
{
    void onExecute()
    {
        auto core = getCore();
        core.loadPackageFromFile("./assets/packages/core/package.sdl");
        logfTrace("\n%s", core.assetGraphToString);
        logForceFlush();
        core.executePipelines();
    }
}