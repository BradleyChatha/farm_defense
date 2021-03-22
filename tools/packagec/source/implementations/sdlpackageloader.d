module implementations.sdlpackageloader;

import std.conv : to;
import std.exception : enforce;
import std.file : readText;
import sdlite;
import engine.core.logging;
import common, interfaces;

final class SdlPackageLoader : IPackageLoader
{
    PackageInfo fromFile(string file, PackagecCore core, PackagecCore.GraphT* graph)
    {
        auto builder = new PackageInfoBuilder();
        const resolver = PathResolver(file);

        void onNode(SDLNode node)
        {
            switch(node.qualifiedName)
            {
                case "name":
                    builder.hasName(node.values[0].textValue);
                    break;

                case "description":
                    builder.hasDescription(node.values[0].textValue);
                    break;

                case "include":
                    this.includeFile(resolver.resolve(node.values[0].textValue), core, graph, builder);
                    break;

                default: throw new Exception("Unexpected node name '"~node.qualifiedName~"' in package file: "~file);
            }
        }

        parseSDLDocument!onNode(file.readText, file);
        return builder.build();
    }

    private void includeFile(string file, PackagecCore core, PackagecCore.GraphT* graph, PackageInfoBuilder builder)
    {
        logfDebug("Handling included file: %s", file);
        void onNode(SDLNode node)
        {
            switch(node.qualifiedName)
            {
                case "define":
                    this.onDefine(node, core, graph, PathResolver(file));
                    break;

                default: throw new Exception("Unexpected node name '"~node.qualifiedName~"' in asset file: "~file);
            }
        }

        parseSDLDocument!onNode(file.readText, file);
    }

    private void onDefine(SDLNode node, PackagecCore core, PackagecCore.GraphT* graph, PathResolver baseDir)
    {
        const assetName = node.values[0].textValue;
        logfDebug("Handling definition for asset: %s", assetName);

        enforce(graph.addOrGetByName(assetName).value.isNull, "Asset "~assetName~" has already been defined.");

        auto pipelineBuilder = new PipelineBuilder(core, baseDir);
        pipelineBuilder.called(assetName);

        AssetGraphNode nodeValue;
        
        foreach(child; node.children)
        {
            if(child.namespace == "use")
            {
                // Special case: We're referring to another asset, so we don't need to assign an importer to it.
                if(child.name == "asset")
                {
                    const depName = child.values[0].textValue;
                    graph.addDependency(assetName, depName);
                    pipelineBuilder.imports(depName, child.getAttribute("alias", SDLValue(depName)).textValue);
                    continue;
                }

                const importerName = child.name;
                auto importer = core.getImporterByName(importerName);
                const depName = importer.getDependencyName(child, baseDir);

                auto nodes = graph.addDependency(assetName, depName);
                pipelineBuilder.imports(depName, child.getAttribute("alias", SDLValue(cast(string)null)).textValue);

                if(nodes[1].value.isNull)
                    nodes[1].value = AssetGraphNode(importer, child, baseDir);

                graph.addDependency(depName, DEPENDENCY_ROOT_NODE_NAME);
            }
            else if(child.qualifiedName == "pipeline")
            {
                foreach(pipelineChild; child.children)
                {
                    auto action = core.getActionByName(pipelineChild.qualifiedName);
                    pipelineBuilder.then(action, pipelineChild);
                }
            }
            else if(child.qualifiedName == "export")
            {
                pipelineBuilder.exports(child.values[0].textValue);
            }
            else if(child.namespace == "output")
            {
                nodeValue.exporterNode = child;
                nodeValue.exporter = core.getExporterByName(child.name);
            }
            else
                throw new Exception("Unexpected node '"~child.qualifiedName~"' when parsing definition for asset "~assetName);
        }
        
        nodeValue.pipeline = pipelineBuilder.build();
        nodeValue.loadType = AssetLoadingType.usesPipeline;
        graph.addOrGetByName(assetName).value = nodeValue;
    }
}