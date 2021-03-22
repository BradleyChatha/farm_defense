module engine.graphics.materialbuilder;

import engine.core, engine.graphics;

private enum ShaderSource
{
    ERROR,
    bytes
}

private struct Shader
{
    ShaderSource source;
    union
    { 
        ubyte[] asBytes;
    }
}

struct MaterialBuilder
{
    private
    {
        MaterialRenderer _renderer;
        Shader _vertexShader;
        Shader _fragmentShader;
    }

    MaterialBuilder forRenderer(MaterialRenderer renderer)
    {
        this._renderer = renderer;
        return this;
    }

    MaterialBuilder withVertexShader(ubyte[] fromBytes)
    {
        this._vertexShader.asBytes = fromBytes;
        this._vertexShader.source = ShaderSource.bytes;
        return this;
    }

    MaterialBuilder withFragmentShader(ubyte[] fromBytes)
    {
        this._fragmentShader.asBytes = fromBytes;
        this._fragmentShader.source = ShaderSource.bytes;
        return this;
    }

    Material build()
    {
        return new Material();
    }
}