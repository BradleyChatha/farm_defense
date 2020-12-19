module engine.core.logging.sinks.console;

import std.array : Appender;
import std.stdio : writeln;
import std.conv : to;
import std.range : padLeft;
import std.file : getcwd;
import std.path : asRelativePath;
import engine.core;
import jaster.cli.ansi;

enum ConsoleLoggerStyle
{
    none,
    coloured = 1 << 0,
    fileInfo = 1 << 1,
    logLevel = 1 << 2,
    funcInfo = 1 << 3,
    timestamp = 1 << 4
}

void addConsoleLoggingSink(ConsoleLoggerStyle style, LogLevel minLevel)
{
    addLoggingSink(msg => consoleLogger(msg, style, minLevel));
}

void consoleLogger(LogMessage msg, ConsoleLoggerStyle style, LogLevel minLevel)
{
    if(cast(int)msg.level < cast(int)minLevel)
        return;

    Appender!(char[]) output;
    createMessage(output, msg, style);

    auto text = output.data.ansi;
    colourOutput(text, msg, style);

    writeln(text);
}

private void createMessage(ref Appender!(char[]) output, LogMessage msg, ConsoleLoggerStyle style)
{
    if((style & ConsoleLoggerStyle.timestamp) > 0)
    {
        output.put(msg.timestamp.hour.to!string.padLeft('0', 2));
        output.put(':');
        output.put(msg.timestamp.minute.to!string.padLeft('0', 2));
        output.put(':');
        output.put(msg.timestamp.second.to!string.padLeft('0', 2));
        output.put(' ');
    }

    if((style & ConsoleLoggerStyle.logLevel) > 0)
    {
        output.put('[');
        output.put(msg.level.to!string);
        output.put("] ");
    }

    if((style & ConsoleLoggerStyle.fileInfo) > 0)
    {
        output.put('<');
        output.put(msg.file.asRelativePath(getcwd()));
        output.put(':');
        output.put(msg.line.to!string);
        output.put('>');
    }

    if((style && ConsoleLoggerStyle.funcInfo) > 0)
    {
        output.put("::");
        output.put(msg.function_);
    }

    if(output.data.length > 0)
        output.put(' ');

    output.put(msg.message);
}

private void colourOutput(ref AnsiText text, LogMessage msg, ConsoleLoggerStyle style)
{
    if((style & ConsoleLoggerStyle.coloured) == 0)
        return;

    final switch(msg.level) with(LogLevel)
    {
        case trace:                                         break;
        case debug_:    text.fg = Ansi4BitColour.green;     break;
        case info:      text.bold = true;                   break;
        case warning:   text.fg = Ansi4BitColour.yellow;    break;
        case error:
        case fatal:     text.fg = Ansi4BitColour.red;       break;
    }
}