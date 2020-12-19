module engine.core.logging.logmessage;

import std.datetime : SysTime, Clock;

enum LogLevel
{
    trace,
    debug_,
    info,
    warning,
    error,
    fatal
}

struct LogMessage
{
    string module_;
    string file;
    string function_;
    size_t line;

    string message;
    SysTime timestamp;
    LogLevel level;

    static LogMessage fromString(
        string M = __MODULE__, 
        string FI = __FILE_FULL_PATH__, 
        string FU = __PRETTY_FUNCTION__, 
        size_t L = __LINE__
    )(string str, LogLevel level = LogLevel.info, SysTime timestamp = SysTime.init)
    {
        return LogMessage(M, FI, FU, L, str, (timestamp == SysTime.init) ? Clock.currTime : timestamp, level);
    }
}