module engine.core.interfaces.disposable;

interface IDisposable
{
    void dispose();
    bool isDisposed();
}

mixin template IDisposableBoilerplate()
{
    private bool _isDisposed;

    static assert(__traits(hasMember, typeof(this), "disposeImpl"), "Please add a function called `disposeImpl`.");

    void dispose()
    {
        if(this._isDisposed)
            return;

        this._isDisposed = true;
        this.disposeImpl();
    }

    bool isDisposed()
    {
        return this._isDisposed;
    }
}

enum isDisposable(T) = __traits(hasMember, T, "dispose") && __traits(hasMember, T, "isDisposed");