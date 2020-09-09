import std.stdio, std.experimental.logger, std.exception;
import bindbc.sdl, bindbc.freetype, erupted, game.vulkan;

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
    main_03_loadSystems();
    main_04_runGame();
    main_05_unloadThirdPartyDeps();
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
    import std.string;
    import game.vulkan.init, game.graphics, game.common;

    info("Loading SDL2 Dynamic Libraries");

    const support = loadSDL();
    enforce(support == sdlSupport, "Unable to load SDL2");

    auto error = FT_Init_FreeType(&g_freeType);
    enforce(error == 0, "Error loading FT");

    SDL_Init(SDL_INIT_EVERYTHING);
    Window.onInit();
    
    vkInitAllJAST();
}

void main_03_loadSystems()
{
    import game.core.loop, game.graphics.renderer;

    loopInit();
    renderInit();
}

void main_04_runGame()
{
    import game.core.loop;

    loopRun();
}

void main_05_unloadThirdPartyDeps()
{
    import game.vulkan.init;
    
    info("Unload SDL");
    SDL_Quit();

    FT_Done_FreeType(g_freeType);
    vkUninitJAST();
}