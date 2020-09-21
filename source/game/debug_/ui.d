module game.debug_.ui;

import std.experimental.logger;
import game.common, game.core, game.graphics, game.gui;

private ubyte[] DEBUG_FONT_BYTES = cast(ubyte[])import("Roboto-Black.ttf");
private Font g_debugFont;

alias DebugCommandMessage = MessageWithData!(MessageType.debugCommand, const char[]);
alias DebugLogMessage     = MessageWithData!(MessageType.debugLog, const char[]);

private final class DebugConsole : Container, IFocusable
{
    RectangleShape log;
    RectangleShape textbox;
    Label          logText;
    Label          text;
    char[]         textBuffer;
    char[]         logTextBuffer;

    override
    {
        void onInit()
        {
            this.log     = this.gui.make!RectangleShape(vec2f(Window.size.x, 240), Color.black);
            this.textbox = this.gui.make!RectangleShape(vec2f(Window.size.x, 20),  Color(56, 56, 56));
            this.text    = this.gui.make!Label(g_debugFont);
            this.logText = this.gui.make!Label(g_debugFont);

            this.addChild(this.log);
            this.addChild(this.logText);
            this.addChild(this.textbox);
            this.addChild(this.text);

            this.logText.position = this.log.position + vec2f(2);
            this.textbox.position = vec2f(this.log.position.x, this.log.size.y);
            this.text.position    = this.textbox.position + vec2f(0, 2);
        }
        
        void onGainFocus()
        {
            messageBusSubmit!AllowTextInputMessage(true);
        }

        void onLoseFocus()
        {
            messageBusSubmit!AllowTextInputMessage(false);
        }

        void onTextInput(TextInputMessage message)
        {
            this.textBuffer ~= message.data;
            this.text.text = this.textBuffer;
        }

        void onMouseButton(MouseButtonMessage message)
        {
            message.handled = true;

            if(message.data.state & ButtonState.down && message.data.button == MouseButton.left && message.data.state & ButtonState.tapped)
                this.gui.focusedControl = (this.textbox.bounds.contains(vec2f(message.data.position))) ? this : null;
        }

        void onKeyButton(KeyButtonMessage message)
        {
            if(!this.gui.isFocusedControl(this))
                return;

            if(message.data.scancode == SDL_SCANCODE_BACKSPACE && message.data.state & ButtonState.down)
            {
                message.handled = true;
                if(this.textBuffer.length > 0)
                {
                    this.textBuffer.length -= 1;
                    this.text.text = this.textBuffer;
                }
            }

            if(message.data.scancode == SDL_SCANCODE_RETURN && message.data.state & ButtonState.down)
            {
                message.handled = true;

                if(this.textBuffer.length > 0)
                {
                    this.addLogMessage(this.textBuffer);
                    messageBusSubmit!DebugCommandMessage(this.textBuffer);
                }
                this.textBuffer.length = 0;
                this.text.text = this.textBuffer;
            }
        }
    }

    void addLogMessage(const char[] text)
    {
        if(!this.isVisible)
            return;

        this.logTextBuffer ~= text;
        this.logTextBuffer ~= '\n';
        this.logText.text = this.logTextBuffer;

        while(this.logText.position.y + this.logText.size.y > this.log.position.y + this.log.size.y)
        {
            import std.algorithm : countUntil;
            auto newLineIndex = this.logTextBuffer.countUntil('\n');
            if(newLineIndex == -1)
                break;

            this.logTextBuffer = this.logTextBuffer[newLineIndex+1..$];
        }
    }
}

final class DebugUIService : Service
{
    mixin IMessageHandlerBoilerplate;

    Gui          gui;
    Label        fpsLabel;
    DebugConsole console;
    Image        testTexture;
    import game.data.tiled;
    Map          test;

    this()
    {
        g_debugFont = new Font(DEBUG_FONT_BYTES);
        this.gui    = new Gui();

        this.gui.root = this.gui.make!AlignmentContainer(vec2f(Window.size));

        auto debugStatTray = this.gui.make!RectangleShape(vec2f(85, 20), Color(0, 0, 0, 200));
        debugStatTray.vertAlignment = VertAlignment.bottom;
        this.gui.root.addChild(debugStatTray);

        this.fpsLabel = this.gui.make!Label(g_debugFont);
        this.fpsLabel.vertAlignment = VertAlignment.bottom;
        this.gui.root.addChild(this.fpsLabel);

        this.console = this.gui.make!DebugConsole();
        this.console.isVisible = false;
        this.gui.root.addChild(this.console);

        this.testTexture = this.gui.make!Image(null);
        this.testTexture.vertAlignment = VertAlignment.center;
        this.testTexture.horizAlignment = HorizAlignment.center;
        this.gui.root.addChild(this.testTexture);

        this.test = assetsGet!Map("m_test");
    }

    override
    {
        void onFrame()
        {
            this.displayFPS();
            this.gui.onUpdate();

            auto commands = this.gui.gatherDrawCommands();
            foreach(ref command; commands)
                command.sortOrder = SORT_ORDER_DEBUG_UI;

            messageBusSubmit!SubmitDrawCommandsMessage(commands);
            messageBusSubmit!SubmitDrawCommandsMessage(this.test.drawCommands);
        }
    }

    void displayFPS()
    {
        import std.algorithm : reduce;
        import std.format    : sformat;

        static char[50] fpsBuffer;
        static uint[60] msBuffer;
        static size_t   msBufferIndex;

        msBuffer[msBufferIndex++] = gametimeMillisecs();
        if(msBufferIndex == msBuffer.length)
            msBufferIndex = 0;
        
        this.fpsLabel.text = sformat(fpsBuffer, "%sms %s fps", msBuffer.reduce!((a, b) => a + b) / msBuffer.length, gametimeFps());
    }

    @Subscribe
    void onDebugLog(DebugLogMessage message)
    {
        this.console.addLogMessage(message.data);
    }

    @Subscribe
    void onKeyButton(KeyButtonMessage message)
    {
        if(message.data.scancode == SDL_SCANCODE_GRAVE && message.data.state & ButtonState.down)
        {
            message.handled = true;
            this.console.isVisible = !this.console.isVisible;
        }
    }

    @Subscribe
    void onDebugCommand(DebugCommandMessage message)
    {
        import std.algorithm : countUntil;

        const firstSpace = message.data.countUntil(' ');
        const command    = (firstSpace < 0) ? message.data : message.data[0..firstSpace];
        const arg        = (firstSpace < 0) ? null         : message.data[firstSpace+1..$];

        switch(command)
        {
            case "show_texture": this.testTexture.changeTexture(assetsGet!Texture(arg.idup)); break;
            default: break;
        }   
    }
}