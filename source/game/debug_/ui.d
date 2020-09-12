module game.debug_.ui;

import std.experimental.logger;
import game.common, game.core, game.graphics;

private ubyte[] DEBUG_FONT_BYTES = cast(ubyte[])import("Roboto-Black.ttf");

final class DebugUIService : Service
{
    mixin messageHandlerBoilerplate;

    Font font;
    Text fpsText;

    this()
    {
        this.font    = new Font(DEBUG_FONT_BYTES);
        this.fpsText = new Text(this.font);
    }

    override
    {
        void onFrame()
        {
            this.displayFPS();
            messageBusSubmit!SubmitDrawCommandsMessage([this.fpsText.drawCommand]);
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
        
        this.fpsText.text = sformat(fpsBuffer, "%sms %s fps", msBuffer.reduce!((a, b) => a + b) / msBuffer.length, gametimeFps());
    }
}