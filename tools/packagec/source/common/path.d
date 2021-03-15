module common.path;

import std.file, std.path, std.stdio;

private const OUTPUT_DIR_RELATIVE_TO_ROOT = "./assets/build/";
private string[] g_locationStack;

void ensureInGameRootDir()
{
    while(!exists("./assets/"))
        chdir("..");
}

string getBuildOutputDir()
{
    static string _str;
    if(_str is null)
        _str = buildPath(getcwd(), OUTPUT_DIR_RELATIVE_TO_ROOT);

    return _str;
}

void pushLocation(string location)
{
    g_locationStack ~= getcwd();
    chdir(location);
}

void popLocation()
{
    chdir(g_locationStack[$-1]);
    g_locationStack.length--;
}

struct PathResolver
{
    private string _root;

    this(string root)
    {
        this._root = (root.extension !is null)
                     ? root.dirName
                     : root;
    }

    string resolve(string relativePath) const
    {
        return buildNormalizedPath(this._root, relativePath);
    }

    PathResolver asResolver(string relativePath) const
    {
        return PathResolver(this.resolve(relativePath));
    }

    string root() const
    {
        return this._root;
    }
}