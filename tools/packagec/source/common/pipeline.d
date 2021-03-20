module common.pipeline;

import std.typecons : Nullable;
import sdlite;
import engine.vulkan, engine.util;
import common, interfaces;

struct PipelineImport
{
    string assetName;
    Nullable!string alias_;
}

struct PipelineAction
{
    IPipelineAction action;
    SDLNode node;
}

final class Pipeline
{
    private
    {
        PackagecCore _core;
        PipelineImport[] _imports;
        PipelineAction[] _actions;
        SubmitPipeline _pipeline;
        string _exportName;
        string _definitionName;
    }

    package this(PackagecCore core, PipelineImport[] imports, PipelineAction[] actions, string exportName, string defineName)
    {
        this._core = core;
        this._imports = imports;
        this._exportName = exportName;
        this._definitionName = defineName;
        this._actions = actions;
        
        auto builder = new SubmitPipelineBuilder();
        foreach(action; actions)
        {
            // A bit of a hacky way to pass data through, but this is a limitation of the static design of SubmitPipelineBuilder.
            builder.then((context)
            {
                auto pipelineContext = context.userContext.as!PipelineContext;
                pipelineContext.popStageSdlNode();
            });
            action.action.appendToPipeline(builder);
        }
        this._pipeline = builder.build();
    }

    IAsset execute()
    {
        import std.conv : to;

        auto context = new PipelineContext(this._core);
        foreach(import_; this._imports)
            context.setAsset(this._core.getAssetByName(import_.assetName), import_.alias_.get(null));
        foreach(action; this._actions)
            context.appendStageSdlNode(action.node);

        auto execution = submitPipeline(this._pipeline, copyToBorrowedTypedPointer(context));
        scope(exit) submitFree(execution);
        submitExecute(SubmitPipelineExecutionType.runToEnd, execution);

        context.cleanup();
        auto asset = context.getAsset(this._exportName);
        asset.changeName(this._definitionName);
        return asset;
    }
}