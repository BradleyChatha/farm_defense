module game.vulkan.command;

import std.experimental.logger;
import std.typecons : Flag;
import arsd.color;
import game.vulkan;

alias IsPrimaryBuffer = Flag!"isPrimaryBuffer";
alias ResetOnSubmit   = Flag!"isBufferSingleUse";

private CommandPoolManager*[uint] g_managersByQueueIndex;

struct CommandPoolManager
{
    private
    {
        CommandPool[VkCommandPoolCreateFlagBits] _poolsByFlag;
        LogicalDevice                            _device;
        uint                                     _queueIndex;
    }

    this(LogicalDevice device, uint queueIndex)
    {
        infof("Creating pool manager for queue family %s", queueIndex);
        this._device     = device;
        this._queueIndex = queueIndex;
    }

    static CommandPoolManager* getByQueueIndex(LogicalDevice device, uint queueIndex)
    {
        scope ptr = (queueIndex in g_managersByQueueIndex);
        if(ptr !is null)
            return *ptr;

        auto manager = new CommandPoolManager(device, queueIndex);
        g_managersByQueueIndex[queueIndex] = manager;

        return manager;
    }

    CommandPool get(VkCommandPoolCreateFlagBits flags)
    {
        scope ptr = (flags in this._poolsByFlag);
        if(ptr !is null)
            return *ptr;

        auto pool = CommandPool(this._device, this._queueIndex, flags);
        this._poolsByFlag[flags] = pool;
        
        return pool;
    }
}

struct CommandPool
{
    mixin VkWrapperJAST!VkCommandPool;
    VkCommandPoolCreateFlagBits flags;
    uint                        queueIndex;

    this(LogicalDevice device, uint queueIndex, VkCommandPoolCreateFlagBits flags)
    {
        infof("Creating pool for queue family %s with flags %s", queueIndex, flags);

        VkCommandPoolCreateInfo info = 
        {
            queueFamilyIndex: queueIndex,
            flags:            flags
        };

        this.queueIndex = queueIndex;
        CHECK_VK(vkCreateCommandPool(device, &info, null, &this.handle));
        vkTrackJAST(this);
    }

    CommandBuffer[] allocate(uint count, IsPrimaryBuffer isPrimary = IsPrimaryBuffer.yes)
    {
        tracef("Allocating %s %s command buffers with flags %s.", count, (isPrimary) ? "primary" : "secondary", this.flags);

        VkCommandBufferAllocateInfo info = 
        {
            commandPool:        this,
            level:              (isPrimary) ? VK_COMMAND_BUFFER_LEVEL_PRIMARY : VK_COMMAND_BUFFER_LEVEL_SECONDARY,
            commandBufferCount: count
        };

        // This function will be called *after* LogicalDevice is constructed, so we can safely use g_device now.
        auto handles = new VkCommandBuffer[count];
        CHECK_VK(vkAllocateCommandBuffers(g_device, &info, handles.ptr));

        auto buffers = new CommandBuffer[count];
        foreach(i, handle; handles)
        {
            buffers[i] = CommandBuffer(this, handle, this.queueIndex);
            vkTrackJAST(buffers[i]);
        }

        return buffers;
    }
}

struct CommandBuffer
{
    mixin VkWrapperJAST!VkCommandBuffer;
    CommandPool                 pool;
    VkCommandPoolCreateFlagBits flags;
    uint                        queueIndex;

    this(CommandPool pool, VkCommandBuffer handle, uint queueIndex)
    {
        this.pool       = pool;
        this.handle     = handle;
        this.queueIndex = queueIndex;
    }

    // COMMON
    public
    {
        void begin(ResetOnSubmit resetOnSubmit)
        {
            VkCommandBufferBeginInfo info;

            if(resetOnSubmit)
                info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

            vkBeginCommandBuffer(this, &info);
        }

        void end()
        {
            vkEndCommandBuffer(this);
        }

        void reset()
        {
            vkResetCommandBuffer(this, 0);
        }

        void insertDebugMarker(lazy string name, Color colour = Color(255, 255, 255, 0))
        {
            if(vkCmdInsertDebugUtilsLabelEXT is null)
                return;

            import std.string : toStringz;

            VkDebugUtilsLabelEXT info;
            info.pLabelName = name.toStringz;
            info.color      = colour.toSrgb();

            vkCmdInsertDebugUtilsLabelEXT(this, &info);
        }

        void pushDebugRegion(lazy string name, Color colour = Color(255, 255, 255, 0))
        {
            if(vkCmdBeginDebugUtilsLabelEXT is null)
                return;

            import std.string : toStringz;

            VkDebugUtilsLabelEXT info;
            info.pLabelName = name.toStringz;
            info.color      = colour.toSrgb();

            vkCmdBeginDebugUtilsLabelEXT(this, &info);
        }

        void popDebugRegion()
        {
            if(vkCmdEndDebugUtilsLabelEXT !is null)
                vkCmdEndDebugUtilsLabelEXT(this);
        }
    }

