module game.scene;

import std.experimental.logger;
import game;

abstract class Scene
{
    private
    {
    }

    public abstract
    {
        void onInit();
        void onReset();
        void onUpdate(uint gameTime);
        void onDraw(Renderer renderer);
    }
}

final class SceneManager
{
    // TODO: For now, since we're only using a single scene, I'm not gonna bother actually making this class properly.
    private
    {
        DefenseScene _scene;
    }

    public
    {
        void swapScene(S : Scene)()
        {
            info("Swapping scene to ", S.stringof);

            static assert(is(S == DefenseScene), "Only DefenseScene is supported right now");
            if(this._scene is null)
            {
                info("Scene is null, initialising and resetting it.");
                this._scene = new DefenseScene();
                this._scene.onInit();
                this._scene.onReset();
            }
        }

        void onFrame(uint delta, Renderer renderer)
        {
            this._scene.onUpdate(delta);
            this._scene.onDraw(renderer);
        }
    }
}