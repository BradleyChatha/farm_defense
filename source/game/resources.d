module game.resources;

import std.path : absolutePath;
import std.file : fread = read;
import std.experimental.logger;
import bgfx;

struct Texture
{
    bgfx_texture_handle_t handle;
    bgfx_texture_info_t   info;
    ubyte[]               data; // I'm not completely sure if BGFX needs me to keep this data around, so we store a reference to stop the GC collecting it.
}

// Game has minimal resources, so we don't need any fancy reloading or unloading or whatever capabilities, and 
// keeping this as a singleton is pretty fine.
final class Resources
{
    private static
    {
        Texture[string] _textures; // key is absolute path to file.
    }

    public static
    {
        const(Texture) loadTexture(string relativeOrAbsolutePath)
        {
            import std.file : exists;

            const path = relativeOrAbsolutePath.absolutePath;
            info("Loading texture: ", path);

            if(!path.exists)
            {
                info("Texture not found, loading default texture instead.");
                return loadTexture("./resources/images/default.ktx"); // Possible infinite loop, just don't delete the default texture 4head
            }

            const ptr = (path in _textures);
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

            auto texture = Texture(handle, info, cast(ubyte[])content);
            _textures[path] = texture;

            return texture;
        }
    }
}