module engine.core.lua.luascriptresource;

import engine.core, engine.util;

final class LuaScriptResource : IResource
{
    mixin IResourceBoilerplate;

    private
    {
        string _code;
    }

    this(string code)
    {
        this._code = code;
    }

    @property
    string code() const
    {
        return this._code;
    }
}