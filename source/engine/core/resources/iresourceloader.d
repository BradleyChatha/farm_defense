module engine.core.resources.iresourceloader;

import engine.core.resources, engine.util;

interface IResourceLoader
{
    Result!IResource loadFromLoadInfo(ResourceLoadInfo loadInfo, ref PackageLoadContext context);
    TypeInfo loadInfoT();
}

mixin template IResourceLoaderBoilerplate(LoadInfoT)
{
    override TypeInfo loadInfoT() { return typeid(LoadInfoT); }
}