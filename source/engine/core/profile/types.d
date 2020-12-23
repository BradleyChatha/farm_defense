module engine.core.profile.types;

import core.time : Duration;
import std.datetime : SysTime;
import taggedalgebraic;

enum MAX_VALUES_PER_BLOCK = 5;

union ProfileValueUnion
{
    ProfileStartEnd startEnd;
}
alias ProfileValue = TaggedUnion!ProfileValueUnion;

struct ProfileBlock
{
    string name;
    ProfileStartEnd time;
    ProfileValue[MAX_VALUES_PER_BLOCK] values;
    size_t valueCount;
}

struct ProfileStartEnd
{
    string name;
    SysTime start;
    SysTime end;
    
    Duration elapsed()
    {
        assert(this.end > this.start, "End <= Start?");
        return this.end - this.start;
    }
}