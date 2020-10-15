module game.scenes.level;

import game.core, game.common, game.graphics, game.debug_, game.data, game.gameplay;

final class LevelScene : Scene
{
    mixin IMessageHandlerBoilerplate;

    MapInstance mapInstance;

    this()
    {
        super();
    }

    override DrawCommand[] drawCommands()
    {
        return (this.mapInstance) is null ? null : this.mapInstance.gatherDrawCommands();
    }

    void loadMap(string mapName)
    {
        auto map = assetsGet!Map(mapName);
        if(map is null)
            return;

        this.mapInstance = new MapInstance(map, super.input, super.camera);
    }

    override void handleMessageBase(scope MessageBase message)
    {
        super.handleMessageBase(message);

        if(this.mapInstance !is null)
            this.mapInstance.handleMessage(message);
    }

    override void onUpdate()
    {
        if(this.mapInstance !is null)
            this.mapInstance.onUpdate();
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
    }
}