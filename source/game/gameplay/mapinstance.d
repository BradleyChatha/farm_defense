module game.gameplay.mapinstance;

import game.core, game.common, game.data, game.graphics, game.gameplay;

final class MapInstance : IMessageHandler
{
    private
    {
        Map           _map;
        Player        _player;
        DrawCommand[] _drawCommands;
    }

    this(Map map, ref InputHandler input, Camera camera)
    {
        this._map           = map;
        camera.constrainBox = rectanglef(0, 0, this._map.sizeInPixels.x, this._map.sizeInPixels.y);
        this._player        = new Player(this, input, camera);

        this._drawCommands.length = this._map.drawCommands.length + 1; // + 1 for player's commands.
    }

    void onUpdate()
    {
        this._player.onUpdate();
    }

    void handleMessage(scope MessageBase message)
    {
        this._player.handleMessage(message);
    }

    DrawCommand[] gatherDrawCommands()
    {
        this._drawCommands[0]    = this._player.drawCommand;
        this._drawCommands[1..$] = this._map.drawCommands[0..$];
        return this._drawCommands;
    }
}