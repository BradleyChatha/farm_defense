module engine.util.structures.typedpointer;

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
    {
        return *this.asPtr!T;
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