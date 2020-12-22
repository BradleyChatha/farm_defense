module engine.core.logging.sinks.console;

import std.stdio : writeln;
import engine.core.logging.sinks._import;

void addConsoleLoggingSink(LogMessageStyle style, LogLevel minLevel)
{
    addLoggingSink(msg => consoleLogger(msg, style, minLevel));
}

void consoleLogger(LogMessage msg, LogMessageStyle style, LogLevel minLevel)
{
    if(cast(int)msg.level < cast(int)minLevel)
        return;

    Appender!(char[]) output;
    defaultMessageCreator(output, msg, style);

    auto text = output.data.ansi;
    defaultMessageColourer(text, msg, style);

    writeln(text);
}