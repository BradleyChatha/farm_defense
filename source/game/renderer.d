module game.renderer;

import std.file : fread = read;
import std.experimental.logger;
import bgfx, gfm.math, arsd.color;
import game.window, game.resources, game.sprite;

struct Vertex
{
    align(1): // Just so the compiler doesn't decide to add alignment padding.

    static assert(Vertex.sizeof == 4 + 8 + 8); // Colour + vec2f + vec2f
    Color color;
    vec2f position;
    vec2f uv;
}

// While the renderer could also be a singleton like a bunch of other things in this game, we want to limit which sections of code can actually
// render to the screen, so we'll be passing this around like normal.
final class Renderer
{
    private
    {
        struct TextureAndBuffer
        {
            StaticTexture texture;
            QuadBuffer buffer;
        }

        bgfx_vertex_layout_t       _vertexLayout;   // Again, with basic 2D every object's the same, so we can just do this all beforehand.
        bgfx_program_handle_t      _shader; // There will only ever be one shader for this game, we're not gonna do anything fancy.
        bgfx_uniform_handle_t      _uniformTextureColour;
        TextureAndBuffer[]         _buffers; // One buffer per texture/atlas, to simplify sprite batching.
        bool                       _showDebugStats;

        void setupGenericCamera()
        {
            auto view = mat4f.identity;
            auto proj = mat4f.orthographic(0, Window.WIDTH, Window.HEIGHT, 0, -1, 1);
            bgfx_set_view_transform(0, view.v.ptr, proj.v.ptr);
        }
        
        void updateDebugFlags()
        {
            uint flags;
            flags |= (this._showDebugStats) ? BGFX_DEBUG_STATS : 0;

            bgfx_set_debug(flags);
        }

        QuadBuffer getBufferForTexture(StaticTexture texture)
        {
            const index = texture.handle.idx;
            if(this._buffers.length <= index)
                this._buffers.length = index + 1;

            auto buffer = this._buffers[index];
            if(buffer.buffer is null)
            {
                buffer = TextureAndBuffer(texture, new QuadBuffer(this));
                this._buffers[index] = buffer;
            }

            return buffer.buffer;
        }
    }

    public
    {
        void onInit()
        {
            info("Initialising renderer");

            // Create the vertex definition for our `Vertex` struct.
            bgfx_vertex_layout_begin(&this._vertexLayout, bgfx_renderer_type_t.BGFX_RENDERER_TYPE_NOOP);
                bgfx_vertex_layout_add(&this._vertexLayout, bgfx_attrib_t.BGFX_ATTRIB_COLOR0,    4, bgfx_attrib_type_t.BGFX_ATTRIB_TYPE_UINT8, true,  false);
                bgfx_vertex_layout_add(&this._vertexLayout, bgfx_attrib_t.BGFX_ATTRIB_POSITION,  2, bgfx_attrib_type_t.BGFX_ATTRIB_TYPE_FLOAT, false, false);
                bgfx_vertex_layout_add(&this._vertexLayout, bgfx_attrib_t.BGFX_ATTRIB_TEXCOORD0, 2, bgfx_attrib_type_t.BGFX_ATTRIB_TYPE_FLOAT, false, false);
            bgfx_vertex_layout_end(&this._vertexLayout);

            // Load our shader.
            auto vert = fread("./resources/shaders/vertex.bin");
            auto frag = fread("./resources/shaders/fragment.bin");
            this._shader = bgfx_create_program(
                bgfx_create_shader(bgfx_make_ref(vert.ptr, cast(uint)vert.length)), // The cast is yuck, but I literally have no choice, it only takes uint there.
                bgfx_create_shader(bgfx_make_ref(frag.ptr, cast(uint)frag.length)), 
                true
            );

            // Create all uniforms.
            this._uniformTextureColour = bgfx_create_uniform("s_texColor", bgfx_uniform_type_t.BGFX_UNIFORM_TYPE_SAMPLER, 1);

            // Misc
        }

        void toggleDebugStats()
        {
            this._showDebugStats = !this._showDebugStats;
            this.updateDebugFlags();
        }

        void drawTextured(QuadBuffer buffer, const StaticTexture texture)
        {
            this.setupGenericCamera();
            
            buffer.bind();
            bgfx_set_texture(0, this._uniformTextureColour, texture.handle, uint.max);
            bgfx_submit(0, this._shader, 0, cast(byte)BGFX_DISCARD_ALL);
        }

        void draw(ref scope Sprite sprite)
        {
            auto buffer = this.getBufferForTexture(sprite.texture);
            buffer.addQuad(sprite.verts);
        }

        void renderFrame()
        {
            foreach(buffer; this._buffers)
            {
                if(buffer.buffer !is null)
                    this.drawTextured(buffer.buffer, buffer.texture);
            }

            bgfx_frame(false);
        }
    }
}

