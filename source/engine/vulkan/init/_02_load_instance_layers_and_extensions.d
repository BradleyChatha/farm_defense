module engine.vulkan.init._02_load_instance_layers_and_extensions;

import std.file : exists;
import std.string : fromStringz;
import bindbc.sdl : SDL_Vulkan_GetInstanceExtensions;
import engine.core, engine.vulkan, engine.window;

private immutable LUA_LOADER = "./assets/config/vulkan/instance_layers_and_extensions.lua";

package void _02_load_instance_layers_and_extensions()
{
    logfTrace("02. Loading instance layers and extensions.");

    if(g_window !is null)
        addSdlExtensions();

    if(LUA_LOADER.exists)
        addLuaExtensionsAndLayers();

    loadAll();
    printResults();
}

private void addSdlExtensions()
{
    logfTrace("02. g_window is not null, so loading required SDL extensions as well.");

    auto extensions = vkGetArrayJAST!SDL_Vulkan_GetInstanceExtensions(g_window.handle);

    foreach(str; extensions)
    {
        import std.string : fromStringz;
        const slice = str.fromStringz.idup;

        g_vkInstance.extensions.require(slice, VStringAndVersion(slice));
    }
}

private void addLuaExtensionsAndLayers()
{
    static struct Result
    {
        VStringAndVersion[] extensions;
        VStringAndVersion[] layers;
    }

    logfTrace("02. LUA loader found, executing it.");

    auto guard = LuaStackGuard(g_luaState, 0);

    g_luaState.loadFile(LUA_LOADER);
    g_luaState.pcall(0, 1).enforceOk;
    auto result = g_luaState.asEx!Result(-1).enforceOkValue;
    g_luaState.pop(1);

    foreach(ext; result.extensions)
        g_vkInstance.extensions.require(ext.name, VStringAndVersion(ext.name)).isOptional = ext.isOptional;

    foreach(layer; result.layers)
        g_vkInstance.layers.require(layer.name, VStringAndVersion(layer.name)).isOptional = layer.isOptional;
}

private void loadAll()
{
    import std.algorithm : map, joiner;
    logfTrace("02. Loading list of supported layers and extensions.");

    auto extensions = vkGetArrayJAST!vkEnumerateInstanceExtensionProperties(null);
    auto layers = vkGetArrayJAST!vkEnumerateInstanceLayerProperties();

    auto expectedExtensions = g_vkInstance.extensions.dup;
    auto expectedLayers = g_vkInstance.layers.dup;

    // Not worth functionising this tiny piece of very specific code.
    foreach(ext; extensions)
    {
        auto name     = (&ext.extensionName[0]).fromStringz.idup;
        bool exists   = (name in g_vkInstance.extensions) !is null;
        scope ptr     = &g_vkInstance.extensions.require(name, VStringAndVersion(name));
        ptr.version_  = ext.specVersion;
        ptr.isEnabled = exists;
        expectedExtensions.remove(name);
    }

    foreach(layer; layers)
    {        
        auto name     = (&layer.layerName[0]).fromStringz.idup;
        bool exists   = (name in g_vkInstance.layers) !is null;
        scope ptr     = &g_vkInstance.layers.require(name, VStringAndVersion(name));
        ptr.version_  = layer.specVersion;
        ptr.isEnabled = exists;
        expectedLayers.remove(name);
    }

    if(expectedLayers.length > 0)
    {
        logfFatal(
            "02. The following required layers are not supported on this hardware: %s",
            expectedLayers.byValue.map!(l => "\t"~l.name).joiner("\n")
        );
        logForceFlush();
        throw new Exception("");
    }
    else if(expectedExtensions.length > 0)
    {
        logfFatal(
            "02. The following required extensions are not supported on this hardware: %s",
            expectedExtensions.byValue.map!(e => "\t"~e.name).joiner("\n")
        );
        logForceFlush();
        throw new Exception("");
    }
}

private void printResults()
{
    import std.algorithm : filter, sort;
    import std.array : Appender, array;
    import std.conv : to;

    Appender!(char[]) output;

    void toOutput(VStringAndVersion[string] values)
    {
        auto sorted = values.byValue.array;
        sort!"cast(int)a.isOptional + cast(int)a.isEnabled > cast(int)b.isOptional + cast(int)b.isEnabled"(sorted);

        foreach(v; sorted)
        {
            output.put("\t[");
            if(v.isEnabled)
                output.put('E');
            else if(v.isOptional)
                output.put('O');
            else
                output.put('U');
            output.put("] ");
            output.put(v.name);
            output.put(" v");
            output.put(v.version_.to!string);
            output.put('\n');
        }
    }

    toOutput(g_vkInstance.layers);
    logfDebug("02. Layers:\n%s", output.data);

    output.clear();
    toOutput(g_vkInstance.extensions);
    logfDebug("02. Extensions:\n%s", output.data);
}