module engine.core.lua.funcs._import;

import std.traits;
public import std.string : fromStringz;
public import std.conv : to;
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

template luaTypeOf(T)
{
         static if(is(T == enum))            enum luaTypeOf = luaTypeOf!(OriginalType!T);
    else static if(is(T == typeof(null)))    enum luaTypeOf = LUA_TNIL;
    else static if(is(T == bool))            enum luaTypeOf = LUA_TBOOLEAN;
    else static if(is(T == void*))           enum luaTypeOf = LUA_TLIGHTUSERDATA;
    else static if(isNumeric!T)              enum luaTypeOf = LUA_TNUMBER;
    else static if(is(T == string))          enum luaTypeOf = LUA_TSTRING;
    else static assert(false, "Don't know the LUA type of "~T.stringof);
}