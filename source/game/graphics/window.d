module game.graphics.window;

import std.experimental.logger;
import bindbc.sdl;
import game.core, game.common, game.vulkan;

alias WindowEventMessage = MessageWithData!(MessageType.WindowEvent, SDL_Event);

// Reasons for singleton here:
//  1. We're only ever going to have a single window for this game.
//  2. The scope of this game is so, so small that certain programming practices (e.g. no singletons) just aren't worth adhearing to.
final class Window
{
    // Hard coded since strong configuration options really aren't needed for this small of a game (unless Nathan wants it to expand in scope).
    static const WIDTH  = 860;
    static const HEIGHT = 860;
    static const TITLE  = "Farm Defense";
    static const FLAGS  = SDL_WindowFlags.SDL_WINDOW_SHOWN | SDL_WindowFlags.SDL_WINDOW_VULKAN;

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
        
        bool isMinimised()
        {
            uint flags = SDL_GetWindowFlags(this.handle);
            return (flags & SDL_WINDOW_MINIMIZED) > 0;
        }

        Surface createSurface()
        {
            import erupted;

            info("Creating Window Surface");

            Surface surface;
            CHECK_SDL(SDL_Vulkan_CreateSurface(_handle, g_vkInstance, &surface.handle));
            surface.debugName = "Window's Surface";

            return surface;
        }

        SDL_Window* handle()
        {
            return _handle;
        }

        vec2u size()
        {
            return vec2u(WIDTH, HEIGHT);
        }

        VkStringJAST[] requiredExtentions()
        {
            return vkGetArrayJAST!(VkStringJAST, SDL_Vulkan_GetInstanceExtensions)(_handle);
        }
    }
}