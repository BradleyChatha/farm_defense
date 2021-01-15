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
    VStringAndVersion[] enabledExtensions;
    VQueueFamily transferFamily;
    VQueueFamily graphicsFamily;
    VQueueFamily presentFamily;
}