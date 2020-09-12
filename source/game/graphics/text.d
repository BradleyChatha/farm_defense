module game.graphics.text;

import game.core, game.common, game.graphics;

final class Text : IDisposable
{
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
    }

    @property
    void text(const char[] value)
    {
        this._text = value;
        if(value.length == 0)
            return;

        const vertCount = this._font.calculateVertCount(value);
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
                value,
                this._fontSize,
                vec2f(0),
                this._colour,
                this._lineSpacing
            );
            this._verts.vertsToUpload[0..$] = this._verts.verts[0..$];
            this._verts.upload(0, this._verts.length);
        this._verts.unlock();
    }
    
    @property
    const(char)[] text()
    {
        return this._text;
    }

    @property
    DrawCommand drawCommand()
    {
        return DrawCommand(
            &this._verts,
            0,
            this._vertsToRender,
            this._font.getFontSize(this._fontSize).texture,
            true,
            0
        );
    }
}