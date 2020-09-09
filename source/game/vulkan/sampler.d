module game.vulkan.sampler;

import game.common, game.vulkan;

struct SamplerConfig
{
    enum DEFAULT = SamplerConfig(VK_FILTER_NEAREST, VK_FILTER_NEAREST, VK_SAMPLER_ADDRESS_MODE_REPEAT, VK_SAMPLER_ADDRESS_MODE_REPEAT, VK_SAMPLER_ADDRESS_MODE_REPEAT);

    VkFilter             minFilter;
    VkFilter             magFilter;
    VkSamplerAddressMode modeU;
    VkSamplerAddressMode modeV;
    VkSamplerAddressMode modeW;
}

struct Sampler
{
    mixin VkWrapperJAST!VkSampler;

    static void create(
        scope ref Sampler* ptr,
                  SamplerConfig config = SamplerConfig.DEFAULT
    )
    {
        assert(ptr is null, "Sampler does not support recreation.");
        ptr = new Sampler();

        VkSamplerCreateInfo info = 
        {
            magFilter:                  config.magFilter,
            minFilter:                  config.minFilter,
            addressModeU:               config.modeU,
            addressModeV:               config.modeV,
            addressModeW:               config.modeW,
            anisotropyEnable:           VK_FALSE,
            borderColor:                VK_BORDER_COLOR_INT_OPAQUE_BLACK,
            unnormalizedCoordinates:    VK_FALSE,
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