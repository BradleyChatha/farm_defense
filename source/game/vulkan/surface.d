module game.vulkan.surface;

import game.vulkan, erupted;

struct Surface
{
    mixin VkWrapperJAST!VkSurfaceKHR;
}