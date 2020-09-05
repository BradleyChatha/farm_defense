module game.graphics.renderer;

import stdx.allocator, stdx.allocator.building_blocks;
import std.experimental.logger;
import game.common, game.graphics, game.vulkan;

// Following the weird C-like API for the Vulkan wrapper stuff, I want to see what a renderer in that style may look like.
// Just gonna KISS it, and only support one vertex type for now.

private:

// START private Data types
struct MemoryRange
{
    size_t offset;
    size_t length;
}

struct RenderBucket
{
    Texture             texture;
    MandatoryUniform    mandatoryUniforms;
    TexturedQuadUniform quadUniforms;
    MemoryRange         gpuRangeInVerts;
    bool                usesTransparency;

    bool rangeIsSideBySideWith(RenderBucket bucket)
    {
        return (bucket.gpuRangeInVerts.offset > this.gpuRangeInVerts.offset)
               ? this.gpuRangeInVerts.offset + this.gpuRangeInVerts.length     == bucket.gpuRangeInVerts.offset
               : bucket.gpuRangeInVerts.offset + bucket.gpuRangeInVerts.length == this.gpuRangeInVerts.offset;
    }

    // Any bucket with the same settings, and with verts who live side-by-side, are compatible.
    bool isCompatibleWith(RenderBucket bucket)
    {
        return (
            this.texture           is bucket.texture
         && this.mandatoryUniforms == bucket.mandatoryUniforms
         && this.quadUniforms      == bucket.quadUniforms
         && this.usesTransparency  == bucket.usesTransparency
         && this.rangeIsSideBySideWith(bucket)
        );
    }

    void merge(RenderBucket bucket)
    {
        assert(this.isCompatibleWith(bucket));

        if(bucket.gpuRangeInVerts.offset > this.gpuRangeInVerts.offset)
            this.gpuRangeInVerts.length += bucket.gpuRangeInVerts.length;
        else
            this.gpuRangeInVerts.offset = bucket.gpuRangeInVerts.offset;
    }
}
unittest
{
    RenderBucket b1;
    RenderBucket b2;
    
    b2.gpuRangeInVerts.offset += 2;
    assert(!b1.isCompatibleWith(b2));
    assert(!b2.isCompatibleWith(b1));

    b1.gpuRangeInVerts.length += 2;
    assert(b1.isCompatibleWith(b2));
    assert(b2.isCompatibleWith(b1));

    b2.gpuRangeInVerts.length = 1;
    b1.merge(b2);
    assert(b1.gpuRangeInVerts.offset == 0);
    assert(b1.gpuRangeInVerts.length == 3);
}

// START Command/Queue related variables.
Semaphore[]                         g_renderImageAvailableSemaphores;
Semaphore[]                         g_renderRenderFinishedSemaphores;
Semaphore                           g_currentImageAvailableSemaphore;
CommandBuffer[]                     g_renderGraphicsCommandBuffers;
QueueSubmitSyncInfo[]               g_renderGraphicsSubmitSyncInfos;
DescriptorSet!TexturedQuadUniform[] g_renderDescriptorSets;
GpuCpuBuffer*[]                     g_renderDescriptorSetBuffersMandatory;
GpuCpuBuffer*[]                     g_renderDescriptorSetBuffersQuad;
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
RenderBucket[]      g_renderBuckets;
size_t              g_renderBucketCount;

