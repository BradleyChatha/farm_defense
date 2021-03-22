module implementations.rawshadermoduleasset;

import engine.util;
import common, interfaces;

class RawShaderModuleAsset : IRawShaderModuleAsset
{
    private ubyte[] _data;
    private SpirvShaderModuleType _type;
    private string _name;
    private SpirvReflection _reflection;

    this(ubyte[] data, SpirvShaderModuleType type, string name, SpirvReflection reflection)
    {
        this._data = data;
        this._type = type;
        this._name = name;
        this._reflection = reflection;
    }

    @property
    override string name() const
    {
        return this._name;
    }

    @property
    override protected void name(string value)
    {
        this._name = value;
    }

    @property
    override ubyte[] bytes()
    {
        return this._data;
    }

    @property
    override SpirvShaderModuleType type() const
    {
        return this._type;
    }

    @property
    override SpirvReflection reflection()
    {
        return this._reflection;
    }
}