module game.core.input;

import bindbc.sdl;
import game.graphics : WindowEventMessage;
import game.core, game.common;

public import bindbc.sdl.bind.sdlscancode;

final class InputMessage(MessageType type, ValueT) : MessageWithData!(type, ValueT)
{
    bool handled;

    this(ValueT value)
    {
        super(value);
    }
}

struct MouseMotionEvent { vec2i currentPos;         vec2i delta;                                                            }
struct MouseButtonEvent { vec2i position;           ubyte clicks;           ButtonState state;  MouseButton button;         }
struct KeyButtonEvent   { SDL_Scancode scancode;    SDL_Keycode keycode;    ButtonState state;  bool isTextInputEnabled;    }

alias MouseMotionMessage    = InputMessage!(MessageType.mouseMotion, MouseMotionEvent);
alias MouseButtonMessage    = InputMessage!(MessageType.mouseButton, MouseButtonEvent);
alias KeyButtonMessage      = InputMessage!(MessageType.keyButton, KeyButtonEvent);
alias TextInputMessage      = InputMessage!(MessageType.textInput, const(char)[]);
alias AllowTextInputMessage = MessageWithData!(MessageType.allowTextInput, bool);

enum ButtonState
{
    ERROR,
    up     = 1,
    down   = 2,
    tapped = 0b1000000,
}

enum MouseButton : ubyte
{
    ERROR,
    left   = SDL_BUTTON_LEFT,
    right  = SDL_BUTTON_RIGHT,
    middle = SDL_BUTTON_MIDDLE
}

private:

struct InfoPair(InfoT)
{
    InfoT prevFrame;
    InfoT thisFrame;
}

InfoPair!ButtonState[MouseButton.max+1]  g_mouseButtons;
InfoPair!ButtonState[SDL_Scancode.max+1] g_keyButtons;

final class InputHandler : IMessageHandler
{
    mixin IMessageHandlerBoilerplate;

    @Subscribe
    void onWindowEvent(WindowEventMessage message)
    {
        switch(message.data.type)
        {
            case SDL_MOUSEBUTTONUP:
            case SDL_MOUSEBUTTONDOWN: this.onMouseButtonInput(message.data.button); break;

            case SDL_MOUSEMOTION: this.onMouseMotionInput(message.data.motion); break;

            case SDL_KEYUP:   this.onKeyInput(message.data.key, false); break;
            case SDL_KEYDOWN: this.onKeyInput(message.data.key, true);  break;

            case SDL_TEXTINPUT: this.onTextInput(message.data.text); break;

            default: break;
        }
    }

    @Subscribe
    void onSetTextInputState(AllowTextInputMessage message)
    {
        if(message.data)
            SDL_StartTextInput();
        else
            SDL_StopTextInput();
    }

    void onTextInput(SDL_TextInputEvent event)
    {
        // .text is static, so find '\0'. Can't use strlen as I don't know guarentees about the last character always being \0 or not.
        size_t length;
        for(length = 0; length < event.text.length; length++)
        {
            if(event.text[length] == '\0')
                break;
        }

        messageBusSubmit!TextInputMessage(event.text[0..length]);
    }

    void onMouseMotionInput(SDL_MouseMotionEvent event)
    {
        messageBusSubmit!MouseMotionMessage(MouseMotionEvent(vec2i(event.x, event.y), vec2i(event.xrel, event.yrel)));
    }

    void onMouseButtonInput(SDL_MouseButtonEvent event)
    {
        if(event.button > MouseButton.max || event.button < MouseButton.min)
            return;

        scope infoPair = &g_mouseButtons[event.button];
        this.updateButtonState(infoPair.thisFrame, infoPair.prevFrame, event.state == SDL_PRESSED);

        messageBusSubmit!MouseButtonMessage(MouseButtonEvent(
            vec2i(event.x, event.y),
            event.clicks,
            infoPair.thisFrame,
            cast(MouseButton)event.button
        ));
    }

    void onKeyInput(SDL_KeyboardEvent event, bool downTrueUpFalse)
    {
        if(event.keysym.scancode > g_keyButtons.length)
            return;

        scope infoPair = &g_keyButtons[event.keysym.scancode];
        this.updateButtonState(infoPair.thisFrame, infoPair.prevFrame, downTrueUpFalse);

        messageBusSubmit!KeyButtonMessage(KeyButtonEvent(
            event.keysym.scancode,
            event.keysym.sym,
            infoPair.thisFrame,
            cast(bool)SDL_IsTextInputActive()
        ));
    }

    void updateButtonState(ref ButtonState thisFrame, ref ButtonState prevFrame, bool downTrueUpFalse)
    {
        thisFrame = (downTrueUpFalse) ? ButtonState.down : ButtonState.up;
        if((prevFrame & ~ButtonState.tapped) != (thisFrame & ~ButtonState.tapped))
            thisFrame |= ButtonState.tapped;

        prevFrame = thisFrame;
    }
}

public:

void inputInit()
{
    messageBusSubscribe(new InputHandler());
}