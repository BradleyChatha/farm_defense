module common.texture;

import imagefmt;
import engine.vulkan, engine.util;
import common, interfaces;

struct RawTextureInfo
{
    TextureFormats format;
    ubyte[] data;
    vec2u size;
}

enum TextureFormats : VkFormat
{
    bc7         = VK_FORMAT_BC7_SRGB_BLOCK,
    rgba_u8     = VK_FORMAT_R8G8B8A8_UINT,
    rgba_srgb8  = VK_FORMAT_R8G8B8A8_SRGB
}

bool isValidBlitDestFormat(VkFormat format)
{
    VkFormatProperties props;
    vkGetPhysicalDeviceFormatProperties(g_device.physical, format, &props);

    return !!(props.optimalTilingFeatures & VK_FORMAT_FEATURE_BLIT_DST_BIT);
}

RawTextureInfo loadAssetAsTexture(IAsset asset)
{
    RawTextureInfo info;

    if(IRawImageAsset imageAsset = cast(IRawImageAsset)asset)
    {
        info.format = imageAsset.format;
        info.size = imageAsset.size;
        info.data = imageAsset.bytes;
    }
    else if(IRawAsset rawAsset = cast(IRawAsset)asset)
    {
        auto imgRgba8 = read_image(rawAsset.bytes, 4, 8);
        if(imgRgba8.e)
            throw new Exception("Error when converting asset '"~asset.name~"' into a texture: "~IF_ERROR[imgRgba8.e]);
        info.format = TextureFormats.rgba_u8;
        info.size = vec2u(imgRgba8.w, imgRgba8.h);
        info.data = imgRgba8.buf8.dup; // buf8 is malloced, we want it on the GC as this data might be persisted for long periods of time.
        imgRgba8.free();
    }
    else
        throw new Exception("Don't know how to load "~asset.classinfo.toString()~" ('"~asset.name~"') as a texture.");

    return info;
}