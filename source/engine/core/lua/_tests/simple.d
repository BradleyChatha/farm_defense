module engine.core.lua._tests.simple;

import fluent.asserts;
import engine.core.lua;

@("LUA loadString, pcall, toTempString")
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

@("LUA foreach")
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