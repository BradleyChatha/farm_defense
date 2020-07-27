module game.graphics.window;

import std.experimental.logger;
public import bindbc.sdl;

// Reasons for singleton here:
//  1. We're only ever going to have a single window for this game.
//  2. The scope of this game is so, so small that certain programming practices (e.g. no singletons) just aren't worth adhearing to.
final class Window
{
    // Hard coded since strong configuration options really aren't needed for this small of a game (unless Nathan wants it to expand in scope).
    static const WIDTH  = 832;
    static const HEIGHT = 832;
    static const TITLE  = "Farm Defense";
    static const FLAGS  = SDL_WindowFlags.SDL_WINDOW_SHOWN | SDL_WindowFlags.SDL_WINDOW_VULKAN | SDL_WindowFlags.SDL_WINDOW_RESIZABLE;

    private static
    {
        SDL_Window* _handle;
    }

    static
    {
        void onInit()
        {
            info("Creating SDL2 window");
            _handle = SDL_CreateWindow(TITLE.ptr, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, WIDTH, HEIGHT, FLAGS);
            if(_handle is null)
                fatal("Failed to create SDL2 window");

            info("Configuring bgfx to use the SDL2 window");
            SDL_SysWMinfo windowManagerInfo;

            SDL_VERSION(&windowManagerInfo.version_);
            if(!SDL_GetWindowWMInfo(_handle, &windowManagerInfo))
                fatal("Unable to get Window Manager info from SDL2");
        }

        void onUninit()
        {
            info("Destroying SDL Window");
            SDL_DestroyWindow(_handle);
        }

        bool nextEvent(SDL_Event* event)
        {
            return cast(bool)SDL_PollEvent(event);
        }

        SDL_Window* handle()
        {
            return _handle;
        }
    }
}