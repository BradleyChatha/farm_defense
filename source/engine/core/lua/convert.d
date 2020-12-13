module engine.core.lua.convert;

import std.format, std.traits;
import std.typecons : Flag;
import engine.core.lua.funcs._import;

alias FailIfCantConvert = Flag!"failIfCantConvert";

void pushAsLuaTable(FailIfCantConvert Fail, T)(ref LuaState state, T obj)
if(is(T == struct))
{
    auto guard = LuaStackGuard(state, 1);
    state.newTable();

    static foreach(member; __traits(allMembers, T))
    {{
        alias Symbol = __traits(getMember, T, member);
        const SymbolName = member;
        alias SymbolType = typeof(Symbol);
        auto SymbolValue = mixin("obj."~SymbolName);

        state.push(SymbolName);

        static if(!Fail)
            bool dontPush;

        static if(__traits(compiles, state.push(SymbolValue)))
            state.push(SymbolValue);
        else
        {
            static if(Fail)
                static assert(false, "Don't know how to convert '"~SymbolType.name~" "~SymbolName~"' from '"~T.stringof~"'");
            else
            {
                dontPush = true;
                state.pop(1);
            }
        }

        static if(!Fail)
        { if(!dontPush) state.rawSet(-3); }
        else
            state.rawSet(-3);
    }}
}

void pushAsLuaTable(T)(ref LuaState state, T obj)
{
    state.pushAsLuaTable!(FailIfCantConvert.yes, T)(obj);
}

int luaCFuncFor(alias Func, alias ContextT = void)(lua_State* state) nothrow
if(isSomeFunction!Func)
{
    static assert(isFunction!Func || !is(ContextT == void), "You must provide ContextT for delegates, i.e. the struct/class' type.");

    auto lua = LuaState.wrap(state);
    try
    {
        // The first parameter for delegates should be a light userdata pointing to the delegate's context.
        static if(isDelegate!Func || Parameters!Func.length == 2)
        {
            lua.checkType(1, LUA_TLIGHTUSERDATA);
            auto ctx = cast(ContextT)lua.as!(void*)(1);
            lua.remove(1);

            static if(Parameters!Func.length == 1)
                auto func = () => mixin("ctx.%s(lua);".format(__traits(identifier, Func)));
            else
                auto func = () => Func(ctx, lua);
        }
        else
            auto func = () => Func(lua);

        return func();
    }
    catch(Exception ex)
    {
        lua.push(ex.msg);
        return lua_error(lua.handle);
    }
}