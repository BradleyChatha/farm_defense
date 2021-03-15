module implementations.totextureaction;

import std.conv : to;
import std.exception : enforce;
import sdlite, imagefmt, taggedalgebraic;
import engine.vulkan, engine.core.logging, engine.util;
import common, interfaces;

private struct ToTextureActionContext
{
    union ValuesUnion
    {
        VObjectRef!VBuffer buffer;
        ubyte[] bytes;
    }

    alias Values = TaggedUnion!ValuesUnion;
    Values value;
    TextureFormats format;
    vec2u size;
    string imageAssetName;
}

final class ToTextureAction : IPipelineAction
{
    void appendToPipeline(SubmitPipelineBuilder builder)
    {
        builder.needsFencesAtLeast(1)
               .needsBufferFor(VQueueType.graphics)
               .then((SubmitPipelineContext* ctx)
                {
                    auto graphics = ctx.graphicsBuffer.get;
                    auto pipelineContext = ctx.userContext.as!PipelineContext;
                    auto node = pipelineContext.currentStageNode;

                    auto imgAsset = pipelineContext.getAsset!IRawAsset(node.values[0].textValue);
                    auto imgInfo  = loadAssetAsTexture(imgAsset);
                    const format  = node.getAttribute("format").textValue.to!TextureFormats;
                    if(isValidBlitDestFormat(format))
                    {
                        convertUsingVulkan(ctx, graphics, pipelineContext, imgInfo, format, node.values[0].textValue);
                    }
                    else switch(format) with(TextureFormats)
                    {
                        default:
                            throw new Exception("No Software or Hardware implementation for format conversion into: "~format.to!string~"("~(cast(VkFormat)format).to!string~")");
                    }
                }, "ToTexture - Conversion")
               .submit(VQueueType.graphics, 0, "ToTexture - Submit")
               .waitOnFence!0
               .reset(VQueueType.graphics)
               .then((SubmitPipelineContext* ctx)
               {
                   auto actionContext = ctx.userContext.as!ToTextureActionContext;
                   ctx.popUserContext();

                   auto pipelineContext = ctx.userContext.as!PipelineContext;
                   auto node = pipelineContext.currentStageNode;
                   const name = node.getAttribute("alias", node.values[0]).textValue;

                   ubyte[] finalRawBytes;
                   actionContext.value.visit!(
                       (VObjectRef!VBuffer buffer) { finalRawBytes = buffer.value.mappedSlice.dup; },
                       (ubyte[] bytes) { finalRawBytes = bytes; }
                   );

                   import implementations;
                   pipelineContext.setAsset(new RawImageAsset(finalRawBytes, actionContext.format, actionContext.size, actionContext.imageAssetName), name);
               }, "ToTexture - Bytes");
    }
}

private void convertUsingVulkan(SubmitPipelineContext* ctx, VCommandBuffer graphics, PipelineContext pipelineContext, RawTextureInfo rawImage, TextureFormats format, string imageName)
{
    const toFormat = cast(VkFormat)format;
    enforce(isValidBlitDestFormat(toFormat), "Your vulkan implementation cannot use "~toFormat.to!string~" as a blit destination format.");

    auto buffer = createBuffer(
        rawImage.data.length,
        VK_BUFFER_USAGE_TRANSFER_SRC_BIT | VK_BUFFER_USAGE_TRANSFER_DST_BIT,
        VK_SHARING_MODE_EXCLUSIVE,
        VMA_ALLOCATION_CREATE_MAPPED_BIT,
        VMA_MEMORY_USAGE_CPU_TO_GPU
    );
    pipelineContext.onCleanup((){ resourceFree(buffer); });
    buffer.value.uploadMapped(rawImage.data, 0);

    auto srcImage = createImage2D(
        rawImage.size,
        rawImage.format,
        VK_IMAGE_TILING_OPTIMAL,
        VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        VK_SHARING_MODE_EXCLUSIVE,
        VK_IMAGE_LAYOUT_UNDEFINED,
        0,
        VMA_MEMORY_USAGE_GPU_ONLY
    );
    pipelineContext.onCleanup((){ resourceFree(srcImage); });
    auto dstImage = createImage2D(
        rawImage.size,
        toFormat,
        VK_IMAGE_TILING_OPTIMAL,
        VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
        VK_SHARING_MODE_EXCLUSIVE,
        VK_IMAGE_LAYOUT_UNDEFINED,
        0,
        VMA_MEMORY_USAGE_GPU_TO_CPU
    );
    pipelineContext.onCleanup((){ resourceFree(dstImage); });

    // srcImage -> TRANSFER_DST_OPTIMAL
    srcImage.value.transition(
        graphics,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        0,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_WRITE_BIT
    );
    // Ensure it's safe to access the buffer
    graphics.barrier(
        VBufferBarrier()
        .forBuffer(buffer).fromOffset(0).ofSize(VK_WHOLE_SIZE)
        .fromQueue(graphics.queue).toQueue(graphics.queue)
        .producerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
        .consumerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
        .producerAccess(VK_ACCESS_TRANSFER_WRITE_BIT)
        .consumerAccess(VK_ACCESS_TRANSFER_READ_BIT)
    );
    // buffer -> srcImage transfer
    srcImage.value.upload2D(
        graphics,
        buffer.value,
        0,
        rectangleu(0, 0, srcImage.value.size.x, srcImage.value.size.y),
        V_IMAGE_SUBRESOURCE_L_COLOUR_2D
    );
    // srcImage -> TRANSFER_SRC_OPTIMAL
    srcImage.value.transition(
        graphics,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_WRITE_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_READ_BIT
    );

    // dstImage -> TRANSFER_DST_OPTIMAL
    dstImage.value.transition(
        graphics,
        VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
        VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT,
        0,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_WRITE_BIT
    );
    // srcImage -> dstImage w/ format conversion
    const copyRect = rectangleu(0, 0, rawImage.size.x, rawImage.size.y);
    dstImage.value.blit2D(
        graphics,
        srcImage.value,
        copyRect,
        copyRect,
        V_IMAGE_SUBRESOURCE_L_COLOUR_2D,
        VK_FILTER_NEAREST
    );

    // Create a new buffer if needed
    VkMemoryRequirements reqs;
    vkGetImageMemoryRequirements(g_device.logical, dstImage.value.handle, &reqs);

    auto outputBuffer = buffer;
    if(reqs.size > outputBuffer.value.userAllocSize)
    {
        outputBuffer = createBuffer(
            reqs.size, 
            VK_BUFFER_USAGE_TRANSFER_DST_BIT,
            VK_SHARING_MODE_EXCLUSIVE, 
            VMA_ALLOCATION_CREATE_MAPPED_BIT,
            VMA_MEMORY_USAGE_GPU_TO_CPU
        );
        pipelineContext.onCleanup((){ resourceFree(outputBuffer); });
    }

    // dstImage -> outputBuffer
    dstImage.value.transition(
        graphics,
        VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_WRITE_BIT,
        VK_PIPELINE_STAGE_TRANSFER_BIT,
        VK_ACCESS_TRANSFER_READ_BIT
    );
    buffer.value.upload2D(
        graphics,
        dstImage.value,
        0,
        rectangleu(0, 0, dstImage.value.size.x, dstImage.value.size.y),
        V_IMAGE_SUBRESOURCE_L_COLOUR_2D
    );

    // Persist the buffer so we can continue after the queue's submitted
    ctx.pushUserContext(copyToGcTypedPointer(ToTextureActionContext(
        ToTextureActionContext.Values(outputBuffer),
        format,
        dstImage.value.size,
        imageName
    )));
}