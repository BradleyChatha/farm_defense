module engine.vulkan.types.vqueuefamily;

import engine.vulkan;

struct VQueueFamily
{
    uint index;
    uint queueCount;

    this(uint index, VkQueueFamilyProperties family)
    {
        this.index = index;
        this.queueCount = family.queueCount;
    }
}