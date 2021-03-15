module common.packageccorebuilder;

import std.exception : enforce;
import common, interfaces;

final class PackagecCoreBuilder
{
    private
    {
        IPackageLoader[string]  _packageLoadersByExtension;
        IAssetImporter[string]  _assetImportersByName;
        IAssetExporter[string]  _assetExportersByName;
        IPipelineAction[string] _actionsByName;

        PackagecCoreBuilder addUnique(T)(string key, T value)
        in(value !is null)
        in(key !is null)
        {
            static if(is(T == IPackageLoader))
                alias Store = _packageLoadersByExtension;
            else static if(is(T == IAssetImporter))
                alias Store = _assetImportersByName;
            else static if(is(T == IPipelineAction))
                alias Store = _actionsByName;
            else static if(is(T == IAssetExporter))
                alias Store = _assetExportersByName;
            else static assert(false);

            enforce((key in Store) is null, T.stringof~" "~key~" already exists.");
            Store[key] = value;
            return this;
        }
    }

    PackagecCoreBuilder withLoader(string extension, IPackageLoader loader)
    in(extension !is null && extension[0] == '.', "Extensions should start with a dot.")
    {
        return this.addUnique(extension, loader);
    }

    PackagecCoreBuilder withImporter(string typeName, IAssetImporter importer)
    {
        return this.addUnique(typeName, importer);
    }

    PackagecCoreBuilder withExporter(string typeName, IAssetExporter exporter)
    {
        return this.addUnique(typeName, exporter);
    }

    PackagecCoreBuilder withAction(string name, IPipelineAction action)
    {
        return this.addUnique(name, action);
    }

    PackagecCore build()
    {
        return new PackagecCore(
            this._packageLoadersByExtension,
            this._assetImportersByName,
            this._assetExportersByName,
            this._actionsByName
        );
    }
}