// START Render state variables
Texture             g_renderTexture;
MandatoryUniform    g_uniformsMandatory;
TexturedQuadUniform g_uniformsQuad;
bool                g_renderEnableBlending;

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

    g_renderDescriptorSetBuffersMandatory.length = imageCount;
    g_renderDescriptorSetBuffersQuad.length      = imageCount;
    foreach(i; 0..imageCount)
    {
        g_renderDescriptorSetBuffersMandatory[i] = g_gpuCpuAllocator.allocate(MandatoryUniform.sizeof,    VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
        g_renderDescriptorSetBuffersQuad[i]      = g_gpuCpuAllocator.allocate(TexturedQuadUniform.sizeof, VK_BUFFER_USAGE_UNIFORM_BUFFER_BIT);
    }

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

void renderAddBucket(RenderBucket bucket)
{
    if(g_renderBucketCount >= g_renderBuckets.length)
        g_renderBuckets.length = (g_renderBuckets.length + 1) * 2;

    if(g_renderBucketCount == 0 || !g_renderBuckets[g_renderBucketCount - 1].isCompatibleWith(bucket))
    {
        g_renderBuckets[g_renderBucketCount++] = bucket;
        return;
    }

    g_renderBuckets[g_renderBucketCount - 1].merge(bucket);
}

public:

// START public Data Types
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

void renderQuads(ref QuadAllocation quads, size_t quadCount = size_t.max, size_t quadOffset = 0)
{
    import std.algorithm : min;

    auto startVertex = quads._offsetIntoCpuBuffer + (min(quads._verts.length / VERTS_PER_QUAD, quadOffset) * VERTS_PER_QUAD);
    auto endVertex   = startVertex + min(quadCount, quads._verts.length - (quadCount * VERTS_PER_QUAD));

    renderAddBucket(RenderBucket(
        g_renderTexture,
        g_uniformsMandatory,
        g_uniformsQuad,
        MemoryRange(startVertex, endVertex),
        g_renderEnableBlending,
    ));
}

void renderSetTexture(Texture texture)
{
    assert(texture !is null);
    g_renderTexture = texture;
}

void renderUseBlending(bool useBlending)
{
    g_renderEnableBlending = useBlending;
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
    import std.format : format;
    import bindbc.sdl : SDL_GetTicks;

    auto buffer = g_renderGraphicsCommandBuffers[g_imageIndex];

    buffer.pushDebugRegion("Begin Render Pass");
    buffer.beginRenderPass(g_swapchain.framebuffers[g_imageIndex]);

    // {
    //     buffer.pushDebugRegion("Pipeline Textured Opaque");
    //     scope(exit) buffer.popDebugRegion();
    //     buffer.bindPipeline(g_pipelineQuadTexturedTransparent.base);
    //     buffer.bindVertexBuffer(g_quadGpuBuffer);
    //     buffer.pushConstants(g_pipelineQuadTexturedTransparent.base, TexturedQuadPushConstants(SDL_GetTicks()));
    //     buffer.bindDescriptorSet(g_pipelineQuadTexturedTransparent.base, TEST_uniforms);
    //     buffer.drawVerts(MAX_QUADS, 0);
    // }

    buffer.pushDebugRegion("Setting bucket-common data");
        buffer.bindVertexBuffer(g_quadGpuBuffer);
        buffer.pushConstants(g_pipelineQuadTexturedTransparent.base, TexturedQuadPushConstants(SDL_GetTicks()));
    buffer.popDebugRegion();
    foreach(i, bucket; g_renderBuckets[0..g_renderBucketCount])
    {
        assert(bucket.texture !is null,    "There must be a texture.");
        assert(!bucket.texture.isDisposed, "Texture has been disposed of.");

        if(!bucket.texture.finalise())
            continue;
        
        auto pipeline = (bucket.usesTransparency) ? g_pipelineQuadTexturedTransparent.base : g_pipelineQuadTexturedOpaque.base;
        buffer.pushDebugRegion("Bucket %s Texture %s Blending %s".format(i, bucket.texture, bucket.usesTransparency), Color(38, 72, 102, 255));
            buffer.bindPipeline(pipeline);

            auto uniforms = g_descriptorPools.pool.allocate!TexturedQuadUniform(pipeline);
            uniforms.update(
                bucket.texture.imageView, 
                bucket.texture.sampler,
                g_renderDescriptorSetBuffersMandatory[g_imageIndex],
                g_renderDescriptorSetBuffersQuad[g_imageIndex]
            );
            buffer.bindDescriptorSet(pipeline, uniforms);
            buffer.drawVerts(cast(uint)bucket.gpuRangeInVerts.length, cast(uint)bucket.gpuRangeInVerts.offset);
        buffer.popDebugRegion();
    }

    buffer.endRenderPass();
    buffer.popDebugRegion();
    buffer.end();

    // Clear buckets
    g_renderBucketCount = 0;

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