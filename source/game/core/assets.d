module game.core.assets;

import std.experimental.logger;
import sdlang : parseSdlFile = parseFile, Tag;
import game.core, game.common, game.graphics;

const ASSET_LIST_FILE = "./resources/assets.sdl";

private:

// START VARIABLES

Object[string] g_assets;

// START ASSET LOADING FUNCTIONS
void assetLoadTexture(Tag tag)
{
    const name = tag.values[0].get!string;
    const path = tag.values[1].get!string;

    tracef("Loading Texture Asset '%s' from path '%s'.", name, path);
    g_assets[name] = new Texture(path);
}

void assetLoadFont(Tag tag)
{
    const name = tag.values[0].get!string;
    const path = tag.values[1].get!string;

    tracef("Loading Font Asset '%s' from path '%s'.", name, path);
    g_assets[name] = new Font(path);
}

public:

// START FUNCTIONS

void assetsLoad()
{
    auto list = parseSdlFile(ASSET_LIST_FILE);

    foreach(tag; list.tags)
    {
        switch(tag.name)
        {
            case "font":    assetLoadFont(tag);    break;
            case "texture": assetLoadTexture(tag); break;
            default:        throw new Exception("Unknown tag name in top-level scope: "~tag.name);
        }
    }
}

T assetsGet(T)(string name)
{
    tracef("Getting asset '%s' as type %s.", name, T.stringof);
    return (name in g_assets) ? cast(T)g_assets[name] : null;
}