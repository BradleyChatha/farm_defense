module engine.core.logging.logmessage;

import std.datetime : SysTime, Clock;

struct LogMessage
{
    string module_;
    string file;
    string function_;
    size_t line;

    string message;
    SysTime timestamp;

    static LogMessage fromString(
        string M = __MODULE__, 
        string FI = __FILE_FULL_PATH__, 
        string FU = __PRETTY_FUNCTION__, 
        size_t L = __LINE__
    )(string str, SysTime timestamp = SysTime.init)
    {
        return LogMessage(M, FI, FU, L, str, (timestamp == SysTime.init) ? Clock.currTime : timestamp);
    }
}