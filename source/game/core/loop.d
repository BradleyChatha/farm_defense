module game.core.loop;

import bindbc.sdl;
import game.common, game.core, game.graphics;

private:

// START variables
bool g_loopRun;

// START Message Handler
final class LoopMessageHandler : IMessageHandler
{
    mixin messageHandlerBoilerplate;

    @Subscribe
    void onWindowEvent(WindowEventMessage message)
    {
        auto event = message.data;

        if(event.type == SDL_QUIT)
            loopStop();
    }
}

public:

// TEST vars
VertexBuffer verts;
Font         font;

// START functions
void loopInit()
{
    messageBusSubscribe(new LoopMessageHandler());

    font = new Font("./resources/fonts/arial.ttf");

    const TEXT = "abcdefghijklmnopqrstuvwxyz";
    box2f size;
    verts.resize(font.calculateVertCount(TEXT));
    verts.lock();
        auto slice = verts.verts[0..$];
        font.textToVerts(Ref(slice), Ref(size), TEXT, 64);
        verts.upload(0, verts.length);
    verts.unlock();
}

void loopRun()
{
    g_loopRun = true;
    while(g_loopRun)
    {
        loopStep();
    }
}

void loopStep()
{
    SDL_Event event;
    while(Window.nextEvent(&event))
        messageBusSubmit!WindowEventMessage(event);

    renderFrameBegin();
    messageBusSubmit!SubmitDrawCommandsMessage([DrawCommand(&verts, 0, verts.length, font.getFontSize(64).texture, true, 0, 0)]);
    renderFrameEnd();
}

void loopStop()
{
    g_loopRun = false;
}