/// Since our Vulkan wrapper stuff takes on a more C-like API, we need to keep track of globals somewhere, which'll be this module.
module game.vulkan.globals;

import erupted;
import game.vulkan, game.common.maths;

// Most globals will be created during `init.d`, and from that point on won't be modified outside of being passed to Vulkan functions.
__gshared:

PhysicalDevice[]    g_physicalDevices;
PhysicalDevice      g_gpu;
LogicalDevice       g_device;
VulkanInstance      g_vkInstance;
Swapchain*          g_swapchain;
VkPipelineCache     g_pipelineCache;
TexturedQuadShader  g_shaderQuadTextured;

// START Additional data types //
struct TexturedQuadPushConstants
{

}

struct TexturedQuadUniform
{
}

alias TexturedQuadShader = Shader!(TexturedQuadPushConstants, TexturedQuadUniform);