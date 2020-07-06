module game.scenes.defense_scene;

import game, gfm.math;

final class DefenseScene : Scene
{
    private
    {
        Level _level;
    }

    public override
    {
        void onInit()
        {
            this._level = Resources.loadLevel("./resources/levels/first.sdl");
        }

        void onReset()
        {
        }

        void onUpdate(uint gameTime)
        {
        }

        void onDraw(Renderer renderer)
        {
            this._level.onDraw(renderer);
        }
    }
}

final class Level
{
    const TILE_SIZE   = 64;
    const GRID_WIDTH  = Window.WIDTH / TILE_SIZE;
    const GRID_HEIGHT = Window.HEIGHT / TILE_SIZE;

    private
    {
        string _name;
        Sprite _background;
    }

    public
    {
        this(string name, Sprite background)
        {
            this._name       = name;
            this._background = background;
        }

        void onDraw(Renderer renderer)
        {
            renderer.draw(this._background);
        }
    }
}