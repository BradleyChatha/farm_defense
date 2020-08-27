module game.vulkan.queue;

import std.experimental.logger;
import game.vulkan;

mixin template VkQueueJAST()
{
    mixin VkWrapperJAST!VkQueue;
    uint                queueIndex;
    CommandPoolManager* commandPools;

    this(LogicalDevice device, uint queueIndex)
    {
        infof("Creating Queue using family index %s", queueIndex);
        vkGetDeviceQueue(device, queueIndex, 0, &this.handle);
        this.queueIndex   = queueIndex;
        this.commandPools = CommandPoolManager.getByQueueIndex(device, queueIndex);
        this.debugName    = typeof(this).stringof;
    }
}

struct GraphicsQueue
{
    mixin VkQueueJAST;
}

struct PresentQueue
{
    mixin VkQueueJAST;
}

struct TransferQueue
{
    mixin VkQueueJAST;
}