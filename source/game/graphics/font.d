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
    int          ascender;
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
        size.ascender = this._face.size.metrics.ascender >> 6;

        // Misc Constants
        const GUTTER_BETWEEN_GLYPHS_X = 1; // To account for floating point inprecision: don't accidentally bleed pixels between glyphs when rendering.
        const GUTTER_BETWEEN_GLYPHS_Y = 1;

        // Calculations.
        const CHARS_TO_LOAD           = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-=+!\"£$%^&*()\\/.,<>?| \n";
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
            glyph.bearing  = vec2i(glyphInfo.bitmap_left,    glyphInfo.bitmap_top);
            glyph.advance  = vec2i(glyphInfo.advance.x >> 6, glyphInfo.advance.y >> 6);

            // Move the cursor down a line if we need to
            if(cursor.x + glyphInfo.bitmap.width >= pixels.size.x)
            {
                enforce(maxHeightThisLine > 0, "Pixel buffer is too narrow.");
                cursor.x = 0;
                cursor.y += maxHeightThisLine + GUTTER_BETWEEN_GLYPHS_Y;
                maxHeightThisLine = 0;
            }
            glyph.textureRect.min = cursor;

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
            glyph.textureRect.max = vec2u(cursor.x + glyphInfo.bitmap.width, cursor.y + glyphInfo.bitmap.rows);
            cursor               += vec2u(glyphInfo.bitmap.width + GUTTER_BETWEEN_GLYPHS_X, 0);
            size.glyphs[ch]       = glyph;
        }

        size.texture = new Texture(pixels.pixelsAsBytes, pixels.size, "Font Size %s".format(sizeInPixels));
        this._sizes[sizeInPixels] = size;
        return size;
    }

    void textToVerts(
        ref   TexturedVertex[] buffer, // Can be null/empty.
        ref   box2f            boundingBox,
        const char[]           text,
              uint             sizeInPixels,
              vec2f            initialCursor = vec2f(0),
              Color            colour        = Color.white,
              float            lineSpacing   = 0
    )
    {
        import std.utf : byUTF;

        assert(buffer.length >= this.calculateVertCount(text), "Buffer is too small for the given text.");

             boundingBox = box2f(0, 0, 0, 0);
        auto fontSize    = this.getFontSize(sizeInPixels);
        auto cursor      = initialCursor;
        auto bufferIndex = 0;
        foreach(ch; text.byUTF!dchar)
        {
            // Get the glyph.
            auto ptr = (ch in fontSize.glyphs);
            enforce(ptr !is null, "No glyph for character '%s'(%s)".format(ch, cast(uint)ch));

            auto glyph = *ptr;

            // Calculate things.
            const bearedCursor = cursor + glyph.bearing;
            const w = glyph.textureRect.width;
            const h = glyph.textureRect.height;
            const x = bearedCursor.x;
            const y = ((h - glyph.bearing.y) + (fontSize.ascender - h)) + cursor.y; // Since we're down undah, we need to know how far *down* the baseline to go, instead of up.

            infof("'%s' c:%s b:%s bc:%s x:%s y:%s w:%s h:%s a:%s bb:%s", ch, cursor, glyph.bearing, bearedCursor, x, y, w, h, fontSize.ascender, boundingBox);

            // Check if we need to go onto the next line.
            const MAX_WIDTH = float.max; // Here for when we support letter wrapping/occlusion.
            if(w + h > MAX_WIDTH || ch == '\n')
            {
                cursor.x  = initialCursor.x;
                cursor.y  = lineSpacing + boundingBox.max.y;
                continue;
            }

            // Generate verts.
            TexturedVertex[4] verts = 
            [
                TexturedVertex(vec3f(x,     y,     0), vec2f(glyph.textureRect.min.x, glyph.textureRect.min.y), colour),
                TexturedVertex(vec3f(x + w, y,     0), vec2f(glyph.textureRect.max.x, glyph.textureRect.min.y), colour),
                TexturedVertex(vec3f(x + w, y + h, 0), vec2f(glyph.textureRect.max.x, glyph.textureRect.max.y), colour),
                TexturedVertex(vec3f(x,     y + h, 0), vec2f(glyph.textureRect.min.x, glyph.textureRect.max.y), colour),
            ];

            buffer[bufferIndex++] = verts[0];
            buffer[bufferIndex++] = verts[1];
            buffer[bufferIndex++] = verts[2];
            buffer[bufferIndex++] = verts[2];
            buffer[bufferIndex++] = verts[3];
            buffer[bufferIndex++] = verts[0];

            // Keep track of the largest/smallest posisions, so we can also provide a size box.
            if(y < boundingBox.min.y)     boundingBox.min.y = y;
            if(y + h > boundingBox.max.y) boundingBox.max.y = y + h;
            if(x < boundingBox.min.x)     boundingBox.min.x = x;
            if(x + w > boundingBox.max.x) boundingBox.max.x = x + w;

            // Advance cursor.
            cursor.x += glyph.advance.x;
        }
    }

    size_t calculateVertCount(const char[] text)
    {
        return text.length * 6; // 6 Verts to a quad.
    }
}