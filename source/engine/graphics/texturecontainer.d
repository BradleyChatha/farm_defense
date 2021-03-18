module engine.graphics.texturecontainer;

import engine.core, engine.vulkan, engine.util, engine.graphics;

final class TextureContainer : IResource, IDisposable
{
    mixin IResourceBoilerplate;
    mixin IDisposableBoilerplate;

    private VObjectRef!VImage _gpuTexture;
    private TextureFrame[string] _framesByName;

    private void disposeImpl()
    {
        if(this._gpuTexture.isValid)
            resourceFree(this._gpuTexture);
    }

    package this(VObjectRef!VImage fromImage)
    {
        assert(fromImage.isValidNotNull);
        this._gpuTexture = fromImage;
    }
}