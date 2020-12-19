module engine.core.lua.convert;

import std.format, std.traits, std.conv;
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

void pushAsLuaTable(FailIfCantConvert Fail, E)(ref LuaState state, E IGNORED = E.init)
if(is(E == enum))
{
    assert(IGNORED == E.init, "The value parameter isn't used here.");

    auto guard = LuaStackGuard(state, 1);
    state.newTable();

    // `Fail` is ignored, it's just for API parity for the other versions.
    static assert(__traits(compiles, state.push(OriginalType!E.init)), "Can't convert "~E.stringof~" due to its base type.");

    static foreach(member; EnumMembers!E)
    {{
        const EnumValueName = member.to!string;
        const EnumValue = member.to!(OriginalType!E);
        state.push(EnumValueName);
        state.push(EnumValue);
        state.rawSet(-3);
    }}
}

void pushAsLuaTable(T)(ref LuaState state, T obj = T.init)
{
    state.pushAsLuaTable!(FailIfCantConvert.yes, T)(obj);
}

int luaCFuncWithContext(alias Func)(lua_State* state) nothrow
if(isFunction!Func)
{
    alias Params = Parameters!Func;
    static assert(Params.length == 2, "Function must have exactly 2 parameters.");
    static assert(is(Params[0] == class) || is(Params[0] == interface) || isPointer!(Params[0]), "The first parameter must be a pointer or reference type.");
    static assert(is(Params[1] == LuaState) && (ParameterStorageClassTuple!Func[1] & ParameterStorageClass.ref_) > 0, "The second parameter must be a `ref LuaState`");

    auto lua = LuaState.wrap(state);
    lua.checkType(1, LUA_TLIGHTUSERDATA);
    auto obj = cast(Object)lua.as!(void*)(1);
    auto ctx = cast(Params[0])obj;
    assert(ctx !is null, "Expected user data of type "~Params[0].stringof~" but got something else instead.");
    lua.remove(1);

    try return Func(ctx, lua);
    catch(Exception ex)
        return lua.error(ex.msg);
}

int luaCFunc(alias Func)(lua_State* state) nothrow
if(isFunction!Func)
{
    alias Params = Parameters!Func;
    static assert(Params.length == 1, "Function must have only 1 parameter.");
    static assert(is(Params[0] == LuaState) && (ParameterStorageClassTuple!Func[0] & ParameterStorageClass.ref_) > 0, "The parameter must be a `ref LuaState`");

    auto lua = LuaState.wrap(state);
    try return Func(lua);
    catch(Exception ex)
        return lua.error(ex.msg);
}