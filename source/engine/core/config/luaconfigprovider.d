module engine.core.config.luaconfigprovider;
import engine.core, engine.util;

// A LUA configuration file is simply a LUA file that that returns an object.
//
// We can auto serialise the values we want.
//
// Currently there are no specially supported functions/objects.

Result!void loadLuaTableAsConfig(ref LuaState lua, Config conf)
{
    import std.math : ceil;
    assert(conf !is null);

    auto guard = LuaStackGuard(lua, -1);

    if(!lua.isTable(-1))
    {
        guard.delta = 0;
        return Result!void.failure("Top of stack is not a table.");
    }

    void serialise(int index, string keyPrefix)
    {
        lua.forEach(index, (ref _)
        {
            const key = keyPrefix ~ lua.as!string(-2);
            const valueType = lua.type(-1);

            switch(valueType)
            {
                case LUA_TSTRING: conf.set(key, lua.as!string(-1)); break;
                case LUA_TBOOLEAN: conf.set(key, lua.as!bool(-1)); break;
                case LUA_TNUMBER:
                    const d = lua.as!double(-1);
                    if(d.ceil == d)
                        conf.set(key, cast(long)d);
                    else
                        conf.set(key, d);
                    break;

                case LUA_TTABLE: serialise(-1, key~":"); break;
                
                default: break;
            }
        });
    }

    serialise(-1, "");
    lua.pop(1);

    return Result!void.ok();
}

@("Config - loadLuaTableAsConfig")
unittest
{
    import fluent.asserts;

    auto conf  = new Config();
    auto state = LuaState.create();
    state.loadString(`
    return {
        str = "Hello!",
        i = 420,
        d = 420.69,
        o = {
            str = "World!"
        }
    };
    `).isOk.should.equal(true);

    state.pcall(0, 1).isOk.should.equal(true);
    state.loadLuaTableAsConfig(-1, conf);

    conf.getOrDefault!string("str").should.equal("Hello!");
    conf.getOrDefault!long("i").should.equal(420);
    conf.getOrDefault!double("d").should.be.approximately(420.69, 0.0000000001);
    conf.getOrDefault!string("o:str").should.equal("World!");
}