module engine.core.lua.funcs._import;

public import std.string : fromStringz;
public import bindbc.lua;
public import engine.core.lua, engine.util;

void CHECK_LUA(int code)
{
    import std.format;
    assert(code == 0, "Lua returned: %s".format(code));
}

// In general LUA will copy strings, so making a GC copy using the normal toStringz, just so LUA can make *its* own copy, is stupid.
const(char)* toStringz(const(char)[] str)
{
    if(str.length == 0)
        return null;

    static char[] buffer;

    if(str.length + 1 >= buffer.length)
        buffer.length = (str.length + 1) * 2;

    buffer[0..str.length] = str[];
    buffer[str.length] = '\0';
    return buffer.ptr;
}

const(char)* toStringzPerm(const(char)[] str)
{
    import std.string : stdStringz = toStringz;
    return stdStringz(str);
}