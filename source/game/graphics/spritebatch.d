module game.graphics.spritebatch;

import std.typecons : Flag;
import game.core, game.common, game.graphics;

alias AllowTransparency = Flag!"useBlending";

struct SpriteBatchMemory
{
    private 
    {
        SpriteBatch _batch;
        size_t      _spriteCount;
        size_t      _vertOffset;
        size_t      _startBit;

        @property @safe @nogc
        size_t vertCount() nothrow
        {
            return this._spriteCount * SpriteBatch.VERTS_PER_SPRITE;
        }
    }

    @disable
    this(this){}

    ~this()
    {
        this.free();
    }

    void free()
    {
        if(this._batch !is null)
            this._batch.deallocate(this);
    }

    void updateVerts(
            size_t    spriteIndex,
        ref Transform transform,
            vec2f     size = vec2f.init, // vec2f.init if no size change.
            box2f     uv   = box2f.init  // ditto.
    )
    {
        this._batch.updateMemoryVerts(this, transform, size, uv, spriteIndex);
    }

    @property
    size_t length()
    {
        return this._spriteCount;
    }
}

// Basically just an allocator for verts, except:
//      This class abstracts access to the verts to make it safer to use.
//      This class is bound only to a single texture, allowing it to...
//      Provide its own `DrawCommand`, which will draw every single vert being managed.
//      So it also sets "unallocated" verts to not be visible, so only "allocated" verts are shown on screen.
final class SpriteBatch : IDisposable
{
    mixin IDisposableBoilerplate;

    enum VERTS_PER_SPRITE = 6;

    private
    {
        VertexBuffer           _verts;
        BitmappedBookkeeper!() _quadKeeper;
        size_t                 _currentSpriteCapacity;
        Texture                _texture;
        bool                   _useBlending;
    }

    this(Texture texture, AllowTransparency useBlending, size_t initialSpriteCapacity = 1000)
    {
        assert(texture !is null);
        assert(!texture.isDisposed);

        this._texture     = texture;
        this._useBlending = useBlending;

        this._verts.lock(); // Since we never expose slices to the buffer's arrays, this is safe to keep persistant.
        this.resize(VERTS_PER_SPRITE * initialSpriteCapacity);
    }

    void onDispose()
    {
        this._verts.dispose();
    }

    void resize(size_t spriteCapacity)
    {
        this._verts.unlock();
        this._verts.resize(spriteCapacity * VERTS_PER_SPRITE);
        this._quadKeeper.setLengthInBits(spriteCapacity); // 1 bit = 1 sprite
        this._currentSpriteCapacity = spriteCapacity;
        this._verts.lock();
    }

    void allocate(ref SpriteBatchMemory memory, size_t spriteCount)
    {
        if(memory != SpriteBatchMemory.init)
            this.deallocate(memory);
            
        const couldAllocate = this._quadKeeper.markNextNBits(memory._startBit, spriteCount);
        if(!couldAllocate)
        {
            this.resize(this._currentSpriteCapacity * 2);
            this.allocate(memory, spriteCount);
            return;
        }

        memory._vertOffset  = memory._startBit * VERTS_PER_SPRITE;
        memory._spriteCount = spriteCount;
        memory._batch       = this;
    }

    void deallocate(ref SpriteBatchMemory memory)
    {
        if(memory._batch is null)
            return;

        assert(memory._batch == this);

        const startVert = memory._vertOffset;
        const endVert   = startVert + memory.vertCount;
        this._quadKeeper.setBitRange!false(memory._startBit, memory._spriteCount);
        this._verts.verts[startVert..endVert] = TexturedVertex.init;
        this._verts.upload(startVert, memory.vertCount);

        memory = SpriteBatchMemory.init;
    }

    @property
    DrawCommand drawCommand()
    {
        return DrawCommand(
            &this._verts,
            0,
            this._verts.length,
            this._texture,
            this._useBlending
        );
    }

    private void updateMemoryVerts(
        ref SpriteBatchMemory memory,
        ref Transform         transform,
            vec2f             spriteSize,
            box2f             spriteUv,
            size_t            spriteIndex
    )
    {
        const vertCount = ((spriteIndex + 1) * VERTS_PER_SPRITE);
        auto verts = this._verts.verts[memory._vertOffset..memory._vertOffset + vertCount];
        assert(verts.length == 0 || verts.length % 6 == 0);

        auto quad = verts.getQuadVerts();

        if(!spriteSize.isNaN)
        {
            quad[1].position.x = spriteSize.x;
            quad[3].position.y = spriteSize.y;
            quad[2].position   = vec3f(spriteSize, 0);
        }
        if(!spriteUv.min.isNaN && !spriteUv.max.isNaN)
        {
            quad[0].uv = spriteUv.min;
            quad[1].uv = vec2f(spriteUv.max.x, spriteUv.min.y);
            quad[2].uv = spriteUv.max;
            quad[3].uv = vec2f(spriteUv.min.x, spriteUv.max.y);
        }

        verts.setQuadVerts(quad);
        this._verts.transformAndUpload(memory._vertOffset, vertCount, transform);
    }
}