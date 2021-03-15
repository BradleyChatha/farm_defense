module common.packageccore;

import std.exception : enforce;
import std.path;
import sdlite;
import engine.core.logging;
import common, interfaces;

enum AssetLoadingType
{
    ERROR,
    alreadyLoaded,
    usesPipeline,
    usesImporter
}

struct AssetGraphNode
{
    IAsset asset;
    AssetLoadingType loadType;

    IAssetExporter exporter;
    SDLNode exporterNode;

    union
    {
        Pipeline pipeline;

        struct 
        {
            IAssetImporter importer;
            SDLNode node;
            PathResolver baseDir;
        }
    }

    this(Pipeline pipeline)
    {
        this.pipeline = pipeline;
        this.loadType = AssetLoadingType.usesPipeline;
    }

    this(IAssetImporter importer, SDLNode node, PathResolver baseDir)
    {
        this.importer = importer;
        this.node = node;
        this.baseDir = baseDir;
        this.loadType = AssetLoadingType.usesImporter;
    }
}

final class PackagecCore
{
    alias GraphT = DependencyGraph!AssetGraphNode;

    private
    {
        IPackageLoader[string]  _packageLoadersByExtension; // e.g. .sdl
        IAssetImporter[string]  _assetImportersByName;      // e.g. use:file -> ["file"]
        IAssetExporter[string]  _assetExportersByName;      // e.g. output:texture -> ["texture"]
        IPipelineAction[string] _actionsByName;             // e.g. "texture:stitch"

        GraphT                  _assetGraph;
        PackageInfo[string]     _packagesByName;
        PathResolver            _buildDirResolver;
    }

    package this(IPackageLoader[string] loaders, IAssetImporter[string] importers, IAssetExporter[string] exporters, IPipelineAction[string] actions)
    {
        this._packageLoadersByExtension = loaders;
        this._assetImportersByName = importers;
        this._assetExportersByName = exporters;
        this._actionsByName = actions;
        this._buildDirResolver = PathResolver("./assets/packages/build/");

        logfDebug("Loaders: %s", loaders);
        logfDebug("Importers: %s", importers);
        logfDebug("Actions: %s", actions);
    }

    IAsset getAssetByName(string name)
    {
        return this._assetGraph.addOrGetByName(name).value.get.asset;
    }

    IAssetImporter getImporterByName(string name)
    {
        scope ptr = (name in this._assetImportersByName);
        enforce(ptr !is null, "Importer '"~name~"' does not exist.");

        return *ptr;
    }

    IAssetExporter getExporterByName(string name)
    {
        scope ptr = (name in this._assetExportersByName);
        enforce(ptr !is null, "Exporter '"~name~"' does not exist.");

        return *ptr;
    }

    IPipelineAction getActionByName(string name)
    {
        scope ptr = (name in this._actionsByName);
        enforce(ptr !is null, "Action '"~name~"' does not exist.");

        return *ptr;
    }

    void loadPackageFromFile(string file)
    {
        logfInfo("Loading package from file: "~file);
        scope loaderPtr = (file.extension in this._packageLoadersByExtension);
        enforce(loaderPtr !is null, "No loader found for file: "~file);

        auto loader = *loaderPtr;
        auto info = loader.fromFile(file, this, &this._assetGraph);

        synchronized
        {
            enforce((info.name in this._packagesByName) is null, "Package "~info.name~" already exists!");
            this._packagesByName[info.name] = info;
        }

        logfInfo("Successful loading of package %s from file %s.", info.name, file);
    }

    void executePipelines()
    {
        import engine.vulkan;

        logfInfo("Executing pipelines for loaded packages.");

        this._assetGraph.enforceGraphIsValid();
        auto nodes = this._assetGraph.topSort();

        foreach(node; nodes)
        {
            auto info = node.value.get;

            final switch(info.loadType)
            {
                case AssetLoadingType.ERROR: assert(false);
                case AssetLoadingType.alreadyLoaded: break;
                case AssetLoadingType.usesImporter:
                    info.asset = info.importer.importAsset(info.node, info.baseDir);
                    break;
                case AssetLoadingType.usesPipeline:
                    info.asset = info.pipeline.execute();
                    break;
            }

            info.loadType = AssetLoadingType.alreadyLoaded;
            node.value = info;

            if(info.exporter !is null)
                info.exporter.exportAsset(info.asset, info.exporterNode, this._buildDirResolver);
        }
    }

    string assetGraphToString()
    {
        import std.string : replace;
        return this._assetGraph.toString().replace("\\", "/"); // T_T Wondows pls.
    }
}