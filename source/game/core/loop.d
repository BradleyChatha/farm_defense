module game.core.loop;

import std.experimental.logger;
import bindbc.sdl;
import game.common, game.core, game.graphics, game.debug_;

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

    @Subscribe
    void onKeyEvent(KeyButtonMessage message)
    {
        if(message.data.scancode == SDL_SCANCODE_ESCAPE && !message.handled)
        {
            loopStop();
            message.handled = true;
        }
    }
}

public:

// START functions
void loopInit()
{
    messageBusSubscribe(new LoopMessageHandler());
    servicesRegister(ServiceType.debugUI, new DebugUIService());

    // Order of message evaluation is determined by order of being started.
    servicesStart(ServiceType.debugUI);
}

void loopRun()
{
    g_loopRun = true;

    uint ticksLastFrame = SDL_GetTicks();
    while(g_loopRun)
    {
        gametimeSet(SDL_GetTicks() - ticksLastFrame);
        ticksLastFrame = SDL_GetTicks();

        loopStep();
    }
}

void loopStep()
{
    import game.vulkan;

    SDL_Event event;
    while(Window.nextEvent(&event))
        messageBusSubmit!WindowEventMessage(event);

    renderFrameBegin();
        servicesOnFrame();
    renderFrameEnd();
    g_device.graphics.processFences();
    g_device.transfer.processFences();
    g_device.present.processFences();
}

void loopStop()
{
    g_loopRun = false;
}