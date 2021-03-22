module engine.core.events;

import engine.util;

enum CoreEventChannel
{
    ERROR,
    window
}

enum CoreEventType
{
    ERROR,

    windowEvent
}

abstract class CoreMessage
{

}

EventBus!(CoreEventChannel, CoreEventType, CoreMessage, 8) g_coreEventBus; // Only really relevent for the main thread.