module engine.util.structures.result;

enum ResultType
{
    ERROR,
    ok,
    failure
}

struct Result(ValueT)
{
    private ResultType _type;
    private union
    {
        static if(!is(ValueT == void)) ValueT _okValue;
        string _failureMessage;
    }

    invariant(this._type != ResultType.ERROR, "Attempting to observe uninitialised Result.");

    static if(!is(ValueT == void))
    static Result!ValueT ok()(ValueT value)
    {
        auto result = Result!ValueT(ResultType.ok);
        result._okValue = value;
        return result;
    }
    else
    static Result!ValueT ok()()
    {
        return Result!ValueT(ResultType.ok);
    }

    static Result!ValueT failure()(string error)
    {
        auto value = Result!ValueT(ResultType.failure);
        value._failureMessage = error;
        return value;
    }

    static if(!is(ValueT == void))
    @property
    inout(ValueT) value()() inout
    {
        assert(this.isOk, "Cannot use .value() for non-ok result types.");
        return this._okValue;
    }

    @property @trusted @nogc
    string error() nothrow const
    {
        assert(this.isFailure, "Cannot use .error() for non-failure result types.");
        return this._failureMessage;
    }

    @property @safe @nogc
    ResultType type() nothrow const
    {
        return this._type;
    }

    @safe @nogc bool isType(ResultType type)() nothrow const { return this._type == type; }
    alias isOk = isType!(ResultType.ok);
    alias isFailure = isType!(ResultType.failure);
}