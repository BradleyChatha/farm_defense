module implementations.texturestitchaction;

import std.typecons : Nullable;
import std.exception : enforce;
import common, interfaces, implementations;
import engine.vulkan, engine.util;

private enum MAX_IMAGE_DIMENSION = 16384; // Most widely supported max texture size throughout all Vulkan devices.

private struct TextureStitchInput
{
    IRawImageAsset asset;
    vec2u stitchOffset;
    VObjectRef!VImage image;
    VObjectRef!VBuffer buffer;
}

private struct TextureStitchContext
{
    VObjectRef!VBuffer buffer;
    vec2u size;
}

final class TextureStitchAction : IPipelineAction
{
    void appendToPipeline(SubmitPipelineBuilder builder)
    {
        enum OUTPUT_FORMAT = TextureFormats.rgba_u8;
        builder.needsFencesAtLeast(1)
               .needsBufferFor(VQueueType.graphics)
               .then((SubmitPipelineContext* ctx)
               {
                   auto graphics = ctx.graphicsBuffer.get;
                   auto pipelineContext = ctx.userContext.as!PipelineContext;
                   auto node = pipelineContext.currentStageNode;

                   // Calculate the size of the final stitched texture, as well as where each subtexture goes.
                   TextureStitchInput[] input;
                   foreach(value; node.values)
                   {
                       const name = value.textValue;
                       input ~= TextureStitchInput(pipelineContext.getAsset!IRawImageAsset(name));
                       input[$-1].image = createImage2D(
                           input[$-1].asset.size,
                           input[$-1].asset.format,
                           VK_IMAGE_TILING_OPTIMAL,
                           VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT,
                           VK_SHARING_MODE_EXCLUSIVE,
                           VK_IMAGE_LAYOUT_UNDEFINED,
                           0,
                           VMA_MEMORY_USAGE_GPU_ONLY
                       );
                       input[$-1].buffer = createBuffer(
                           input[$-1].image.value.memoryReqs.size,
                           VK_BUFFER_USAGE_TRANSFER_SRC_BIT,
                           VK_SHARING_MODE_EXCLUSIVE,
                           VMA_ALLOCATION_CREATE_MAPPED_BIT,
                           VMA_MEMORY_USAGE_CPU_TO_GPU
                       );
                       input[$-1].image.value.transition(
                           graphics, 
                           VK_IMAGE_LAYOUT_GENERAL, 
                           VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, 
                           0, 
                           VK_PIPELINE_STAGE_TRANSFER_BIT, 
                           0
                       );
                   }
                   pipelineContext.onCleanup(()
                   {
                       foreach(value; input)
                       {
                           resourceFree(value.buffer);
                           resourceFree(value.image);
                       }
                   });

                   const textureSize = calculateStitchOffsets(input);
                   
                   // Create the image, staging image, and the buffer we'll use to transfer it to the CPU.
                   auto image = createImage2D(
                       textureSize, 
                       OUTPUT_FORMAT, 
                       VK_IMAGE_TILING_OPTIMAL, 
                       VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT, 
                       VK_SHARING_MODE_EXCLUSIVE, 
                       VK_IMAGE_LAYOUT_UNDEFINED, 
                       0, 
                       VMA_MEMORY_USAGE_GPU_ONLY
                   );
                   pipelineContext.onCleanup((){ resourceFree(image); });

                   const reqs = image.value.memoryReqs;
                   auto buffer = createBuffer(
                       reqs.size,
                       VK_BUFFER_USAGE_TRANSFER_DST_BIT,
                       VK_SHARING_MODE_EXCLUSIVE,
                       VMA_ALLOCATION_CREATE_MAPPED_BIT,
                       VMA_MEMORY_USAGE_CPU_TO_GPU
                   );
                   pipelineContext.onCleanup((){ resourceFree(buffer); });

                   image.value.transition(
                       graphics, 
                       VK_IMAGE_LAYOUT_GENERAL, 
                       VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, 
                       0, 
                       VK_PIPELINE_STAGE_TRANSFER_BIT, 
                       0
                    );

                   // Blit all the images into our mega image.
                   foreach(texture; input)
                   {
                       texture.buffer.value.uploadMapped(texture.asset.bytes, 0);
                       graphics.barrier(
                           VBufferBarrier()
                           .fromQueue(graphics.queue).toQueue(graphics.queue)
                           .forBuffer(texture.buffer).ofSize(texture.asset.bytes.length)
                           .producerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .producerAccess(VK_ACCESS_TRANSFER_WRITE_BIT)
                           .consumerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .consumerAccess(VK_ACCESS_TRANSFER_READ_BIT)
                       );
                       texture.image.value.upload2D(
                           graphics,
                           texture.buffer.value,
                           0,
                           rectangleu(0, 0, texture.asset.size.x, texture.asset.size.y),
                           V_IMAGE_SUBRESOURCE_L_COLOUR_2D
                       );
                       graphics.barrier(
                           VImageBarrier()
                           .fromQueue(graphics.queue).toQueue(graphics.queue)
                           .fromLayout(VK_IMAGE_LAYOUT_GENERAL).toLayout(VK_IMAGE_LAYOUT_GENERAL)
                           .forImage(texture.image).forSubresource(V_IMAGE_SUBRESOURCE_R_COLOUR_2D)
                           .producerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .producerAccess(VK_ACCESS_TRANSFER_WRITE_BIT)
                           .consumerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .consumerAccess(VK_ACCESS_TRANSFER_READ_BIT)
                       );
                       image.value.blit2D(
                           graphics,
                           texture.image.value,
                           rectangleu(0, 0, texture.asset.size.x, texture.asset.size.y),
                           rectangleu(texture.stitchOffset.x, texture.stitchOffset.y, texture.asset.size.x, texture.asset.size.y),
                           V_IMAGE_SUBRESOURCE_L_COLOUR_2D
                       );
                       graphics.barrier(
                           VImageBarrier()
                           .fromQueue(graphics.queue).toQueue(graphics.queue)
                           .fromLayout(VK_IMAGE_LAYOUT_GENERAL).toLayout(VK_IMAGE_LAYOUT_GENERAL)
                           .forImage(image).forSubresource(V_IMAGE_SUBRESOURCE_R_COLOUR_2D)
                           .producerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .producerAccess(VK_ACCESS_TRANSFER_WRITE_BIT)
                           .consumerStage(VK_PIPELINE_STAGE_TRANSFER_BIT)
                           .consumerAccess(VK_ACCESS_TRANSFER_READ_BIT)
                       );
                   }

                   // Copy result to the buffer
                   buffer.value.upload2D(
                       graphics,
                       image.value,
                       0,
                       rectangleu(0, 0, textureSize.x, textureSize.y),
                       V_IMAGE_SUBRESOURCE_L_COLOUR_2D
                   );

                   ctx.pushUserContext(copyToGcTypedPointer(TextureStitchContext(
                       buffer,
                       textureSize
                   )));
               })
               .submit(VQueueType.graphics, 0)
               .waitOnFence!0
               .reset(VQueueType.graphics)
               .then((SubmitPipelineContext* ctx)
               {
                   auto actionContext = ctx.userContext.as!TextureStitchContext;
                   ctx.popUserContext();

                   auto pipelineContext = ctx.userContext.as!PipelineContext;
                   auto node = pipelineContext.currentStageNode;
                   const alias_ = node.getAttribute("alias", node.values[0]).textValue;
                   enforce(alias_ !is null, "When stitching textures, an alias must always be defined.");

                   import implementations;
                   pipelineContext.setAsset(
                       new RawImageAsset(actionContext.buffer.value.mappedSlice.dup, OUTPUT_FORMAT, actionContext.size, alias_),
                       null
                   );
               });
    }
}

