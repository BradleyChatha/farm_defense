module game.common.interfaces;

import std.typecons : Flag;
import game.common;

alias AddHooks = Flag!"addHooks";

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

interface ITransformable(AddHooks ShouldAddHooks)
{
    @property @nogc
    ref Transform transform() nothrow;

    static if(ShouldAddHooks)
    void onTransformChanged();

    final void move(vec2f amount)
    {
        this.position = this.position + amount;
    }
    final void move(float x, float y){ this.move(vec2f(x, y)); }

    @property
    final void position(vec2f pos)
    {
        this.transform.translation = pos;
        this.transform.markDirty();

        static if(ShouldAddHooks) this.onTransformChanged();
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