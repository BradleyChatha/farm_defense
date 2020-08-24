module game.vulkan.surface;

import game.vulkan, erupted;

struct Surface
{
    mixin VkWrapperJAST!(VkSurfaceKHR, VK_DEBUG_REPORT_OBJECT_TYPE_SURFACE_KHR_EXT);
}