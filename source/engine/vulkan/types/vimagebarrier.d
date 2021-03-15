module engine.vulkan.types.vimagebarrier;

import engine.vulkan, engine.vulkan.types._vkhandlewrapper;

struct VImageBarrier
{
    VkImageMemoryBarrier asVkBarrier;
    VkPipelineStageFlags srcStage;
    VkPipelineStageFlags dstStage;

    VImageBarrier producerStage(VkPipelineStageFlags stage)
    {
        this.srcStage = stage;
        return this;
    }

    VImageBarrier consumerStage(VkPipelineStageFlags stage)
    {
        this.dstStage = stage;
        return this;
    }

    VImageBarrier producerAccess(VkAccessFlags flags)
    {
        asVkBarrier.srcAccessMask = flags;
        return this;
    }

    VImageBarrier consumerAccess(VkAccessFlags flags)
    {
        asVkBarrier.dstAccessMask = flags;
        return this;
    }

    VImageBarrier fromLayout(VkImageLayout layout)
    {
        asVkBarrier.oldLayout = layout;
        return this;
    }

    VImageBarrier toLayout(VkImageLayout layout)
    {
        asVkBarrier.newLayout = layout;
        return this;
    }

    VImageBarrier fromQueue(VQueue queue)
    {
        asVkBarrier.srcQueueFamilyIndex = queue.family.index;
        return this;
    }

    VImageBarrier toQueue(VQueue queue)
    {
        asVkBarrier.dstQueueFamilyIndex = queue.family.index;
        return this;
    }

    VImageBarrier forImage(VkImage image)
    {
        asVkBarrier.image = image;
        return this;
    }

    VImageBarrier forImage(scope ref VImage image)
    {
        return this.forImage(image.handle);
    }

    VImageBarrier forImage(scope ref VObjectRef!VImage image)
    {
        return this.forImage(image.value);
    }

    VImageBarrier forSubresource(VkImageSubresourceRange range)
    {
        asVkBarrier.subresourceRange = range;
        return this;
    }
}