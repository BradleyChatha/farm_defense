/// Since our Vulkan wrapper stuff takes on a more C-like API, we need to keep track of globals somewhere, which'll be this module.
module game.vulkan.globals;

import bindbc.freetype, erupted;
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
TexturedQuadPipeline*       g_pipelineQuadTexturedOpaque;
TexturedQuadPipeline*       g_pipelineQuadTexturedTransparent;
GpuCpuMemoryAllocator       g_gpuCpuAllocator;
GpuMemoryAllocator          g_gpuAllocator;
alias g_renderPass        = RenderPass.instance;

// START globals for third party rendering libs //
FT_Library g_freeType;

// START aliases //
alias TexturedQuadShader          = Shader!(PushConstants, TexturedQuadUniform);
alias TexturedQuadPipeline        = Pipeline!(TexturedVertex, PushConstants, TexturedQuadUniform);
alias TexturedQuadPipelineBuilder = PipelineBuilder!(TexturedVertex, PushConstants, TexturedQuadUniform);

// START Additional data types //
align(4) struct PushConstants
{
    // Vulkan spec guarentees at least 128 bytes of push constant memory, exactly enough for 2 mat4fs.
    mat4f projection;
    mat4f view;
}

struct TexturedQuadUniform
{
}

struct TexturedVertex
{
    import arsd.color;

    vec3f position;
    vec2f uv;
    Color colour;

    static void defineAttributes(ref VertexAttributeBuilder builder)
    {
        builder = builder.location(0).format(VK_FORMAT_R32G32B32_SFLOAT).offset(TexturedVertex.position.offsetof).build()
                         .location(1).format(VK_FORMAT_R32G32_SFLOAT).offset(TexturedVertex.uv.offsetof)         .build()
                         .location(2).format(VK_FORMAT_R8G8B8A8_UINT).offset(TexturedVertex.colour.offsetof)     .build();
    }
}