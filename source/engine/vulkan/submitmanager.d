module engine.vulkan.submitmanager;

import stdx.allocator.building_blocks, stdx.allocator;
import engine.core, engine.util, engine.vulkan;

/++ DATA TYPES ++/
alias SubmitPipelineExecutionPool = AllocatorList!(_ => ContiguousFreeList!(NullAllocator, SubmitPipelineExecution.sizeof)(new ubyte[SubmitPipelineExecution.sizeof * 50]));;

enum SubmitPipelineExecutionType
{
    ERROR,
    manual,
    runToEnd,
    runToWait
}

struct SubmitPipelineExecution
{
    @disable this(this){}

    enum MAX_FENCES = 5;

    private
    {
        SubmitPipeline                       _pipeline;
        SubmitPipelineContext                _context;
        RecycledObjectRef!VFence[MAX_FENCES] _fences;
        VFence[MAX_FENCES]                   _fencesForContext;
        size_t                               _currentStageIndex;
    }

    // This is supposed to be private, but stdx.allocator can't work without it being public.
    /*private*/ this(SubmitPipeline pipeline, TypedPointer userContext)
    {
        this._pipeline = pipeline;
        this._context.fences = this._fencesForContext[0..pipeline.fenceCount];
        this._context.pushUserContext(userContext);

        g_fencePool.lock().alloc(this._fences[0..pipeline.fenceCount]);
        g_fencePool.unlock();

        foreach(i, ref fence; this._fences[0..pipeline.fenceCount])
            this._fencesForContext[i] = fence.value;

        VkCommandBufferAllocateInfo info = 
        {
            level: VK_COMMAND_BUFFER_LEVEL_PRIMARY,
            commandBufferCount: 1
        };

        VkCommandBufferBeginInfo beginInfo = 
        {
            flags: VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT
        };

        VkCommandBuffer buffer;
        if(pipeline.needsGraphics)
        {
            info.commandPool = tl_commandPools[VQueueType.graphics];
            CHECK_VK(vkAllocateCommandBuffers(g_device.logical, &info, &buffer));
            CHECK_VK(vkBeginCommandBuffer(buffer, &beginInfo));
            this._context.graphicsBuffer = VCommandBuffer(buffer, g_device.graphics);
        }
        if(pipeline.needsTransfer)
        {
            info.commandPool = tl_commandPools[VQueueType.transfer];
            CHECK_VK(vkAllocateCommandBuffers(g_device.logical, &info, &buffer));
            CHECK_VK(vkBeginCommandBuffer(buffer, &beginInfo));
            this._context.transferBuffer = VCommandBuffer(buffer, g_device.transfer);
        }
    }

    ~this()
    {
        g_fencePool.lock().free(this._fences[0..this._pipeline.fenceCount]);
        g_fencePool.unlock();

        if(this._pipeline.needsGraphics)
            vkFreeCommandBuffers(g_device.logical, tl_commandPools[VQueueType.graphics], 1, &this._context.graphicsBuffer.get.handle);
        if(this._pipeline.needsTransfer)
            vkFreeCommandBuffers(g_device.logical, tl_commandPools[VQueueType.transfer], 1, &this._context.transferBuffer.get.handle);
    }

