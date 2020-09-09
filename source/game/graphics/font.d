module game.graphics.font;

import std.experimental.logger;
import bindbc.freetype;
import game.common, game.graphics, game.vulkan;

struct Glyph
{
    box2f textureRect;
    vec2i bearing;
    vec2i advance;
    int   index;
}

struct FontSize
{
    Texture      texture;
    Glyph[dchar] glyphs;
}

private void CHECK_FT(int error, string context = "")
{
    enforce(error == 0, "Error when %s: %s".format(context, error));
}

final class Font : IDisposable
{
    mixin IDisposableBoilerplate;

    private
    {
        FontSize[uint] _sizes;
        FT_Face        _face;
        ubyte[]        _fontBytes;
    }

    void onDispose()
    {
        foreach(k, v; this._sizes)
            v.texture.dispose();
        FT_Done_Face(this._face);
    }

    this(ubyte[] fontBytes)
    {
        CHECK_FT(FT_New_Memory_Face(g_freeType, fontBytes.ptr, cast(int)fontBytes.length, 0, &this._face), "loading font");

        this._fontBytes = fontBytes; // Need to keep it alive for as long as FT_Face exists.
    }

    this(string file)
    {
        import std.file : fread = read;

        infof("Loading font from file: %s", file);
        this(cast(ubyte[])fread(file));
    }

    FontSize getFontSize(uint sizeInPixels)
    {
        import std.utf : byUTF;

        auto ptr = (sizeInPixels in this._sizes);
        if(ptr !is null)
            return *ptr;

        info("Generating charmap atlas for font size ", sizeInPixels);
        CHECK_FT(FT_Set_Pixel_Sizes(this._face, 0, sizeInPixels));

        FontSize size;

        // Misc Constants
        const GUTTER_BETWEEN_GLYPHS_X = 1; // To account for floating point inprecision: don't accidentally bleed pixels between glyphs when rendering.
        const GUTTER_BETWEEN_GLYPHS_Y = 1;

        // Calculations.
        const CHARS_TO_LOAD           = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-=+!\"£$%^&*()\\/.,<>?|";
        const CHARS_PER_LINE_ESTIMATE = 10;
        const MARGIN_OF_ERROR         = 2;
        const atlasWidth              = sizeInPixels * (CHARS_PER_LINE_ESTIMATE + MARGIN_OF_ERROR);
        const atlasHeight             = sizeInPixels * ((CHARS_TO_LOAD.length / CHARS_PER_LINE_ESTIMATE) + MARGIN_OF_ERROR);

        // Create the pixels for the atlas.
        auto pixels = PixelBuffer(vec2u(cast(uint)atlasWidth, cast(uint)atlasHeight));
        auto cursor = vec2u(0);
        uint maxHeightThisLine;
        foreach(ch; CHARS_TO_LOAD.byUTF!dchar)
        {
            Glyph glyph;

            glyph.index = FT_Get_Char_Index(this._face, ch);
            CHECK_FT(FT_Load_Glyph(this._face, glyph.index, FT_LOAD_RENDER), "loading glyph");

            // Render it if it's not pre-rendered.
            if(this._face.glyph.format == FT_GLYPH_FORMAT_BITMAP)
                CHECK_FT(FT_Render_Glyph(this._face.glyph, FT_RENDER_MODE_NORMAL));

            // Magical things.
            auto glyphInfo = this._face.glyph;
            glyph.bearing  = vec2i(glyphInfo.bitmap_left,    -glyphInfo.bitmap_top);
            glyph.advance  = vec2i(glyphInfo.advance.x >> 6,  glyphInfo.advance.y >> 6);

            // Move the cursor down a line if we need to
            if(cursor.x + glyphInfo.bitmap.width >= pixels.size.x)
            {
                enforce(maxHeightThisLine > 0, "Pixel buffer is too narrow.");
                cursor.x = 0;
                cursor.y += maxHeightThisLine + GUTTER_BETWEEN_GLYPHS_Y;
                maxHeightThisLine = 0;
            }

            if(glyphInfo.bitmap.rows > maxHeightThisLine)
                maxHeightThisLine = glyphInfo.bitmap.rows;

            // Stitch into the pixel buffer.
            // REMINDER: FT_RENDER_MODE_NORMAL provides the image as an 8-bit grayscale, so we have to do shizz manually.
            foreach(y; 0..glyphInfo.bitmap.rows)
            {
                const rowOffset = y * glyphInfo.bitmap.width;
                foreach(x; 0..glyphInfo.bitmap.width)
                {
                    const offsetIntoBitmap = x + rowOffset;
                    const offsetIntoBuffer = cursor + vec2u(x, y);
                    const alpha            = glyphInfo.bitmap.buffer[offsetIntoBitmap];
                    pixels.set(offsetIntoBuffer, Color(255, 255, 255, alpha));
                }
            }
            cursor += vec2u(glyphInfo.bitmap.width + GUTTER_BETWEEN_GLYPHS_X, 0);
            size.glyphs[ch] = glyph;
        }

        size.texture = new Texture(pixels.pixelsAsBytes, pixels.size, "Font Size %s".format(sizeInPixels));
        this._sizes[sizeInPixels] = size;
        return size;
    }
}