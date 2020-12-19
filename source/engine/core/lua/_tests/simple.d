module engine.core.lua._tests.simple;

import fluent.asserts;
import engine.core.lua;

@("LUA - loadString, pcall, toTempString")
unittest
{
    auto state = LuaState.create();
    auto guard = LuaStackGuard(state, 1);
    auto result = state.loadString("return 420");
    result.isOk.should.equal(true);

    result = state.pcall(0, 1);
    result.isOk.should.equal(true);

    state.toTempString(-1).should.equal("420");
}

@("LUA - foreach")
unittest
{
    auto state = LuaState.create();
    auto guard = LuaStackGuard(state, 1);
    auto result = state.loadString("return {400, 8, 12}");
    result.isOk.should.equal(true);

    result = state.pcall(0, 1);
    result.isOk.should.equal(true);

    state.isTable(-1).should.equal(true);

    int value;
    state.forEach(-1, (ref _)
    {
        value += state.as!int(-1);
    });
    value.should.equal(420);
}

@("LUA - struct to table")
unittest
{
    static struct S
    {
        string str;
        int i;
    }

    static struct S2
    {
        string str;
        void* bad;
    }

    const code = `
    return function(table)
        return table.str == "Hello" or not table.i
    end
    `;

    auto state = LuaState.create();
    auto guard = LuaStackGuard(state, 1);

    state.loadString(code).isOk.should.equal(true);

    state.type(-1).should.equal(LUA_TFUNCTION);
    state.pcall(0, 1).isOk.should.equal(true); // Get the function
    state.pushAsLuaTable(S("Hello", 69)); // Push the table.

    state.getTop.should.equal(2);
    state.type(-1).should.equal(LUA_TTABLE);
    state.type(-2).should.equal(LUA_TFUNCTION);
    auto result = state.pcall(1, 1); // Execute it
    result.isOk.should.equal(true).because((result.isFailure) ? result.error : null);

    state.type(-1).should.equal(LUA_TBOOLEAN);
    state.as!bool(-1).should.equal(true);
    state.pop(1);

    state.loadString(code);
    state.pcall(0, 1);
    state.pushAsLuaTable!(FailIfCantConvert.no)(S2("non", null));
    state.pcall(1, 1).isOk.should.equal(true);
    state.as!bool(-1).should.equal(true);
}

@("LUA - enum to table")
unittest
{
    static enum E
    {
        e1 = 20,
        e2 = 400
    }

    auto state = LuaState.create();
    auto guard = LuaStackGuard(state, 1);

    auto result = state.loadString("return function(e) return e.e1 + e.e2 end");
    result.isOk.should.equal(true).because((result.isFailure) ? result.error : null);
    state.pcall(0, 1).isOk.should.equal(true);

    state.pushAsLuaTable!E();

    state.type(-1).should.equal(LUA_TTABLE);
    state.type(-2).should.equal(LUA_TFUNCTION);
    state.pcall(1, 1).isOk.should.equal(true);

    state.type(-1).should.equal(LUA_TNUMBER);
    state.as!int(-1).should.equal(420);
}