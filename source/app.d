import std.stdio, std.experimental.logger;
import bindbc.sdl, erupted;
import game.graphics.window, game.graphics.sdl, game.graphics.vulkan, game.graphics.renderer;

void main()
{
    import std.file : exists, chdir;

    // Support running the game from "dub run"
    bool goBack = false;
    if("dub.sdl".exists)
    {
        chdir("bin");
        goBack = true;
    }    
    scope(exit)
    {
        if(goBack)
            chdir("..");
    }

    SDL.onInit();
    Window.onInit();
    Vulkan.onInit();

    // Temporary loop
    auto renderer = new Renderer();
    bool loop = true;
    while(loop)
    {
        SDL_Event event;
        Window.nextEvent(&event);

        if(event.type == SDL_QUIT)
            loop = false;

        if(event.window.event == SDL_WINDOWEVENT_MINIMIZED)
        {
            while(event.window.event != SDL_WINDOWEVENT_RESTORED)
                Window.nextEvent(&event);
        }

        renderer.startFrame();
        renderer.endFrame();
    }

    Vulkan.waitUntilAllDevicesAreIdle();
    Vulkan.onUninit();
    Window.onUninit();
    SDL.onUninit();
}
