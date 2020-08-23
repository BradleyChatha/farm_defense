module game.vulkan.queue;

import std.experimental.logger;
import game.vulkan;

mixin template VkQueueJAST()
{
    mixin VkWrapperJAST!VkQueue;

    this(LogicalDevice device, int queueIndex)
    {
        infof("Creating Queue using family index %s", queueIndex);
        vkGetDeviceQueue(device, queueIndex, 0, &this.handle);
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