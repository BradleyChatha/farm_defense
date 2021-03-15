module interfaces.iassetimporter;

import sdlite;
import common, interfaces;

// Even if I support more formats than SDL, it'll be internally converted into an SdlTag since it is a *very* convenient data structure.
interface IAssetImporter
{
    IAsset importAsset(SDLNode node, PathResolver baseDir);
    string getDependencyName(SDLNode node, PathResolver baseDir);
}