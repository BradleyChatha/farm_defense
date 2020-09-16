module game.debug_.ui;

import std.experimental.logger;
import game.common, game.core, game.graphics, game.gui;

private ubyte[] DEBUG_FONT_BYTES = cast(ubyte[])import("Roboto-Black.ttf");

final class DebugUIService : Service
{
    mixin IMessageHandlerBoilerplate;

    Font  font;
    Gui   gui;
    Label fpsLabel;

    this()
    {
        this.font = new Font(DEBUG_FONT_BYTES);
        this.gui  = new Gui();

        this.gui.root = this.gui.make!AlignmentContainer(vec2f(Window.size));

        auto debugStatTray = this.gui.make!RectangleShape(vec2f(85, 20), Color(0, 0, 0, 200));
        debugStatTray.vertAlignment = VertAlignment.bottom;
        this.gui.root.addChild(debugStatTray);

        this.fpsLabel = this.gui.make!Label(this.font);
        this.fpsLabel.vertAlignment = VertAlignment.bottom;
        this.gui.root.addChild(this.fpsLabel);
    }

    override
    {
        void onFrame()
        {
            this.displayFPS();
            this.gui.onUpdate();

            messageBusSubmit!SubmitDrawCommandsMessage(this.gui.gatherDrawCommands());
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
    void onKeyButton(KeyButtonMessage message)
    {
    }
}