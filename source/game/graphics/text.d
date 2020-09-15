module game.graphics.text;

import game.core, game.common, game.graphics;

final class Text : IDisposable, ITransformable!(AddHooks.no)
{
    mixin ITransformableBoilerplate;
    mixin IDisposableBoilerplate;

    private
    {
        Font          _font;
        const(char)[] _text;
        VertexBuffer  _verts;
        uint          _vertsToRender;
        box2f         _bounds;
        uint          _fontSize;
        Color         _colour;
        float         _lineSpacing;
    }

    this(Font font, const char[] text = "", uint fontSize = 14, Color colour = Color.white, float lineSpacing = 14.0f)
    {
        assert(font !is null);
        this._font        = font;
        this._fontSize    = fontSize;
        this._colour      = colour;
        this._lineSpacing = lineSpacing;
        this.text         = text;
    }

    void onDispose()
    {
        this._verts.dispose();
    }

    @property
    vec2f size()
    {
        return this._bounds.size;
    }

    @property
    void colour(Color col)
    {
        if(this._colour != col)
        {
            this._colour = col;
            this.modifyVerts!((ref vert) => vert.colour = col);
        }
    }

    @property
    Color colour()
    {
        return this._colour;
    }

    @property
    void text(const char[] value)
    {
        this._text = value;
        if(value.length == 0)
            return;

        this.recalcVerts();
    }
    
    @property
    const(char)[] text()
    {
        return this._text;
    }

    @property
    DrawCommand drawCommand()
    {
        if(this.transform.isDirty)
            this.recalcVerts();

        return DrawCommand(
            &this._verts,
            0,
            this._vertsToRender,
            this._font.getFontSize(this._fontSize).texture,
            true,
            0
        );
    }

    private void recalcVerts()
    {
        const vertCount = this._font.calculateVertCount(this._text);
        if(vertCount > this._verts.length)
        {
            this._verts.resize(vertCount);
            this._vertsToRender = cast(uint)vertCount;
        }

        this._verts.lock();
            auto vertsLValue = this._verts.verts;
            this._font.textToVerts(
                vertsLValue,
                this._bounds,
                this._text,
                this._fontSize,
                vec2f(0),
                this._colour,
                this._lineSpacing
            );

            auto matrix = this.transform.matrix;
            foreach(i, vert; this._verts.verts)
            {
                vert.position                = (matrix * vec4f(vert.position, 1)).xyz;
                this._verts.vertsToUpload[i] = vert;
            }

            this._verts.upload(0, this._verts.length);
        this._verts.unlock();
    }

    private void modifyVerts(alias Func)()
    {
        this._verts.lock();
            foreach(ref vert; this._verts.verts)
                Func(vert);
            foreach(ref vert; this._verts.vertsToUpload)
                Func(vert);
            this._verts.upload(0, this._verts.length);
        this._verts.unlock();
    }
}