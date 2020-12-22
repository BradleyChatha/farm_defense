module engine.core.lua.funcs.table;

import engine.core.lua.funcs._import;

void newTable(ref LuaState lua)
{
    lua_newtable(lua.handle);
}

void rawSet(ref LuaState lua, int tableIndex)
{
    lua_rawset(lua.handle, tableIndex);
}

void rawSet(ref LuaState lua, int tableIndex, int key)
{
    lua_rawseti(lua.handle, tableIndex, key);
}

size_t rawLength(ref LuaState lua, int tableIndex)
{
    return lua_objlen(lua.handle, tableIndex);
}

void rawGet(ref LuaState lua, int tableIndex)
{
    lua_rawget(lua.handle, tableIndex);
}

void rawGet(ref LuaState lua, int tableIndex, int key)
{
    lua_rawgeti(lua.handle, tableIndex, key);
}

bool next(ref LuaState lua, int tableIndex)
{
    return cast(bool)lua_next(lua.handle, tableIndex);
}

// -2 is key, -1 is value.
void forEach(ref LuaState lua, int tableIndex, scope void delegate(ref LuaState) func)
{
    auto guard = LuaStackGuard(lua, 0);
    if(tableIndex < 0)
        tableIndex--; // Since we're pushing a key on top.

    const oldTop = lua.getTop();
    scope(failure) lua.setTop(oldTop);

    lua.push(Nil());
    while(lua.next(tableIndex))
    {
        auto iterGuard = LuaStackGuard(lua, -1);
        func(lua);
        lua.pop(1); // Pop the value, keep the key
    }
}

Result!T rawGet(T, alias Getter = as)(ref LuaState lua, int tableIndex, string key)
{
    auto guard = LuaStackGuard(lua, 0);

    lua.push(key);
    lua.rawGet(tableIndex - 1);
    if(lua.type(-1) != luaTypeOf!T)
    {
        auto result = Result!T.failure("Expected "~luaTypeOf!T.stringof~" not "~lua.type(-1).to!string~" for value of index '"~key~"'");
        lua.pop(1);
        return result;
    }

    auto value = Getter!T(lua, -1);
    lua.pop(1);

    return Result!T.ok(value);
}