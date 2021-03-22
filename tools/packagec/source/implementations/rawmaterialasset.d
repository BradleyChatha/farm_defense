module implementations.rawmaterialasset;

import engine.graphics;
import common, interfaces;

final class RawMaterialAsset : IMaterialAsset
{
    private string _name;
    private IRawShaderModuleAsset _vertex;
    private IRawShaderModuleAsset _fragment;
    private MaterialRenderer _renderer;

    this(string name, IRawShaderModuleAsset vert, IRawShaderModuleAsset frag, MaterialRenderer rend)
    {
        this._name = name;
        this._vertex = vert;
        this._fragment = frag;
        this._renderer = rend;
    }

    @property
    string name() const
    {
        return this._name;
    }

    @property
    protected void name(string name)
    {
        this._name = name;
    }

    @property
    IRawShaderModuleAsset vertexShader()
    {
        return this._vertex;
    }

    @property
    IRawShaderModuleAsset fragmentShader()
    {
        return this._fragment;
    }

    @property
    MaterialRenderer renderer()
    {
        return this._renderer;
    }
}