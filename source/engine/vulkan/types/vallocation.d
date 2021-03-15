module engine.vulkan.types.vallocation;

import engine.vulkan;

struct VAllocation
{
    VmaAllocation allocation;
    VmaAllocationInfo info;
    VmaMemoryUsage usage;
}