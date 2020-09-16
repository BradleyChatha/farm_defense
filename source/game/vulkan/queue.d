module game.vulkan.queue;

import std.conv : to;
import std.typecons : Flag;
import std.experimental.logger;
import game.vulkan, game.common.util;

alias StartSignaled = Flag!"startSignaled";

struct Fence
{
    mixin VkWrapperJAST!VkFence;

    this(VkFence toWrap)
    {
        this.handle = toWrap;
    }

    this(StartSignaled signaled, lazy LogicalDevice device = g_device)
    {
        infof("Creating Fence that is%s signaled", signaled ? "" : " not");
        VkFenceCreateInfo info = 
        {
            flags: (signaled) ? VK_FENCE_CREATE_SIGNALED_BIT : 0
        };

        CHECK_VK(vkCreateFence(device, &info, null, &this.handle));
        vkTrackJAST(this);
    }
}

struct Semaphore
{
    mixin VkWrapperJAST!VkSemaphore;

    this(Semaphore toWrap)
    {
        this.handle = toWrap;
    }

    this(LogicalDevice device)
    {
        infof("Creating Semaphore");
        VkSemaphoreCreateInfo info;
        CHECK_VK(vkCreateSemaphore(device, &info, null, &this.handle));
        vkTrackJAST(this);
    }
}

struct QueueSubmitSyncInfo
{
    private
    {
        ulong* _queueParity; // This pointer is GC allocated, so we're safe with using it.
        ulong  _parityWhenSubmitted;
        Fence  _fence;
    }

    invariant(_queueParity !is null);

    @property
    bool submitHasFinished()
    {
        return *this._queueParity != this._parityWhenSubmitted;
    }

    @property
    Fence fence()
    {
        return this._fence;
    }
}

struct OneTimeSubmit
{
    CommandBuffer       buffer;
    QueueSubmitSyncInfo syncInfo;

    bool finalise()
    {
        auto hasFinished = this.syncInfo == QueueSubmitSyncInfo.init || this.syncInfo.submitHasFinished;
        if(!hasFinished)
            return false;

        this.syncInfo = QueueSubmitSyncInfo.init;
        if(this.buffer.handle !is null)
            vkDestroyJAST(this.buffer);
        return true;
    }
}

mixin template VkFenceManagerJAST()
{    
    enum MAX_FENCES_IN_FLIGHT = 10;

    private static struct FenceInfo
    {
        uint fenceIndex;
        ulong* parity;
    }

    Fence[MAX_FENCES_IN_FLIGHT]     fences;
    FenceInfo[MAX_FENCES_IN_FLIGHT] fencesInFlight;
    FenceInfo[MAX_FENCES_IN_FLIGHT] fencesAvailable;
    uint                            fencesInFlightCount;
    uint                            fencesAvailableCount;

    private void setupFenceManager(LogicalDevice device)
    {
        vkListenOnFrameChangeJAST(&this.onFrameChange);

        foreach(i, ref fence; this.fences)
        {
            fence                   = Fence(StartSignaled.no, device);
            this.fencesAvailable[i] = FenceInfo(i.to!uint, new ulong);
        }

        this.fencesAvailableCount = this.fencesAvailable.length;
    }

    void debugPrintFences()
    {
        info("[DEBUG FENCE MANAGER]");
        info("Fences:");
        foreach(fence; this.fences)
            infof("\t%s", fence.toString());
        info("In Flight:");
        foreach(fence; this.fencesInFlight[0..this.fencesInFlightCount])
            infof("\t#%s (%s)", fence.fenceIndex, *fence.parity);
        info("Available:");
        foreach(fence; this.fencesAvailable[0..this.fencesAvailableCount])
            infof("\t#%s (%s)", fence.fenceIndex, *fence.parity);
    }

    private Fence nextFence(ref ulong* parityPtr)
    out(f; f.handle != VK_NULL_HANDLE)
    {
        // Block until we have an available fence.
        while(this.fencesAvailableCount == 0)
        {
            info("No fences available, blocking for up to 10 seconds...");
            //CHECK_VK(vkWaitForFences(g_device, this.fencesInFlightCount.to!uint, this.fencesInFlight.ptr, VK_FALSE, 10_000));
            this.onFrameChange(0); // Sorts out all the fences.
        }

        auto info = this.fencesAvailable[--this.fencesAvailableCount];
        parityPtr = info.parity;

        this.fencesInFlight[this.fencesInFlightCount++] = info;
        return this.fences[info.fenceIndex];
    }

    private void onFrameChange(uint _)
    {
        this.processFences();
    }

    void processFences()
    {
        if(this.fencesInFlightCount == 0)
            return;

        VkFence[MAX_FENCES_IN_FLIGHT] fences;
        foreach(i, fence; this.fencesInFlight[0..this.fencesInFlightCount])
            fences[i] = this.fences[fence.fenceIndex].handle;

        // Get status of fences, then immediately return, we're not actually blocking here.
        if(this.fencesInFlightCount > 0)
            vkWaitForFences(g_device, this.fencesInFlightCount, fences.ptr, VK_FALSE, 0);

        // Figure out which fences are still in flight, and which can be reset and reused.
        VkFence[MAX_FENCES_IN_FLIGHT]   canReuse;
        FenceInfo[MAX_FENCES_IN_FLIGHT] stillInFlightInfo;
        
        uint newFencesInFlightCount;
        uint resetFencesCount;
        foreach(i, fence; fences[0..this.fencesInFlightCount])
        {
            if(vkGetFenceStatus(g_device, fence) == VK_SUCCESS)
            {
                canReuse[resetFencesCount++]                      = fence;
                *this.fencesInFlight[i].parity                   += 1;
                this.fencesAvailable[this.fencesAvailableCount++] = this.fencesInFlight[i];
            }
            else
                stillInFlightInfo[newFencesInFlightCount++] = this.fencesInFlight[i];
        }

        // Reset fences where we can
        if(resetFencesCount > 0)
            CHECK_VK(vkResetFences(g_device, resetFencesCount, canReuse.ptr));

        // Set new values
        this.fencesInFlight      = stillInFlightInfo;
        this.fencesInFlightCount = newFencesInFlightCount;

        assert(this.fencesInFlightCount + this.fencesAvailableCount == this.fences.length, "We've limboed some fence");
    }
}

