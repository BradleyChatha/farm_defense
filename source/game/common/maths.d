module game.common.maths;

public import gfm.math;
import erupted  : VkExtent2D;

alias vec2u = Vector!(uint, 2);

VkExtent2D toExtent(Vect)(Vect vect)
{
    import std.conv : to;

    return VkExtent2D(vect.x.to!uint, vect.y.to!uint);
}