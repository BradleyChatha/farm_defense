module engine.core.resources.resourceloadinfo;

struct ResourceLoadInfo
{
    private
    {
        void* _loadInfo;
        package TypeInfo _loadInfoT;
    }

    invariant(this._loadInfo !is null, "This ResourceLoadInfo contains no load info.");

    this(LoadInfoT)(LoadInfoT value)
    {
        this._loadInfoT = typeid(LoadInfoT);
        
        auto ptr = new LoadInfoT;
        *ptr = value;
        this._loadInfo = cast(void*)ptr;
    }

    LoadInfoT as(LoadInfoT)()
    {
        if(this._loadInfoT != typeid(LoadInfoT))
            assert(false, "This contains '"~this._loadInfoT.toString()~"' not '"~LoadInfoT.stringof~"'");
        return *cast(LoadInfoT*)this._loadInfo;
    }
}