module common.pipelinecontext;

import std.exception : enforce;
import std.format : format;
import engine.vulkan, engine.core.logging;
import sdlite;
import common, interfaces;

alias PipelineCleanupFunc = void delegate();

final class PipelineContext
{
    private
    {
        PackagecCore          _core;
        IAsset[string]        _assets;
        SDLNode[]             _stageNodes;
        SDLNode               _currentNode;
        PipelineCleanupFunc[] _cleanupFuncs;
    }

    package this(PackagecCore core)
    {
        this._core = core;
    }

    package void appendStageSdlNode(SDLNode node)
    {
        this._stageNodes ~= node;
    }
    
    package void popStageSdlNode()
    {
        assert(this._stageNodes.length > 0, "Empty node list");
        this._currentNode = this._stageNodes[0];
        this._stageNodes = this._stageNodes[1..$];
    }

    void onCleanup(PipelineCleanupFunc func)
    {
        this._cleanupFuncs ~= func;
    }

    void cleanup()
    {
        logfTrace("Cleaning up pipeline assets.");
        foreach(func; this._cleanupFuncs)
            func();
        this._cleanupFuncs = null;
    }

    void setAsset(IAsset asset, string alias_)
    {
        const key = (alias_ is null) ? asset.name : alias_;
        logfTrace("Adding asset '%s' of type %s to context.", key, asset);
        this._assets[key] = asset;
    }

    IAsset getAsset(string name)
    {
        enforce(name in this._assets, "Asset not found: "~name);
        return this._assets[name];
    }

    AssetT getAsset(AssetT : IAsset)(string name)
    {
        enforce(name in this._assets, "Asset not found: "~name);
        auto asset = this._assets[name];
        auto casted = cast(AssetT)asset;
        enforce(casted !is null, "Could not convert asset '%s' of type %s to type %s.".format(name, asset, AssetT.stringof));
        return casted;
    }

    @property
    SDLNode currentStageNode()
    {
        return this._currentNode;
    }
}