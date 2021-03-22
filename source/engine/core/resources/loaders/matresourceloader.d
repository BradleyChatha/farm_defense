module engine.core.resources.loaders.matresourceloader;

import std.bitmanip : bigEndianToNative;
import std.conv : to;
import std.exception : assumeUnique;
import std.string : fromStringz;
import jarchive.enums, jarchive.binarystream;
import engine.core, engine.graphics, engine.util, engine.vulkan;

private struct Header
{
    ubyte[3] magicNumber;
    ubyte version_;
    string name;
    MaterialRenderer rendererType;
    uint pointerToSpirvBlock;
}

private enum DataBlockFlags
{
    none = 0,
    compressed = 1 << 0
}

private enum MAX_SUPPORTED_VERSION = 1;
private enum MIN_SUPPORTED_VERSION = 1;
private enum MAX_NAME_LENGTH       = 1024;

// Need to DRY this in a bit.
final class MatFileLoadInfoResourceLoader : IResourceLoader
{
    mixin IResourceLoaderBoilerplate!MatFileLoadInfo;
    
    override Result!IResource loadFromLoadInfo(ResourceLoadInfo loadInfo, ref PackageLoadContext context)
    {
        auto info = loadInfo.as!MatFileLoadInfo;

        scope stream = jarcBinaryStream_openFileByName(JarcReadWrite.read, cast(ubyte*)info.absolutePath.ptr, info.absolutePath.length, false);
        if(stream is null)
            return typeof(return).failure("Could not open MAT file: "~info.absolutePath);
        scope(exit) jarcBinaryStream_free(stream);

        auto headerResult = this.readHeader(stream);
        if(!headerResult.isOk)
            return typeof(return).failure(headerResult.error);
        
        const header    = headerResult.value;
        auto spirvBlock = readBlock(stream, header.pointerToSpirvBlock);

        MaterialBuilder builder;
        builder.forRenderer(header.rendererType);

        const spirvBlockResult = this.processSpirvBlock(spirvBlock, builder);
        if(spirvBlockResult !is null)
            return typeof(return).failure("Unable to process SPIRV block: "~spirvBlockResult);

        import std.stdio;
        writeln(builder);
        return typeof(return).failure("Incomplete implementation.");
    }

    private Result!Header readHeader(JarcBinaryStream* stream)
    {
        Header header;

        jarcBinaryStream_readBytes(stream, header.magicNumber.ptr, null, header.magicNumber.length);
        if(header.magicNumber != cast(ubyte[])['M', 'A', 'T'])
            return typeof(return).failure("Invalid magic number.");

        jarcBinaryStream_readBytes(stream, &header.version_, null, 1);
        if(header.version_ > MAX_SUPPORTED_VERSION || header.version_ < MIN_SUPPORTED_VERSION)
            return typeof(return).failure("Unsupported TEX file version.");

        ulong nameLength;
        CHECK_JARC_EX(jarcBinaryStream_read7BitEncodedU(stream, &nameLength));

        if(nameLength > MAX_NAME_LENGTH)
            return typeof(return).failure("Name is too long.");
        
        auto name = new char[nameLength];
        jarcBinaryStream_readBytes(stream, cast(ubyte*)name.ptr, null, nameLength);
        header.name = name.assumeUnique;

        CHECK_JARC_EX(jarcBinaryStream_readU8(stream, cast(ubyte*)(&header.rendererType)));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &header.pointerToSpirvBlock));
        return typeof(return).ok(header);
    }

    private ubyte[] readBlock(JarcBinaryStream* stream, uint pointer)
    {
        if(pointer == 0)
            return null;

        uint length;
        jarcBinaryStream_setCursor(stream, pointer);
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &length));

        auto data = new ubyte[length];
        const bytesRead = jarcBinaryStream_readBytes(stream, data.ptr, null, data.length);
        assert(bytesRead == data.length);

        return data;
    }

    private string processSpirvBlock(ubyte[] block, ref MaterialBuilder builder)
    {
        auto stream = jarcBinaryStream_openBorrowedMemory(JarcReadWrite.read, block.ptr, block.length);
        scope(exit) jarcBinaryStream_free(stream);

        ushort vertReflectLength;
        ushort fragReflectLength;
        uint vertSpirvLength;
        uint fragSpirvLength;
        CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &vertReflectLength));
        CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &fragReflectLength));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &vertSpirvLength));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &fragSpirvLength));

        string readShader(string type)(size_t spirvLength)
        {
            // TODO: Read reflect data once we start writing it.

            auto spirv = new ubyte[spirvLength];
            if(jarcBinaryStream_readBytes(stream, spirv.ptr, null, spirv.length) != spirv.length)
                return "Unable to fully read "~type~" SPIRV.";

            static if(type == "vertex")
            {
                builder.withVertexShader(spirv);
            }
            else static if(type == "fragment")
            {
                builder.withFragmentShader(spirv);
            }
            else static assert(false, spirv);

            return null;
        }

        auto result = readShader!"vertex"(vertSpirvLength);
        if(result !is null) 
            return result;

        result = readShader!"fragment"(fragSpirvLength);
        if(result !is null)
            return result;
        return null;
    }
}