module engine.core.lua._tests.config;

import engine.core, engine.util;
import fluent.asserts;

@("LUA - Config interface basic setup")
unittest
{
    auto conf = new Config();
    auto lua = LuaState.create();
    lua.registerConfigLibrary("config");
    lua.push(cast(void*)conf);
    lua.setGlobal("instance");

    // Check that the user data was set properly.
    lua.loadString("return instance").isOk.should.equal(true);
    lua.pcall(0, 1).isOk.should.equal(true);
    lua.type(-1).should.equal(LUA_TLIGHTUSERDATA);
    lua.as!(void*)(-1).should.equal(cast(void*)conf);
    lua.pop(1);
}

@("LUA - Config interface basic usage")
unittest
{
    auto conf = new Config();
    auto lua = LuaState.create();
    lua.registerConfigLibrary("config");
    lua.push(cast(void*)conf);
    lua.setGlobal("instance");

    lua.loadString("config.setString(instance, 'key', 'Hello!')").isOk.should.equal(true);
    auto result = lua.pcall(0, 0);
    result.isOk.should.equal(true).because(result.isOk ? null : result.error);
    conf.getOrDefault!string("key").should.equal("Hello!");

    lua.loadString("return config.getString(instance, 'key') == 'Hello!'").isOk.should.equal(true);
    lua.pcall(0, 1).isOk.should.equal(true);
    lua.as!bool(-1).should.equal(true);
}