module interfaces.iasset;

import engine.util;
import common;

interface IAsset
{
    @property
    string name() const;
}

interface IRawAsset : IAsset
{
    @property
    ubyte[] bytes();
}

interface IRawImageAsset : IRawAsset
{
    @property
    TextureFormats format() const;

    @property
    vec2u size() const;
}