module engine.window.sdlwindow;

import bindbc.sdl;
import engine.core, engine.util;

final class Window : IDisposable
{
    mixin IDisposableBoilerplate;

    private
    {
        SDL_Window* _handle;
        vec2i       _size;
    }

    this(string title, vec2i size)
    {
        import std.string : toStringz;

        logfTrace("Creating window called '%s' with size of %s", title, size);
        this._handle = SDL_CreateWindow(
            title.toStringz,
            SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
            size.x, size.y,
            SDL_WINDOW_SHOWN | SDL_WINDOW_VULKAN
        );
        this._size = size;
    }

    ~this()
    {
        this.dispose();
    }

    private void disposeImpl()
    {
        SDL_DestroyWindow(this._handle);
    }

    @property
    vec2i size()
    {
        return this._size;
    }

    @property
    SDL_Window* handle()
    {
        return this._handle;
    }
}