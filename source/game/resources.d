module game.resources;

import std.path : absolutePath;
import std.file : fread = read, exists;
import std.experimental.logger;
import bgfx, gfm.math, imagefmt, sdlang;
import game;

struct StaticTexture
{
    bgfx_texture_handle_t handle;
    bgfx_texture_info_t   info;
    ubyte[]               data; // I'm not completely sure if BGFX needs me to keep this data around, so we store a reference to stop the GC collecting it.
}

struct StitchedTexture
{
    StaticTexture atlas;
    vec4i area;
}

struct StitchableAtlas
{
    private
    {
        bgfx_texture_handle_t _handle;
        vec2i                 _cursor;
        vec2i                 _size;
        uint                  _largestHeightOnLine;
    }

    public
    {
        @disable
        this(this)
        {
        }

        this(ushort width, ushort height)
        {
            this._size = vec2i(width, height);
            this._handle = bgfx_create_texture_2d(
                width, 
                height, 
                false, 
                1, 
                bgfx_texture_format_t.BGFX_TEXTURE_FORMAT_RGBA8,
                BGFX_SAMPLER_UVW_CLAMP | BGFX_SAMPLER_MIN_POINT | BGFX_SAMPLER_MAG_POINT,
                null
            );
            bgfx_set_texture_name(this._handle, "Atlas", 5);
        }

        ~this()
        {
            bgfx_destroy_texture(this._handle);
        }

        StitchedTexture stitch(ubyte[] rgba, vec2i size)
        {
            import std.format : format;

            infof("Stitching a %s texture to cursor %s", size, this._cursor);

            assert(size.x >= 0);
            assert(size.y >= 0);

            const total = size.x * size.y * 4; // 4 = RGBA
            assert(rgba.length == total, "Expected: %s | Got: %s".format(total, rgba.length));

            auto botRight = this._cursor + size;
            if(botRight.x >= this._size.x)
            {
                infof("Texture hit edge, going down a line to Y %s", this._largestHeightOnLine);

                this._cursor.y += this._largestHeightOnLine;
                this._cursor.x = 0;

                botRight = this._cursor + size;
                assert(botRight.x < this._size.x, "Texture is too wide.");

                info("Cursor is now ", this._cursor);
            }
            assert(botRight.y < this._size.y, "Texture is too high.");

            const area = vec4i(this._cursor, size);
            if(area.y > this._largestHeightOnLine)
                this._largestHeightOnLine = area.y;

            info("Final area ", area);

            // meh..
            bgfx_update_texture_2d(
                this._handle, 
                0, 0, 
                cast(ushort)area.x, 
                cast(ushort)(this._size.y - (area.y + area.w)), // Top make things start from the top-left
                cast(ushort)area.z, 
                cast(ushort)area.w, 
                bgfx_copy(rgba.ptr, cast(uint)total),
                ushort.max
            );

            this._cursor.x += area.z;
            info("Cursor is now ", this._cursor);
            return StitchedTexture(StaticTexture(this._handle), area);
        }
    }
}

// Game has minimal resources, so we don't need any fancy reloading or unloading or whatever capabilities, and 
// keeping this as a singleton is pretty fine.
final class Resources
{
    private static
    {
        StaticTexture[string]   _staticTextures; // key is absolute path to file.
        StitchedTexture[string] _stitchedTextures;
        StitchableAtlas[]       _atlases;
        Level[string]           _levels; // Key is absolute path to definition file.
    }

    public static
    {
        const(StaticTexture) loadStaticTexture(string relativeOrAbsolutePath, bool cache = true)
        {
            const path = relativeOrAbsolutePath.absolutePath;
            info("Loading texture: ", path);

            if(!path.exists)
            {
                info("Texture not found, loading default texture instead.");
                return loadStaticTexture("./resources/images/static/default.ktx"); // Possible infinite loop, just don't delete the default texture 4head
            }

            const ptr = (path in _staticTextures);
            if(ptr !is null)
            {
                info("Texture was cached.");
                return *ptr;
            }

            info("Texture wasn't cached, loading from disk.");
            const content = fread(path);

            bgfx_texture_info_t info;
            const handle = bgfx_create_texture(
                bgfx_make_ref(content.ptr, cast(uint)content.length), 
                BGFX_SAMPLER_UVW_CLAMP | BGFX_SAMPLER_MIN_POINT | BGFX_SAMPLER_MAG_POINT, // a.k.a "don't make me blurry"
                0,
                &info
            );
            bgfx_set_texture_name(handle, path.ptr, cast(int)path.length); // How weird that it uses uint everywhere, except here.

            auto texture = StaticTexture(handle, info, cast(ubyte[])content);
            if(cache)
                _staticTextures[path] = texture;

            return texture;
        }

        const(StitchedTexture) loadAndStitchTexture(string relativeOrAbsolutePath, size_t atlasNum)
        {
            const path = relativeOrAbsolutePath.absolutePath;
            info("Loading texture: ", path);

            if(!path.exists)
            {
                info("Texture not found, loading default texture instead.");
                return loadAndStitchTexture("./resources/images/dynamic/default.png", 0); // Possible infinite loop, just don't delete the default texture 4head
            }

            const ptr = (path in _stitchedTextures);
            if(ptr !is null)
            {
                info("Texture was cached.");
                return *ptr;
            }

            info("Texture wasn't cached, loading from disk.");
            auto image = read_image(path, 4);
            if(image.e)
                criticalf("Error loading image: %s", IF_ERROR[image.e]);
            scope(exit) image.free();

            if(this._atlases.length <= atlasNum)
            {
                info("Expanding atlas list to ", atlasNum + 1);
                this._atlases.length = atlasNum + 1;
            }

            if(this._atlases[atlasNum] == StitchableAtlas.init)
            {
                info("Initialising atlas #", atlasNum);
                this._atlases[atlasNum] = StitchableAtlas(4096, 4096);
            }

            auto texture = this._atlases[atlasNum].stitch(image.buf8, vec2i(image.w, image.h));
            this._stitchedTextures[path] = texture;
            return texture;
        }

        Level loadLevel(string relativeOrAbsolutePath)
        {
            const path = relativeOrAbsolutePath.absolutePath;
            info("Loading level: ", path);

            if(!path.exists)
                criticalf("Path to level definition does not exist: ", path);

            const ptr = (path in _levels);
            if(ptr !is null)
            {
                info("Level was cached.");
                return cast()*ptr;
            }

            info("Level wasn't cached, loading from disk.");
            auto  sdl        = parseFile(path);
            const name       = sdl.expectTagValue!string("name");
            const background = sdl.expectTagValue!string("background");
            const backAtlas  = sdl.expectTagValue!int("background_atlas");
            auto level       = new Level(name, Sprite(loadAndStitchTexture(background, backAtlas)));

            _levels[path] = level;
            return level;
        }
    }
}