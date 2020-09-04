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
    enum MAX_PIPELINES                  = 10;
    enum MAX_STATE_CHANGES_PER_PIPELINE = 50;

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
            descriptorCount = g_swapchain.images.length.to!uint * MAX_PIPELINES * MAX_STATE_CHANGES_PER_PIPELINE;
        }        
        with(sizes[1])
        {
            type            = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            descriptorCount = g_swapchain.images.length.to!uint * 2 * MAX_PIPELINES * MAX_STATE_CHANGES_PER_PIPELINE; // Since we have two uniform buffers in each pipeline.
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
        infof("Allocated 1 descriptor set with handle %s", handle);

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

    this(VkDescriptorSet toWrap)
    {
        this.handle = toWrap;
    }
    
    void update(
        scope GpuImageView* imageView,
        scope Sampler*      sampler,
        scope GpuCpuBuffer* mandatoryUniformBuffer,
        scope GpuCpuBuffer* userUniformBuffer)
    {
        VkDescriptorImageInfo imageInfo = 
        {
            imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            imageView:   imageView.handle,
            sampler:     sampler.handle
        };

        VkDescriptorBufferInfo mandatoryInfo = 
        {
            buffer: mandatoryUniformBuffer.handle,
            offset: 0,
            range:  MandatoryUniform.sizeof.to!uint
        };

        VkDescriptorBufferInfo userInfo = 
        {
            buffer: userUniformBuffer.handle,
            offset: 0,
            range:  UniformT.sizeof.to!uint
        };

        VkWriteDescriptorSet[3] writeInfo;

        with(writeInfo[0])
        {
            dstSet          = this;
            dstBinding      = 0;
            dstArrayElement = 0;
            descriptorType  = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            descriptorCount = 1;
            pImageInfo      = &imageInfo;
        }
        with(writeInfo[1])
        {
            dstSet          = this;
            dstBinding      = 1;
            dstArrayElement = 0;
            descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            descriptorCount = 1;
            pBufferInfo     = &mandatoryInfo;
        }
        with(writeInfo[2])
        {
            dstSet          = this;
            dstBinding      = 2;
            dstArrayElement = 0;
            descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            descriptorCount = 1;
            pBufferInfo     = &userInfo;
        }

        vkUpdateDescriptorSets(g_device, writeInfo.length.to!uint, writeInfo.ptr, 0, null);
    }
}