mixin template VkQueueJAST()
{
    // This struct probably does too much now, but meh, it's very logically coupled together.
    mixin VkWrapperJAST!VkQueue;
    mixin VkFenceManagerJAST;
    uint                queueIndex;
    CommandPoolManager* commandPools;

    this(LogicalDevice device, uint queueIndex)
    {
        infof("Creating Queue using family index %s", queueIndex);
        vkGetDeviceQueue(device, queueIndex, 0, &this.handle);
        this.queueIndex   = queueIndex;
        this.commandPools = CommandPoolManager.getByQueueIndex(device, queueIndex);
        this.debugName    = typeof(this).stringof;

        this.setupFenceManager(device);
    }

    QueueSubmitSyncInfo submit(
        CommandBuffer        buffer, 
        Semaphore*           semaphoreToSignal,
        Semaphore*           semaphoreToWaitFor,
        VkPipelineStageFlags stagesToWaitIn = 0
    )
    {
        QueueSubmitSyncInfo info;
        info._fence               = this.nextFence(info._queueParity);
        info._parityWhenSubmitted = *info._queueParity;

        VkSubmitInfo submitInfo = 
        {
            waitSemaphoreCount:   (semaphoreToWaitFor is null) ? 0 : 1,
            signalSemaphoreCount: (semaphoreToSignal is null) ? 0 : 1,
            commandBufferCount:   1,
            pWaitDstStageMask:    &stagesToWaitIn,
            pCommandBuffers:      &buffer.handle,
            pWaitSemaphores:      &semaphoreToWaitFor.handle,
            pSignalSemaphores:    &semaphoreToSignal.handle
        };

        CHECK_VK(vkQueueSubmit(this, 1, &submitInfo, info._fence));
        return info;
    }

    void submit(ref OneTimeSubmit info)
    {
        info.syncInfo = this.submit(info.buffer, null, null);
    }

    OneTimeSubmit getOneTimeBuffer()
    {
        return OneTimeSubmit(this.commandPools.get(VK_COMMAND_POOL_CREATE_TRANSIENT_BIT).allocate(1)[0]);
    }
}

struct GraphicsQueue
{
    mixin VkQueueJAST;
}

struct PresentQueue
{
    mixin VkQueueJAST;
}

struct TransferQueue
{
    mixin VkQueueJAST;
}