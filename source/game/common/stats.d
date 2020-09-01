module game.common.stats;

import std.format : format;

private Stat[string] g_stats;

enum StatType
{
    ERROR,
    Counter
}

struct Stat
{
    StatType type;
    union
    {
        ulong counter;
    }
}

ref Stat statCreateOrGetByName(string name, StatType type)
{
    auto ptr = (name in g_stats);
    if(ptr !is null)
    {
        assert(ptr.type == type, "Stat '%s' is a %s not a %s.".format(name, ptr.type, type));
        return *ptr;
    }

    g_stats[name] = Stat(type);
    return g_stats[name];
}

void statCounterIncrement(string name)
{
    statCreateOrGetByName(name, StatType.Counter).counter++;
}

const(Stat[string]) statsGetAll()
{
    return g_stats;
}

string statToJson()
{
    import std.conv : to;
    import std.json;

    JSONValue json = parseJSON("{}");

    json["frame"] = 0; // TODO
    foreach(key, value; g_stats)
    {
        json[key]         = parseJSON("{}");
        json[key]["type"] = value.type.to!string;
        
        final switch(value.type) with(StatType)
        {
            case ERROR:   assert(false);
            case Counter: json[key]["value"] = value.counter;
        }
    }

    return json.toPrettyString();
}