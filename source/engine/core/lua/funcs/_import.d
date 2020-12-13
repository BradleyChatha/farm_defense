module engine.core.lua.funcs._import;

public import std.string : fromStringz, toStringz;
public import bindbc.lua;
public import engine.core.lua, engine.util;

void CHECK_LUA(int code)
{
    import std.format;
    assert(code == 0, "Lua returned: %s".format(code));
}