struct SwappableBuffer(T)
{
    private
    {
        // Meh, if memory ever actually becomes an issue in this game, I'll make this better.
        T[][2] _buffers;
        T[][2] _slices;
        size_t _index;

        @property
        ref currentBuffer()
        {
            return this._buffers[this._index];
        }

        @property
        ref currentSlice()
        {
            return this._slices[this._index];
        }
    }

    public
    {
        void swap()
        {
            if(this._index == 0)
                this._index++;
            else
                this._index = 0;

            this.currentSlice = this.currentBuffer[0..0];
        }

        void addToBuffer(const scope T[] toAdd)
        {
            const newLength = this.currentSlice.length + toAdd.length;
            if(newLength > this.currentBuffer.length)
                this.currentBuffer.length = newLength * 2;

            const start                 = this.currentSlice.length;
            this.currentSlice           = this.currentBuffer[0..newLength];
            this.currentSlice[start..$] = toAdd;
        }

        alias data = currentSlice;
    }
}

final class QuadBuffer
{
    private
    {
        SwappableBuffer!Vertex _verts;
        SwappableBuffer!uint   _indicies;

        bgfx_dynamic_vertex_buffer_handle_t _vertBuffer;
        bgfx_dynamic_index_buffer_handle_t  _indexBuffer;
    }

    public
    {
        this(Renderer renderer)
        {
            this._vertBuffer  = bgfx_create_dynamic_vertex_buffer(0, &renderer._vertexLayout, BGFX_BUFFER_ALLOW_RESIZE);
            this._indexBuffer = bgfx_create_dynamic_index_buffer(0, BGFX_BUFFER_ALLOW_RESIZE | BGFX_BUFFER_INDEX32);
        }

        void addQuad(Vertex[4] verts)
        {
            const topLeft  = cast(uint)this._verts.data.length;
            const topRight = topLeft + 1;
            const botLeft  = topLeft + 2;
            const botRight = topLeft + 3;

            uint[6] indicies = 
            [
                topLeft,  botLeft,  botRight,
                botRight, topRight, topLeft
            ];

            this._verts.addToBuffer(verts[]);
            this._indicies.addToBuffer(indicies[]);
        }

        void bind()
        {
            auto verts = this._verts.data();
            bgfx_update_dynamic_vertex_buffer(
                this._vertBuffer, 
                0, 
                bgfx_make_ref(verts.ptr, cast(uint)(verts.length * Vertex.sizeof))
            );

            auto indicies = this._indicies.data();
            bgfx_update_dynamic_index_buffer(
                this._indexBuffer,
                0,
                bgfx_make_ref(indicies.ptr, cast(uint)(indicies.length * uint.sizeof))
            );

            bgfx_set_dynamic_vertex_buffer(0, this._vertBuffer, 0, cast(uint)verts.length);
            bgfx_set_dynamic_index_buffer(this._indexBuffer, 0, cast(uint)indicies.length);

            this._verts.swap();
            this._indicies.swap();
        }
    }
}