module game.common.interfaces;

import game.common;

interface IDisposable
{
    void dispose();
    bool isDisposed();
}

mixin template IDisposableBoilerplate()
{
    private bool _isDisposed;
    public void dispose()
    {
        if(this._isDisposed)
            return;

        this.onDispose();
    }
    public bool isDisposed()
    {
        return this._isDisposed;
    }
}

interface ITransformable
{
    @property @nogc
    ref Transform transform() nothrow;

    final void move(vec2f amount)
    {
        this.transform.translation += amount;
        this.transform.markDirty();
    }
    final void move(float x, float y){ this.move(vec2f(x, y)); }

    @property
    final void position(vec2f pos)
    {
        this.transform.translation = pos;
        this.transform.markDirty();
    }

    @property
    final vec2f position()
    {
        return this.transform.translation;
    }
}

mixin template ITransformableBoilerplate()
{
    private Transform _transform;

    @property @nogc
    ref Transform transform() nothrow
    {
        return this._transform;
    }
}