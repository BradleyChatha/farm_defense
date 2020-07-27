module game.graphics.sdl;

import std.experimental.logger;
import bindbc.sdl;

void CHECK_SDL(Args...)(Args)
{
    import std.string    : fromStringz;
    import std.exception : enforce;

    const error = SDL_GetError().fromStringz;
    enforce(error.length == 0, error);
}

final class SDL
{
    public static
    {
        void onInit()
        {
            info("Initialising SDL2");

            const support = loadSDL();
            if(support != sdlSupport)
                fatalf("Unable to load SDL2 dynamic library: %s", support);

            SDL_Init(SDL_INIT_EVERYTHING);
        }

        void onUninit()
        {
            info("Qutting SDL2");
            SDL_Quit();
        }
    }
}