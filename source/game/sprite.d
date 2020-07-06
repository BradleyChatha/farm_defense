module game.sprite;

import gfm.math, arsd.color;
import game.renderer, game.resources;

struct Sprite
{
    private
    {
        StaticTexture _texture;
        Vertex[4]     _verts;
        vec2i         _size;
        vec2f         _position = vec2f(0);
        Color         _colour = Color.white;
        bool          _dirty;
    }

    this(const StitchedTexture texture)
    {
        this._texture = cast()texture.atlas;
        this._size    = texture.area.zw;
        this._dirty   = true;

        this._verts = 
        [
            // UVs are based from bottom-left, because OpenGL.
            Vertex(Color.white, vec2f(0), vec2f(texture.area.x,                  texture.area.y + texture.area.w)),
            Vertex(Color.white, vec2f(0), vec2f(texture.area.x + texture.area.z, texture.area.y + texture.area.w)),
            Vertex(Color.white, vec2f(0), vec2f(texture.area.x,                  texture.area.y)),
            Vertex(Color.white, vec2f(0), vec2f(texture.area.x + texture.area.z, texture.area.y))
        ];
    }

    this(const StaticTexture texture)
    {
        this(StitchedTexture(cast()texture, vec4i(0, 0, texture.info.width, texture.info.height)));
    }

    @property
    void position(vec2f pos) { this._position = pos; this._dirty = true; }
    @property
    void size(vec2i siz)     { this._size = siz; this._dirty = true; }
    @property
    void color(Color col)    { this._colour = col; this._dirty = true; }

    @property
    vec2f position() { return this._position; }
    @property
    vec2i size() { return this._size; }
    @property
    Color color() { return this._colour; }

    @property
    Vertex[4] verts()
    {
        if(!this._dirty)
            return this._verts;

        this._verts[0].position = vec2f(0);
        this._verts[1].position = vec2f(this._size.x, 0);
        this._verts[2].position = vec2f(0, this._size.y);
        this._verts[3].position = vec2f(this._size);

        const transform = mat4f.translation(vec3f(this._position, 0));
        foreach(ref vert; this._verts)
            vert.position = (transform * vec4f(vert.position, 0, 1)).xy;

        this._dirty = false;
        return this._verts;
    }

    @property
    StaticTexture texture()
    {
        return this._texture;
    }
}