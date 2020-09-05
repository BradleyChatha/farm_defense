module game.graphics.renderer;

import stdx.allocator, stdx.allocator.building_blocks;
import std.experimental.logger;
import game.common, game.graphics, game.vulkan;

// Following the weird C-like API for the Vulkan wrapper stuff, I want to see what a renderer in that style may look like.
// Just gonna KISS it, and only support one vertex type for now.

private:

// START Command/Queue related variables.
Semaphore[]                         g_renderImageAvailableSemaphores;
Semaphore[]                         g_renderRenderFinishedSemaphores;
Semaphore                           g_currentImageAvailableSemaphore;
CommandBuffer[]                     g_renderGraphicsCommandBuffers;
QueueSubmitSyncInfo[]               g_renderGraphicsSubmitSyncInfos;
DescriptorSet!TexturedQuadUniform[] g_renderDescriptorSets;
uint                                g_imageIndex;

// START Resource related variables.
enum MAX_VERTS          = 100_002;
enum MAX_VERTS_IN_BYTES = TexturedQuadVertex.sizeof * MAX_VERTS;
enum VERTS_PER_QUAD     = 6;
enum MAX_QUADS          = MAX_VERTS / VERTS_PER_QUAD;
enum MAX_QUADS_IN_BYTES = MAX_QUADS * TexturedQuadVertex.sizeof;

alias QuadAllocator     = ContiguousFreeList!(NullAllocator, TexturedQuadVertex.sizeof * VERTS_PER_QUAD);
alias QuadCpuBookkeeper = BitmappedBookkeeper!MAX_QUADS;

static assert(MAX_VERTS % VERTS_PER_QUAD == 0, "MAX_VERTS needs to be a multiple of VERTS_PER_QUAD");

QuadAllocator       g_quadAllocator;
GpuCpuBuffer*       g_quadCpuBuffer;
GpuBuffer*          g_quadGpuBuffer;
QuadCpuBookkeeper   g_quadCpuBookkeeper;

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

    g_renderDescriptorSets.length = imageCount;
    foreach(i; 0..imageCount)
        g_renderDescriptorSets[i] = g_descriptorPools.pool.allocate!TexturedQuadUniform(g_pipelineQuadTexturedOpaque.base); // Should work fine...

    recreateSemaphores(Ref(g_renderImageAvailableSemaphores));
    recreateSemaphores(Ref(g_renderRenderFinishedSemaphores));

    g_renderGraphicsSubmitSyncInfos.length = imageCount;
}

// START PRIVATE Resource Functions
void renderOnQuadModification(size_t offset, TexturedQuadVertex[] verts)
{
    g_quadCpuBuffer.as!TexturedQuadVertex[offset..offset+verts.length] = verts[0..$];

    auto bufferForThisFrame = g_renderGraphicsCommandBuffers[g_imageIndex];
    bufferForThisFrame.insertDebugMarker("Copy modified Quads");
    bufferForThisFrame.copyBuffer(
        verts.length * TexturedQuadVertex.sizeof,
        g_quadCpuBuffer, offset * TexturedQuadVertex.sizeof,
        g_quadGpuBuffer, offset * TexturedQuadVertex.sizeof
    );
}

public:

DescriptorSet!TexturedQuadUniform TEST_uniforms;

// START Data Types
struct QuadAllocation
{
    private
    {
        size_t               _offsetIntoCpuBuffer;
        size_t               _bookkeepingStartBit;
        TexturedQuadVertex[] _verts;
        bool                 _allowModify;
    }

    @disable
    this(this){}

    void beginModify()
    {
        assert(!this._allowModify, "Redundant call to beginModify");
        this._allowModify = true;
    }

    void endModifyAndUpdate()
    {
        this._allowModify = false;
        renderOnQuadModification(this._offsetIntoCpuBuffer, this._verts);
    }

    @property
    const(TexturedQuadVertex[]) vertsReadOnly()
    {
        return cast(const)this._verts;
    }

    @property
    TexturedQuadVertex[] vertsMutable()
    {
        assert(this._allowModify, "QuadAllocation is not in modify mode.");
        return this._verts;
    }
}

