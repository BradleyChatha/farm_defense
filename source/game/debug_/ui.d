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

        // Just a bit of fun, stressed out today.
        static bool bounceRight = true;
        static bool bounceDown  = true;
        const float bounceSpeed = 200 * gametimeSecs();
        if(bounceRight)
            this.fpsText.move(bounceSpeed, 0);
        else
            this.fpsText.move(-bounceSpeed, 0);

        if(bounceDown)
            this.fpsText.move(0, bounceSpeed / 2);
        else
            this.fpsText.move(0, -bounceSpeed / 2);

        if(this.fpsText.position.x + this.fpsText.size.x > Window.size.x)
            bounceRight = false;
        else if(this.fpsText.position.x < 0)
            bounceRight = true;

        if(this.fpsText.position.y + this.fpsText.size.y > Window.size.y)
            bounceDown = false;
        else if(this.fpsText.position.y < 0)
            bounceDown = true;
    }
}