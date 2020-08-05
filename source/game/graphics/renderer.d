module game.graphics.renderer;

import std.experimental.logger;
import erupted, erupted.vulkan_lib_loader, bindbc.sdl, arsd.color, gfm.math;
import game.graphics.window, game.graphics.sdl, game.common.util, game.graphics.vulkan;

struct Vertex
{
    vec2f position;
    Color colour;

    this(vec2f position, Color colour)
    {
        this.position = position;
        this.colour   = colour;
    }

    this(float x, float y, Color colour)
    {
        this(vec2f(x, y), colour);
    }
}

final class Renderer
{
    private
    {
        VkClearValue _clearColour = VkClearValue(VkClearColorValue([0.0f, 0.0f, 0.0f, 1.0f]));
    }

    void drawTriangle(Vertex[3] verts)
    {
        const start = RendererResources._vertsToRenderCount;
        RendererResources.addVerts(verts);
    }

    void startFrame()
    {
        auto swapchain = RendererResources._swapchain;

        // Get the index for our next available image
        uint imageIndex;
        auto imageResult = vkAcquireNextImageKHR(swapchain.vulkan.device.logical.handle, swapchain.vulkan.handle, uint.max, swapchain.imageAvailableSemaphore.handle, null, &imageIndex);
        swapchain.setFrame(imageIndex);

        vkWaitForFences(swapchain.vulkan.device.logical.handle, 1, &swapchain.fence.handle, VK_TRUE, uint.max);

        // Start command buffer
        VkCommandBufferBeginInfo beginInfo;
        beginInfo.flags = 0;
        CHECK_VK(vkBeginCommandBuffer(swapchain.graphicsBuffer.handle, &beginInfo));

        // Start render pass
        VkRenderPassBeginInfo renderInfo;
        renderInfo.renderPass        = RendererResources._pipeline.renderPass.handle;
        renderInfo.framebuffer       = swapchain.framebuffer.handle;
        renderInfo.renderArea.offset = VkOffset2D(0, 0);
        renderInfo.renderArea.extent = swapchain.vulkan.extent;
        renderInfo.clearValueCount   = 1;
        renderInfo.pClearValues      = &this._clearColour;
        
        vkCmdBeginRenderPass(swapchain.graphicsBuffer.handle, &renderInfo, VK_SUBPASS_CONTENTS_INLINE);

        if(imageResult == VK_ERROR_OUT_OF_DATE_KHR || imageResult == VK_SUBOPTIMAL_KHR)
        {
            this.endFrame(); // Clear any state that'd end up in limbo otherwise.
            VulkanResources.recreateSwapchain();
            this.startFrame();
            return;
        }

        // Bind the pipeline and main vertex buffer
        vkCmdBindPipeline(swapchain.graphicsBuffer.handle, VK_PIPELINE_BIND_POINT_GRAPHICS, RendererResources._pipeline.handle);

        VkBuffer[1] buffers = 
        [
            RendererResources._gpuVertBuffer.handle
        ];
        VkDeviceSize[1] offsets =
        [
            VkDeviceSize(0)
        ];
        vkCmdBindVertexBuffers(swapchain.graphicsBuffer.handle, 0, 1, buffers.ptr, offsets.ptr);

        // TEMP
        this.drawTriangle([
            Vertex(0.0f, -0.0f, Color.red),
            Vertex(0.5f, 0.5f,  Color.green),
            Vertex(-0.5f, 0.5f, Color.blue)
        ]);
    }

    void endFrame()
    {
        auto swapchain = RendererResources._swapchain;

        // Upload verticies, and issue draw commands.
        vkCmdDraw(swapchain.graphicsBuffer.handle, cast(uint)RendererResources._vertsToRenderCount, 1, 0, 0);
        RendererResources.submitFrame();

        // Finish frame
        vkCmdEndRenderPass(swapchain.graphicsBuffer.handle);
        CHECK_VK(vkEndCommandBuffer(swapchain.graphicsBuffer.handle));

        // Submit our graphics queue
        VkSemaphore[1]          signalSemaphores  = [swapchain.renderFinishedSemaphore.handle];
        VkSemaphore[1]          waitForSemaphores = [swapchain.imageAvailableSemaphore.handle];
        VkPipelineStageFlags[1] waitForStages     = [VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT];
        VkCommandBuffer[1]      commandBuffers    = [swapchain.graphicsBuffer.handle];
        VkSubmitInfo            submitInfo;
        submitInfo.waitSemaphoreCount   = waitForSemaphores.length;
        submitInfo.pWaitSemaphores      = waitForSemaphores.ptr;
        submitInfo.pWaitDstStageMask    = waitForStages.ptr;
        submitInfo.commandBufferCount   = commandBuffers.length;
        submitInfo.pCommandBuffers      = commandBuffers.ptr;
        submitInfo.signalSemaphoreCount = signalSemaphores.length;
        submitInfo.pSignalSemaphores    = signalSemaphores.ptr;

        vkResetFences(swapchain.vulkan.device.logical.handle, 1, &swapchain.fence.handle);
        CHECK_VK(vkQueueSubmit(swapchain.vulkan.device.logical.graphicsQueue.handle, 1, &submitInfo, swapchain.fence.handle));

        // Present the results to our swap chain
        uint currentFrame = cast(uint)swapchain._currentFrame;
        VkSwapchainKHR[1] swapchains = [swapchain.vulkan.handle];
        VkPresentInfoKHR presentInfo;
        presentInfo.waitSemaphoreCount = signalSemaphores.length;
        presentInfo.pWaitSemaphores    = signalSemaphores.ptr;
        presentInfo.swapchainCount     = swapchains.length;
        presentInfo.pSwapchains        = swapchains.ptr;
        presentInfo.pImageIndices      = &currentFrame;

        vkQueuePresentKHR(swapchain.vulkan.device.logical.presentQueue.handle, &presentInfo);
    }
}

