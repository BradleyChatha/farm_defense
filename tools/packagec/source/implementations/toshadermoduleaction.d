module implementations.toshadermoduleaction;

import std.conv, std.utf;
import engine.core, engine.vulkan;
import common, interfaces, implementations;

final class ToShaderModuleAction : IPipelineAction
{
    override void appendToPipeline(SubmitPipelineBuilder builder)
    {
        builder.then((SubmitPipelineContext* ctx)
        {
            auto pipelineContext = ctx.userContext.as!PipelineContext;
            auto node = pipelineContext.currentStageNode;

            auto asset = pipelineContext.getAsset!IRawAsset(node.values[0].textValue);
            const format = node.getAttribute("stage").textValue.to!SpirvShaderModuleType;
            const alias_ = node.getAttribute("alias").textValue;

            const code = (cast(char[])asset.bytes).idup;
            code.validate();

            auto bytes = Spirv.compile(code, format);
            auto reflect = Spirv.reflect(bytes);
            pipelineContext.setAsset(new RawShaderModuleAsset(bytes, format, alias_, reflect), null);
        });
    }
}