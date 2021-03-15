module engine.vulkan.init.uninit;

import engine.core, engine.vulkan;

void uninitVulkanBasic()
{
    CHECK_VK(vkDeviceWaitIdle(g_device.logical));
    resourcePerThreadUninit();
    submitPerThreadUninit();

    threadJoinVulkanThreads();
    resourceGlobalUninit();
    submitGlobalUninit();
    vmaDestroyAllocator(g_vkAllocator);
    vkDestroyDevice(g_device.logical, null);
    vkDestroyInstance(g_vkInstance.handle, null);
}