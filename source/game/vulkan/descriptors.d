module game.vulkan.descriptors;

import std.experimental.logger, std.conv;
import game.vulkan, game.common.util;

struct DescriptorPoolManager
{
    private
    {
        uint              _swapchainImageIndex;
        OnFrameChangeId   _onFrameChangeId;
        DescriptorPool*[] _pools;
    }

    @disable
    this(this){}

    static void create(scope ref DescriptorPoolManager* ptr)
    {
        info("Creating DescriptorPoolManager.");
        ptr = new DescriptorPoolManager();
        ptr._onFrameChangeId = vkListenOnFrameChangeJAST(&ptr.onFrameChange);

        ptr._pools.length = g_swapchain.images.length;
        foreach(i; 0..g_swapchain.images.length)
            DescriptorPool.create(Ref(ptr._pools[i]));
    }

    void onFrameChange(uint swapchainImageIndex)
    {
        this._swapchainImageIndex = swapchainImageIndex;
        CHECK_VK(vkResetDescriptorPool(g_device, this.pool.handle, 0));
    }

    @property
    DescriptorPool* pool()
    {
        return this._pools[this._swapchainImageIndex];
    }
}

struct DescriptorPool
{
    enum MAX_PIPELINES               = 10;
    enum MAX_STATE_CHANGES_PER_IMAGE = 50;

    mixin VkSwapchainResourceWrapperJAST!VkDescriptorPool;

    static void create(scope ref DescriptorPool* ptr)
    {
        const areWeRecreating = ptr !is null;
        if(!areWeRecreating)
            ptr = new DescriptorPool();
        infof("%s the DescriptorPool.", (areWeRecreating) ? "Recreating" : "Creating");

        ptr.recreateFunc = (p) => create(p);

        VkDescriptorPoolSize[2] sizes;
        with(sizes[0])
        {
            type            = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            descriptorCount = g_swapchain.images.length.to!uint * MAX_PIPELINES * MAX_STATE_CHANGES_PER_IMAGE;
        }        
        with(sizes[1])
        {
            type            = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            descriptorCount = g_swapchain.images.length.to!uint * 2 * MAX_PIPELINES * MAX_STATE_CHANGES_PER_IMAGE; // Since we have two uniform buffers in each pipeline.
        }

        VkDescriptorPoolCreateInfo poolInfo = 
        {
            maxSets:       g_swapchain.images.length.to!uint,
            poolSizeCount: sizes.length,
            pPoolSizes:    sizes.ptr
        };

        if(areWeRecreating)
            vkDestroyJAST(ptr);

        CHECK_VK(vkCreateDescriptorPool(g_device, &poolInfo, null, &ptr.handle));
        vkTrackJAST(ptr);
    }

    DescriptorSet!UniformT allocate(UniformT)(PipelineBase* pipeline)
    {
        VkDescriptorSet handle;

        VkDescriptorSetAllocateInfo allocation = 
        {
            descriptorPool:     this,
            descriptorSetCount: 1,
            pSetLayouts:        &pipeline.descriptorLayoutHandle
        };

        CHECK_VK(vkAllocateDescriptorSets(g_device, &allocation, &handle));

        return typeof(return)(handle);
    }

    auto allocate(PipelineT)(PipelineT* pipeline)
    {
        return this.allocate!(PipelineT.UniformT)(pipeline.base);
    }
}

struct DescriptorSet(UniformT)
{
    mixin VkWrapperJAST!VkDescriptorSet;
}