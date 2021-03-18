module implementations.textureexporter;

import std.exception : enforce;
import std.file : mkdirRecurse;
import std.path : dirName;
import std.conv : to;
import stdx.allocator.mallocator, stdx.allocator;
import jarchive.binarystream, jarchive.enums;
import bindings.lz4;
import imagefmt, sdlite;
import common, interfaces;

private enum CURRENT_TEX_VERSION = 1;

private enum DataBlockFlags : ubyte
{
    none = 0,
    compressed = 1 << 0
}

final class TextureExporter : IAssetExporter
{
    void exportAsset(IAsset asset, SDLNode node, PathResolver buildDirResolver, PackageFileList files)
    {
        foreach(child; node.children)
        {
            const path = buildDirResolver.resolve(child.values[0].textValue);
            path.dirName.mkdirRecurse();

            switch(child.qualifiedName)
            {
                case "raw": this.exportRaw(asset, path); break;
                case "compiled": this.exportCompiled(asset, path, files); break;
                default: throw new Exception("Unexpected node: "~child.qualifiedName);
            }
        }
    }

    void exportRaw(IAsset asset, string path)
    {
        auto casted = cast(IRawImageAsset)asset;
        enforce(casted !is null, "Asset is not an image: "~asset.name);
        enforce(casted.format == TextureFormats.rgba_u8, "Asset must be in RGBA_U8 format for a raw export: "~asset.name);

        import std.stdio;
        writeln(casted.size, " ", casted.bytes.length);

        const unalignedBytes = casted.bytes[0..(casted.size.x * casted.size.y * 4)]; // Vulkan-based implementations may have a larger byte buffer than is actually needed here.
        const result = write_image(path, casted.size.x, casted.size.y, unalignedBytes, 4);
        enforce(result == 0, IF_ERROR[result]);
    }

    void exportCompiled(IAsset asset, string path, PackageFileList files)
    {
        auto asRawImage = cast(IRawImageAsset)asset;
        enforce(asRawImage !is null, "Asset is not an image: "~asset.name);

        scope stream = jarcBinaryStream_openFileByName(JarcReadWrite.write, cast(ubyte*)path.ptr, path.length);
        enforce(stream !is null, "Could not open file at path: "~path);
        scope(exit) jarcBinaryStream_free(stream);

        files.add(PackageFileType.texture, path);

        // pointers
        c_long frameBlockPtrPtr;
        c_long frameBlockPtr;
        c_long dataBlockPtrPtr;
        c_long dataBlockPtr;
        c_long jumpBackPtr;

        // other
        auto dataBlockFlags = DataBlockFlags.compressed; // Just assume compression will always be best for now.

        // Write header
        jarcBinaryStream_writeBytes(stream, cast(ubyte*)['T', 'E', 'X'].ptr, 3);
        jarcBinaryStream_writeU8(stream, CURRENT_TEX_VERSION);
        jarcBinaryStream_writeString(stream, asset.name.ptr, asset.name.length); // jarchiveBinaryStream is only *slightly* inconsistant with when it uses char and when it uses ubyte...
        jarcBinaryStream_writeU16(stream, asRawImage.size.x.to!ushort);
        jarcBinaryStream_writeU16(stream, asRawImage.size.y.to!ushort);
        jarcBinaryStream_writeU32(stream, asRawImage.format);
        dataBlockPtrPtr = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_writeU32(stream, 0);
        frameBlockPtrPtr = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_writeU32(stream, 0);

        // Write data block (TODO: Compression)
        dataBlockPtr = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_writeU32(stream, 0); // length
        jarcBinaryStream_writeU8(stream, dataBlockFlags); // flags

        if(!(dataBlockFlags & DataBlockFlags.compressed))
        {
            jarcBinaryStream_writeBytes(stream, asRawImage.bytes.ptr, asRawImage.bytes.length); // pixelData
        }
        else
        {
            jarcBinaryStream_writeU32(stream, asRawImage.bytes.length.to!uint); // decompressedSize
        
            // Gonna malloc this just to reduce GC strain.
            const maxSize = LZ4_compressBound(asRawImage.bytes.length.to!int);
            auto destBuffer = Mallocator.instance.makeArray!ubyte(maxSize);
            assert(destBuffer !is null, "Memory allocation failed.");
            scope(exit) Mallocator.instance.dispose(destBuffer);

            const bytesWritten = LZ4_compress_default(asRawImage.bytes.ptr, destBuffer.ptr, asRawImage.bytes.length.to!int, destBuffer.length.to!int);
            assert(bytesWritten > 0, "Compression failed?");

            jarcBinaryStream_writeBytes(stream, destBuffer.ptr, bytesWritten); // compressedPixelData
        }
        jumpBackPtr = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_setCursor(stream, dataBlockPtr);
        jarcBinaryStream_writeU32(stream, jumpBackPtr.to!uint - (dataBlockPtr + uint.sizeof).to!uint);
        jarcBinaryStream_setCursor(stream, jumpBackPtr);

        // Write frame block
        if(auto asTextureContainer = cast(ITextureContainerAsset)asRawImage)
        {
            frameBlockPtr = jarcBinaryStream_getCursor(stream);
            jarcBinaryStream_writeU32(stream, 0);
            foreach(frame; asTextureContainer.frames)
            {
                jarcBinaryStream_writeString(stream, frame.name.ptr, frame.name.length); // name
                jarcBinaryStream_writeU16(stream, frame.rect.min.x.to!ushort); // offsetX
                jarcBinaryStream_writeU16(stream, frame.rect.min.y.to!ushort); // offsetY
                jarcBinaryStream_writeU16(stream, frame.rect.width.to!ushort); // width
                jarcBinaryStream_writeU16(stream, frame.rect.height.to!ushort); // height
            }            
            jumpBackPtr = jarcBinaryStream_getCursor(stream);
            jarcBinaryStream_setCursor(stream, frameBlockPtr);
            jarcBinaryStream_writeU32(stream, jumpBackPtr.to!uint - (frameBlockPtr + uint.sizeof).to!uint);
            jarcBinaryStream_setCursor(stream, jumpBackPtr);
        }

        // Update the pointers to pointers
        jarcBinaryStream_setCursor(stream, dataBlockPtrPtr);
        jarcBinaryStream_writeU32(stream, dataBlockPtr);

        if(frameBlockPtr != 0)
        {
            jarcBinaryStream_setCursor(stream, frameBlockPtrPtr);
            jarcBinaryStream_writeU32(stream, frameBlockPtr);
        }
    }
}