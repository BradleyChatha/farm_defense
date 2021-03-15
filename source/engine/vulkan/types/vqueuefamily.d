module engine.vulkan.types.vqueuefamily;

import engine.vulkan;

enum FAMILY_NOT_FOUND = uint.max;

struct VQueueFamily
{
    uint index = FAMILY_NOT_FOUND;
    uint queueCount;

    this(uint index, VkQueueFamilyProperties family)
    {
        this.index = index;
        this.queueCount = family.queueCount;
    }
}