module engine.core.logging.sinks.file;

import std.stdio : File;
import engine.core.logging.sinks._import;

private class FileLogger
{
    File file;

    this(string file)
    {
        import std.file : mkdirRecurse;
        import std.path : dirName;

        mkdirRecurse(file.dirName);
        this.file = File(file, "w");
    }
}

void addFileLoggingSink(string file, LogMessageStyle style, LogLevel minLevel, LogLevel maxLevel)
{
    auto logger = new FileLogger(file);
    addLoggingSink(msg => fileLogger(logger, msg, style, minLevel, maxLevel));
}

void fileLogger(FileLogger logger, LogMessage msg, LogMessageStyle style, LogLevel minLevel, LogLevel maxLevel)
{
    if(cast(int)msg.level < cast(int)minLevel || cast(int)msg.level > cast(int)maxLevel)
        return;

    Appender!(char[]) output;
    defaultMessageCreator(output, msg, style);
    logger.file.writeln(output.data);
}