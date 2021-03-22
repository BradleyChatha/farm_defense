module engine.core.resources.loaders.texresourceloader;

import std.bitmanip : bigEndianToNative;
import std.conv : to;
import std.exception : assumeUnique;
import std.string : fromStringz;
import bindings.lz4;
import jarchive.enums, jarchive.binarystream;
import engine.core, engine.graphics, engine.util, engine.vulkan;

private struct Header
{
    ubyte[3] magicNumber;
    ubyte version_;
    string name;
    ushort width;
    ushort height;
    VkFormat vkImageFormat;
    uint pointerToDataBlock;
    uint pointerToFrameBlock;
}

private enum DataBlockFlags
{
    none = 0,
    compressed = 1 << 0
}

private enum MAX_SUPPORTED_VERSION = 1;
private enum MIN_SUPPORTED_VERSION = 1;
private enum MAX_NAME_LENGTH       = 1024;

final class TexFileLoadInfoResourceLoader : IResourceLoader
{
    mixin IResourceLoaderBoilerplate!TexFileLoadInfo;
    
    override Result!IResource loadFromLoadInfo(ResourceLoadInfo loadInfo, ref PackageLoadContext context)
    {
        auto info = loadInfo.as!TexFileLoadInfo;

        scope stream = jarcBinaryStream_openFileByName(JarcReadWrite.read, cast(ubyte*)info.absolutePath.ptr, info.absolutePath.length, false);
        if(stream is null)
            return typeof(return).failure("Could not open TEX file: "~info.absolutePath);
        scope(exit) jarcBinaryStream_free(stream);

        auto headerResult = this.readHeader(stream);
        if(!headerResult.isOk)
            return typeof(return).failure(headerResult.error);
        
        const header     = headerResult.value;
        const dataBlock  = readBlock(stream, header.pointerToDataBlock);
        const frameBlock = readBlock(stream, header.pointerToFrameBlock);

        auto builder = TextureContainerBuilder();
        const dataBlockError = this.processDataBlock(builder, dataBlock, header);
        if(dataBlockError !is null)
            return typeof(return).failure("Unable to process data block: "~dataBlockError);

        const frameBlockError = this.processFrameBlock(builder, frameBlock);
        if(frameBlockError !is null)
            return typeof(return).failure("Unable to process frame block: "~frameBlockError);
        return typeof(return).ok(builder.build());
    }

    private Result!Header readHeader(JarcBinaryStream* stream)
    {
        Header header;

        jarcBinaryStream_readBytes(stream, header.magicNumber.ptr, null, header.magicNumber.length);
        if(header.magicNumber != cast(ubyte[])['T', 'E', 'X'])
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

        CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &header.width));
        CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &header.height));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, cast(uint*)&header.vkImageFormat));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &header.pointerToDataBlock));
        CHECK_JARC_EX(jarcBinaryStream_readU32(stream, &header.pointerToFrameBlock));
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

    private string processDataBlock(ref TextureContainerBuilder builder, const ubyte[] block, Header header)
    {
        auto flags = block[0].to!DataBlockFlags;
        ubyte[] bytes;

        if(flags & DataBlockFlags.compressed)
        {
            bytes.length = block[1..5].bigEndianToNative!uint;
            const compressedBytes = block[5..$];

            const result = LZ4_decompress_safe(compressedBytes.ptr, bytes.ptr, compressedBytes.length.to!int, bytes.length.to!int);
            if(result < 0)
                return "Unable to decompress the compressed data("~result.to!string~"): "~LZ4F_getErrorName(result).fromStringz.to!string;
        }
        else
            bytes = cast(ubyte[])block[1..$]; // Cast away const for simplicity, but note that we're still treating it as const.
        
        if(bytes.length != header.width * header.height * bytesPerPixel(header.vkImageFormat))
            return "Bad data length, expected "~(header.width * header.height * bytesPerPixel(header.vkImageFormat)).to!string~" but got "~bytes.length.to!string;

        builder.fromBytes(bytes, header.vkImageFormat, vec2u(header.width, header.height));
        return null;
    }

    private string processFrameBlock(ref TextureContainerBuilder builder, const ubyte[] block)
    {
        if(block.length == 0)
            return null;

        auto stream = jarcBinaryStream_openBorrowedMemory(JarcReadWrite.read, cast(ubyte*)block.ptr, block.length);
        scope(exit) jarcBinaryStream_free(stream);

        while(jarcBinaryStream_getCursor(stream) < block.length)
        {
            ulong nameLength;
            ushort x;
            ushort y;
            ushort width;
            ushort height;

            CHECK_JARC_EX(jarcBinaryStream_read7BitEncodedU(stream, &nameLength));

            auto name = new char[nameLength];
            jarcBinaryStream_readBytes(stream, cast(ubyte*)name.ptr, null, name.length);

            CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &x));
            CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &y));
            CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &width));
            CHECK_JARC_EX(jarcBinaryStream_readU16(stream, &height));

            builder.defineFrame(TextureFrame(name.assumeUnique, rectangleu(x, y, width, height)));
        }
        assert(jarcBinaryStream_getCursor(stream) == block.length);

        return null;
    }
}