module implementations.tomaterialaction;

import std.conv : to;
import std.exception : enforce;
import engine.core, engine.vulkan, engine.graphics;
import common, interfaces;

final class ToMaterialAction : IPipelineAction
{
    void appendToPipeline(SubmitPipelineBuilder builder)
    {
        builder.then((SubmitPipelineContext* ctx)
        {
            auto pipelineContext = ctx.userContext.as!PipelineContext;
            auto node = pipelineContext.currentStageNode;

            auto vertexShader = pipelineContext.getAsset!IRawShaderModuleAsset(node.getAttribute("vert").textValue);
            auto fragmentShader = pipelineContext.getAsset!IRawShaderModuleAsset(node.getAttribute("frag").textValue);
            const type = node.getAttribute("renderer").to!MaterialRenderer;
            const alias_ = node.getAttribute("alias").textValue;

            enforce(vertexShader.type == SpirvShaderModuleType.vert);
            enforce(fragmentShader.type == SpirvShaderModuleType.frag);

            import implementations;
            pipelineContext.setAsset(new RawMaterialAsset(alias_, vertexShader, fragmentShader, type), null);
        });
    }
}