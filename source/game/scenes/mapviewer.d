module game.scenes.mapviewer;

import game.core, game.common, game.graphics, game.debug_, game.data;

final class MapViewerScene : Scene
{
    mixin IMessageHandlerBoilerplate;

    Map map;

    this()
    {
        super();
        
        const CAMERA_SPEED = 200.0f;
        super.input.onDown(SDL_SCANCODE_D, () => super.camera.move(vec2f(-CAMERA_SPEED * gametimeSecs(), 0)));
        super.input.onDown(SDL_SCANCODE_A, () => super.camera.move(vec2f(CAMERA_SPEED * gametimeSecs(), 0)));
        super.input.onDown(SDL_SCANCODE_W, () => super.camera.move(vec2f(0, CAMERA_SPEED * gametimeSecs())));
        super.input.onDown(SDL_SCANCODE_S, () => super.camera.move(vec2f(0, -CAMERA_SPEED * gametimeSecs())));
    }

    override DrawCommand[] drawCommands()
    {
        return (this.map is null) ? null : this.map.drawCommands;
    }

    void loadMap(string name)
    {
        this.map = assetsGet!Map(name);
    }

    @Subscribe
    void onDebugCommandMessage(DebugCommandMessage message)
    {
        auto range = message.data;
        if(range.empty)
            return;

        if(range.front == "load_map")
        {
            range.popFront();
            if(!range.empty)
                this.loadMap(cast(string)range.front); // Mutations won't affect this code path, so casting to string is relatively fine here.
        }

        if(range.front == "center_camera")
        {
            import std.conv : to;
            range.popFront();
            if(!range.empty)
            {
                const x = range.front.to!float;
                range.popFront();
                if(range.empty)
                    return;

                const y = range.front.to!float;
                this.camera.lookAt(vec2f(x, y));
            }
        }

        if(range.front == "constrain_camera")
        {
            import std.conv : to;
            range.popFront();
            if(!range.empty)
            {
                const x = range.front.to!float;
                range.popFront();
                if(range.empty)
                    return;

                const y = range.front.to!float;
                this.camera.constrainBox = rectanglef(0, 0, x, y);
            }
        }
    }
}