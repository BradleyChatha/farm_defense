module game.engine;

import std, std.experimental.logger;
import bgfx, bindbc.sdl;
import game;

final class Engine
{
    private
    {
        bool _doLoop;
        Renderer _renderer;
        SceneManager _scenes;
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

            this._scenes = new SceneManager();
            this._scenes.swapScene!DefenseScene();
        }

        void loop()
        {
            info("Starting game loop");
            this._doLoop = true;

            uint delta = 1; // Starting at 0 might cause strange issues, so start at 1.
            while(this._doLoop)
            {
                const startTicks = SDL_GetTicks();

                // To stop more strange issues happening, if the delta is more than a second, then we'll
                // smoothly progress frame by frame by a second each.
                while(delta >= 1000)
                {
                    this.onFrame(1000);
                    delta -= 1000;
                }

                if(delta > 0)
                    this.onFrame(delta);
                
                delta = SDL_GetTicks() - startTicks;
            }
        }

        void onFrame(uint delta)
        {
            SDL_Event event;
            while(Window.nextEvent(&event))
                this.onWindowEvent(event);
                
            this._scenes.onFrame(delta, this._renderer);
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