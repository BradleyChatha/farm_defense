module interfaces.iasset;

import engine.util, engine.graphics;
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

interface ITextureContainerAsset : IRawImageAsset
{
    @property
    TextureFrame[] frames();
}