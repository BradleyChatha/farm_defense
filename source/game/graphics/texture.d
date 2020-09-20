module game.graphics.texture;

import std.experimental.logger;
import game.common, game.graphics, game.vulkan;

final class Texture : IDisposable
{
    mixin IDisposableBoilerplate;

    private
    {
        GpuImage*           _image;
        GpuImageView*       _imageView;
        Sampler*            _sampler;
        GpuCpuBuffer*       _pixelBuffer;
        CommandBuffer       _transferBuffer;
        QueueSubmitSyncInfo _uploadSync;
        vec2u               _size;
    }

    this(ubyte[] pixels, vec2u size, string debugName = "Unnamed Texture")
    {
        enforce(pixels.length == size.x * size.y * 4, "Pixel buffer is too small. Did you load it in RGBA format?");
        
        GpuImage.create(this._image, size, VK_FORMAT_R8G8B8A8_SRGB, VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_SAMPLED_BIT);
        this._image.debugName = debugName;
        this._image.memory.debugName = debugName ~ " - GPU BUFFER";

        this._pixelBuffer = g_gpuCpuAllocator.allocate(pixels.length, VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
        this._pixelBuffer.as!ubyte[0..$] = pixels[0..$];
        this._pixelBuffer.debugName = debugName ~ " - PIXEL BUFFER";

        this._transferBuffer = g_device.transfer.commandPools.get(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT).allocate(1)[0];
        this._transferBuffer.begin(ResetOnSubmit.no);
        {
            this._transferBuffer.pushDebugRegion("Uploading texture: "~debugName, Color.green.darken(0.5));
            scope(exit) this._transferBuffer.popDebugRegion();
            this._transferBuffer.transitionImageLayout(this._image, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
            this._transferBuffer.copyBufferToImage(this._pixelBuffer, this._image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL);
            this._transferBuffer.transitionImageLayout(this._image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL);
        }
        this._transferBuffer.end();
        
        this._uploadSync = g_device.transfer.submit(this._transferBuffer, null, null); 
        this._size       = size;
    }

    this(string file, string debugName = null)
    {
        import std.file : fread = read;
        import std.path : baseName;
        import game.bindings.lodepng;

        info("Loading texture from file: ", file);
        auto bytes = cast(ubyte[])fread(file);

        uint width;
        uint height;
        ubyte* pixels;
        
        auto result = lodepng_decode32(&pixels, &width, &height, bytes.ptr, bytes.length);
        if(result != 0)
        {
            import std.string : fromStringz;
            throw new Exception("Failed to load texture because: "~lodepng_error_text(result).fromStringz.idup);
        }

        this(pixels[0..width*height*4], vec2u(width, height), debugName ? debugName : file.baseName);
    }

    void onDispose()
    {
        if(this._pixelBuffer !is null)
            g_gpuCpuAllocator.deallocate(this._pixelBuffer);
        if(this._image !is null)
            vkDestroyJAST(this._image);
        if(this._imageView !is null)
            vkDestroyJAST(this._imageView);
        if(this._sampler !is null)
            vkDestroyJAST(this._sampler);
    }

    /++
     + Checks if the texture is/can be finalised.
     +
     + Notes:
     +  This function MUST be called before any usage of this texture.
     + ++/
    bool finalise()
    {
        if(this._pixelBuffer is null)
            return true;

        if(!this._uploadSync.submitHasFinished)
            return false;

        // Can finalise now.
        g_gpuCpuAllocator.deallocate(this._pixelBuffer);
        vkDestroyJAST(this._transferBuffer);

        GpuImageView.create(this._imageView, this._image, GpuImageType.colour2D);
        Sampler.create(this._sampler);

        return true;
    }

    @property
    GpuImageView* imageView()
    {
        return this._imageView;
    }

    @property
    Sampler* sampler()
    {
        return this._sampler;
    }

    @property
    vec2u size()
    {
        return this._size;
    }
}