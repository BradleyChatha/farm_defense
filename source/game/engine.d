module game.engine;

import std, std.experimental.logger;
import bgfx;
import game.window, game.renderer;

final class Engine
{
    private
    {
        bool _doLoop;
        Renderer _renderer;
    }

    public
    {
        void onInit()
        {
            info("Initialising engine");
            bgfx_set_view_clear(0, BGFX_CLEAR_COLOR | BGFX_CLEAR_DEPTH, 0x443355FF, 1.0f, 0);
            bgfx_set_view_rect(0, 0, 0, Window.WIDTH, Window.HEIGHT);

            this._renderer = new Renderer();
            this._renderer.onInit();
        }

        void loop()
        {
            info("Starting game loop");
            this._doLoop = true;

            while(this._doLoop)
                this.onFrame();
        }

        void onFrame()
        {
            SDL_Event event;
            while(Window.nextEvent(&event))
                this.onWindowEvent(event);
                
            this._renderer.renderFrame();
        }
    }

    private
    {
        void onWindowEvent(SDL_Event event)
        {
            switch(event.type)
            {
                case SDL_EventType.SDL_QUIT:
                    this._doLoop = false;
                    break;

                case SDL_EventType.SDL_KEYDOWN:
                    switch(event.key.keysym.scancode) with(SDL_Scancode)
                    {
                        case SDL_SCANCODE_ESCAPE: this._doLoop = false;              break;
                        case SDL_SCANCODE_F1:     this._renderer.toggleDebugStats(); break;

                        default: break;
                    }
                    break;

                default: break;
            }
        }
    }
}