    void executeStage(out bool isWaiting)
    {
        assert(!this.isDone);
        auto stage = this._pipeline.stages[this._currentStageIndex++];

        VCommandBuffer getBufferByType(VQueueType type)
        {
            final switch(type) with(VQueueType)
            {
                case present:
                case compute:
                case VQueueType.ERROR: assert(false);

                case transfer: return this._context.transferBuffer.get;
                case graphics: return this._context.graphicsBuffer.get;
            }
        }

        final switch(stage.type) with(SubmitPipeline.StageType)
        {
            case ERROR: assert(false);
            case exec: stage.execFunc(&this._context); break;
            case reset:
                auto buffer = getBufferByType(stage.submitBufferType);

                VkCommandBufferBeginInfo info;
                CHECK_VK(vkBeginCommandBuffer(buffer.handle, &info));
                break;
            case wait:
                const result = stage.waitFunc(&this._context);
                if(result == KeepWaiting.yes)
                {
                    this._currentStageIndex--;
                    isWaiting = true;
                }
                break;
            case submit:
                VCommandBuffer submitBuffer = getBufferByType(stage.submitBufferType);
                VkSubmitInfo info = 
                {
                    commandBufferCount: 1,
                    pCommandBuffers: &submitBuffer.handle                    
                };
                CHECK_VK(vkEndCommandBuffer(submitBuffer.handle));
                CHECK_VK(vkQueueSubmit(submitBuffer.queue.handle, 1, &info, this._context.fences[stage.fenceIndex].handle));
                break;
        }

        if(this.isDone && this._pipeline.onDone !is null)
            this._pipeline.onDone(&this._context);
    }

    bool isDone()
    {
        return this._currentStageIndex >= this._pipeline.stages.length;
    }
}

/++ VARIABLES ++/
private __gshared:
Lockable!(RecyclingObjectPool!VFence) g_fencePool;
Lockable!SubmitPipelineExecutionPool  g_executionPool;

private:
VkCommandPool[VQueueType.max + 1] tl_commandPools;

/++ FUNCTIONS ++/
public:

void submitGlobalInit()
{
    auto lockRaii = g_fencePool.lockRaii();
    lockRaii.value.onPopulate = (scope slice)
    {
        logfDebug("Allocating %s fences.", slice.length);
        VkFenceCreateInfo info = {};

        foreach(i; 0..slice.length)
            CHECK_VK(vkCreateFence(g_device.logical, &info, null, &slice[i].value.handle));
    };
    lockRaii.value.onFree = (scope slice)
    {
        logfDebug("Freeing %s fences.", slice.length);
        foreach(ref thing; slice)
            vkDestroyFence(g_device.logical, thing.value.handle, null);
    };
}

void submitGlobalUninit()
{
    g_fencePool.lock().dispose();
}

void submitPerThreadInit()
{
    // This is just so queue types that use the same queue family also share the same command pools.
    with(VQueueType) foreach(type; [graphics, compute, present, transfer])
    {
        if(tl_commandPools[type] !is null)
            continue;

        const queueIndex = g_device.queueByType[type].family.index;
        if(queueIndex == FAMILY_NOT_FOUND)
            continue;

        VkCommandPoolCreateInfo info = 
        {
            queueFamilyIndex: queueIndex,
            flags: VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT
        };
        VkCommandPool pool;
        CHECK_VK(vkCreateCommandPool(g_device.logical, &info, null, &pool));

        foreach(otherType; [graphics, compute, present, transfer])
        {
            if(otherType != type)
                continue;

            tl_commandPools[otherType] = pool;
        }
    }
}

void submitPerThreadUninit()
{
    import std.algorithm : uniq;
    foreach(pool; tl_commandPools[].uniq)
    {
        if(pool !is null)
            vkDestroyCommandPool(g_device.logical, pool, null);
    }
    tl_commandPools[] = null;
}

SubmitPipelineExecution* submitPipeline(SubmitPipeline pipeline, TypedPointer userContext = TypedPointer.init)
{
    auto raii = g_executionPool.lockRaii();
    return raii.value.make!SubmitPipelineExecution(pipeline, userContext);
}

void submitExecute(SubmitPipelineExecutionType type, SubmitPipelineExecution* execution)
{
    bool isWaiting;
    final switch(type) with(SubmitPipelineExecutionType)
    {
        case ERROR: assert(false);
        case manual: break;
        case runToEnd: while(!execution.isDone) execution.executeStage(isWaiting); break;
        case runToWait: while(!execution.isDone && !isWaiting) execution.executeStage(isWaiting); break;
    }
}

void submitFree(SubmitPipelineExecution* execution)
{
    auto raii = g_executionPool.lockRaii();
    raii.value.dispose(execution);
}