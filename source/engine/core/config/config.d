module engine.core.config.config;

import core.sync.mutex;
import std.traits;
import engine.util, engine.core.config;

// It's a bit of bad design to put *all* statically known config options here, buuuut it really helps keep things simple.
const CONFIG_OPTION_REQUIRE_COMPUTE = "requireCompute";

private struct ArrayWrapper(T)
{
    T array;
}

// Multithreaded as the rendering thread may need to access the config at some point.
final class Config
{
    private
    {
        TypedPointer[string] _values;
    }

    static Config instance()
    {
        __gshared static Config conf = new Config();
        return conf;
    }

    void set(string name, ref TypedPointer value)
    {
        import std.algorithm : move;

        synchronized
        {
            auto ptr = (name in this._values);
            if(ptr is null)
            {
                this._values[name] = TypedPointer.init;
                ptr = (name in this._values);
            }

            move(value, *ptr);
        }
    }

    void set(T)(string name, T value)
    {
        static if(isDynamicArray!T)
            auto ptr = copyToGcTypedPointer(ArrayWrapper!T(value));
        else
            auto ptr = copyToGcTypedPointer(cast()value);
        this.set(name, ptr);
    }

    T getOrDefault(T)(string name, scope lazy T default_ = T.init)
    {
        auto result = this.get!T(name);
        return (result.isOk) ? result.value : default_;
    }

    Result!T get(T)(string name)
    {
        TypedPointer* ptr;
        synchronized
        {
            ptr = (name in this._values);
            if(ptr is null)
                return Result!T.failure("'"~name~"' not found");
        }
        
        static if(isDynamicArray!T)
            return Result!T.ok(ptr.as!(ArrayWrapper!T).array);
        else static if(isPointer!T)
            return Result!T.ok(ptr.asPtr!(typeof(*T)));
        else
            return Result!T.ok(ptr.as!T);
    }
}