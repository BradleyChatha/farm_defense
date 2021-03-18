module common.packagefilelist;

import std.conv : to;
import std.path : relativePath, absolutePath;
import std.algorithm : startsWith;
import jarchive.binarystream, jarchive.enums;

enum CURRENT_LST_VERSION = 1;

private struct PackageFile
{
    string relativeAssetPath;
    PackageFileType type;
}

enum PackageFileType : ubyte
{
    ERROR,
    texture
}

final class PackageFileList
{
    private string _packageRootDir;
    private PackageFile[] _files;

    this(string rootDir)
    {
        if(rootDir.startsWith("./"))
            rootDir = rootDir[2..$];
        this._packageRootDir = rootDir.absolutePath;
    }

    void add(PackageFileType type, string path)
    {
        if(path.startsWith("./"))
            path = path[2..$];

        path = path.absolutePath.relativePath(this._packageRootDir);
        this._files ~= PackageFile(path, type);
    }

    ubyte[] exportToBinary()
    {
        scope stream = jarcBinaryStream_openNewMemory(JarcReadWrite.write);
        assert(stream !is null, "Failed to create binary stream.");
        scope(exit) jarcBinaryStream_free(stream);

        jarcBinaryStream_writeBytes(stream, cast(ubyte*)['L', 'S', 'T'].ptr, 3); // magicNumber
        jarcBinaryStream_writeU8(stream, CURRENT_LST_VERSION); // version
        jarcBinaryStream_writeU32(stream, this._files.length.to!uint); // entryCount
        foreach(file; this._files) // entries
        {
            assert(file.type != PackageFileType.ERROR, "File type is ERROR.");
            jarcBinaryStream_writeU8(stream, file.type);
            jarcBinaryStream_writeString(stream, file.relativeAssetPath.ptr, file.relativeAssetPath.length);
        }

        ubyte* ptr;
        size_t length;
        jarcBinaryStream_getMemory(stream, &ptr, &length);
        return ptr[0..length].dup;
    }
}