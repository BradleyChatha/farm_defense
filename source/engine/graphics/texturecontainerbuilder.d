module engine.graphics.texturecontainerbuilder;

import std.exception : enforce;
import engine.graphics, engine.util, engine.vulkan;

private enum ContainerSourceType
{
    ERROR,
    vimage,
    bytes
}

// Create a staging buffer; upload to staging buffer; transfer from buffer into image; done.
// By default we'll assume that the texture is used for colour attachments, because that's going to be the most common case.
private auto DEFAULT_UPLOAD_TEXTURE_PIPELINE = 
    (new SubmitPipelineBuilder())
    .needsFences(1)
    .needsBufferFor(VQueueType.graphics)
    .then((SubmitPipelineContext* ctx)
    {
        auto graphics = ctx.graphicsBuffer.get;
        auto uploadContext = ctx.userContext.asPtr!TextureContainerUploadPipelineContext;
        uploadContext.outputImage = createImage2D(
            uploadContext.size, 
            uploadContext.format, 
            VK_IMAGE_TILING_OPTIMAL, 
            VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, 
            VK_SHARING_MODE_EXCLUSIVE, 
            VK_IMAGE_LAYOUT_UNDEFINED, 
            0, 
            VmaMemoryUsage.VMA_MEMORY_USAGE_GPU_ONLY
        );

        uploadContext.stagingBuffer = createBuffer(
            uploadContext.outputImage.value.memoryReqs.size,
            VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
            VK_SHARING_MODE_EXCLUSIVE,
            VmaAllocationCreateFlagBits.VMA_ALLOCATION_CREATE_MAPPED_BIT,
            VmaMemoryUsage.VMA_MEMORY_USAGE_CPU_TO_GPU
        );

        uploadContext.stagingBuffer.value.uploadMapped(uploadContext.bytes, 0);
        graphics.barrier(
            VBufferBarrier()
            .fromQueue(graphics.queue).toQueue(graphics.queue)
            .forBuffer(uploadContext.stagingBuffer).ofSize(uploadContext.bytes.length)
            .producerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
            .producerAccess(VK_ACCESS_TRANSFER_WRITE_BIT)
            .consumerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
            .consumerAccess(VK_ACCESS_TRANSFER_READ_BIT)
        );
        uploadContext.outputImage.value.transition(
            graphics,
            VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_ACCESS_TRANSFER_WRITE_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_ACCESS_TRANSFER_READ_BIT
        );
        uploadContext.outputImage.value.upload2D(
            graphics,
            uploadContext.stagingBuffer.value,
            0,
            rectangleu(0, 0, uploadContext.size.x, uploadContext.size.y),
            V_IMAGE_SUBRESOURCE_L_COLOUR_2D
        );
        uploadContext.outputImage.value.transition(
            graphics,
            VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_ACCESS_TRANSFER_WRITE_BIT,
            VK_PIPELINE_STAGE_FRAGMENT_SHADER_BIT,
            VK_ACCESS_SHADER_READ_BIT
        );
    })
    .submit(VQueueType.graphics, 0)
    .waitOnFence!0
    .then((SubmitPipelineContext* ctx)
    {
        resourceFree(ctx.userContext.as!TextureContainerUploadPipelineContext.stagingBuffer);
    })
    .build();

struct TextureContainerUploadPipelineContext
{
    ubyte[] bytes;
    VkFormat format;
    vec2u size;

    VObjectRef!VBuffer stagingBuffer;
    VObjectRef!VImage outputImage;
}

struct TextureContainerBuilder
{
    private ContainerSourceType _type;
    private TextureFrame[string] _framesByName;
    private union
    {
        VObjectRef!VImage _fromImage;

        struct
        {
            TextureContainerUploadPipelineContext _fromBytesContext;
            SubmitPipeline _fromBytesPipeline;
        }
    }

    TextureContainerBuilder fromImage(VObjectRef!VImage image)
    {
        this._fromImage = image;
        this._type = ContainerSourceType.vimage;
        return this;
    }

    TextureContainerBuilder fromBytes(ubyte[] bytes, VkFormat format, vec2u size, lazy SubmitPipeline pipeline = DEFAULT_UPLOAD_TEXTURE_PIPELINE)
    {
        this._fromBytesContext.bytes = bytes;
        this._fromBytesContext.format = format;
        this._fromBytesContext.size = size;
        this._fromBytesPipeline = pipeline;
        this._type = ContainerSourceType.bytes;
        return this;
    }

    TextureContainerBuilder defineFrame(const TextureFrame frame)
    {
        enforce((frame.name in this._framesByName) is null, "Frame '"~frame.name~"' is already defined!");
        this._framesByName[frame.name] = frame;
        return this;
    }

    TextureContainer build()
    {
        final switch(this._type) with(ContainerSourceType)
        {
            case ERROR: assert(false, "No call to .fromImage or .fromBytes was made.");
            case vimage: return new TextureContainer(this._fromImage);
            case bytes:
                auto ctx = this._fromBytesContext;

                // I don't gain too much at the moment by allowing async texture uploads, so we'll just do this slow but easy way.
                // As a near-negligable side benefit, this stack frame will always exist alongside the pipeline execution, so we don't need to
                // allocate the context onto the heap.
                auto pipeline = submitPipeline(this._fromBytesPipeline, copyToBorrowedTypedPointer(&ctx));
                submitExecute(SubmitPipelineExecutionType.runToEnd, pipeline);

                assert(pipeline.isDone, "???");
                assert(ctx.outputImage.isValidNotNull, "No output image was made by the pipeline.");
                return new TextureContainer(ctx.outputImage);
        }
    }
}