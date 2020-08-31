module game.common.maths;

public import gfm.math;
import erupted  : VkExtent2D;

alias vec2u = Vector!(uint, 2);

VkExtent2D toExtent(Vect)(Vect vect)
{
    import std.conv : to;

    return VkExtent2D(vect.x.to!uint, vect.y.to!uint);
}

/++ 
 + Handles the following edge cases:
 +      amount = 0:                               returns 0
 +      amount not evenly divisible by magnitude: returns amount / magnitude + 1
 +      amount evenly divisible by magnitude:     returns amount / magnitude
 + ++/
@safe @nogc
T amountDivideMagnitudeRounded(T)(T amount, T magnitude) nothrow pure
{
    assert(magnitude != 0, "Divide by zero");
    return (amount / magnitude) + !!(amount % magnitude);
}
///
unittest
{
    assert(amountDivideMagnitudeRounded(0,  32) == 0);
    assert(amountDivideMagnitudeRounded(20, 32) == 1);
    assert(amountDivideMagnitudeRounded(32, 32) == 1);
    assert(amountDivideMagnitudeRounded(33, 32) == 2);
}