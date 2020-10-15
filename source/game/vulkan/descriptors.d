module game.vulkan.descriptors;

import std.experimental.logger, std.conv;
import game.vulkan, game.common.util;

// Most of the stuff in here is a crock of shit, but still useable for what I need.
struct DescriptorPoolManager
{
    private
    {
        uint              _swapchainImageIndex;
        OnFrameChangeId   _onFrameChangeId;
        DescriptorPool*[] _pools;
        DescriptorPool*   _persistentPool;
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
            DescriptorPool.create(ptr._pools[i]);

        DescriptorPool.create(ptr._persistentPool, false);
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

    // Doesn't get reset between frames. Only one pool as opposed to one pool per swapchain image.
    @property
    DescriptorPool* persistentPool()
    {
        return this._persistentPool;
    }
}

struct DescriptorPool
{
    enum MAX_SETS = 10_000;

    mixin VkSwapchainResourceWrapperJAST!VkDescriptorPool;

    static void create(scope ref DescriptorPool* ptr, bool allowRecreate = true)
    {
        const areWeRecreating = ptr !is null;
        if(areWeRecreating && !allowRecreate)
            return;

        if(!areWeRecreating)
            ptr = new DescriptorPool();
        infof("%s the DescriptorPool.", (areWeRecreating) ? "Recreating" : "Creating");

        ptr.recreateFunc = (p) => create(p, allowRecreate);

        VkDescriptorPoolSize[1] sizes;
        with(sizes[0])
        {
            type            = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            descriptorCount = g_swapchain.images.length.to!uint * MAX_SETS;
        }

        VkDescriptorPoolCreateInfo poolInfo = 
        {
            maxSets:       MAX_SETS,
            poolSizeCount: sizes.length,
            pPoolSizes:    sizes.ptr
        };

        if(areWeRecreating)
            vkDestroyJAST(ptr);

        CHECK_VK(vkCreateDescriptorPool(g_device, &poolInfo, null, &ptr.handle));
        vkTrackJAST(ptr);
    }

    DescriptorSet allocate(VkDescriptorSetLayout layout)
    {
        VkDescriptorSet handle;

        VkDescriptorSetAllocateInfo allocation = 
        {
            descriptorPool:     this,
            descriptorSetCount: 1,
            pSetLayouts:        &layout
        };

        CHECK_VK(vkAllocateDescriptorSets(g_device, &allocation, &handle));

        return typeof(return)(handle);
    }
}

struct DescriptorSet
{
    mixin VkWrapperJAST!VkDescriptorSet;

    this(VkDescriptorSet toWrap)
    {
        this.handle = toWrap;
    }

    // One function for each type of descriptor set.

    void updateImage(
        scope GpuImageView* imageView,
        scope Sampler*      sampler
    )
    {
        VkDescriptorImageInfo imageInfo = 
        {
            imageLayout: VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL,
            imageView:   imageView.handle,
            sampler:     sampler.handle
        };        
        
        VkWriteDescriptorSet writeInfo;
        with(writeInfo)
        {
            dstSet          = this;
            dstBinding      = 0;
            dstArrayElement = 0;
            descriptorType  = VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER;
            descriptorCount = 1;
            pImageInfo      = &imageInfo;
        }

        vkUpdateDescriptorSets(g_device, 1, &writeInfo, 0, null);
    }

    void updateLighting(scope GpuCpuBuffer* buffer, size_t offset = 0)
    {
        VkDescriptorBufferInfo info = 
        {
            buffer: buffer.handle,
            offset: offset.to!uint,
            range:  LightingUniform.sizeof.to!uint
        };

        VkWriteDescriptorSet writeInfo;
        with(writeInfo)
        {
            dstSet          = this;
            dstBinding      = 0;
            dstArrayElement = 0;
            descriptorType  = VK_DESCRIPTOR_TYPE_UNIFORM_BUFFER;
            descriptorCount = 1;
            pBufferInfo     = &info;
        }

        vkUpdateDescriptorSets(g_device, 1, &writeInfo, 0, null);
    }
}