module engine.vulkan.types.vbufferbarrier;

import engine.vulkan, engine.vulkan.types._vkhandlewrapper;

struct VBufferBarrier
{
    VkBufferMemoryBarrier asVkBarrier;
    VkPipelineStageFlags srcStage;
    VkPipelineStageFlags dstStage;

    VBufferBarrier producerStage(VkPipelineStageFlags stage)
    {
        this.srcStage = stage;
        return this;
    }

    VBufferBarrier consumerStage(VkPipelineStageFlags stage)
    {
        this.dstStage = stage;
        return this;
    }

    VBufferBarrier producerAccess(VkAccessFlags flags)
    {
        asVkBarrier.srcAccessMask = flags;
        return this;
    }

    VBufferBarrier consumerAccess(VkAccessFlags flags)
    {
        asVkBarrier.dstAccessMask = flags;
        return this;
    }

    VBufferBarrier fromQueue(VQueue queue)
    {
        asVkBarrier.srcQueueFamilyIndex = queue.family.index;
        return this;
    }

    VBufferBarrier toQueue(VQueue queue)
    {
        asVkBarrier.dstQueueFamilyIndex = queue.family.index;
        return this;
    }

    VBufferBarrier forBuffer(VkBuffer buffer)
    {
        asVkBarrier.buffer = buffer;
        return this;
    }

    VBufferBarrier forBuffer(scope ref VBuffer image)
    {
        return this.forBuffer(image.handle);
    }

    VBufferBarrier forBuffer(scope ref VObjectRef!VBuffer image)
    {
        return this.forBuffer(image.value);
    }

    VBufferBarrier fromOffset(VkDeviceSize offset)
    {
        asVkBarrier.offset = offset;
        return this;
    }

    VBufferBarrier ofSize(VkDeviceSize size)
    {
        asVkBarrier.size = size;
        return this;
    }
}