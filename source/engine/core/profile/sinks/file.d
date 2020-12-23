module engine.core.profile.sinks.file;

import std.file, std.path, std.stdio, std.datetime, std.format, std.conv;
import taggedalgebraic;
import engine.core;

private const OUTPUT_PARENT_DIR = "./profiling/";

void profileFlushAddFileSink()
{
    profileAddSinkFactory(() => new Sink());
}

private final class Sink : IProfileSink
{
    File file;

    override void start(string threadName, SysTime initTime)
    {
        const dir  = "%s-%s-%s %s.%s.%s".format(initTime.year, initTime.month, initTime.day, initTime.hour, initTime.minute, initTime.second);
        const file = buildNormalizedPath(OUTPUT_PARENT_DIR, dir, threadName~".json");
        mkdirRecurse(file.dirName);
        this.file  = File(file, "w");
    }

    override void push(ProfileBlock block)
    {
        import std.json; // Forgive me lord, for I have sinned this day.

        JSONValue root = parseJSON("{}");
        root["name"] = block.name;
        root["start"] = block.time.start.toISOString();
        root["end"] = block.time.end.toISOString();
        root["elapsed_hnsecs"] = block.time.elapsed().total!"hnsecs".to!string();

        JSONValue[] values;
        foreach(value; block.values[0..block.valueCount])
        {
            JSONValue obj = parseJSON("{}");
            obj["type"] = value.kind.to!string();
            value.visit!(
                (ProfileStartEnd timer)
                {
                    obj["name"] = timer.name;
                    obj["start"] = timer.start.toISOString();
                    obj["end"] = timer.end.toISOString();
                    obj["elapsed_hnsecs"] = block.time.elapsed().total!"hnsecs".to!string();
                }
            );
            values ~= obj;
        }

        root["values"] = values;
        this.file.writeln(root.toPrettyString());
    }

    override void end()
    {
        this.file.close();
    }
}  