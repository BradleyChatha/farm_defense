module engine.core.logging.sinks.console;

import std.stdio : writeln;
import engine.core.logging.sinks._import;

void addConsoleLoggingSink(LogMessageStyle style, LogLevel minLevel, LogLevel maxLevel)
{
    addLoggingSink(msg => consoleLogger(msg, style, minLevel, maxLevel));
}

void consoleLogger(LogMessage msg, LogMessageStyle style, LogLevel minLevel, LogLevel maxLevel)
{
    if(cast(int)msg.level < cast(int)minLevel || cast(int)msg.level > cast(int)maxLevel)
        return;

    Appender!(char[]) output;
    defaultMessageCreator(output, msg, style);

    auto text = output.data.ansi;
    defaultMessageColourer(text, msg, style);

    writeln(text);
}