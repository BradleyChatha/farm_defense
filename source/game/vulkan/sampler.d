module game.vulkan.sampler;

import game.common, game.vulkan;

struct Sampler
{
    mixin VkWrapperJAST!VkSampler;

    static void create(
        scope ref Sampler* ptr
    )
    {
        assert(ptr is null, "Sampler does not support recreation.");
        ptr = new Sampler();

        VkSamplerCreateInfo info = 
        {
            magFilter:                  VK_FILTER_LINEAR,
            minFilter:                  VK_FILTER_LINEAR,
            addressModeU:               VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            addressModeV:               VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            addressModeW:               VK_SAMPLER_ADDRESS_MODE_CLAMP_TO_BORDER,
            anisotropyEnable:           VK_FALSE,
            borderColor:                VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            unnormalizedCoordinates:    VK_TRUE,
            compareEnable:              VK_FALSE,
            compareOp:                  VK_COMPARE_OP_ALWAYS,
            mipmapMode:                 VK_SAMPLER_MIPMAP_MODE_NEAREST,
            mipLodBias:                 0.0f,
            minLod:                     0.0f,
            maxLod:                     0.0f
        };

        CHECK_VK(vkCreateSampler(g_device, &info, null, &ptr.handle));
        vkTrackJAST(ptr);
    }
}