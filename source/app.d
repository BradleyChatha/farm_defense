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
    auto  texture          = new Texture("./resources/images/static/Transparency Test.png");
    auto  uniformBuffer1   = g_gpuCpuAllocator.allocate(MandatoryUniform.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
    auto  uniformBuffer2   = g_gpuCpuAllocator.allocate(TexturedQuadUniform.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);

    auto quads = renderAllocateQuads(1);
    scope(exit) renderFreeQuads(quads);

    while(!texture.finalise())
    {
        g_device.transfer.processFences();
        g_device.graphics.processFences();
    }

    while(SDL_GetTicks() < 2_000)
    {
        renderBegin();
        quads.beginModify();
        quads.vertsMutable[0..6] = 
        [
            TexturedQuadVertex(vec2f(-0.5, -0.5),  vec2f(0, 0), Color.red),
            TexturedQuadVertex(vec2f(0.5, -0.5),  vec2f(128, 0), Color.green),
            TexturedQuadVertex(vec2f(0.5, 0.5),  vec2f(128, 128), Color.blue),
            TexturedQuadVertex(vec2f(0.5, 0.5),  vec2f(128, 128), Color.red),
            TexturedQuadVertex(vec2f(-0.5, 0.5),  vec2f(0, 128), Color.green),
            TexturedQuadVertex(vec2f(-0.5, -0.5),  vec2f(0, 0), Color.blue),
        ];
        quads.endModifyAndUpdate();

        auto uniforms = g_descriptorPools.pool.allocate!TexturedQuadUniform(g_pipelineQuadTexturedTransparent.base);
        uniforms.update(texture.imageView, texture.sampler, uniformBuffer1, uniformBuffer2);
        TEST_uniforms = uniforms;
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