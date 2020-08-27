module game.vulkan.image;

import std.experimental.logger;
import game.vulkan;

enum GpuImageType
{
    colour2D
}

struct GpuImage
{
    mixin VkWrapperJAST!VkImage;
    VkFormat format;

    this(VkImage handle, VkFormat format)
    {
        this.handle = handle;
        this.format = format;
    }
}

struct GpuImageView
{
    mixin VkSwapchainResourceWrapperJAST!VkImageView;
    GpuImage*    image;
    GpuImageType type;

    static void create(
        scope ref GpuImageView* ptr,
        scope ref GpuImage*     image,
                  GpuImageType  type
    )
    {
        const areWeRecreating = ptr !is null;
        if(!areWeRecreating)
            ptr = new GpuImageView();
        infof("%s a GpuImageView of type %s.", (areWeRecreating) ? "Recreating" : "Creating", type);

        ptr.recreateFunc = (p) => GpuImageView.create(p, image, type);

        // Determine vulkan settings.
        VkImageViewType    viewType;
        VkImageAspectFlags aspectMask;
        switch(type) with(GpuImageType)
        {
            case colour2D:
                viewType    = VK_IMAGE_VIEW_TYPE_2D;
                aspectMask |= VK_IMAGE_ASPECT_COLOR_BIT;
                break;

            default: assert(false, "Unsupported image view type");
        }

        // Create the view
        VkImageViewCreateInfo info;
        info.image                           = image.handle;
        info.viewType                        = viewType;
        info.format                          = image.format;
        info.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
        info.subresourceRange.aspectMask     = aspectMask;
        info.subresourceRange.baseMipLevel   = 0;
        info.subresourceRange.levelCount     = 1;
        info.subresourceRange.baseArrayLayer = 0;
        info.subresourceRange.layerCount     = 1;

        ptr.type  = type;
        ptr.image = image;

        if(areWeRecreating)
            vkDestroyJAST(ptr);
        
        CHECK_VK(vkCreateImageView(g_device, &info, null, &ptr.handle));
        vkTrackJAST(ptr);
    }
}