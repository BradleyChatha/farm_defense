module implementations.rawfileasset;

import sdlite;
import common, interfaces;

final class RawFileAsset : IRawAsset
{
    private ubyte[] _data;
    private string _path;
    private string _name;

    this(string path, string name)
    {
        this._path = path;
        this._name = name;
    }

    @property
    override string name() const
    {
        return this._name;
    }

    @property
    override protected void name(string value)
    {
        this._name = value;
    }

    @property
    override ubyte[] bytes()
    {
        import std.exception : enforce;
        import std.file : exists, read;

        if(this._data is null)
        {
            enforce(this._path.exists, "File does not exist: "~this._path);
            this._data = cast(ubyte[])read(this._path);
        }

        return this._data;
    }
}

final class RawFileAssetImporter : IAssetImporter
{
    override IAsset importAsset(SDLNode node, PathResolver baseDir)
    {
        const path = baseDir.resolve(node.values[0].textValue);
        return new RawFileAsset(path, node.values[0].textValue);
    }

    override string getDependencyName(SDLNode node, PathResolver baseDir)
    {
        return baseDir.resolve(node.values[0].textValue);
    }
}