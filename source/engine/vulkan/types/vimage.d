module engine.vulkan.types.vimage;

import bindings.vma;
import engine.core, engine.vulkan, engine.vulkan.types._vkhandlewrapper, engine.util.maths;

enum V_IMAGE_SUBRESOURCE_L_COLOUR_2D = VkImageSubresourceLayers(VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1);
enum V_IMAGE_SUBRESOURCE_R_COLOUR_2D = VkImageSubresourceRange(VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1);

struct VImageInfo
{
    VkFormat format;
    VkImageTiling tiling;
    VkImageUsageFlags usage;
    VkSharingMode sharing;
    VkImageLayout initialLayout;
}

struct VImage
{
    mixin VkWrapper!(VkImage, HasLifetimeInfo.yes);
    VAllocation allocInfo;
    VImageInfo imageInfo;
    vec2u size;
    package VkImageLayout currentLayout = VK_IMAGE_LAYOUT_UNDEFINED;

    this(VkImage image)
    {
        this.handle = image;
    }

    this(vec2u size, VkImage image, VAllocation allocInfo, VImageInfo info)
    {
        this(image);
        this.allocInfo = allocInfo;
        this.imageInfo = info;
        this.size = size;
    }

    VkMemoryRequirements memoryReqs()
    {
        VkMemoryRequirements reqs;
        vkGetImageMemoryRequirements(g_device.logical, this.handle, &reqs);

        return reqs;
    }

    void transition(
        VCommandBuffer commands,
        VQueue fromQueue,
        VQueue toQueue,
        VkImageLayout to, 
        VkPipelineStageFlags producerStage, 
        VkAccessFlags producerAccess, 
        VkPipelineStageFlags consumerStage, 
        VkAccessFlags consumerAccess
    )
    {
        commands.barrier(
            VImageBarrier()
            .forImage(this)
            .forSubresource(V_IMAGE_SUBRESOURCE_R_COLOUR_2D)
            .fromQueue(fromQueue).toQueue(toQueue)
            .fromLayout(this.currentLayout).toLayout(to)
            .producerStage(producerStage)
            .consumerStage(consumerStage)
            .producerAccess(producerAccess)
            .consumerAccess(consumerAccess)
        );
        this.currentLayout = to;
    }

    void transition(
        VCommandBuffer commands,
        VkImageLayout to, 
        VkPipelineStageFlags producerStage, 
        VkAccessFlags producerAccess, 
        VkPipelineStageFlags consumerStage, 
        VkAccessFlags consumerAccess
    )
    {
        this.transition(commands, commands.queue, commands.queue, to, producerStage, producerAccess, consumerStage, consumerAccess);
    }

    void upload2D(VCommandBuffer commands, scope ref VBuffer buffer, VkDeviceSize bufferOffset, box2u copyRegion, VkImageSubresourceLayers subresource)
    {
        VkBufferImageCopy copyInfo = 
        {
            bufferOffset: bufferOffset,
            imageSubresource: subresource,
            imageOffset: VkOffset3D(copyRegion.min.x, copyRegion.min.y, 0),
            imageExtent: VkExtent3D(copyRegion.width, copyRegion.height, 1)
        };

        vkCmdCopyBufferToImage(
            commands.handle,
            buffer.handle,
            this.handle,
            this.currentLayout,
            1, &copyInfo
        );
    }

    void upload2D(
        VCommandBuffer commands, 
        scope ref VImage fromImage, 
        vec2u fromOffset, 
        vec2u toOffset, 
        vec2u size,
        VkImageSubresourceLayers resource
    )
    {
        VkImageCopy copyInfo = 
        {
            srcSubresource: resource,
            dstSubresource: resource,
            srcOffset: VkOffset3D(fromOffset.x, fromOffset.y, 0),
            dstOffset: VkOffset3D(toOffset.x, toOffset.y, 0),
            extent: VkExtent3D(size.x, size.y, 1)
        };

        vkCmdCopyImage(
            commands.handle,
            this.handle,
            this.currentLayout,
            fromImage.handle,
            fromImage.currentLayout,
            1, &copyInfo
        );
    }

    void blit2D(
        VCommandBuffer commands,
        scope ref VImage fromImage,
        box2u fromRect,
        box2u toRect,
        VkImageSubresourceLayers resource,
        VkFilter filter = VK_FILTER_NEAREST
    )
    {
        VkImageBlit blitInfo = 
        {
            srcSubresource: resource,
            dstSubresource: resource,
            srcOffsets: [VkOffset3D(fromRect.min.x, fromRect.min.y, 0), VkOffset3D(fromRect.max.x, fromRect.max.y, 1)],
            dstOffsets: [VkOffset3D(toRect.min.x, toRect.min.y, 0), VkOffset3D(toRect.max.x, toRect.max.y, 1)]
        };

        vkCmdBlitImage(
            commands.handle,
            fromImage.handle,
            fromImage.currentLayout,
            this.handle,
            this.currentLayout,
            1, &blitInfo,
            filter
        );
    }
}

VObjectRef!VImage createImage2D(
    vec2u size,
    VkFormat format,
    VkImageTiling tiling,
    VkImageUsageFlags usage,
    VkSharingMode sharing,
    VkImageLayout layout,
    VmaAllocationCreateFlags allocFlags,
    VmaMemoryUsage memoryUsage,
    scope VQueue[] sharingQueues = null
)
{
    UniqueIndexBuffer buffer;
    const uniqueQueueIndicies = sharingQueues.findUniqueIndicies(buffer);
    VkImageCreateInfo imageInfo = 
    {
        extent                : VkExtent3D(size.x, size.y, 1),
        imageType             : VK_IMAGE_TYPE_2D,
        format                : format,
        mipLevels             : 1,
        arrayLayers           : 1,
        samples               : VK_SAMPLE_COUNT_1_BIT,
        tiling                : tiling,
        usage                 : usage,
        sharingMode           : sharing,
        initialLayout         : layout,
        queueFamilyIndexCount : cast(uint)uniqueQueueIndicies.length,
        pQueueFamilyIndices   : uniqueQueueIndicies.ptr
    };

    VmaAllocationCreateInfo allocInfo =
    {
        flags   : allocFlags,
        usage   : memoryUsage,
    };

    VImageInfo imageSettings = 
    {
        format          : format,
        tiling          : tiling,
        usage           : usage,
        sharing         : sharing,
        initialLayout   : layout
    };

    VkImage image;
    VAllocation alloc;

    CHECK_VK(vmaCreateImage(
        g_vkAllocator,
        &imageInfo,
        &allocInfo,
        &image,
        &alloc.allocation,
        &alloc.info
    ));
    alloc.usage = memoryUsage;

    auto obj = resourceMake!VImage(size, image, alloc, imageSettings);
    obj.value.freeImpl = (VImage* ptr)
    {
        vmaDestroyImage(g_vkAllocator, ptr.handle, ptr.allocInfo.allocation);
    };

    return obj;
}