module game.graphics.pixelbuffer;

import game.common, game.graphics;

// A CPU-side buffer for manipulating pixels.
//
// This buffer always functions in RGBA format, with 8 bits per channel.
struct PixelBuffer
{
    private
    {
        Color[] _pixels;
        vec2u   _size;
    }

    @disable
    this(this){}

    this(vec2u size)
    {
        this._pixels.length = size.x * size.y;
        this._size          = size;
    }

    void set(vec2u position, Color value)
    {
        this._pixels[position.x + (position.y * this._size.x)] = value;
    }

    bool copyRgba(const Color[] source, vec2u start, vec2u size)
    {
        const bottomRight = start + size;
        if(bottomRight.x >= this._size.x
        || bottomRight.y >= this._size.y)
            return false;

        const startX = start.x;
        const endX   = start.x + size.x;
        for(size_t y = 0; y < size.y; y++)
        {
            const column = y * size.x;
            this._pixels[column + startX..column + endX] = source[column..column + size.x];
        }

        return true;
    }

    // Helpful overloads
    void copyRgba(const ubyte[] source, vec2u start, vec2u size){ this.copyRgba(cast(Color[])source, start, size); }

    @property
    vec2u size()
    {
        return this._size;
    }

    @property
    Color[] pixels()
    {
        return this._pixels;
    }

    @property
    ubyte[] pixelsAsBytes()
    {
        return cast(ubyte[])this._pixels;
    }
}