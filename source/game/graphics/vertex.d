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

/++
 + Always 6 verts to a quad, since indexing is less useful in a 2D-only environment.
 +
 + Face direction is clockwise, thus vertex ordering is:
 +  [0] = top left
 +  [1] = top right
 +  [2] = bot right
 +  [3] = bot right
 +  [4] = bot left
 +  [5] = top left
 + ++/
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

    void dispose()
    {
        if(this._localVerts !is null)
            g_localVertexAllocator.dispose(this._localVerts);
        if(this._cpuBuffer !is null)
            g_gpuCpuAllocator.deallocate(this._cpuBuffer);
        if(this._gpuBuffer !is null)
            g_gpuAllocator.deallocate(this._gpuBuffer);
    }

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

    void transformAndUpload(size_t offset, size_t amount, ref Transform transform)
    {
        auto matrix = transform.matrix;
        foreach(i, vert; this.verts[offset..offset+amount])
        {
            vert.position         = (matrix * vec4f(vert.position, 1)).xyz;
            this.vertsToUpload[i] = vert;
        }
        this.upload(offset, amount);
    }

    /// Initialises the given `buffer` to contain a quad of a specified `size`.
    ///
    /// In general prefer the usage/creation of types that can use a single VertexBuffer for multiple quads (like a sprite batch), but of course
    /// this isn't always feasable.
    static void quad(ref VertexBuffer buffer, vec2f size, vec2f uv, Color colour)
    {
        assert(buffer == VertexBuffer.init, "This is a ctor function, so can only be used in buffers that are in their initial state.");
        auto  topLeft  = TexturedVertex(vec3f(0,      0,      0), vec2f(0,    0),    colour);
        auto  topRight = TexturedVertex(vec3f(size.x, 0,      0), vec2f(uv.x, 0),    colour);
        auto  botRight = TexturedVertex(vec3f(size.x, size.y, 0), vec2f(uv.x, uv.y), colour);
        auto  botLeft  = TexturedVertex(vec3f(0,      size.y, 0), vec2f(0,    uv.y), colour);

        buffer.resize(6);
        buffer.lock();
            buffer.verts[0..6] = 
            [
                topLeft,
                topRight,
                botRight,

                botRight,
                botLeft,
                topLeft
            ];
        buffer.unlock();
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

TexturedVertex[4] getQuadVerts(TexturedVertex[] verts)
{
    assert(verts.length >= 6);
    return 
    [
        verts[0],
        verts[1],
        verts[2],
        verts[4]
    ];
}

void setQuadVerts(TexturedVertex[] dest, TexturedVertex[4] quad)
{
    assert(dest.length >= 6);
    dest[0..6] = 
    [
        quad[0],
        quad[1],
        quad[2],
        quad[2],
        quad[3],
        quad[0]
    ];
}