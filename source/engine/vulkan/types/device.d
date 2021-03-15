module engine.vulkan.types.device;

import engine.vulkan;

struct Device
{
    VkPhysicalDevice physical;
    VkPhysicalDeviceProperties properties;
    VkPhysicalDeviceFeatures features;
    VkPhysicalDeviceMemoryProperties memoryProperties;
    VkQueueFamilyProperties[] queueFamilies;
    VStringAndVersion[] allExtensions;
    
    VkDevice logical;
    VStringAndVersion[string] enabledExtensions;
    VQueueFamily transferFamily;
    VQueueFamily graphicsFamily;
    VQueueFamily computeFamily;
    VQueueFamily presentFamily;
    VQueue transfer;
    VQueue graphics;
    VQueue present;
    VQueue compute;
    VQueue[VQueueType.max+1] queueByType;
}