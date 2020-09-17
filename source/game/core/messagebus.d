module game.core.messagebus;

import stdx.allocator;
import game.common;

private:

// START variables
IMessageHandler[] g_messageHandlers;
PoolAllocator     g_messageAllocator;

public:

// START Data Types
struct Subscribe;

enum MessageType
{
    ERROR,
    Unittest,
    windowEvent,
    submitDrawCommands,
    displayDebugUI,
    mouseMotion,
    mouseButton,
    keyButton,
    allowTextInput,
    textInput,
    debugCommand,
    debugLog
}

interface IMessageHandler
{
    void handleMessage(scope MessageBase message)
    in(message !is null);
}

abstract class MessageBase
{
    private MessageType _type;

    this(MessageType type)
    {
        this._type = type;
    }

    @property
    final MessageType type()
    {
        return this._type;
    }

    @property
    final CastT as(CastT : MessageBase)()
    out(o; o !is null, "This Message could not be casted to a "~CastT.stringof)
    {
        return cast(CastT)this;
    }
}

class Message(MessageType MessageType_) : MessageBase
{
    enum ThisMessageType = MessageType_;

    this()
    {
        super(ThisMessageType);
    }
}

class MessageWithData(MessageType ThisMessageType, alias DataT) : Message!ThisMessageType
{
    DataT data;

    this(DataT data)
    {
        this.data = data;
    }
}

// START Functions
void messageBusSubscribe(IMessageHandler handler)
{
    debug foreach(registeredHandler; g_messageHandlers)
        assert(registeredHandler != handler, "This handler has already been subscribed.");

    g_messageHandlers ~= handler;
}

void messageBusUnsubscribe(IMessageHandler handler)
{
    import std.algorithm : remove, countUntil;

    auto index = g_messageHandlers.countUntil(handler);
    assert(index > -1, "Cannot unsubscribe this handler as it's not subscribed in the first place.");

    g_messageHandlers = g_messageHandlers.remove(index);
}

void messageBusSubmit(MailT : MessageBase, CtorArgs...)(CtorArgs args)
{
    auto message = g_messageAllocator.make!MailT(args);
    assert(message !is null, "Could not allocate message.");
    scope(exit) g_messageAllocator.dispose(message);

    foreach(handler; g_messageHandlers)
        handler.handleMessage(message);
}

// START mixins
mixin template IMessageHandlerBoilerplate()
{
    import std.traits : getSymbolsByUDA, isInstanceOf, Parameters;

    alias ThisType = typeof(this);

    void handleMessage(scope MessageBase message)
    {
        import std.conv : to;
        SwitchLabel: switch(message.type)
        {
            case MessageType.ERROR: assert(false, "Message with type ERROR was received.");

            static foreach(func; getSymbolsByUDA!(ThisType, Subscribe))
            {{
                enum  FuncIdent  = __traits(identifier, func);
                alias FuncType   = typeof(func);
                alias FuncParams = Parameters!FuncType;

                static assert(
                    FuncParams.length == 1 && (isInstanceOf!(Message, FuncParams[0]) || isInstanceOf!(MessageWithData, FuncParams[0]) || isInstanceOf!(InputMessage, FuncParams[0])),
                    "Function "~FuncIdent~" must have only ONE parameter of type `Message`"
                );

                case mixin("FuncParams[0].ThisMessageType"):
                    func(message.as!(FuncParams[0]));
                    break SwitchLabel;
            }}

            default: break;
        }
    }
}
///
unittest
{
    static class C : IMessageHandler
    {
        mixin IMessageHandlerBoilerplate;

        @Subscribe
        void f(Message!(MessageType.Unittest))
        {
            *this.thing = true;
        }

        bool* thing;
        this(bool* thing)
        {
            this.thing = thing;
        }
    }

    bool wasHandled = false;
    auto c = new C(&wasHandled);

    c.handleMessage(new Message!(MessageType.Unittest));
    assert(wasHandled);
}