module engine.core.lua.convert;

import std.algorithm : startsWith;
import std.exception : assumeWontThrow;
import std.format, std.traits, std.conv;
import std.typecons : Flag;
import engine.core.lua.funcs._import;

alias FailIfCantConvert = Flag!"failIfCantConvert";

void pushEx(FailIfCantConvert Fail, T)(ref LuaState state, T obj)
if(is(T == struct))
{
    auto guard = LuaStackGuard(state, 1);
    state.newTable();

    int top;
    static foreach(member; __traits(allMembers, T))
    {{
        alias Symbol = __traits(getMember, T, member);
        const SymbolName = member;
        alias SymbolType = typeof(Symbol);
        auto SymbolValue = mixin("obj."~SymbolName);

        state.push(SymbolName);

        static if(!Fail)
            bool dontPush;

        static if(__traits(compiles, state.chooseBestPush!Fail(SymbolValue)))
        {
            static if(!Fail) top = state.getTop();
            state.chooseBestPush!Fail(SymbolValue);
            
            // Edge case: If Fail is no, then chooseBestPush might not actually push any data onto the stack.
            static if(!Fail)
            {
                if(state.getTop() <= top)
                {
                    dontPush = true;
                    state.pop(1);
                }
            }
        }
        else
        {
            static if(Fail)
                static assert(false, "Don't know how to convert '"~SymbolType.stringof~" "~SymbolName~"' from '"~T.stringof~"'");
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

void pushEx(FailIfCantConvert Fail, T)(ref LuaState state, T array)
if(isDynamicArray!T && !is(T == string))
{
    auto guard = LuaStackGuard(state, 1);
    state.newTable();

    foreach(i; 0..array.length)
    {
        // If we can't fail then we need to do extra checks to see if something was actually pushed or not.
        static if(!Fail)
        {
            const before = state.getTop();
            state.chooseBestPush!Fail(array[i]);

            if(state.getTop() > before)
                state.rawSet(-2, cast(uint)i+1); // result[i<one-based>] = pushed_value;
        }
        else
        {
            state.chooseBestPush!Fail(array[i]);
            state.rawSet(-2, cast(uint)i+1);
        }
    }
}

void pushEx(FailIfCantConvert Fail, T)(ref LuaState state, T array)
if(isStaticArray!T && is(typeof(array[]) : const(char)[]))
{
    state.push(array.ptr.fromStringz);
}

void pushEx(FailIfCantConvert Fail, E)(ref LuaState state, E IGNORED = E.init)
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

void pushEx(T)(ref LuaState state, T obj = T.init)
{
    state.pushEx!(FailIfCantConvert.yes, T)(obj);
}

Result!T asEx(FailIfCantConvert Fail, T)(ref LuaState state, int index)
if(is(T == struct))
{
    auto guard = LuaStackGuard(state, 0);
    T value;

    if(!state.isTable(index))
        return typeof(return).failure("Value is not a table.");

    static foreach(member; __traits(allMembers, T))
    {{
        alias Symbol = __traits(getMember, T, member);
        const SymbolName = member;
        alias SymbolType = typeof(Symbol);

        // _ = valueTable[SymbolName]
        state.push(SymbolName);
        state.rawGet(index - 1);

        if(!state.isNil(-1))
        {
            // _ -> D type
            auto result = state.chooseBestAs!(Fail, SymbolType)(-1);
            if(!result.isOk)
            {
                version(Fail)
                    throw new Exception("Error when converting "~SymbolName~" of type "~SymbolType.stringof~" from LUA into D: "~result.error);
            }
            else
                mixin("value."~SymbolName~" = result.value;");
        }
        state.pop(1);
    }}

    return typeof(return).ok(value);
}

import engine.vulkan;
Result!T asEx(FailIfCantConvert Fail, T)(ref LuaState state, int index)
if(isDynamicArray!T && !is(T == string))
{
    import std.range : ElementEncodingType;
    alias BASE_TYPE = ElementEncodingType!T;

    auto guard = LuaStackGuard(state, 0);

    if(!state.isTable(index))
        return typeof(return).failure("Value is not a table.");

    T array;
    array.length = state.rawLength(index);
    
    foreach(i; 0..array.length)
    {
        state.rawGet(index, cast(int)i + 1);
        array[i] = state.chooseBestAs!(Fail, BASE_TYPE)(-1).enforceOkValue;
        state.pop(1);
    }

    return typeof(return).ok(array);
}

Result!T asEx(T)(ref LuaState state, int index)
{
    return state.asEx!(FailIfCantConvert.yes, T)(index);
}

void chooseBestPush(FailIfCantConvert Fail, T)(ref LuaState state, T value)
{
    static if(__traits(compiles, state.push(value)))
        state.push(value);
    else static if(is(T == enum))
        state.chooseBestPush!(Fail, OriginalType!T)(value);
    else static if(__traits(compiles, state.pushEx!Fail(value)))
        state.pushEx!Fail(value);
    else static assert(!Fail, "Don't know how to convert '"~T.stringof~"' into LUA.");
}

private Result!T chooseBestAs(FailIfCantConvert Fail, T)(ref LuaState state, int index)
{
    static if(__traits(compiles, state.as!T(index)))
        return Result!T.ok(state.as!T(index));
    else static if(__traits(compiles, state.asEx!(Fail, T)(index)))
        return state.asEx!(Fail, T)(index);
    else static assert(!Fail, "Don't know how to convert '"~T.stringof~"' from LUA.");
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
    catch(Throwable ex) // We *have* to catch Throwable here, because if an Error or assert or something is thrown, we just get a crash with no info because we're in a LUA stack frame, not a D one.
        return lua.error(ex.msg~"\n"~ex.info.toString().assumeWontThrow);
}

int luaCFunc(alias Func)(lua_State* state) nothrow
if(isFunction!Func)
{
    alias Params = Parameters!Func;
    static assert(Params.length == 1, "Function must have only 1 parameter.");
    static assert(is(Params[0] == LuaState) && (ParameterStorageClassTuple!Func[0] & ParameterStorageClass.ref_) > 0, "The parameter must be a `ref LuaState`");

    auto lua = LuaState.wrap(state);
    try return Func(lua);
    catch(Throwable ex)
        return lua.error(ex.msg~"\n"~ex.info.toString().assumeWontThrow);
}

int luaCFuncWithUpvalues(alias Func)(lua_State* state) nothrow
if(isFunction!Func)
{
    alias Params = Parameters!Func;
    static assert(Params.length > 0, "Function must have at least 1 parameter.");
    static assert(is(Params[0] == LuaState) && (ParameterStorageClassTuple!Func[0] & ParameterStorageClass.ref_) > 0, "The first parameter must be a `ref LuaState`");

    Params params;
    params[0] = LuaState.wrap(state);

    static foreach(i, Param; Params[1..$])
    {{
        params[i+1] = params[0].as!Param(lua_upvalueindex(i+1));
    }}

    try return Func(params);
    catch(Throwable ex)
        return params[0].error(ex.msg~"\n"~ex.info.toString().assumeWontThrow);
}