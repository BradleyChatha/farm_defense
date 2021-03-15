module engine.vulkan.submitpipeline;

import std.exception : enforce;
import std.typecons : Nullable, Flag;
import engine.vulkan, engine.util;

// NOTE: Submit pipeline creation is intended to only happen at the start of the program, so the GC can be used without worry.

alias KeepWaiting = Flag!"wait";

alias SubmitPipelineExecFunc   = void function(SubmitPipelineContext*);
alias SubmitPipelineWaitFunc   = KeepWaiting function(SubmitPipelineContext*);
alias SubmitPipelineOnDoneFunc = void function(SubmitPipelineContext*);

struct SubmitPipeline
{
    package
    {
        enum StageType
        {
            ERROR,
            exec,
            wait,
            submit,
            reset
        }

        static struct Stage
        {
            StageType type;
            string name;
            union
            {
                SubmitPipelineExecFunc execFunc;
                SubmitPipelineWaitFunc waitFunc;

                struct
                {
                    VQueueType submitBufferType;
                    size_t fenceIndex;
                }
            }
        }

        size_t fenceCount;
        Stage[] stages;
        bool needsTransfer;
        bool needsGraphics;
        SubmitPipelineOnDoneFunc onDone;
    }
}

struct SubmitPipelineContext
{
    private TypedPointer[] _userContextStack;
    VFence[] fences;
    Nullable!VCommandBuffer transferBuffer;
    Nullable!VCommandBuffer graphicsBuffer;

    void pushUserContext(TypedPointer ptr)
    {
        this._userContextStack ~= ptr;
    }

    void popUserContext()
    {
        this._userContextStack.length--;
    }

    @property
    TypedPointer userContext()
    {
        assert(this._userContextStack.length > 0, "No user contexts exists");
        return this._userContextStack[$-1];
    }
}

final class SubmitPipelineBuilder
{
    private SubmitPipeline _data;

    SubmitPipeline build()
    {
        return this._data;
    }

    SubmitPipelineBuilder needsFences(size_t count)
    {
        this._data.fenceCount = count;
        return this;
    }

    SubmitPipelineBuilder needsFencesAtLeast(size_t count)
    {
        if(count > this._data.fenceCount)
            this._data.fenceCount = count;
        return this;
    }

    SubmitPipelineBuilder needsBufferFor(VQueueType type)
    {
        final switch(type) with(VQueueType)
        {
            case present:
            case compute:
            case ERROR: assert(false);

            case graphics: this._data.needsGraphics = true; break;
            case transfer: this._data.needsTransfer = true; break;
        }

        return this;
    }

    SubmitPipelineBuilder then(SubmitPipelineExecFunc exec, string stageName = null)
    {
        SubmitPipeline.Stage stage;
        stage.type = SubmitPipeline.StageType.exec;
        stage.execFunc = exec;
        stage.name = stageName;
        this._data.stages ~= stage;
        return this;
    }

    SubmitPipelineBuilder wait(SubmitPipelineWaitFunc wait, string stageName = null)
    {
        SubmitPipeline.Stage stage;
        stage.type = SubmitPipeline.StageType.wait;
        stage.waitFunc = wait;
        stage.name = stageName;
        this._data.stages ~= stage;
        return this;
    }

    SubmitPipelineBuilder submit(VQueueType type, size_t fenceIndex, string stageName = null)
    {
        SubmitPipeline.Stage stage;
        stage.type = SubmitPipeline.StageType.submit;
        stage.submitBufferType = type;
        stage.fenceIndex = fenceIndex;
        stage.name = stageName;
        this._data.stages ~= stage;
        return this;
    }

    
    SubmitPipelineBuilder reset(VQueueType type, string stageName = null)
    {
        SubmitPipeline.Stage stage;
        stage.type = SubmitPipeline.StageType.reset;
        stage.submitBufferType = type;
        stage.name = stageName;
        this._data.stages ~= stage;
        return this;
    }

    SubmitPipelineBuilder waitOnFence(size_t fenceIndex)()
    {
        import std.conv : to;

        assert(fenceIndex < this._data.fenceCount, "Cannot wait on a fence that won't exist!");

        enum STAGE_NAME = "Wait for fence #"~fenceIndex.to!string;
        this.wait((context)
        {
            if(!context.fences[fenceIndex].isSignaled)
                return KeepWaiting.yes;

            context.fences[fenceIndex].reset();
            return KeepWaiting.no;
        }, STAGE_NAME);
        return this;
    }
}