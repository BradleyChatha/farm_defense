module engine.init._01_init_thirdparty;

import bindbc.sdl;

void init_01_init_thirdparty()
{
    initSDL();
}

void initSDL()
{
    const result = loadSDL();
    if(result == SDLSupport.noLibrary) throw new Exception("Could not find the SDL dynamic library.");
    if(result == SDLSupport.badLibrary) throw new Exception("This version of the SDL dynamic library is not supported.");

    SDL_Init(SDL_INIT_EVENTS | SDL_INIT_VIDEO);
}