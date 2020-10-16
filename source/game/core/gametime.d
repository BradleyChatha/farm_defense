module game.core.gametime;

private:

// START variables.

uint g_timespan; // msecs
int  g_fpsCountdown = 1000;
uint g_fpsCount;
uint g_fps;

public:

// START Data types

alias TimerFunc(ReturnT) = ReturnT delegate();
struct Timer(ReturnT)
{
    uint timeBetweenTicks;
    uint timeElapsed;
    TimerFunc!ReturnT func;

    this(uint timeBetweenTicks, TimerFunc!ReturnT func)
    {
        assert(func !is null);
        this.func = func;
        this.timeBetweenTicks = timeBetweenTicks;
    }

    void onUpdate()
    {
        if(this.func is null)
            return;

        this.timeElapsed += gametimeMillisecs();
        if(this.timeElapsed >= this.timeBetweenTicks)
        {
            this.timeElapsed -= this.timeBetweenTicks;
            this.func();
        }
    }
}

// START functions

@safe @nogc
uint gametimeMillisecs() nothrow
{
    return g_timespan;
}

@safe @nogc
float gametimeSecs() nothrow
{
    return cast(float)g_timespan / 1000.0f;
}

@safe @nogc
uint gametimeFps() nothrow
{
    return g_fps;
}

@safe @nogc
package void gametimeSet(uint millisecs) nothrow
{
    g_timespan = millisecs;
    
    g_fpsCountdown -= millisecs;
    if(g_fpsCountdown <= 0)
    {
        g_fpsCountdown += 1000;
        g_fps           = g_fpsCount;
        g_fpsCount      = 0;
    }

    g_fpsCount++;
}