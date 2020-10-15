module game.gameplay.mapinstance;

import game.core, game.common, game.data, game.graphics, game.gameplay, game.debug_;

final class MapInstance : IMessageHandler
{
    private
    {
        Map                 _map;
        Player              _player;
        EnemyManager        _enemyManager;
        DrawCommand[]       _drawCommands;
        MapDayNightCycle    _dayNightCycle;
    }

    this(Map map, ref InputHandler input, Camera camera)
    {
        this._map           = map;
        camera.constrainBox = rectanglef(0, 0, this._map.sizeInPixels.x, this._map.sizeInPixels.y);
        this._player        = new Player(this, input, camera, vec2f(Window.size) / vec2f(2));
        this._enemyManager  = new EnemyManager(map);
        this._dayNightCycle = new MapDayNightCycle(map);

        this._drawCommands.length = 
            this._map.drawCommands.length 
            + 1;    // Player's commands.
    }

    void onUpdate()
    {
        this._dayNightCycle.onUpdate();
        this._player.onUpdate();
    }

    void handleMessage(scope MessageBase message)
    {
        this._dayNightCycle.handleMessage(message);
        this._player.handleMessage(message);
    }

    DrawCommand[] gatherDrawCommands()
    {
        this._drawCommands[0]    = this._player.drawCommand;
        this._drawCommands[1..$] = this._map.drawCommands[0..$];

        foreach(ref command; this._drawCommands)
            command.sun = this._dayNightCycle.sunColour;

        return this._drawCommands;
    }

    @property
    Map mapInfo()
    {
        return this._map;
    }
}

final class MapDayNightCycle : IMessageHandler
{
    mixin IMessageHandlerBoilerplate;

    private
    {
        Color _sunColour;
    }

    this(Map mapInfo)
    {
    }

    void onUpdate()
    {
    }

    @property
    Color sunColour()
    {
        return this._sunColour;
    }
}