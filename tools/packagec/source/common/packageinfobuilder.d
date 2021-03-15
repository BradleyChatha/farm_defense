module common.packageinfobuilder;

import interfaces;
import common.packageinfo;

final class PackageInfoBuilder
{
    private
    {
        PackageInfo _info;
    }

    this()
    {
        this._info = new PackageInfo();
    }

    PackageInfoBuilder hasName(string name)
    {
        this._info.name = name;
        return this;
    }

    PackageInfoBuilder hasDescription(string description)
    {
        this._info.description = description;
        return this;
    }

    PackageInfo build()
    {
        import std.exception : enforce;
        enforce(this._info.name !is null, "No name was given to this package.");
        enforce(this._info.description !is null, "Package "~this._info.name~" needs a description.");
        return this._info;
    }
}