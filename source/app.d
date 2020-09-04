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
    import game.graphics, game.vulkan, arsd.color, game.common;
    // Prelim loop

    // Don't have the renderer fully set up yet, but I need to make sure all the building blocks for it work.
    // Hence the manual vulkan calls.    
    const VERT_COUNT       = TexturedQuadVertex.sizeof * 3;
    auto  cpuBuffer        = g_gpuCpuAllocator.allocate(VERT_COUNT, VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
    auto  gpuBuffer        = g_gpuAllocator.allocate(VERT_COUNT, VK_BUFFER_USAGE_VERTEX_BUFFER_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT);
    auto  transferCommands = g_device.transfer.commandPools.get(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT).allocate(1)[0];
    
    cpuBuffer.as!TexturedQuadVertex[0..3] = 
    [
        TexturedQuadVertex(vec2f(-0.5, 0.5), vec2f(0), Color.red),
        TexturedQuadVertex(vec2f(0,    -0.5), vec2f(0), Color.green),
        TexturedQuadVertex(vec2f(0.5, 0.5), vec2f(0), Color.blue)
    ];
    transferCommands.begin(ResetOnSubmit.yes);
        transferCommands.copyBuffer(VERT_COUNT, cpuBuffer, 0, gpuBuffer, 0);
    transferCommands.end();

    auto syncInfo = g_device.transfer.submit(transferCommands, null, null, 0);
    while(!syncInfo.submitHasFinished)
        g_device.transfer.processFences();

    TEST_testDrawVerts = gpuBuffer;
    while(SDL_GetTicks() < 2_000)
    {
        renderBegin();
        renderEnd();
    }

    g_device.graphics.debugPrintFences();
    g_device.transfer.debugPrintFences();
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
    import game.vulkan.init, game.graphics, game.common;

    info("Loading SDL2 Dynamic Libraries");

    const support = loadSDL();
    enforce(support == sdlSupport, "Unable to load SDL2");

    SDL_Init(SDL_INIT_EVERYTHING);
    Window.onInit();

    vkInitAllJAST();
    renderInit();
}

void main_04_unloadThirdPartyDeps()
{
    import game.vulkan.init;
    
    info("Unload SDL");
    SDL_Quit();

    vkUninitJAST();
}