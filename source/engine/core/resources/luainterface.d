module engine.core.resources.luainterface;

import std.algorithm : startsWith, splitter;
import engine.core, engine.util;

void registerResourceLoader(ref LuaState lua, PackageManager manager)
{
    auto guard = LuaStackGuard(lua, 0);

    // top = package.loaders
    lua.getGlobal("package");
    lua.push("loaders");
    lua.rawGet(-2);

    // package.loaders[#+1] = loader
    lua.pushWithUpvalues(&luaCFuncWithUpvalues!loader, cast(void*)manager);
    lua.rawSet(-2, cast(int)lua.rawLength(-2) + 1);

    // package and package.loaders are still on the stack
    lua.pop(2);
}

private int loader(ref LuaState lua, void* managerPtr)
{
    auto obj = cast(Object)managerPtr;
    auto manager = cast(PackageManager)obj;
    if(manager is null)
        return lua.error("Upvalue passed is not a PackageManager.");

    const path = lua.as!string(1);
    if(!path.startsWith("res:"))
    {
        lua.push("Require path does not begin with 'res:'. Assuming this loader is not to be used.");
        return 1;
    }

    auto split = path.splitter(':');
    split.popFront();
    if(split.empty)
    {
        lua.push("'res:' was specified but no path/name was provided.");
        return 1;
    }

    const code = manager.getOrNull!LuaScriptResource(split.front);
    auto result = lua.loadString(code.code);
    if(!result.isOk)
        lua.push(result.error);

    return 1;
}