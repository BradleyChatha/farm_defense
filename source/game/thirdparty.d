module game.thirdparty;

import std.experimental.logger;
import bindbc.sdl, bgfx;
import game.window;

static class ThirdParty
{
    static
    {
        void onInit()
        {
            info("Initialising SDL2");

            const support = loadSDL();
            if(support != sdlSupport)
                fatalf("Unable to load SDL2 dynamic library: %s", support);

            SDL_Init(SDL_INIT_EVERYTHING);
        }

        void onPostInit()
        {
            info("Initialising bgfx");
            bgfx_init_t init;
            init.type               = bgfx_renderer_type_t.BGFX_RENDERER_TYPE_OPENGL;
            init.resolution.width   = Window.WIDTH;
            init.resolution.height  = Window.HEIGHT;
            init.resolution.reset   = BGFX_RESET_VSYNC;
            bgfx_render_frame(0); // Apparently this stops it doing weird multithreaded stuff if we call it here?
            bgfx_init(&init);
        }
    }
}