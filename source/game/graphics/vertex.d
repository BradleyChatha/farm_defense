module game.graphics.vertex;

import game.common, game.graphics, game.vulkan;

private PoolAllocatorBase!(TexturedVertex.sizeof * 100_000) g_localVertexAllocator;

package struct VertexUploadInfo
{
    uint start;
    uint end;

    bool requiresUpload()
    {
        return this.start != uint.max && this.end != 0;
    }
}

struct VertexBuffer
{
    private
    {
        VertexUploadInfo _uploadInfo;
        TexturedVertex[] _localVerts; // _localVerts = Untrasnformed verts; _cpuBuffer = Verts ready to upload; _gpuBuffer = Verts on the GPU.
        GpuCpuBuffer*    _cpuBuffer;
        GpuBuffer*       _gpuBuffer;
        bool             _locked;
    }

    @disable
    this(this){}

    void resize(size_t length)
    {
        import std.algorithm : min;
        assert(!this._locked, "Cannot resize while locked.");

        TexturedVertex[] oldVerts;
        if(this._cpuBuffer !is null)
        {
            // The allocator will still have this memory mapped and alive, so we can just keep the range and copy shit over.
            oldVerts = this._cpuBuffer.as!TexturedVertex.dup;

            // TODO: Make a realloc function in the allocators... and probably DRY them before doing that.
            g_gpuCpuAllocator.deallocate(this._cpuBuffer);
            g_gpuAllocator.deallocate(this._gpuBuffer);
        }

        this._cpuBuffer = g_gpuCpuAllocator.allocate(length * TexturedVertex.sizeof, VK_BUFFER_USAGE_TRANSFER_SRC_BIT);
        this._gpuBuffer = g_gpuAllocator.allocate(length * TexturedVertex.sizeof, VK_BUFFER_USAGE_TRANSFER_DST_BIT | VK_BUFFER_USAGE_VERTEX_BUFFER_BIT);

        auto vertsToCopy = min(this._cpuBuffer.as!TexturedVertex.length, oldVerts.length);
        this._cpuBuffer.as!TexturedVertex[0..vertsToCopy] = oldVerts[0..vertsToCopy];

        // Copy local verts over.
        if(this._localVerts !is null)
        {
            oldVerts[0..$] = this._localVerts[0..$];
            g_localVertexAllocator.dispose(this._localVerts);
            this._localVerts = g_localVertexAllocator.makeArray!TexturedVertex(length);
            this._localVerts[0..oldVerts.length] = oldVerts[0..$];
        }
        else
            this._localVerts = g_localVertexAllocator.makeArray!TexturedVertex(length);
    }

    void lock()
    {
        assert(!this._locked);
        this._locked = true;
    }

    void unlock()
    {
        assert(this._locked);
        this._locked = false;
    }

    void upload(size_t offset, size_t amount)
    {
        assert(this._locked, "This command must be performed while locked.");

        const start = offset;
        const end   = offset + amount;

        if(start < this._uploadInfo.start)
            this._uploadInfo.start = cast(uint)start;
        if(end > this._uploadInfo.end)
            this._uploadInfo.end = cast(uint)end;
    }

    @property
    TexturedVertex[] verts()
    {
        assert(this._locked, "Please use .lock() first.");
        return this._localVerts;
    }

    @property
    TexturedVertex[] vertsToUpload()
    {
        assert(this._locked, "Please use .lock() first.");
        return this._cpuBuffer.as!TexturedVertex;
    }

    @property
    size_t length()
    {
        return (this._cpuBuffer is null) ? 0 : this._cpuBuffer.as!TexturedVertex.length;
    }

    @property
    package GpuCpuBuffer* cpuHandle()
    {
        return this._cpuBuffer;
    }

    @property
    package GpuBuffer* gpuHandle()
    {
        return this._gpuBuffer;
    }

    @property
    package VertexUploadInfo uploadInfo()
    {
        auto info              = this._uploadInfo;
        this._uploadInfo       = VertexUploadInfo.init;
        this._uploadInfo.start = uint.max;
        return info;
    }
}