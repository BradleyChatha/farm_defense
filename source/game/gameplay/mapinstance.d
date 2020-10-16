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
        MapEventManager     _events;
    }

    this(Map map, ref InputHandler input, Camera camera)
    {
        this._map           = map;
        camera.constrainBox = rectanglef(0, 0, this._map.sizeInPixels.x, this._map.sizeInPixels.y);
        this._player        = new Player(this, input, camera, vec2f(Window.size) / vec2f(2));
        this._dayNightCycle = new MapDayNightCycle(map, input);
        this._enemyManager  = new EnemyManager(map, this._dayNightCycle);
        this._events        = new MapEventManager(map, this._dayNightCycle);

        this._drawCommands.length = 
            this._map.drawCommands.length 
            + 1;    // Player's commands.
    }

    void onUpdate()
    {
        this._dayNightCycle.onUpdate();
        this._events.onUpdate();
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

    @property @safe @nogc
    uint asMinutes() nothrow pure const
    {
        return (this.day * 24 * 60) + (this.hour * 60) + this.minutes;
    }
    ///
    unittest
    {
        MapTime time;

        time.minutes = 20;
        assert(time.asMinutes == 20);

        time.hour = 8;
        assert(time.asMinutes == 500);

        time.day = 1;
        assert(time.asMinutes == 1940);
    }

    @safe @nogc
    int opCmp(const MapTime rhs) const nothrow pure
    {
        if(this.asMinutes > rhs.asMinutes)
            return 1;
        else if(this.asMinutes < rhs.asMinutes)
            return -1;
        else
            return 0;
    }
    ///
    unittest
    {
        auto t1 = MapTime(1, 8, 20);
        auto t2 = MapTime(1, 7, 19);

        assert(t1 > t2);
        assert(t2 < t1);
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
    enum T1_SUN_COLOUR = Color(57, 61, 68);
    enum T2_SUN_COLOUR = Color(222, 183, 132);
    enum T3_SUN_COLOUR = Color(255, 255, 255);

    enum IRL_MS_TO_WORLD_MINUTE = 1; // How many milliseconds in real life translates to a minute in the game world.

    alias TimeEvent = void delegate(MapTime currTime);

    private
    {
        struct Event
        {
            MapTime at;
            TimeEvent func;
        }

        Color      _sunColour;
        Color      _prevSunColour = T2_SUN_COLOUR;
        Color      _nextSunColour = T3_SUN_COLOUR;
        Timer!void _updateWorldTime;
        MapTime    _time;
        Event[]    _events;
    }

    this(Map mapInfo, ref InputHandler input)
    {
        this._updateWorldTime = Timer!void(IRL_MS_TO_WORLD_MINUTE, &this.onTimeTick);
        this._time.addMinutes(8 * 60);
    }

    void at(MapTime time, TimeEvent func)
    {
        this._events ~= Event(time, func);
    }

    void onUpdate()
    {
        this._updateWorldTime.onUpdate();
    }

    void onTimeTick()
    {
        this._time.addMinutes(1);

        this.updateSun();
        this.runEvents();
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

    void runEvents()
    {
        import std.algorithm : remove;

        for(size_t i = 0; i < this._events.length; i++)
        {
            auto event = this._events[i];
            if(event.at <= this._time)
            {
                event.func(this._time);
                this._events = this._events.remove(i);
                i--;
            }
        }
    }

    @property
    Color sunColour()
    {
        return this._sunColour;
    }
}

final class MapEventManager
{
    private
    {
        MapDayNightCycle _dayNightCycle;
        Map              _mapInfo;
        Timer!void[]     _timers;
    }

    this(Map map, MapDayNightCycle dayNightCycle)
    {
        this._dayNightCycle = dayNightCycle;
        this._mapInfo       = map;
        this._timers.reserve(1000);

        this.registerEvents();
    }

    void onUpdate()
    {
        foreach(ref timer; this._timers)
            timer.onUpdate();
    }

    private size_t getTimerIndex()
    {
        // Just for now, we'll literally just grow the array and never shrink.
        auto index = this._timers.length;
        this._timers.length++;

        return index;
    }
    
    private void registerEvents()
    {
        foreach(spawner; this._mapInfo.spawners)
        {
            foreach(event; spawner.events)
            {
                auto start = event.start;
                auto end   = event.end;

                if(event.recurring)
                {
                    start.day = 1;
                    end.day   = 1;
                }

                foreach(instruction; event.instructions)
                {
                    MapDayNightCycle.TimeEvent startFunc;
                    auto timerIndex = this.getTimerIndex();
                    final switch(instruction.kind) with(typeof(instruction.kind))
                    {
                        case spawn:
                            auto spawn = cast(MapSpawnInstruction)instruction;
                            startFunc = (_)
                            {
                                this._timers[timerIndex] = Timer!void(spawn.spawnEveryMs, ()
                                {
                                });                                
                            };
                            break;
                    }

                    MapDayNightCycle.TimeEvent endFunc;
                    endFunc = (_)
                    {
                        this._timers[timerIndex] = Timer!void.init;
                        
                        if(event.recurring)
                        {
                            start.day++;
                            end.day++;
                            this._dayNightCycle.at(start, startFunc);
                            this._dayNightCycle.at(end, endFunc);
                        }
                    };

                    this._dayNightCycle.at(start, startFunc);
                    this._dayNightCycle.at(end, endFunc);
                }
            }
        }
    }
}