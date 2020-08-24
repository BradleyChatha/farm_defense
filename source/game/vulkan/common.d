module game.vulkan.common;

import std.experimental.logger;
import erupted;

alias VkStringJAST = const(char)*;

void CHECK_VK(VkResult result)
{
    import std.conv      : to;
    import std.exception : enforce;

    enforce(result == VkResult.VK_SUCCESS, result.to!string);
}

void CHECK_SDL(Args...)(Args)
{
    import std.string    : fromStringz;
    import std.exception : enforce;
    import bindbc.sdl    : SDL_GetError;

    const error = SDL_GetError().fromStringz;
    enforce(error.length == 0, error);
}

T[] vkGetArrayJAST(T, alias Func, Args...)(Args args)
{
    import std.format : format;
    import std.traits : Parameters, ReturnType;
    import bindbc.sdl : SDL_bool;

    enum PARAMS_AUTO_ADDED  = 2; // Count ptr and data ptr.
    enum FUNC_PARAM_COUNT   = Parameters!Func.length;
    enum EXPECTED_ARG_COUNT = FUNC_PARAM_COUNT - PARAMS_AUTO_ADDED;

    static assert(
        EXPECTED_ARG_COUNT == args.length,
        "Param count mismatch, expected %s but got %s"
            .format(EXPECTED_ARG_COUNT, args.length)
    );

    static if(is(ReturnType!Func == SDL_bool))
        alias CHECK = CHECK_SDL;
    else static if(is(ReturnType!Func == VkResult))
        alias CHECK = CHECK_VK;

    uint count;
    T[]  data;

    static if(__traits(compiles, &CHECK))
    {
        CHECK(Func(args, &count, null));
        data.length = count;
        CHECK(Func(args, &count, data.ptr));
    }
    else
    {
        Func(args, &count, null);
        data.length = count;
        Func(args, &count, data.ptr);
    }

    return data;
}

const(char)[] asSlice(VkStringJAST str)
{
    import core.stdc.string;

    return str is null
         ? null
         : str[0..strlen(str)];
}

struct VkStringArrayJAST
{
    import std.range : ElementEncodingType;

    private
    {
        VkStringJAST[]  _pointers;
        const(char)[][] _slices;
    }

    this(VkStringJAST[] strings)
    {
        this.add(strings);
    }

    void add(VkStringJAST str)
    {
        this._pointers ~= str;
        this._slices   ~= str.asSlice;
    }

    void add(VkStringJAST[] strings)
    {
        this._pointers.reserve(strings.length);
        this._slices.reserve(strings.length);

        foreach(str; strings)
            this.add(str);
    }

    void add(string str)
    {
        this._pointers ~= str.ptr;
        this._slices   ~= str;
    }

    VkStringArrayJAST filter(Range)(Range enabledList)
    if(is(ElementEncodingType!Range : const(char)[]))
    {
        import std.algorithm : canFind;

        VkStringJAST[] strings;

        foreach(i; 0..this._pointers.length)
        {

            if(enabledList.canFind(this._slices[i]))
                strings ~= this._pointers[i];
        }

        return VkStringArrayJAST(strings);
    }

    void outputToLog(int line = __LINE__, string file = __FILE__, string funcName = __FUNCTION__, string prettyFuncName = __PRETTY_FUNCTION__, string moduleName = __MODULE__)
                    (string header)
    {
        infof!(line, file, funcName, prettyFuncName, moduleName)("\t%s:", header);
        foreach(str; this.slices)
            infof!(line, file, funcName, prettyFuncName, moduleName)("\t\t%s", str);
    }

    @property
    VkStringJAST[] ptrs()
    {
        return this._pointers;
    }

    @property
    const(char)[][] slices()
    {
        return this._slices;
    }
}

mixin template VkWrapperJAST(T, VkDebugReportObjectTypeEXT DebugT)
{
    T handle;
    alias handle this;

    invariant(this.handle !is null, "This "~T.stringof~" is null.");

    @property
    void debugName(string name)
    {
        import std.string : toStringz;
        if(vkDebugMarkerSetObjectNameEXT !is null)
        {
            VkDebugMarkerObjectNameInfoEXT info = 
            {
                objectType:  DebugT,
                object:      cast(ulong)this.handle,
                pObjectName: name.toStringz
            };
        }
    }
}

mixin template VkSwapchainResourceWrapperJAST(T, VkDebugReportObjectTypeEXT DebugT)
{
    mixin VkWrapperJAST!(T, DebugT);

    void delegate(typeof(this)*) recreateFunc;
}