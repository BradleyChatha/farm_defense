module implementations.materialexporter;

import std.exception : enforce;
import std.file : mkdirRecurse;
import std.path : dirName;
import std.conv : to;
import jarchive.binarystream, jarchive.enums;
import sdlite;
import common, interfaces;

private enum CURRENT_MAT_VERSION = 1;

final class MaterialExporter : IAssetExporter
{
    void exportAsset(IAsset asset, SDLNode node, PathResolver buildDirResolver, PackageFileList files)
    {
        const path = buildDirResolver.resolve(node.values[0].textValue);
        path.dirName.mkdirRecurse();
        files.add(PackageFileType.material, path);

        auto casted = cast(IMaterialAsset)asset;
        enforce(casted !is null, "Asset is not a material: "~asset.name);

        auto stream = jarcBinaryStream_openFileByName(JarcReadWrite.write, cast(ubyte*)path.ptr, path.length);
        assert(stream !is null);
        scope(exit) jarcBinaryStream_free(stream);

        // POINTERS
        c_long spirvBlockPointerPointer;
        c_long spirvBlockPointer;
        c_long spirvBlockLengthsPointer;
        c_long tempPointer;

        // Header
        const headerBytes = cast(ubyte[])['M', 'A', 'T', CURRENT_MAT_VERSION];
        jarcBinaryStream_writeBytes(stream, headerBytes.ptr, 4); // magicNumber & version
        CHECK_JARC_EX(jarcBinaryStream_writeString(stream, asset.name.ptr, asset.name.length)); // name
        CHECK_JARC_EX(jarcBinaryStream_writeU8(stream, casted.renderer.to!ubyte)); // rendererType
        spirvBlockPointerPointer = jarcBinaryStream_getCursor(stream);
        CHECK_JARC_EX(jarcBinaryStream_writeU32(stream, 0)); // pointerToSpirvBlock
        
        // SpirvBlock
        spirvBlockPointer = jarcBinaryStream_getCursor(stream);
        CHECK_JARC_EX(jarcBinaryStream_writeU32(stream, 0)); // Block.length
        spirvBlockLengthsPointer = jarcBinaryStream_getCursor(stream);
        CHECK_JARC_EX(jarcBinaryStream_writeU16(stream, 0)); // vertReflectLength
        CHECK_JARC_EX(jarcBinaryStream_writeU16(stream, 0)); // fragReflectLength
        CHECK_JARC_EX(jarcBinaryStream_writeU32(stream, casted.vertexShader.bytes.length.to!uint)); // vertSpirvLength
        CHECK_JARC_EX(jarcBinaryStream_writeU32(stream, casted.fragmentShader.bytes.length.to!uint)); // fragSpirvLength

        // vertData & fragData
        this.writeSpirvShaderData(stream, casted.vertexShader, spirvBlockLengthsPointer);
        this.writeSpirvShaderData(stream, casted.fragmentShader, (spirvBlockLengthsPointer + ushort.sizeof).to!c_long);

        tempPointer = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_setCursor(stream, spirvBlockPointerPointer);
        jarcBinaryStream_writeU32(stream, spirvBlockPointer);
        jarcBinaryStream_setCursor(stream, spirvBlockPointer);
        jarcBinaryStream_writeU32(stream, (tempPointer - spirvBlockPointer) - uint.sizeof.to!uint);
    }

    private void writeSpirvShaderData(JarcBinaryStream* stream, IRawShaderModuleAsset asset, c_long spirvBlockLengthsPointer)
    {
        auto start = jarcBinaryStream_getCursor(stream);
        // TODO: Write reflect data
        auto end = jarcBinaryStream_getCursor(stream);
        jarcBinaryStream_setCursor(stream, spirvBlockLengthsPointer);
        jarcBinaryStream_writeU16(stream, (end - start).to!ushort);
        jarcBinaryStream_setCursor(stream, end);
        jarcBinaryStream_writeBytes(stream, asset.bytes.ptr, asset.bytes.length); // rawSpirv
    }
}