import std.stdio, std.experimental.logger, std.exception;
import bindbc.sdl, erupted;

private bool goBack = false;

void main()
{   
    scope(exit)
    {
        import std.file : chdir;
        if(goBack)
            chdir("..");
    }

    main_01_ensureCorrectDirectory();
    main_02_loadThirdPartyDeps();
    main_03_runGame();
    main_04_unloadThirdPartyDeps();
}


void main_03_runGame()
{

}

void main_01_ensureCorrectDirectory()
{
    import std.file : exists, chdir;

    // Support running the game from "dub run"
    if("dub.sdl".exists)
    {
        chdir("bin");
        goBack = true;
    }
}

void main_02_loadThirdPartyDeps()
{
    import game.vulkan.init, game.graphics.window, game.common;

    taskInit();

    info("Loading SDL2 Dynamic Libraries");

    const support = loadSDL();
    enforce(support == sdlSupport, "Unable to load SDL2");

    SDL_Init(SDL_INIT_EVERYTHING);
    Window.onInit();

    vkInitAllJAST();
}

void main_04_unloadThirdPartyDeps()
{
    import game.vulkan.init;
    
    info("Unload SDL");
    SDL_Quit();

    vkUninitJAST();
}