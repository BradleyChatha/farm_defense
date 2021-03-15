module engine.util.maths;

public import 
    gfm.math;

alias vec2u = Vector!(uint, 2);
alias box2u = Box!(uint, 2);

/// Returns: A 2D rectangle with point `x`,`y`, `width` and `height`.
box2u rectangleu(uint x, uint y, uint width, uint height) pure nothrow @nogc
{
    return box2u(x, y, x + width, y + height);
}