// START Resource Functions
QuadAllocation renderAllocateQuads(size_t quadCount)
{
    tracef("Allocating %s quads.", quadCount);

    const vertCount = (quadCount * VERTS_PER_QUAD);
    auto  verts     = g_quadAllocator.makeArray!TexturedQuadVertex(vertCount);
    if(verts is null)
    {
        trace("Not enough memory left inside of the quad allocator.");
        return QuadAllocation.init;
    }

    size_t startBit;
    bool couldAllocate = g_quadCpuBookkeeper.markNextNBits(Ref(startBit), quadCount);
    if(!couldAllocate)
    {
        trace("No space left in the CPU/GPU buffers.");
        return QuadAllocation.init;
    }

    const offsetIntoBuffer = (startBit * VERTS_PER_QUAD);
    tracef("Quad allocation bookkeeping starts at bit %s and data starts at offset %s.", startBit, offsetIntoBuffer);

    return QuadAllocation(offsetIntoBuffer, startBit, verts);
}

void renderFreeQuads(ref QuadAllocation quads)
{
    const quadCount = (quads._verts.length / VERTS_PER_QUAD);
    tracef("Deallocating %s quads whose bookkeeping starts at bit %s and data starts at offset %s.", 
          quadCount, quads._bookkeepingStartBit, quads._offsetIntoCpuBuffer
    );

    g_quadCpuBookkeeper.setBitRange!false(quads._bookkeepingStartBit, quadCount);
    g_quadAllocator.dispose(quads._verts);
    g_quadCpuBuffer.as!TexturedQuadVertex[quads._offsetIntoCpuBuffer..quads._offsetIntoCpuBuffer+quads._verts.length] = TexturedQuadVertex.init;

    quads = QuadAllocation.init;
}

// START Render Functions
void renderInit()
{
    onSwapchainRecreate(cast(uint)g_swapchain.images.length);

    vkListenOnFrameChangeJAST((v) => onFrameChange(v));
    vkListenOnSwapchainRecreateJAST((v) => onSwapchainRecreate(v));

    g_quadCpuBuffer = g_gpuCpuAllocator.allocate(MAX_QUADS_IN_BYTES, VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
    g_quadGpuBuffer = g_gpuAllocator.allocate(MAX_QUADS_IN_BYTES, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);
    g_quadAllocator = QuadAllocator(new ubyte[MAX_QUADS_IN_BYTES]);
    g_quadCpuBookkeeper.setup();
}

void renderBegin()
{
    g_currentImageAvailableSemaphore = g_renderImageAvailableSemaphores[g_imageIndex];

    uint imageIndex;
    const imageFetchResult = vkAcquireNextImageKHR(
        g_device,
        g_swapchain.handle,
        ulong.max,
        g_currentImageAvailableSemaphore,
        null,
        &imageIndex
    );
    
    vkEmitOnFrameChangeJAST(imageIndex);
    while(g_renderGraphicsSubmitSyncInfos[imageIndex] != QueueSubmitSyncInfo.init 
      && !g_renderGraphicsSubmitSyncInfos[imageIndex].submitHasFinished
    )
    {
        g_device.graphics.processFences();
    }

    auto buffer = g_renderGraphicsCommandBuffers[g_imageIndex];
    buffer.begin(ResetOnSubmit.yes);

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
    import bindbc.sdl : SDL_GetTicks;

    auto buffer = g_renderGraphicsCommandBuffers[g_imageIndex];

    buffer.pushDebugRegion("Begin Render Pass");
    buffer.beginRenderPass(g_swapchain.framebuffers[g_imageIndex]);

    {
        buffer.pushDebugRegion("Pipeline Textured Opaque");
        scope(exit) buffer.popDebugRegion();
        buffer.bindPipeline(g_pipelineQuadTexturedTransparent.base);
        buffer.bindVertexBuffer(g_quadGpuBuffer);
        buffer.pushConstants(g_pipelineQuadTexturedTransparent.base, TexturedQuadPushConstants(SDL_GetTicks()));
        buffer.bindDescriptorSet(g_pipelineQuadTexturedTransparent.base, TEST_uniforms);
        buffer.drawVerts(MAX_QUADS, 0);
    }

    buffer.endRenderPass();
    buffer.popDebugRegion();
    buffer.end();

    // Submit primary graphics buffer.
    auto renderFinishedSemaphore = g_renderRenderFinishedSemaphores[g_imageIndex];
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