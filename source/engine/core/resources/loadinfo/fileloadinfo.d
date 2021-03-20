module engine.core.resources.loadinfo.fileloadinfo;

struct FileLoadInfo(string identifier)
{
    string absolutePath;
}

alias TexFileLoadInfo = FileLoadInfo!"tex";