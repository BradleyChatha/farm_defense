module engine.core.lua.funcs.stack;

import std.conv : to;
import std.traits : isNumeric, isFloatingPoint, isUnsigned, OriginalType;
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

void insert(ref LuaState lua, int index)
{
    lua_insert(lua.handle, index);
}

void remove(ref LuaState lua, int index) nothrow
{
    lua_remove(lua.handle, index);
}

int getTop(ref LuaState lua)
{
    return lua_gettop(lua.handle);
}

void setTop(ref LuaState lua, int top)
{
    lua_settop(lua.handle, top);
}

// PUSH

void push(T)(ref LuaState lua, T integer)
if(isNumeric!T && !isFloatingPoint!T)
{
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

void push(ref LuaState lua, const(char)[] str) nothrow
{
    // NOTE: Lua creates a copy of the string.
    lua_pushlstring(lua.handle, str.ptr, str.length);
}

void push(ref LuaState lua, Nil nil)
{
    lua_pushnil(lua.handle);
}

void push(ref LuaState lua, void* lightUserData)
{
    // NOTE: The GC can't scan the LUA stack, so keep a reference around yourself.
    lua_pushlightuserdata(lua.handle, lightUserData);
}

void push(E)(ref LuaState lua, E value)
if(is(E == enum))
{
    lua.push(cast(OriginalType!E)value);
}

void pushWithUpvalues(Args...)(ref LuaState lua, lua_CFunction func, Args upvalues)
{
    auto guard = LuaStackGuard(lua, 1);
    foreach(v; upvalues)
        lua.push(v);
    lua_pushcclosure(lua.handle, func, Args.length);
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
if(isNumeric!T && !is(T == enum))
{
    static if(isFloatingPoint!T)
        return lua_tonumber(lua.handle, index).to!T;
    else
        return lua_tointeger(lua.handle, index).to!T;
}

bool as(T)(ref LuaState lua, int index)
if(is(T == bool))
{
    return cast(bool)lua_toboolean(lua.handle, index);
}

void* as(T)(ref LuaState lua, int index)
if(is(T == void*))
{
    return lua_touserdata(lua.handle, index);
}

E as(E)(ref LuaState lua, int index)
if(is(E == enum))
{
    return (lua.as!(OriginalType!E)(index)).to!E;
}

E asUnchecked(E)(ref LuaState lua, int index)
if(is(E == enum))
{
    return cast(E)lua.as!(OriginalType!E)(index);
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

// CHECK

void checkType(ref LuaState lua, int argNum, int type) nothrow
{
    luaL_checktype(lua.handle, argNum, type);
}