module interfaces.iasset;

import engine.util, engine.graphics;
import common;

interface IAsset
{
    @property
    string name() const;

    @property
    protected void name(string name);

    // This is technically an internal function, it's just that it has to be public due to the source code layout not allowing for `package` to be used.
    final void changeName(string name)
    {
        this.name = name;
    }
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