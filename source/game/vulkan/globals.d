/// Since our Vulkan wrapper stuff takes on a more C-like API, we need to keep track of globals somewhere, which'll be this module.
module game.vulkan.globals;

import erupted;
import game.vulkan, game.common.maths;

// Most globals will be created during `init.d`, and from that point on won't be modified outside of being passed to Vulkan functions.
__gshared:

PhysicalDevice[]            g_physicalDevices;
PhysicalDevice              g_gpu;
LogicalDevice               g_device;
VulkanInstance              g_vkInstance;
Swapchain*                  g_swapchain;
DescriptorPoolManager*      g_descriptorPools;
VkPipelineCache             g_pipelineCache;
TexturedQuadShader          g_shaderQuadTextured;
TexturedQuadOpaquePipeline* g_pipelineQuadTexturedOpaque;
GpuCpuMemoryAllocator       g_gpuCpuAllocator;
alias g_renderPass        = RenderPass.instance;

// START aliases //
alias TexturedQuadShader          = Shader!(TexturedQuadPushConstants, TexturedQuadUniform);
alias TexturedQuadOpaquePipeline  = Pipeline!(TexturedQuadVertex, TexturedQuadPushConstants, TexturedQuadUniform);
alias TexturedQuadPipelineBuilder = PipelineBuilder!(TexturedQuadVertex, TexturedQuadPushConstants, TexturedQuadUniform);

// START Additional data types //
align(4) struct TexturedQuadPushConstants
{
}

struct TexturedQuadUniform
{
}

struct TexturedQuadVertex
{
    import arsd.color;

    vec2f position;
    vec2f uv;
    Color colour;

    static void defineAttributes(ref VertexAttributeBuilder builder)
    {
        builder = builder.location(0).format(VK_FORMAT_R32G32_SFLOAT).offset(TexturedQuadVertex.position.offsetof).build()
                         .location(1).format(VK_FORMAT_R32G32_SFLOAT).offset(TexturedQuadVertex.uv.offsetof)      .build()
                         .location(2).format(VK_FORMAT_R8G8B8A8_UINT).offset(TexturedQuadVertex.colour.offsetof)  .build();
    }
}