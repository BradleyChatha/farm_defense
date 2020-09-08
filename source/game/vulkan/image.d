module game.vulkan.image;

import std.experimental.logger;
import game.vulkan, game.common;

enum GpuImageType
{
    colour2D,
    depth2D
}

struct GpuImage
{
    mixin VkWrapperJAST!VkImage;
    VkFormat   format;
    GpuBuffer* memory;
    vec2u      size;

    this(VkImage handle, VkFormat format)
    {
        this.handle = handle;
        this.format = format;
    }

    static void create(
        scope ref GpuImage*            ptr,
                  vec2u                size,
                  VkFormat             format,
                  VkImageUsageFlagBits usage,
                  bool                 isSwapchainImage = false
    ) 
    {
        assert(ptr is null || isSwapchainImage, "GpuImage does not support recreation unless the image is for the swapchain.");
        infof("Creating GpuImage of size %s format %s and usage %s", size, format, usage);

        if(ptr !is null)
        {
            vkDestroyImage(g_device, ptr.handle, null);
            g_gpuAllocator.deallocate(ptr.memory);
        }
        else
            ptr = new GpuImage();

        VkImageCreateInfo info = 
        {
            flags:          0,
            imageType:      VK_IMAGE_TYPE_2D,
            format:         format,
            extent:         VkExtent3D(size.x, size.y, 1),
            mipLevels:      1,
            arrayLayers:    1,
            samples:        VK_SAMPLE_COUNT_1_BIT,
            tiling:         VK_IMAGE_TILING_OPTIMAL,
            usage:          usage,
            sharingMode:    VK_SHARING_MODE_EXCLUSIVE,
            initialLayout:  VK_IMAGE_LAYOUT_UNDEFINED,
        };

        CHECK_VK(vkCreateImage(g_device, &info, null, &ptr.handle));

        VkMemoryRequirements memNeeds;
        vkGetImageMemoryRequirements(g_device, ptr.handle, &memNeeds);

        ptr.memory = g_gpuAllocator.allocate(memNeeds.size, VK_BUFFER_USAGE_TRANSFER_DST_BIT, memNeeds.alignment);
        vkBindImageMemory(g_device, ptr.handle, ptr.memory.memoryBlock.handle, ptr.memory.memoryRange.offset);

        ptr.size   = size;
        ptr.format = format;
        vkTrackJAST(ptr);
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

            case depth2D:
                viewType    = VK_IMAGE_VIEW_TYPE_2D;
                aspectMask |= VK_IMAGE_ASPECT_DEPTH_BIT;
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