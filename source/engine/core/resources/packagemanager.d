module engine.core.resources.packagemanager;

import engine.core.resources, engine.util;

final class PackageManager
{
    private
    {
        struct ResourceInfo
        {
            IResource resource;
            bool isAlias;
        }

        IPackageLoader[string]    _packageLoadersByTypeName;
        IResourceLoader[TypeInfo] _resourceLoadersByLoadInfoT;
        Package[string]           _packagesByName;
        ResourceInfo[string]      _resourcesByName;

        Result!void postProcessPackage(Package pkg)
        {
            if(pkg.name in this._packagesByName)
                return Result!void.failure("Package '"~pkg.name~"' already exists.");

            this._packagesByName[pkg.name] = pkg;

            foreach(resource; pkg.resources)
            {
                if(resource.resourceName in this._resourcesByName)
                    return Result!void.failure("Resource '"~resource.resourceName~"' already exists.");

                this._resourcesByName[resource.resourceName] = ResourceInfo(resource, false);
            }

            foreach(alias_, original; pkg.aliases)
            {
                if(alias_ in this._resourcesByName)
                    return Result!void.failure("Resource '"~alias_~"' already exists. [Alias]");

                this._resourcesByName[alias_] = this._resourcesByName[original];
                this._resourcesByName[alias_].isAlias = true;
            }

            return Result!void.ok;
        }
    }

    debug void debugSetResource(string name, IResource value)
    {
        this._resourcesByName[name] = ResourceInfo(value, false);
    }

    void register(string typeName, IPackageLoader loader)
    {
        this._packageLoadersByTypeName[typeName] = loader;
    }

    void register(IResourceLoader loader)
    {
        this._resourceLoadersByLoadInfoT[loader.loadInfoT] = loader;
    }

    ResourceT getOrNull(ResourceT : IResource = IResource)(string name)
    {
        auto ptr = (name in this._resourcesByName);
        if(ptr is null)
            return null;

        return cast(ResourceT)(ptr.resource);
    }

    Result!void loadFromFile(string fileName, string typeName)
    {
        import std.path : absolutePath;
        import std.file : exists;

        auto packagePtr = (typeName in this._packageLoadersByTypeName);
        if(packagePtr is null)
            return Result!void.failure("No loader for package type: "~typeName);

        auto path = fileName.absolutePath;
        if(!path.exists && fileName != "UNITTEST")
            return Result!void.failure("No file exists at path: "~path);

        auto taskResult = packagePtr.loadFromFile(path);
        if(!taskResult.isOk)
            return Result!void.failure(taskResult.error);

        auto context = PackageLoadContext(this, taskResult.value);
        auto packageResult = context.process();
        if(!packageResult.isOk)
            return Result!void.failure(packageResult.error);

        auto processResult = this.postProcessPackage(packageResult.value);
        if(!processResult.isOk)
            return processResult;

        return Result!void.ok;
    }

    package Result!IResourceLoader getLoaderForLoadInfoT(TypeInfo loadInfoT)
    {
        auto ptr = (loadInfoT in this._resourceLoadersByLoadInfoT);
        if(ptr is null)
            return Result!IResourceLoader.failure("No loader for type: "~loadInfoT.toString());

        return Result!IResourceLoader.ok(*ptr);
    }
}