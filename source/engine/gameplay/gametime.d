module engine.gameplay.gametime;

import core.time : Duration;

struct GameTime
{
    private
    {
        Duration _duration;
    }

    this(Duration duration)
    {
        this._duration = duration;
    }

    @property
    uint asMsecs()
    {
        return cast(uint)this._duration.total!"msecs";
    }

    @property
    float asPercentOfSecond()
    {
        return (1000.0f / cast(float)this.asMsecs);
    }
}