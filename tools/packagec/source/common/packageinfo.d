module common.packageinfo;

import std.exception : enforce;
import interfaces;

final class PackageInfo
{
    private
    {
        string _name;
        string _description;
    }

    @property
    string name() const
    {
        return this._name;
    }

    @property
    string description() const
    {
        return this._description;
    }

    @property
    package void name(string value)
    in(value !is null)
    {
        this._name = value;
    }

    @property
    package void description(string value)
    in(value !is null)
    {
        this._description = value;
    }
}