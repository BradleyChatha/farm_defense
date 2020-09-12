module game.common.interfaces;

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
    
}