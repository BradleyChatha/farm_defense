module engine.core.logging.logger;

import engine.core, engine.core.logging.sync;

void logRaw(LogMessage message)
{
    logQueue(message);
}

void log(
    LogLevel level,
    string M = __MODULE__, 
    string FI = __FILE__, 
    string FU = __FUNCTION__, 
    size_t L = __LINE__
)(string str)
{
    logQueue(LogMessage.fromString!(M, FI, FU, L)(str, level));
}

void logf(
    LogLevel level,
    string M = __MODULE__, 
    string FI = __FILE__, 
    string FU = __FUNCTION__, 
    size_t L = __LINE__,
    Args...
)(string fmt, Args args)
{
    import std.format : format;
    log!(level, M, FI, FU, L)(fmt.format(args));
}

private mixin template proxyFor(string name, alias F, LogLevel level)
{
    private import std.format;
    mixin(`void %s
    (string M = __MODULE__, string FI = __FILE_FULL_PATH__, string FU = __FUNCTION__, size_t L = __LINE__, Args...)
    (string s, Args args)
    {
        F!(level, M, FI, FU, L, Args)(s, args);
    }`.format(name));
}

mixin proxyFor!("logfTrace", logf, LogLevel.trace);
mixin proxyFor!("logfDebug", logf, LogLevel.debug_);
mixin proxyFor!("logfInfo", logf, LogLevel.info);
mixin proxyFor!("logfWarning", logf, LogLevel.warning);
mixin proxyFor!("logfError", logf, LogLevel.error);
mixin proxyFor!("logfFatal", logf, LogLevel.fatal);

mixin proxyFor!("logTrace", log, LogLevel.trace);
mixin proxyFor!("logDebug", log, LogLevel.debug_);
mixin proxyFor!("logInfo", log, LogLevel.info);
mixin proxyFor!("logWarning", log, LogLevel.warning);
mixin proxyFor!("logError", log, LogLevel.error);
mixin proxyFor!("logFatal", log, LogLevel.fatal);