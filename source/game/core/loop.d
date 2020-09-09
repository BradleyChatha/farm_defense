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
Font font;

// START functions
void loopInit()
{
    messageBusSubscribe(new LoopMessageHandler());

    font = new Font("./resources/fonts/arial.ttf");
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
    renderFrameBegin();

    SDL_Event event;
    while(Window.nextEvent(&event))
        messageBusSubmit!WindowEventMessage(event);

    renderFrameEnd();
}

void loopStop()
{
    g_loopRun = false;
}