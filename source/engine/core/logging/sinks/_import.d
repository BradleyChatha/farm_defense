module engine.core.logging.sinks._import;

public import std.array : Appender;
import std.conv : to;
import std.range : padLeft;
import std.file : getcwd;
import std.path : asRelativePath;
public import engine.core, engine.util, jaster.cli.ansi;

enum LogMessageStyle
{
    none,
    coloured = 1 << 0,
    fileInfo = 1 << 1,
    logLevel = 1 << 2,
    funcInfo = 1 << 3,
    timestamp = 1 << 4
}

package void defaultMessageCreator(ref Appender!(char[]) output, LogMessage msg, LogMessageStyle style)
{
    if((style & LogMessageStyle.timestamp) > 0)
    {
        output.put(msg.timestamp.hour.to!string.padLeft('0', 2));
        output.put(':');
        output.put(msg.timestamp.minute.to!string.padLeft('0', 2));
        output.put(':');
        output.put(msg.timestamp.second.to!string.padLeft('0', 2));
        output.put(' ');
    }

    if((style & LogMessageStyle.logLevel) > 0)
    {
        output.put('[');
        output.put(msg.level.to!string);
        output.put("] ");
    }

    if((style & LogMessageStyle.fileInfo) > 0)
    {
        output.put('<');
        output.put(msg.file.asRelativePath(getcwd()));
        output.put(':');
        output.put(msg.line.to!string);
        output.put('>');
    }

    if((style && LogMessageStyle.funcInfo) > 0)
    {
        output.put("::");
        output.put(msg.function_);
    }

    if(output.data.length > 0)
        output.put(' ');

    output.put(msg.message);
}

package void defaultMessageColourer(ref AnsiText text, LogMessage msg, LogMessageStyle style)
{
    if((style & LogMessageStyle.coloured) == 0)
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