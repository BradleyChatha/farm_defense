module game.common.maths;

public import gfm.math;
public import std.math;
public import std.algorithm : max;
import erupted  : VkExtent2D;

import game.graphics;

alias vec2u = Vector!(uint, 2);

VkExtent2D toExtent(Vect)(Vect vect)
{
    import std.conv : to;

    return VkExtent2D(vect.x.to!uint, vect.y.to!uint);
}

auto toIndex(Vect)(Vect vect, size_t columnCount)
{
    return (vect.y * columnCount) + vect.x;
}

bool isNaN(Vect)(Vect vect)
{
    import std.math : isNaN;
    return vect.x.isNaN && vect.y.isNaN;
}

bool isNaN(box2f box)
{
    return box.min.isNaN && box.max.isNaN;
}

Color mix(Color from, Color to, float amount)
{
    Vector!(ubyte, 4) fromVect;
    Vector!(ubyte, 4) toVect;
    fromVect.v = from.components;
    toVect.v = to.components;

    const resultVect = fromVect.mix(toVect, amount);
    Color result;
    result.components = resultVect.v;

    return result;
}

Vect mix(Vect)(Vect from, Vect to, float amount)
{
    Vect result;
    foreach(i; 0..from.v.length)
    {
        const x = cast(float)from.v[i];
        const y = cast(float)to.v[i];
        result.v[i] = cast(typeof(from.v[0]))(x * (1 - amount) + y * amount);
    }

    return result;
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

struct Transform
{
    private transformMat4f _matrix = transformMat4f.identity;
    private bool  _dirty      = true;
    vec2f         translation = vec2f(0);
    vec2f         origin      = vec2f(0);
    AngleDegrees  rotation    = AngleDegrees(0);

    void markDirty()
    {
        this._dirty = true;
    }

    @property
    bool isDirty()
    {
        return this._dirty;
    }

    @property @safe @nogc
    transformMat4f matrix() nothrow pure
    {
        if(this._dirty)
        {
            this._matrix = transformMat4f.identity;
            this._matrix.translate(-this.origin.x, -this.origin.y, 0);
            this._matrix.scale(1, 1, 1);
            this._matrix.rotateZ(this.rotation.degrees);
            this._matrix.translate(this.origin.x, this.origin.y, 0);
            this._matrix.translate(this.translation.x, this.translation.y, 0);

            this._dirty = false;
        }

        return this._matrix;
    }
}

///
enum AngleType
{
    ///
    Degrees,

    ///
    Radians
}

/++
 + A struct to easily convert an angle between Radians and Degrees.
 +
 + If a conversion does not need to take place (e.g Radians -> Radians) then this struct is zero-cost.
 + ++/
struct Angle(AngleType type)
{
    import std.math : PI;
    
    /// The angle (This struct is `alias this`ed to this variable).
    float angle;
    alias angle this;

    ///
    @property @safe @nogc
    AngleDegrees degrees() nothrow pure const
    {
        static if(type == AngleType.Degrees)
            return this;
        else
            return AngleDegrees(this * (180 / PI));
    }

    ///
    @property @safe @nogc
    AngleRadians radians() nothrow pure const
    {
        static if(type == AngleType.Radians)
            return this;
        else
            return AngleRadians(this * (PI / 180));
    }

    ///
    @safe @nogc
    void opAssign(AngleDegrees rhs) nothrow pure
    {
        static if(type == AngleType.Degrees)
            this.angle = rhs.degrees;
        else
            this.angle = rhs.radians;
    }

    ///
    @safe @nogc
    void opAssign(AngleRadians rhs) nothrow pure
    {
        static if(type == AngleType.Radians)
            this.angle = rhs.radians;
        else
            this.angle = rhs.degrees;
    }
}

///
alias AngleDegrees = Angle!(AngleType.Degrees);
///
alias AngleRadians = Angle!(AngleType.Radians);

// Since GFM's matrix is so shit *that not even translation works*, here's JArena's old Matrix struct.
struct Matrix(T, size_t Columns_, size_t Rows_)
{
    static assert(Columns >= 2 && Columns <= 4, "There can only be 2, 3, or 4 columns.");
    static assert(Rows >= 2    && Rows <= 4,    "There can only be 2, 3, or 4 rows.");

    alias ThisType = typeof(this);
    alias ColumnT  = Vector!(T, Rows);
    alias Columns  = Columns_;
    alias Rows     = Rows_;

    ColumnT[Columns] columns; // Column major

    // #############
    // # FUNCTIONS #
    // #############
    public
    {
        pragma(inline, true) @safe @nogc
        void clear(T value) nothrow pure
        {
            foreach(ref column; this.columns)
                column = ColumnT(value);
        }

        @property @safe @nogc
        static ThisType identity() nothrow pure
        {
            ThisType data;
            data.clear(0);
            foreach(i; 0..(Columns < Rows) ? Columns : Rows)
                data.columns[i].v[i] = 1;

            return data;
        }
        ///
        unittest
        {
            assert(mat4.identity.columns ==
            [
                vec4(1, 0, 0, 0),
                vec4(0, 1, 0, 0),
                vec4(0, 0, 1, 0),
                vec4(0, 0, 0, 1)
            ]);
        }

        @safe @nogc
        T determinant() nothrow const pure
        {
            static if(Columns == 4)
            {
                auto c0 = this.columns[0].v;
                auto c1 = this.columns[1].v;
                auto c2 = this.columns[2].v;
                auto c3 = this.columns[3].v;
                return
                  c0[3] * c1[2] * c2[1] * c3[0] - c0[2] * c1[3] * c2[1] * c3[0]
				- c0[3] * c1[1] * c2[2] * c3[0] + c0[1] * c1[3] * c2[2] * c3[0]
				+ c0[2] * c1[1] * c2[3] * c3[0] - c0[1] * c1[2] * c2[3] * c3[0]
				- c0[3] * c1[2] * c2[0] * c3[1] + c0[2] * c1[3] * c2[0] * c3[1]
				+ c0[3] * c1[0] * c2[2] * c3[1] - c0[0] * c1[3] * c2[2] * c3[1]
				- c0[2] * c1[0] * c2[3] * c3[1] + c0[0] * c1[2] * c2[3] * c3[1]
				+ c0[3] * c1[1] * c2[0] * c3[2] - c0[1] * c1[3] * c2[0] * c3[2]
				- c0[3] * c1[0] * c2[1] * c3[2] + c0[0] * c1[3] * c2[1] * c3[2]
				+ c0[1] * c1[0] * c2[3] * c3[2] - c0[0] * c1[1] * c2[3] * c3[2]
				- c0[2] * c1[1] * c2[0] * c3[3] + c0[1] * c1[2] * c2[0] * c3[3]
				+ c0[2] * c1[0] * c2[1] * c3[3] - c0[0] * c1[2] * c2[1] * c3[3]
                - c0[1] * c1[0] * c2[2] * c3[3] + c0[0] * c1[1] * c2[2] * c3[3];
            }
            
            assert(false);
        }
        ///
        unittest
        {
	        imat4 mat;
            mat.columns = [ ivec4(  1.0,   2.0,   3.0,   4.0),
					        ivec4(- 2.0,   1.0,   5.0, - 2.0),
					        ivec4(  2.0, - 1.0,   7.0,   1.0),
					        ivec4(  3.0, - 3.0,   2.0,   0.0) ];
            
            assert(mat.determinant == -8.0);
        }

        @safe @nogc
        ThisType inverted() nothrow const pure
        {
            auto d = this.determinant;

            static if(Columns == 4)
            {
                auto c0 = this.columns[0].v;
                auto c1 = this.columns[1].v;
                auto c2 = this.columns[2].v;
                auto c3 = this.columns[3].v;

                ThisType data;
                data.columns =
                [
				ColumnT(( c1[ 1 ] * c2[ 2 ] * c3[ 3 ] + c1[ 2 ] * c2[ 3 ] * c3[ 1 ] + c1[ 3 ] * c2[ 1 ] * c3[ 2 ]
						- c1[ 1 ] * c2[ 3 ] * c3[ 2 ] - c1[ 2 ] * c2[ 1 ] * c3[ 3 ] - c1[ 3 ] * c2[ 2 ] * c3[ 1 ] ) / d,
						( c0[ 1 ] * c2[ 3 ] * c3[ 2 ] + c0[ 2 ] * c2[ 1 ] * c3[ 3 ] + c0[ 3 ] * c2[ 2 ] * c3[ 1 ]
						- c0[ 1 ] * c2[ 2 ] * c3[ 3 ] - c0[ 2 ] * c2[ 3 ] * c3[ 1 ] - c0[ 3 ] * c2[ 1 ] * c3[ 2 ] ) / d,
						( c0[ 1 ] * c1[ 2 ] * c3[ 3 ] + c0[ 2 ] * c1[ 3 ] * c3[ 1 ] + c0[ 3 ] * c1[ 1 ] * c3[ 2 ]
						- c0[ 1 ] * c1[ 3 ] * c3[ 2 ] - c0[ 2 ] * c1[ 1 ] * c3[ 3 ] - c0[ 3 ] * c1[ 2 ] * c3[ 1 ] ) / d,
						( c0[ 1 ] * c1[ 3 ] * c2[ 2 ] + c0[ 2 ] * c1[ 1 ] * c2[ 3 ] + c0[ 3 ] * c1[ 2 ] * c2[ 1 ]
						- c0[ 1 ] * c1[ 2 ] * c2[ 3 ] - c0[ 2 ] * c1[ 3 ] * c2[ 1 ] - c0[ 3 ] * c1[ 1 ] * c2[ 2 ] ) / d ),
				ColumnT(( c1[ 0 ] * c2[ 3 ] * c3[ 2 ] + c1[ 2 ] * c2[ 0 ] * c3[ 3 ] + c1[ 3 ] * c2[ 2 ] * c3[ 0 ]
						- c1[ 0 ] * c2[ 2 ] * c3[ 3 ] - c1[ 2 ] * c2[ 3 ] * c3[ 0 ] - c1[ 3 ] * c2[ 0 ] * c3[ 2 ] ) / d,
						( c0[ 0 ] * c2[ 2 ] * c3[ 3 ] + c0[ 2 ] * c2[ 3 ] * c3[ 0 ] + c0[ 3 ] * c2[ 0 ] * c3[ 2 ]
						- c0[ 0 ] * c2[ 3 ] * c3[ 2 ] - c0[ 2 ] * c2[ 0 ] * c3[ 3 ] - c0[ 3 ] * c2[ 2 ] * c3[ 0 ] ) / d,
						( c0[ 0 ] * c1[ 3 ] * c3[ 2 ] + c0[ 2 ] * c1[ 0 ] * c3[ 3 ] + c0[ 3 ] * c1[ 2 ] * c3[ 0 ]
						- c0[ 0 ] * c1[ 2 ] * c3[ 3 ] - c0[ 2 ] * c1[ 3 ] * c3[ 0 ] - c0[ 3 ] * c1[ 0 ] * c3[ 2 ] ) / d,
						( c0[ 0 ] * c1[ 2 ] * c2[ 3 ] + c0[ 2 ] * c1[ 3 ] * c2[ 0 ] + c0[ 3 ] * c1[ 0 ] * c2[ 2 ]
						- c0[ 0 ] * c1[ 3 ] * c2[ 2 ] - c0[ 2 ] * c1[ 0 ] * c2[ 3 ] - c0[ 3 ] * c1[ 2 ] * c2[ 0 ] ) / d ),
				ColumnT(( c1[ 0 ] * c2[ 1 ] * c3[ 3 ] + c1[ 1 ] * c2[ 3 ] * c3[ 0 ] + c1[ 3 ] * c2[ 0 ] * c3[ 1 ]
						- c1[ 0 ] * c2[ 3 ] * c3[ 1 ] - c1[ 1 ] * c2[ 0 ] * c3[ 3 ] - c1[ 3 ] * c2[ 1 ] * c3[ 0 ] ) / d,
						( c0[ 0 ] * c2[ 3 ] * c3[ 1 ] + c0[ 1 ] * c2[ 0 ] * c3[ 3 ] + c0[ 3 ] * c2[ 1 ] * c3[ 0 ]
						- c0[ 0 ] * c2[ 1 ] * c3[ 3 ] - c0[ 1 ] * c2[ 3 ] * c3[ 0 ] - c0[ 3 ] * c2[ 0 ] * c3[ 1 ] ) / d,
						( c0[ 0 ] * c1[ 1 ] * c3[ 3 ] + c0[ 1 ] * c1[ 3 ] * c3[ 0 ] + c0[ 3 ] * c1[ 0 ] * c3[ 1 ]
						- c0[ 0 ] * c1[ 3 ] * c3[ 1 ] - c0[ 1 ] * c1[ 0 ] * c3[ 3 ] - c0[ 3 ] * c1[ 1 ] * c3[ 0 ] ) / d,
						( c0[ 0 ] * c1[ 3 ] * c2[ 1 ] + c0[ 1 ] * c1[ 0 ] * c2[ 3 ] + c0[ 3 ] * c1[ 1 ] * c2[ 0 ]
						- c0[ 0 ] * c1[ 1 ] * c2[ 3 ] - c0[ 1 ] * c1[ 3 ] * c2[ 0 ] - c0[ 3 ] * c1[ 0 ] * c2[ 1 ] ) / d ),
				ColumnT(( c1[ 0 ] * c2[ 2 ] * c3[ 1 ] + c1[ 1 ] * c2[ 0 ] * c3[ 2 ] + c1[ 2 ] * c2[ 1 ] * c3[ 0 ]
						- c1[ 0 ] * c2[ 1 ] * c3[ 2 ] - c1[ 1 ] * c2[ 2 ] * c3[ 0 ] - c1[ 2 ] * c2[ 0 ] * c3[ 1 ] ) / d,
						( c0[ 0 ] * c2[ 1 ] * c3[ 2 ] + c0[ 1 ] * c2[ 2 ] * c3[ 0 ] + c0[ 2 ] * c2[ 0 ] * c3[ 1 ]
						- c0[ 0 ] * c2[ 2 ] * c3[ 1 ] - c0[ 1 ] * c2[ 0 ] * c3[ 2 ] - c0[ 2 ] * c2[ 1 ] * c3[ 0 ] ) / d,
						( c0[ 0 ] * c1[ 2 ] * c3[ 1 ] + c0[ 1 ] * c1[ 0 ] * c3[ 2 ] + c0[ 2 ] * c1[ 1 ] * c3[ 0 ]
						- c0[ 0 ] * c1[ 1 ] * c3[ 2 ] - c0[ 1 ] * c1[ 2 ] * c3[ 0 ] - c0[ 2 ] * c1[ 0 ] * c3[ 1 ] ) / d,
						( c0[ 0 ] * c1[ 1 ] * c2[ 2 ] + c0[ 1 ] * c1[ 2 ] * c2[ 0 ] + c0[ 2 ] * c1[ 0 ] * c2[ 1 ]
						- c0[ 0 ] * c1[ 2 ] * c2[ 1 ] - c0[ 1 ] * c1[ 0 ] * c2[ 2 ] - c0[ 2 ] * c1[ 1 ] * c2[ 0 ] ) / d ) 
                ];
                    
                return data;
            }

            assert(false);
        }
        ///
        unittest
        {
            mat4 m4;
            m4.columns = [ vec4(   1.0f,   2.0f,   3.0f,   4.0f),
					       vec4( - 2.0f,   1.0f,   5.0f, - 2.0f),
					       vec4(   2.0f, - 1.0f,   7.0f,   1.0f),
					       vec4(   3.0f, - 3.0f,   2.0f,   0.0f) ];
            assert( m4.determinant == - 8.0f );
            assert( m4.inverted.columns ==  [vec4(   6.875f,   7.875f, - 11.75f,  11.125f),
                                             vec4(   6.625f,   7.625f, - 11.25f,  10.375f),
                                             vec4( - 0.375f, - 0.375f,    0.75f, - 0.625f),
                                             vec4( - 4.5f,   -   5.5f,     8.0f,   - 7.5f )]);
        }

        // ###############
        // # TRANSLATION #
        // ###############
        static if(Columns == 2) // Reminder: Only 2, 3, and 4 are valid values for Columns and Rows.
        {
        }
        else static if(Columns == 3)
        {

        }
        else static if(Columns == 4)
        {
            @safe @nogc
            static ThisType translation(T x, T y, T z) nothrow pure
            {
                ThisType data = ThisType.identity;
                data.columns[3].xyz = Vector!(T, 3)(x, y, z);
                return data;
            }

            @safe @nogc
            ThisType translate(T x, T y, T z) nothrow pure
            {
                this = ThisType.translation(x, y, z) * this;
                return this;
            }
        }

        // ############
        // # ROTATION #
        // ############
        static if(Columns >= 2)
        {
        }
        static if(Columns >= 3)
        {
            pragma(inline, true) @safe @nogc
            ThisType rotationZ(AngleDegrees degrees) nothrow pure
            {
                import std.math;

                ThisType data = ThisType.identity;
                data.columns[0].v[0] = cast(T)cos(degrees);
                data.columns[0].v[1] = cast(T)sin(degrees);
                data.columns[1].v[0] = cast(T)-sin(degrees);
                data.columns[1].v[1] = cast(T)cos(degrees);

                return data;
            }

            @safe @nogc
            ThisType rotateZ(AngleDegrees degrees) nothrow pure
            {
                this = ThisType.rotationZ(degrees) * this;
                return this;
            }
        }

        // #########
        // # SCALE #
        // #########
        static if(Columns >= 2)
        {
        }
        static if(Columns >= 3)
        {
            pragma(inline, true) @safe @nogc
            static ThisType scaling(T x, T y, T z) nothrow pure
            {
                ThisType data = ThisType.identity;
                data.columns[0].x = x;
                data.columns[1].y = y;
                data.columns[2].z = z;
                return data;
            }

            @safe @nogc
            ThisType scale(T x, T y, T z) nothrow pure
            {
                this = ThisType.scaling(x, y, z) * this;
                return this;
            }
        }
    }

    // ######################
    // # OPERATOR OVERLOADS #
    // ######################
    public
    {
        /// Matrix-Matrix addition and subtraction
        pragma(inline, true) @safe @nogc
        ThisType opBinary(string op)(ThisType mat) nothrow const pure
        if(op == "+" || op == "-")
        {
            ThisType data = this;
            foreach(i, ref column; data.columns)
                mixin("column "~op~"= mat.columns[i];");

            return data;
        }
        ///
        unittest
        {
            imat4 mat;
            mat.columns = 
            [
                ivec4(20, 0,  0, 10),
                ivec4(0, 40,  0, 20),
                ivec4(0,  0, 60, 30),
                ivec4(0,  0,  0, 90)
            ];

            assert((mat + mat.identity).columns == 
            [
                ivec4(21, 0,  0, 10),
                ivec4(0, 41,  0, 20),
                ivec4(0,  0, 61, 30),
                ivec4(0,  0,  0, 91)
            ]);
        }

        /// Matrix-Matrix multiplication
        @safe @nogc
        ThisType opBinary(string op)(ThisType rhs) nothrow const pure
        if(op == "*")
        {
            ThisType data = this;
            foreach(column; 0..Columns)
                data.columns[column] = this * rhs.columns[column];

            return data;
        }
        ///
        unittest
        {
            import std.conv : to;
            imat2 mat;
            mat.columns = 
            [
                ivec2(1, 2),
                ivec2(3, 4)
            ];

            imat2 mat_2;
            mat_2.columns =
            [
                ivec2(2, 4),
                ivec2(6, 8)
            ];

            assert((mat * mat_2).columns == 
            [
                ivec2(1*2+3*4, 2*2+4*4),
                ivec2(1*6+3*8, 2*6+4*8)
            ], (mat * mat_2).to!string);

            mat2 m2;
            m2.columns = [vec2(2.0f, 4.0f), vec2(6.0f, 8.0f)];
            assert(( m2 * m2 ).columns == [ vec2( 28.0f, 40.0f ), vec2( 60.0f, 88.0f ) ] );
        }

        /// Matrix-Vector multiplication
        @safe @nogc
        VectT opBinary(string op, VectT)(VectT rhs) nothrow const pure
        if(op == "*" && isVector!VectT)
        {
            static assert(VectT.v.length == Columns, "The Vector's v.length must be the same as this matrix's column count.");
            static assert(VectT.v.length == Rows, "Because I'm lazy, right now there is only support for when the Vector's v.length is the same as this matrix's row count.");
            
            auto data = VectT(0);

            // 1st component
            static if(VectT.v.length >= 1)
            {
                                        data.v[0] += this.columns[0].v[0] * rhs.v[0];
                                        data.v[0] += this.columns[1].v[0] * rhs.v[1];
                static if(Columns >= 3) data.v[0] += this.columns[2].v[0] * rhs.v[2];
                static if(Columns >= 4) data.v[0] += this.columns[3].v[0] * rhs.v[3];
            }

            // 2nd
            static if(VectT.v.length >= 2)
            {
                                        data.v[1] += this.columns[0].v[1] * rhs.v[0];
                                        data.v[1] += this.columns[1].v[1] * rhs.v[1];
                static if(Columns >= 3) data.v[1] += this.columns[2].v[1] * rhs.v[2];
                static if(Columns >= 4) data.v[1] += this.columns[3].v[1] * rhs.v[3];
            }

            // 3rd
            static if(VectT.v.length >= 3)
            {
                                        data.v[2] += this.columns[0].v[2] * rhs.v[0];
                                        data.v[2] += this.columns[1].v[2] * rhs.v[1];
                static if(Columns >= 3) data.v[2] += this.columns[2].v[2] * rhs.v[2];
                static if(Columns >= 4) data.v[2] += this.columns[3].v[2] * rhs.v[3];
            }

            // 4th
            static if(VectT.v.length >= 4)
            {
                                        data.v[3] += this.columns[0].v[3] * rhs.v[0];
                                        data.v[3] += this.columns[1].v[3] * rhs.v[1];
                static if(Columns >= 3) data.v[3] += this.columns[2].v[3] * rhs.v[2];
                static if(Columns >= 4) data.v[3] += this.columns[3].v[3] * rhs.v[3];
            }

            return data;
        }
        ///
        unittest
        {
            import std.conv : to;

            imat2 mat;
            mat.columns = 
            [
                ivec2(1, 2),
                ivec2(3, 4)
            ];

            assert(mat * ivec2(2, 4) == ivec2(1*2+3*4, 2*2+4*4), to!string(mat * ivec2(2, 4)));
            assert(mat * ivec2(6, 8) == ivec2(1*6+3*8, 2*6+4*8));
        }
    }
}

alias transformMat4f = Matrix!(float, 4, 4);