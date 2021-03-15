module engine.vulkan.init._08_load_vma;

import engine.vulkan, engine.core;

void _08_load_vma()
{
    logfInfo("08. Creating VMA allocator.");

    // Erupted exposes vulkan functions as function pointers, not "proper" functions, so the linked vma lib doesn't know how to find anything we load.
    // So this is just to forward all the pointers through.
    VmaVulkanFunctions funcs = 
    {
        vkGetPhysicalDeviceProperties: vkGetPhysicalDeviceProperties,
        vkGetPhysicalDeviceMemoryProperties: vkGetPhysicalDeviceMemoryProperties,
        vkAllocateMemory: vkAllocateMemory,
        vkFreeMemory: vkFreeMemory,
        vkMapMemory: vkMapMemory,
        vkUnmapMemory: vkUnmapMemory,
        vkFlushMappedMemoryRanges: vkFlushMappedMemoryRanges,
        vkInvalidateMappedMemoryRanges: vkInvalidateMappedMemoryRanges,
        vkBindBufferMemory: vkBindBufferMemory,
        vkBindImageMemory: vkBindImageMemory,
        vkGetBufferMemoryRequirements: vkGetBufferMemoryRequirements,
        vkGetImageMemoryRequirements: vkGetImageMemoryRequirements,
        vkCreateBuffer: vkCreateBuffer,
        vkDestroyBuffer: vkDestroyBuffer,
        vkCreateImage: vkCreateImage,
        vkDestroyImage: vkDestroyImage,
        vkCmdCopyBuffer: vkCmdCopyBuffer
    };

    VmaAllocatorCreateInfo info = 
    {
        physicalDevice: g_device.physical,
        device: g_device.logical,
        frameInUseCount: 1,
        instance: g_vkInstance.handle,
        vulkanApiVersion: VK_API_VERSION_1_0,
        pVulkanFunctions: &funcs
    };
    CHECK_VK(vmaCreateAllocator(&info, &g_vkAllocator));
}