    // GRAPHICS
    public
    {
        void beginRenderPass(Framebuffer* framebuffer)
        {
            VkClearValue[2] clearColour;
            clearColour[0].color        = VkClearColorValue([0.5f, 0.5f, 0.25f, 1.0f]);
            clearColour[1].depthStencil = VkClearDepthStencilValue(1.0f, 0);

            VkRenderPassBeginInfo info = 
            {
                renderPass:      g_renderPass,
                framebuffer:     framebuffer.handle,
                clearValueCount: clearColour.length,
                pClearValues:    clearColour.ptr
            };
            info.renderArea.offset = VkOffset2D(0, 0);
            info.renderArea.extent = g_swapchain.capabilities.currentExtent;

            vkCmdBeginRenderPass(this, &info, VK_SUBPASS_CONTENTS_INLINE);
        }

        void endRenderPass()
        {
            vkCmdEndRenderPass(this);
        }

        void bindPipeline(PipelineBase* pipeline)
        {
            vkCmdBindPipeline(this, VK_PIPELINE_BIND_POINT_GRAPHICS, pipeline.handle);
        }

        void bindVertexBuffer(GpuBuffer* buffer)
        {
            VkDeviceSize size = 0;
            vkCmdBindVertexBuffers(this, 0, 1, &buffer.handle, &size);
        }

        void bindDescriptorSets(PipelineBase* pipeline, VkDescriptorSet textureSet, VkDescriptorSet lightingSet)
        {
            VkDescriptorSet[2] sets = 
            [
                textureSet,
                lightingSet
            ];
            vkCmdBindDescriptorSets(
                this,
                VK_PIPELINE_BIND_POINT_GRAPHICS,
                pipeline.layoutHandle,
                0,
                2, sets.ptr,
                0, null
            );
        }

        void drawVerts(uint count, uint offset)
        {
            vkCmdDraw(this, count, 1, offset, 0);
        }

        void pushConstants(PushConstantT)(PipelineBase* pipeline, PushConstantT value)
        {
            vkCmdPushConstants(
                this, 
                pipeline.layoutHandle,
                VK_SHADER_STAGE_VERTEX_BIT | VK_SHADER_STAGE_FRAGMENT_BIT,
                0,
                cast(uint)PushConstantT.sizeof,
                &value
            );
        }
    }

    // TRANSFER
    public
    {
        void copyBuffer(
            ulong         amountInBytes,
            GpuCpuBuffer* from,
            ulong         fromOffset,
            GpuBuffer*    to,
            ulong         toOffset 
        )
        {
            VkBufferCopy region = 
            {
                srcOffset: VkDeviceSize(fromOffset),
                dstOffset: VkDeviceSize(toOffset),
                size:      VkDeviceSize(amountInBytes)
            };

            vkCmdCopyBuffer(this, from.handle, to.handle, 1, &region);
        }

        void copyBufferToImage(
            GpuCpuBuffer* from,
            GpuImage*     image,
            VkImageLayout imageLayout
        )
        {
            VkImageSubresourceLayers layers = 
            {
                aspectMask: VK_IMAGE_ASPECT_COLOR_BIT,
                layerCount: 1
            };

            VkBufferImageCopy info = 
            {
                imageExtent:      VkExtent3D(image.size.x, image.size.y, 1),
                imageSubresource: layers
            };

            vkCmdCopyBufferToImage(this, from.handle, image.handle, imageLayout, 1, &info);
        }

        void transitionImageLayout(
            GpuImage*     image,
            VkImageLayout oldLayout,
            VkImageLayout newLayout
        )
        {
            VkImageMemoryBarrier barrier = 
            {
                oldLayout: oldLayout,
                newLayout: newLayout,
                srcQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
                dstQueueFamilyIndex: VK_QUEUE_FAMILY_IGNORED,
                image: image.handle
            };
            barrier.subresourceRange.aspectMask = VK_IMAGE_ASPECT_COLOR_BIT;
            barrier.subresourceRange.levelCount = 1;
            barrier.subresourceRange.layerCount = 1;

            VkPipelineStageFlags srcStage;
            VkPipelineStageFlags dstStage;

            if(oldLayout == VK_IMAGE_LAYOUT_UNDEFINED
            && newLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL)
            {
                barrier.srcAccessMask = 0;
                barrier.dstAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;

                srcStage = VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT;
                dstStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
            }
            else if(oldLayout == VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL
                 && newLayout == VK_IMAGE_LAYOUT_SHADER_READ_ONLY_OPTIMAL)
            {
                barrier.srcAccessMask = VK_ACCESS_TRANSFER_WRITE_BIT;
                barrier.dstAccessMask = VK_ACCESS_SHADER_READ_BIT;

                srcStage = VK_PIPELINE_STAGE_TRANSFER_BIT;
                dstStage = VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT;
            }
            else assert(false, "Unsupported image transition");

            vkCmdPipelineBarrier(
                this,
                srcStage, dstStage,
                0,
                0, null,
                0, null,
                1, &barrier
            );
        }
    }
}