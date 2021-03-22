module engine.core.resources.loaders.lstpackageloader;

import std.conv : to;
import std.path : dirName, buildPath;
import jarchive.binarystream, jarchive.enums;
import engine.core, engine.graphics, engine.util;

private enum LstFileType : ubyte
{
    ERROR,
    texture,
    material
}

private struct LstFileEntry
{
    LstFileType type;
    string absolutePath;
}

final class LstPackageLoader : IPackageLoader
{
    Result!(ResourceLoadInfo[]) loadFromFile(string absolutePath)
    {
        auto lstResult = this.readLstFile(absolutePath);
        if(!lstResult.isOk)
            return typeof(return).failure(lstResult.error);

        ResourceLoadInfo[] toReturn;
        toReturn.reserve(lstResult.value.length);

        foreach(entry; lstResult.value)
        {
            auto assetResult = this.readAssetFile(entry);
            if(!assetResult.isOk)
                return typeof(return).failure(assetResult.error);

            toReturn ~= assetResult.value;
        }

        return typeof(return).ok(toReturn);
    }

    private Result!ResourceLoadInfo readAssetFile(LstFileEntry entry)
    {
        final switch(entry.type) with(LstFileType)
        {
            case ERROR: return typeof(return).failure("Type of file is ERROR: "~entry.absolutePath);
            case texture: return typeof(return).ok(ResourceLoadInfo(TexFileLoadInfo(entry.absolutePath)));
            case material: return typeof(return).ok(ResourceLoadInfo(MatFileLoadInfo(entry.absolutePath)));
        }
    }

    private Result!(LstFileEntry[]) readLstFile(string path)
    {
        scope stream = jarcBinaryStream_openFileByName(JarcReadWrite.read, cast(ubyte*)path.ptr, path.length, false);
        if(stream is null)
            return typeof(return).failure("Could not open LST file at: "~path);
        scope(exit) jarcBinaryStream_free(stream);

        ubyte[3] magicNumber;
        jarcBinaryStream_readBytes(stream, magicNumber.ptr, null, 3);
        if(magicNumber != ['L', 'S', 'T'])
            return typeof(return).failure("Incorrect magic number for LST file: "~path);

        // TODO: Do something with the version.
        ubyte version_;
        uint count;
        jarcBinaryStream_readU8(stream, &version_);
        jarcBinaryStream_readU32(stream, &count);
        auto entries = new LstFileEntry[count];

        foreach(i; 0..count)
        {
            jarcBinaryStream_readU8(stream, cast(ubyte*)&entries[i].type);

            ulong pathLength;
            jarcBinaryStream_read7BitEncodedU(stream, &pathLength);
            
            auto relativePath = new char[pathLength];
            jarcBinaryStream_readBytes(stream, cast(ubyte*)relativePath.ptr, null, pathLength);

            entries[i].absolutePath = path.dirName.buildPath(relativePath);
        }

        return typeof(return).ok(entries);
    }
}