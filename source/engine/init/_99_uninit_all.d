module engine.init._99_uninit_all;

import bindbc.sdl;
import engine.core, engine.util, engine.window, engine.vulkan;

void uninit_all()
{
    logTrace("Unloading all systems.");
    uninit_05_uninit_graphics();
    uninit_90_uninit_thirdparty();
}

private:

void uninit_05_uninit_graphics()
{
    logTrace("Unloading graphics.");
    g_window.dispose();
    uninitVulkanBasic();
}

void uninit_90_uninit_thirdparty()
{
    logTrace("Unloading Third-Party libraries.");
    unloadSDL();
}