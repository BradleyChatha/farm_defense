module engine.core.lua.funcs.stack;

import std.conv : to;
import std.traits : isNumeric, isFloatingPoint, isUnsigned;
import engine.core.lua.funcs._import;

struct Nil{}

// MISC

LuaRef makeRef(ref LuaState lua, int tableIndex = LUA_REGISTRYINDEX)
{
    auto guard = LuaStackGuard(lua, -1);
    return LuaRef(lua, tableIndex);
}

void pop(ref LuaState lua, int amount)
{
    lua_pop(lua.handle, amount);
}

int getTop(ref LuaState lua)
{
    return lua_gettop(lua.handle);
}

// PUSH

void push(T)(ref LuaState lua, T integer)
if(isNumeric!T && !isFloatingPoint!T)
{
    static if(isUnsigned!T)
        lua_pushunsigned(lua.handle, integer.to!lua_Unsigned);
    else
        lua_pushinteger(lua.handle, integer.to!lua_Integer);
}

void push(T)(ref LuaState lua, T floating)
if(isNumeric!T && isFloatingPoint!T)
{
    lua_pushnumber(lua.handle, floating.to!lua_Number);
}

void push(ref LuaState lua, bool b)
{
    lua_pushboolean(lua.handle, cast(int)b);
}

void push(ref LuaState lua, const(char)[] str)
{
    // NOTE: Lua creates a copy of the string.
    lua_pushlstring(lua.handle, str.ptr, str.length);
}

void push(ref LuaState lua, Nil nil)
{
    lua_pushnil(lua.handle);
}

// GET

const(char)[] toTempString(ref LuaState lua, int index)
{
    size_t length;
    scope ptr = lua_tolstring(lua.handle, index, &length);

    return (ptr is null) ? null : ptr[0..length];
}

string toGCString(ref LuaState lua, int index)
{
    auto str = lua.toTempString(index);
    return (str is null) ? null : str.idup;
}

string as(T)(ref LuaState lua, int index)
if(is(T == string))
{
    return lua.toGCString(index);
}

T as(T)(ref LuaState lua, int index)
if(isNumeric!T)
{
    static if(isFloatingPoint!T)
        return lua_tonumber(lua.handle, index).to!T;
    else static if(isUnsigned!T)
        return lua_tounsigned(lua.handle, index).to!T;
    else
        return lua_tointeger(lua.handle, index).to!T;
}

bool as(T)(ref LuaState lua, int index)
if(is(T == bool))
{
    return cast(bool)lua_toboolean(lua.handle, index);
}

// IS

int type(ref LuaState lua, int index)
{
    return lua_type(lua.handle, index);
}

bool isString(ref LuaState lua, int index)
{
    return cast(bool)lua_isstring(lua.handle, index);
}

bool isNumber(ref LuaState lua, int index)
{
    return cast(bool)lua_isnumber(lua.handle, index);
}

bool isTable(ref LuaState lua, int index)
{
    return cast(bool)lua_istable(lua.handle, index);
}

bool isFunction(ref LuaState lua, int index)
{
    return cast(bool)lua_isfunction(lua.handle, index);
}

bool isNil(ref LuaState lua, int index)
{
    return cast(bool)lua_isnil(lua.handle, index);
}