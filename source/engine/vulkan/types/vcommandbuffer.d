module engine.vulkan.types.vcommandbuffer;

import engine.vulkan, engine.vulkan.types._vkhandlewrapper;

struct VCommandBuffer
{
    mixin VkWrapper!VkCommandBuffer;
    VQueue queue;

    this(VkCommandBuffer buffer, VQueue queue)
    {
        this.handle = buffer;
        this.queue = queue;
    }

    void barrier(VImageBarrier barrier)
    {
        vkCmdPipelineBarrier(
            this.handle,
            barrier.srcStage,
            barrier.dstStage,
            0,
            0, null,
            0, null,
            1, &barrier.asVkBarrier
        );
    }

    void barrier(VBufferBarrier barrier)
    {
        vkCmdPipelineBarrier(
            this.handle,
            barrier.srcStage,
            barrier.dstStage,
            0,
            0, null,
            1, &barrier.asVkBarrier,
            0, null
        );
    }
}