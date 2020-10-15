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
        this._dayNightCycle = new MapDayNightCycle(map, input);

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

// here be dragons

struct MapTime
{
    uint day;
    uint hour;
    uint minutes;

    void addMinutes(uint amount)
    {
        this.minutes += amount;
        this.hour    += this.minutes / 60;
        this.minutes %= 60;

        while(hour >= 24)
        {
            hour -= 24;
            day++;
        }
    }
}

final class MapDayNightCycle : IMessageHandler
{
    mixin IMessageHandlerBoilerplate;

    // Day is split up into a third, each 8 hours long.
    // Q1 = 00:00
    // Q2 = 08:00
    // Q3 = 16:00
    //
    // Q1 -> Q2 dark/dusk to dawn
    // Q2 -> Q3 dawn to day
    // Q3 -> Q1 day to dusk/dark
    //
    // Day should be around 08:00 to 20:00
    // Enemies should spawn between 00:00 to 08:00?
    enum T1_SUN_COLOUR = Color(0, 0, 0);
    enum T2_SUN_COLOUR = Color(128, 128, 128);
    enum T3_SUN_COLOUR = Color(255, 255, 255);

    enum IRL_MS_TO_WORLD_MINUTE = 1; // How many milliseconds in real life translates to a minute in the game world.

    private
    {
        Color   _sunColour;
        Color   _prevSunColour = T2_SUN_COLOUR;
        Color   _nextSunColour = T3_SUN_COLOUR;
        Timer   _updateWorldTime;
        MapTime _time;
    }

    this(Map mapInfo, ref InputHandler input)
    {
        this._updateWorldTime = Timer(IRL_MS_TO_WORLD_MINUTE, &this.onTimeTick);
        this._time.addMinutes(8 * 60);
    }

    void onUpdate()
    {
        this._updateWorldTime.onUpdate();
    }

    void onTimeTick()
    {
        this._time.addMinutes(1);

        this.updateSun();
    }

    void updateSun()
    {
        if(this._time.hour == 0 && this._time.minutes == 0)
        {
            this._prevSunColour = T1_SUN_COLOUR;
            this._nextSunColour = T2_SUN_COLOUR;
        }
        else if(this._time.hour == 8 && this._time.minutes == 0)
        {
            this._prevSunColour = T2_SUN_COLOUR;
            this._nextSunColour = T3_SUN_COLOUR;
        }
        else if(this._time.hour == 16 && this._time.minutes == 0)
        {
            this._prevSunColour = T3_SUN_COLOUR;
            this._nextSunColour = T1_SUN_COLOUR;
        }

        const eightHoursInMins   = cast(float)(8 * 60);
        const elapsedHoursInMins = cast(float)(((this._time.hour % 8) * 60) + this._time.minutes);
        const thirdPercentage    = elapsedHoursInMins / eightHoursInMins;

        this._sunColour = this._prevSunColour.mix(this._nextSunColour, thirdPercentage);
    }

    @property
    Color sunColour()
    {
        return this._sunColour;
    }
}