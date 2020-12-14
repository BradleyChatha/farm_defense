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

int luaCFuncWithContext(alias Func)(lua_State* state) nothrow
if(isFunction!Func)
{
    alias Params = Parameters!Func;
    static assert(Params.length == 2, "Function must have exactly 2 parameters.");
    static assert(is(Params[0] == class) || is(Params[0] == interface) || isPointer!(Params[0]), "The first parameter must be a pointer or reference type.");
    static assert(is(Params[1] == LuaState) && (ParameterStorageClassTuple!Func[1] & ParameterStorageClass.ref_) > 0, "The second parameter must be a `ref LuaState`");

    auto lua = LuaState.wrap(state);
    lua.checkType(1, LUA_TLIGHTUSERDATA);
    auto ctx = cast(Params[0])lua.as!(void*)(1);
    lua.remove(1);

    try return Func(ctx, lua);
    catch(Exception ex)
        return lua.error(ex.msg);
}