/// Returns: The overall size of the final stitched texture.
private vec2u calculateStitchOffsets(ref TextureStitchInput[] input, uint dimension = 256, uint dimensionStep = 256)
{
    import std.algorithm : sort, remove, SwapStrategy, max;

    enforce(dimension <= MAX_IMAGE_DIMENSION, "Cannot stitch images. Resulting texture is too large.");

    // This algorithm works best when we go from largest to smallest height-wise.
    input.sort!"a.asset.size.y > b.asset.size.y"();
    vec2u finalTextureSize = vec2u(dimension, input[0].asset.size.y);
    box2u[] availableBlocks = [rectangleu(0, 0, finalTextureSize.x, finalTextureSize.y)];

    Nullable!box2u findSmallestValidBlock(const vec2u ofSize)
    {
        typeof(return) smallestBlock;
        size_t blockIndex;

        foreach(i, block; availableBlocks)
        {
            if(block.width < ofSize.x || block.height < ofSize.y)
                continue;

            if(smallestBlock.isNull || block.volume < smallestBlock.get.volume)
            {
                smallestBlock = block;
                blockIndex = i;
            }
        }

        // One would hope that .remove!unstable is near O(1) ([i] = [$-1], return [0..$-1]), and since we're always doing an O(n) iteration anyway stability isn't needed.
        // But knowing D, it'd still end up using an O(n) removal algorithm, so each call to this function is O(2n).
        if(!smallestBlock.isNull)
            availableBlocks = availableBlocks.remove!(SwapStrategy.unstable)(blockIndex);

        return smallestBlock;
    }

    foreach(ref texture; input)
    {
        auto block = findSmallestValidBlock(texture.asset.size);
        if(block.isNull)
        {
            // Try to grow the texture in height.
            // If we need more room then give up on this size, and try again with a larger size.
            const oldHeight = finalTextureSize.y;
            finalTextureSize.y += texture.asset.size.y;
            if(finalTextureSize.y > dimension)
                return calculateStitchOffsets(input, dimension + max(dimensionStep, texture.asset.size.y), dimensionStep);

            availableBlocks ~= rectangleu(0, oldHeight, finalTextureSize.x, finalTextureSize.y - oldHeight);
            block = findSmallestValidBlock(texture.asset.size);
            if(block.isNull)
                return calculateStitchOffsets(input, dimension + max(dimensionStep, texture.asset.size.y), dimensionStep); // Safeguard: we'll give up with this size.
        }

        texture.stitchOffset = block.get.min;
        block.get.min.x += texture.asset.size.x;
        if(block.get.min.x > 0)
            availableBlocks ~= block.get;

        availableBlocks ~= rectangleu(
            texture.stitchOffset.x,
            texture.stitchOffset.y + texture.asset.size.y,
            texture.asset.size.x,
            finalTextureSize.y - (texture.stitchOffset.y + texture.asset.size.y)
        );
    }

    return finalTextureSize;
}