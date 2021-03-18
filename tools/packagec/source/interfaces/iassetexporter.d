module interfaces.iassetexporter;

import sdlite;
import common, interfaces;

interface IAssetExporter
{
    void exportAsset(IAsset asset, SDLNode node, PathResolver buildDirResolver, PackageFileList files);
}