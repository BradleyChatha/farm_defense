module engine.vulkan.helpers;

import engine.vulkan;

void CHECK_VK(VkResult result)
{
    import std.conv      : to;
    import std.exception : enforce;

    enforce(result == VkResult.VK_SUCCESS, result.to!string);
}

private void CHECK_SDL(Args...)(Args)
{
    import std.string    : fromStringz;
    import std.exception : enforce;
    import bindbc.sdl    : SDL_GetError;

    const error = SDL_GetError().fromStringz;
    enforce(error.length == 0, error);
}

auto vkGetArrayJAST(alias Func, Args...)(Args args)
{
    import std.format : format;
    import std.traits : Parameters, ReturnType, PointerTarget;
    import bindbc.sdl : SDL_bool;

    enum PARAMS_AUTO_ADDED  = 2; // Count ptr and data ptr.
    enum FUNC_PARAM_COUNT   = Parameters!Func.length;
    enum EXPECTED_ARG_COUNT = FUNC_PARAM_COUNT - PARAMS_AUTO_ADDED;
    alias ARRAY_ELEM_TYPE   = PointerTarget!(Parameters!Func[$-1]);

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
    ARRAY_ELEM_TYPE[] data;

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

@safe @nogc
uint bytesPerPixel(VkFormat format) nothrow pure
{
    import std.exception : assumeWontThrow;
    import std.stdio : writeln;

    switch(format)
    {
        case VK_FORMAT_R8G8B8A8_SINT:
        case VK_FORMAT_R8G8B8A8_UINT:
            return 4;
        default: 
            debug writeln(format).assumeWontThrow;
            assert(false);
    }
}