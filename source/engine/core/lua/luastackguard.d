module engine.core.lua.luastackguard;

import engine.core.lua;

/++
 + Debugging struct used to ensure that, upon scope exit, the stack for a given LuaState is
 + of a certain size.
 + ++/
struct LuaStackGuard
{
    @disable this(this){}
    @disable this();

    private int _startSize;
    private LuaState* _state;
    int delta;

    this(ref LuaState state, int delta = 0)
    {
        this._state = &state;
        this.delta = delta;
        this._startSize = state.getTop();
    }

    ~this()
    {
        if(this._state !is null)
        {
            import std.format;
            const stackSize = (*this._state).getTop();
            const expected  = (this._startSize + this.delta);
            assert(stackSize == expected, 
                "Expected stack size to be %s (start %s with delta %s) but instead it's %s."
                .format(expected, this._startSize, this.delta, stackSize)
            );
        }
    }
}