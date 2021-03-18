module implementations.rawtexturecontainerasset;

import engine.graphics, engine.util;
import common, interfaces, implementations;

final class RawTextureContainerAsset : RawImageAsset, ITextureContainerAsset
{
    private TextureFrame[] _frames;

    this(ubyte[] data, TextureFormats format, vec2u size, string name, TextureFrame[] frames)
    {
        super(data, format, size, name);
        this._frames = frames;
    }

    @property
    TextureFrame[] frames()
    {
        return this._frames;
    }
}