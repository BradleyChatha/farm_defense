module game.core.gametime;

private:

// START variables.

uint g_timespan; // msecs
int  g_fpsCountdown = 1000;
uint g_fpsCount;
uint g_fps;

public:

// START functions

@safe @nogc
uint gametimeMillisecs() nothrow
{
    return g_timespan;
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