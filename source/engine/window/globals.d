module engine.window.globals;

import engine.util, engine.window;

__gshared Window g_window;

void globalWindowInit(string title, vec2i size)
{
    import core.thread;

    assert(g_window is null, "Window has already initialised.");
    assert(Thread.getThis().isMainThread, "This function can only be called on the main thread.");

    g_window = new Window(title, size);
}