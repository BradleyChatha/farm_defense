module common.pipelinebuilder;

import sdlite;
import common, interfaces;

final class PipelineBuilder
{
    private
    {
        PackagecCore _core;
        PipelineAction[] _actions;
        PipelineImport[] _imports;
        string _name;
        PathResolver _baseDir;
        string _export;
    }

    this(PackagecCore core, PathResolver baseDir)
    {
        this._core = core;
        this._baseDir = baseDir;
    }

    PipelineBuilder called(string name)
    {
        this._name = name;
        return this;
    }

    PipelineBuilder then(IPipelineAction action, SDLNode node)
    {
        this._actions ~= PipelineAction(action, node);
        return this;
    }

    PipelineBuilder imports(string assetName, string alias_ = null)
    {
        import std.typecons : nullable;
        this._imports ~= (alias_ is null) ? PipelineImport(assetName) : PipelineImport(assetName, nullable(alias_));
        return this;
    }

    PipelineBuilder exports(string exportName)
    {
        this._export = exportName;
        return this;
    }

    Pipeline build()
    {
        return new Pipeline(this._core, this._imports, this._actions, this._export);
    }
}