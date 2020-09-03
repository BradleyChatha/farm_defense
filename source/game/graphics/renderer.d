module game.graphics.renderer;

import std.experimental.logger;
import game.common, game.graphics, game.vulkan;

// Following the weird C-like API for the Vulkan wrapper stuff, I want to see what a renderer in that style may look like.

private:

// START Variables
Semaphore[]           g_renderImageAvailableSemaphores;
Semaphore[]           g_renderRenderFinishedSemaphores;
Semaphore             g_currentImageAvailableSemaphore;
CommandBuffer[]       g_renderGraphicsCommandBuffers;
QueueSubmitSyncInfo[] g_renderGraphicsSubmitSyncInfos;
uint                  g_imageIndex;

// START Vulkan Event Callbacks
void onFrameChange(uint imageIndex)
{
    g_imageIndex = imageIndex;
}

void onSwapchainRecreate(uint imageCount)
{   
    void recreateSemaphores(ref Semaphore[] sems)
    {
        foreach(sem; sems)
            vkDestroyJAST(sem);

        sems.length = imageCount;

        foreach(ref sem; sems)
            sem = Semaphore(g_device);
    }

    foreach(buffer; g_renderGraphicsCommandBuffers)
        vkDestroyJAST(buffer);
    g_renderGraphicsCommandBuffers = g_device.graphics.commandPools.get(VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT).allocate(imageCount);

    recreateSemaphores(Ref(g_renderImageAvailableSemaphores));
    recreateSemaphores(Ref(g_renderRenderFinishedSemaphores));

    g_renderGraphicsSubmitSyncInfos.length = imageCount;
}

// START Resource getter funcs
GpuImage* imageByIndex(uint index)
{
    return g_swapchain.images[index];
}

Framebuffer* framebufferByIndex(uint index)
{
    return g_swapchain.framebuffers[index];
}

Semaphore imageAvailableSemaphoreByIndex(uint index)
{
    return g_renderImageAvailableSemaphores[index];
}

Semaphore renderFinishedSemaphoreByIndex(uint index)
{
    return g_renderRenderFinishedSemaphores[index];
}

QueueSubmitSyncInfo graphicsSyncInfoByIndex(uint index)
{
    return g_renderGraphicsSubmitSyncInfos[index];
}

CommandBuffer graphicsCommandBufferByIndex(uint index)
{
    return g_renderGraphicsCommandBuffers[index];
}

public:

// START Functions
void renderInit()
{
    onSwapchainRecreate(cast(uint)g_swapchain.images.length);

    vkListenOnFrameChangeJAST((v) => onFrameChange(v));
    vkListenOnSwapchainRecreateJAST((v) => onSwapchainRecreate(v));
}

void renderBegin()
{
    g_currentImageAvailableSemaphore = imageAvailableSemaphoreByIndex(g_imageIndex);

    uint imageIndex;
    const imageFetchResult = vkAcquireNextImageKHR(
        g_device,
        g_swapchain.handle,
        ulong.max,
        g_currentImageAvailableSemaphore,
        null,
        &imageIndex
    );
    
    do vkEmitOnFrameChangeJAST(imageIndex);
    while(graphicsSyncInfoByIndex(imageIndex) != QueueSubmitSyncInfo.init && !graphicsSyncInfoByIndex(imageIndex).submitHasFinished);

    if(imageFetchResult == VK_ERROR_OUT_OF_DATE_KHR || imageFetchResult == VK_SUBOPTIMAL_KHR)
    {
        renderEnd(); // Clear any state that'd end up in limbo otherwise.
        vkDeviceWaitIdle(g_device);
        vkRecreateAllJAST();
        renderBegin();
        return;
    }
}

void renderEnd()
{
    auto buffer = graphicsCommandBufferByIndex(g_imageIndex);
    buffer.begin(ResetOnSubmit.yes);

    buffer.insertDebugMarker("Begin Render Pass");
    buffer.beginRenderPass(framebufferByIndex(g_imageIndex));

    {
        buffer.pushDebugRegion("Pipeline Textured Opaque");
        scope(exit) buffer.popDebugRegion();
        buffer.bindPipeline(g_pipelineQuadTexturedOpaque.base);
        // Draw
    }

    buffer.endRenderPass();
    buffer.end();

    // Submit primary graphics buffer.
    auto renderFinishedSemaphore = renderFinishedSemaphoreByIndex(g_imageIndex);
    auto imageAvailableSemaphore = g_currentImageAvailableSemaphore;
    g_renderGraphicsSubmitSyncInfos[g_imageIndex] = g_device.graphics.submit(
        buffer, 
        &renderFinishedSemaphore, 
        &imageAvailableSemaphore,
        VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT 
    );

    // Present changes to screen.
    VkPresentInfoKHR presentInfo =
    {
        waitSemaphoreCount: 1,
        swapchainCount:     1,
        pWaitSemaphores:    &renderFinishedSemaphore.handle,
        pSwapchains:        &g_swapchain.handle,
        pImageIndices:      &g_imageIndex
    };

    vkQueuePresentKHR(g_device.present.handle, &presentInfo);
}