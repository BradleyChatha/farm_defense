module engine.vulkan.types.vfence;


import std.exception : enforce;
import engine.vulkan, engine.vulkan.types._vkhandlewrapper;

struct VFence
{
    mixin VkWrapper!VkFence;

    void reset()
    {
        assert(this.handle != VK_NULL_HANDLE, "This VFence has not been initialised.");
        CHECK_VK(vkResetFences(g_device.logical, 1, &this.handle));
    }

    bool isSignaled()
    {
        const result = vkGetFenceStatus(g_device.logical, this.handle);
        enforce(result != VK_ERROR_DEVICE_LOST, "Device was lost.");

        return result == VK_SUCCESS;
    }
}