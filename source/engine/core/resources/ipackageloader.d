module engine.core.resources.ipackageloader;

import engine.core.resources, engine.util;

interface IPackageLoader
{
    Result!(ResourceLoadInfo[]) loadFromFile(string absolutePath);
}