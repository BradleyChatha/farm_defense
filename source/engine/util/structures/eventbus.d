module engine.util.structures.eventbus;

import std.traits : EnumMembers, OriginalType, isNumeric;
import std.typecons : Flag;
import engine.util;

alias EventsAreDelegates = Flag!"useDelegates";

struct Subscribe {}

struct EventHandle(alias ChannelTypesEnum, alias EventTypesEnum)
{
    private ChannelTypesEnum channel;
    private EventTypesEnum event;
    private size_t index = size_t.max;
}

struct EventBus(
    alias ChannelTypesEnum, 
    alias EventTypesEnum, 
    alias MessageT, 
    size_t ListenersPerEventPerChannel, 
    EventsAreDelegates UseDelegates = EventsAreDelegates.yes
)
if(is(ChannelTypesEnum == enum) && is(EventTypesEnum == enum) && ListenersPerEventPerChannel > 0)
{
    @disable this(this){}

    static if(UseDelegates)
        alias ListenerFuncT = void delegate(MessageT);
    else
        alias ListenerFuncT = void function(MessageT);

    alias HandleT = EventHandle!(ChannelTypesEnum, EventTypesEnum);

    enum ChannelCount = assertEnumValuesAreSequentialReturnsLength!ChannelTypesEnum;
    enum EventCount   = assertEnumValuesAreSequentialReturnsLength!EventTypesEnum;

    private struct Event
    {
        ListenerFuncT[ListenersPerEventPerChannel] listeners;
        size_t listenerCount;
    }

    private struct Channel
    {
        Event[EventCount] events;
    }

    private
    {
        Channel[ChannelCount] _channels;

        Event* getEvent(ChannelTypesEnum channel, EventTypesEnum event)
        {
            return &this._channels[cast(size_t)channel].events[cast(size_t)event];
        }
    }

    HandleT on(ChannelTypesEnum channel, EventTypesEnum event, ListenerFuncT callback)
    in(callback !is null)
    {
        scope ptr = this.getEvent(channel, event);
        assert(ptr.listenerCount < ptr.listeners.length, "Too many listeners for event.");

        ptr.listeners[ptr.listenerCount++] = callback;
        return HandleT(channel, event, ptr.listenerCount - 1);
    }

    /// Returns: A static `HandleT[]` where the length is how many functions were subscribed.
    auto register(T)(T me)
    if(is(T == class) || is(T == interface))
    in(me !is null, "Value is null.")
    {
        import std.typecons : Nullable;
        import std.traits : getSymbolsByUDA;

        alias Symbols = getSymbolsByUDA!(T, Subscribe);
        HandleT[Symbols.length] result;
        size_t cursor;

        static foreach(Symbol; Symbols)
        {{
            Nullable!ChannelTypesEnum channel;
            Nullable!EventTypesEnum event;

            static foreach(attr; __traits(getAttributes, Symbol))
            {{
                static if(__traits(compiles, typeof(attr)))
                {
                    static if(is(typeof(attr) == ChannelTypesEnum))
                        channel = attr;
                    else static if(is(typeof(attr) == EventTypesEnum))
                        event = attr;
                }
            }}

            assert(!channel.isNull, "Please attach a UDA of type "~ChannelTypesEnum.stringof~" onto function "~__traits(identifier, Symbol));
            assert(!event.isNull, "Please attach a UDA of type "~EventTypesEnum.stringof~" onto function "~__traits(identifier, Symbol));

            result[cursor++] = this.on(channel.get, event.get, mixin("&me."~__traits(identifier, Symbol)));
        }}

        return result;
    }

    void remove(ref HandleT handle)
    in(handle.index != size_t.max, "Invalid handle was passed.")
    {
        import std.algorithm : remove;

        scope ptr = this.getEvent(handle.channel, handle.event);
        ptr.listenerCount--;
        ptr.listeners[].remove(handle.index);

        handle = HandleT.init;
    }

    void remove(HandleT[] handles)
    {
        foreach(ref handle; handles)
            this.remove(handle);
    }

    void emit(ChannelTypesEnum channel, EventTypesEnum event, MessageT message)
    {
        scope ptr = this.getEvent(channel, event);
        const startCount = ptr.listenerCount;
        for(size_t i = 0; i < ptr.listenerCount; i++)
        {
            auto listener = ptr.listeners[i];
            listener(message);
            if(startCount < ptr.listenerCount)
                i--;
        }
    }
}
///
@("EventBus")
unittest
{
    import fluent.asserts;

    enum C
    {
        a,
        b
    }

    enum E
    {
        a,
        b
    }

    struct Message
    {
        string str;
    }

    static class Test
    {
        int value;

        @Subscribe
        @(C.a, E.a)
        void aa(Message msg)
        {
            if(msg.str == "aa")
                value++;
        }

        @Subscribe
        @(C.a, E.b)
        void ab(Message msg)
        {
            if(msg.str == "aa")
                value++;
        }

        @Subscribe
        @(C.b, E.a)
        void ba(Message msg)
        {
            value++;
        }
    }

    alias EventBusT = EventBus!(C, E, Message, 1);

    EventBusT bus;
    auto test = new Test();
    auto handles = bus.register(test);

    bus.emit(C.a, E.a, Message("aa"));
    test.value.should.equal(1);

    bus.emit(C.a, E.a, Message());
    test.value.should.equal(1);

    bus.emit(C.a, E.b, Message("aa"));
    test.value.should.equal(2);

    bus.emit(C.b, E.a, Message());
    test.value.should.equal(3);

    bus.remove(handles);

    bus.emit(C.b, E.a, Message());
    test.value.should.equal(3);
}

private size_t assertEnumValuesAreSequentialReturnsLength(alias E)()
{
    alias NumT = OriginalType!E;
    static assert(isNumeric!NumT, E.stringof~"'s base type must be numerical.");

    static foreach(i; 0..EnumMembers!E.length)
        assert(cast(NumT)EnumMembers!E[i] == i, "Enum values are not sequential.");

    return EnumMembers!E.length;
}