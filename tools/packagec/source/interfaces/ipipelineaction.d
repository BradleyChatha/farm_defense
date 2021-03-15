module interfaces.ipipelineaction;

import std.typecons : Flag;
import sdlite;
import engine.vulkan;

import common, interfaces;

alias SubmitGraphicsBuffer = Flag!"submitGraphics";
alias SubmitComputeBuffer = Flag!"submitCompute";

struct PipelineActionResult
{
    alias PassFuncT = PipelineActionResult delegate();

    PassFuncT nextPass;
    IAsset result;
    SubmitGraphicsBuffer submitGraphicsBuffer;
    SubmitComputeBuffer submitComputeBuffer;

    this(PassFuncT nextPass, SubmitGraphicsBuffer submitGraphics, SubmitComputeBuffer submitCompute)
    {
        this.nextPass = nextPass;
        this.submitComputeBuffer = submitCompute;
        this.submitGraphicsBuffer = submitGraphics;
    }

    this(IAsset asset)
    {
        this.result = asset;
    }
}

interface IPipelineAction
{
    void appendToPipeline(SubmitPipelineBuilder builder);   
}