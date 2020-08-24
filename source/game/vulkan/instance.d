module game.vulkan.instance;

import game.vulkan;

struct VulkanInstance
{
    mixin VkWrapperJAST!(VkInstance, VK_DEBUG_REPORT_OBJECT_TYPE_INSTANCE_EXT);
    VkStringArrayJAST layers;
}