module game.vulkan.instance;

import game.vulkan;

struct VulkanInstance
{
    mixin VkWrapperJAST!VkInstance;
    VkStringArrayJAST layers;
}