module engine.util.structures.typedpointer;

import std.traits : isBuiltinType;

struct TypedPointer
{
    this(this){ assert(this._canPostBlit, "This TypedPointer cannot be copied."); }

    private
    {
        bool                            _canPostBlit;
        TypeInfo                        _typeInfo;
        void*                           _data;
        void function(ref TypedPointer) _dtor;
    }

    ~this()
    {
        if(this._dtor !is null)
            this._dtor(this);
    }

    bool isNull()
    {
        return this._data is null;
    }

    TypeInfo typeInfo()
    {
        assert(!this.isNull);
        return this._typeInfo;
    }

    void* ptr()
    {
        assert(!this.isNull);
        return this._data;
    }

    T* asPtr(T)()
    {
        assert(!this.isNull);
        assert(typeid(T) == this._typeInfo, "Cannot cast "~this._typeInfo.toString()~" into "~T.stringof);
        return cast(T*)this._data;
    }

    T as(T)()
    if(is(T == struct) || isBuiltinType!T)
    {
        return *this.asPtr!T;
    }

    T as(T)()
    if(is(T == class) || is(T == Interface))
    {
        assert(!this.isNull);
        assert(typeid(T) == this._typeInfo, "Cannot cast "~this._typeInfo.toString()~" into "~T.stringof);
        return cast(T)this._data;
    }
}

TypedPointer copyToGcTypedPointer(T)(T value)
{
    static assert(!is(T == class) && !is(T == Interface), "TODO");

    T* ptr = new T;
    *ptr = value;

    return TypedPointer(
        true,
        typeid(T),
        ptr,
        null
    );
}

/// Uses TypedPointer as a wrapper around another pointer. Does not perform any memory management.
TypedPointer copyToBorrowedTypedPointer(T)(T* value)
{
    return TypedPointer(
        true,
        typeid(T),
        value,
        null
    );
}

TypedPointer copyToBorrowedTypedPointer(T)(T value)
if(is(T == class) || is(T == interface))
{
    return TypedPointer(
        true,
        typeid(T),
        cast(void*)value,
        null
    );
}