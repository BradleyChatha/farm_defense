module game.graphics.vertex;

import game.graphics, game.vulkan;

struct VertexBuffer
{
    private
    {
        GpuCpuBuffer*       _cpuBuffer;
        GpuBuffer*          _gpuBuffer;
        bool                _locked;
        CommandBuffer       _transferCommands; // Only valid between lockVerts() and unlockVerts() intervals.
        QueueSubmitSyncInfo _transferSync;
    }

    @disable
    this(this){}

    void resize(size_t length)
    {
        assert(!this._locked, "Cannot resize while locked.");

        // The allocator will still have this memory mapped and alive, so we can just keep the range and copy shit over.
        auto oldVerts = this._cpuBuffer.as!TexturedVertex;

        // TODO: Make a realloc function in the allocators... and probably DRY them before doing that.
        g_gpuCpuAllocator.deallocate(this._cpuBuffer);
        g_gpuAllocator.deallocate(this._gpuBuffer);

        this._cpuBuffer = g_gpuCpuAllocator.allocate(length * TexturedVertex.sizeof, VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
        this._gpuBuffer = g_gpuAllocator.allocate(length * TexturedVertex.sizeof, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);

        this._cpuBuffer.as!TexturedVertex[0..oldVerts.length] = oldVerts[0..$];
    }

    void lockVerts()
    {
        assert(!this._locked);
        assert(this.finalise(), "We've not finalised the previous transfers yet. Are you calling this multiple times per frame?");
        this._locked = true;
        this._transferCommands = g_device.transfer.commandPools.get(VK_COMMAND_POOL_CREATE_TRANSIENT_BIT).allocate(1)[0];
    }

    void unlockVerts()
    {
        assert(this._locked);
        this._locked = false;
        this._transferSync = g_device.transfer.submit(this._transferCommands, null, null);
    }

    void uploadVerts(size_t offset, size_t amount)
    {
        assert(this._locked, "This command must be performed while locked.");
        this._transferCommands.copyBuffer(amount, this._cpuBuffer, offset, this._gpuBuffer, offset);
    }

    // Finalise any transfers, returns whether transfers are finished yet.
    bool finalise()
    {
        if(this._transferSync == QueueSubmitSyncInfo.init)
            return true;

        if(!this._transferSync.submitHasFinished)
            return false;

        this._transferSync = QueueSubmitSyncInfo.init;
        vkDestroyJAST(this._transferCommands);
        return true;
    }

    @property
    TexturedVertex[] verts()
    {
        assert(this._locked, "Please use .lockVerts() first.");
        return this._cpuBuffer.as!TexturedVertex;
    }

    @property
    size_t length()
    {
        return this._cpuBuffer.as!TexturedVertex.length;
    }

    @property
    package GpuBuffer* gpuHandle()
    {
        return this._gpuBuffer;
    }
}