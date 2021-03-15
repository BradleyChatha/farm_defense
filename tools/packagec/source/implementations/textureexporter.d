module implementations.textureexporter;

import std.exception : enforce;
import std.file : mkdirRecurse;
import std.path : dirName;
import imagefmt, sdlite;
import common, interfaces;

final class TextureExporter : IAssetExporter
{
    void exportAsset(IAsset asset, SDLNode node, PathResolver buildDirResolver)
    {
        foreach(child; node.children)
        {
            const path = buildDirResolver.resolve(child.values[0].textValue);
            path.dirName.mkdirRecurse();

            switch(child.qualifiedName)
            {
                case "raw": this.exportRaw(asset, path); break;
                case "compiled": this.exportCompiled(asset, path); break;
                default: throw new Exception("Unexpected node: "~child.qualifiedName);
            }
        }
    }

    void exportRaw(IAsset asset, string path)
    {
        auto casted = cast(IRawImageAsset)asset;
        enforce(casted !is null, "Asset is not an image: "~asset.name);
        enforce(casted.format == TextureFormats.rgba_u8, "Asset must be in RGBA_U8 format: "~asset.name);

        import std.stdio;
        writeln(casted.size, " ", casted.bytes.length);

        const unalignedBytes = casted.bytes[0..(casted.size.x * casted.size.y * 4)]; // Vulkan-based implementations may have a larger byte buffer than is actually needed here.
        const result = write_image(path, casted.size.x, casted.size.y, unalignedBytes, 4);
        enforce(result == 0, IF_ERROR[result]);
    }

    void exportCompiled(IAsset asset, string path)
    {
    }
}