final class RendererResources
{
    private static
    {
        Swapchain       _swapchain;
        VulkanPipeline* _pipeline;
        VulkanBuffer    _gpuVertBuffer;
        Vertex[]        _vertBuffer;
        size_t          _vertsToRenderCount;
    }

    public static
    {
    }

    private static
    {
        void addVerts(Vertex[] verts)
        {
            const end = this._vertsToRenderCount + verts.length;
            if(end > this._vertBuffer.length)
                this._vertBuffer.length = end * 2;

            this._vertBuffer[this._vertsToRenderCount..end] = verts[];
            this._vertsToRenderCount = end;
        }

        void submitFrame()
        {
            import std.math : fmin;

            const countInBytes = cast(size_t)fmin(this._vertsToRenderCount * Vertex.sizeof, this._gpuVertBuffer.memory.size);

            // Upload verts
            scope void* data;
            vkMapMemory(this._gpuVertBuffer.device.logical.handle, this._gpuVertBuffer.memory.handle, 0, countInBytes, 0, &data);
            data[0..countInBytes] = cast(ubyte[])(this._vertBuffer[0..countInBytes / Vertex.sizeof]);
            vkUnmapMemory(this._gpuVertBuffer.device.logical.handle, this._gpuVertBuffer.memory.handle);

            this._vertsToRenderCount = 0;
        }
    }

    package static
    {
        void onPostVulkanInit(
            VulkanSwapchain* swapchain,
            VulkanPipeline*  pipeline,
            VulkanBuffer     vertBuffer
        )
        {
            this._swapchain     = new Swapchain(swapchain);
            this._pipeline      = pipeline;
            this._gpuVertBuffer = vertBuffer;
        }
    }
}

// HELPER/UTILITY CLASES //

private final class Swapchain
{
    private
    {
        VulkanSwapchain* _swapchain;
        size_t           _frameCount;
        size_t           _currentFrame;
    }

    this(VulkanSwapchain* swapchain)
    {
        this._swapchain  = swapchain;
        this._frameCount = swapchain.framebuffers.length;

        infof("Wrapping swapchain with %s frames", this._frameCount);
    }

    void setFrame(size_t frame)
    {
        assert(frame < this._frameCount);

        auto thisFrameImageReadySemaphore = this._swapchain.imageAvailableSemaphores[this._currentFrame];
        this._swapchain.imageAvailableSemaphores[this._currentFrame] = this._swapchain.imageAvailableSemaphores[frame];
        this._swapchain.imageAvailableSemaphores[frame] = thisFrameImageReadySemaphore;

        this._currentFrame = frame;
    }

    @property
    VulkanImage* image()
    {
        return this._swapchain.images[this._currentFrame];
    }

    @property
    VulkanImageView* colourView()
    {
        return this._swapchain.imageColourViews[this._currentFrame];
    }

    @property
    VulkanFramebuffer* framebuffer()
    {
        return this._swapchain.framebuffers[this._currentFrame];
    }

    @property
    VulkanCommandBuffer* graphicsBuffer()
    {
        return this._swapchain.graphicsBuffers[this._currentFrame];
    }

    @property
    VulkanSwapchain* vulkan()
    {
        return this._swapchain;
    }
    
    @property
    VulkanSemaphore imageAvailableSemaphore()
    {
        return this._swapchain.imageAvailableSemaphores[this._currentFrame];
    }

    @property
    VulkanSemaphore renderFinishedSemaphore()
    {
        return this._swapchain.renderFinishedSemaphores[this._currentFrame];
    }

    @property
    ref VulkanFence fence()
    {
        return this._swapchain.fences[this._currentFrame];
    }
}