module implementations.rawimageasset;

import engine.util;
import common, interfaces;

class RawImageAsset : IRawImageAsset
{
    private ubyte[] _data;
    private TextureFormats _format;
    private string _name;
    private vec2u _size;

    this(ubyte[] data, TextureFormats format, vec2u size, string name)
    {
        this._data = data;
        this._format = format;
        this._name = name;
        this._size = size;
    }

    @property
    override string name() const
    {
        return this._name;
    }

    @property
    override ubyte[] bytes()
    {
        return this._data;
    }

    @property
    override TextureFormats format() const
    {
        return this._format;
    }

    @property
    override vec2u size() const
    {
        return this._size;
    }
}