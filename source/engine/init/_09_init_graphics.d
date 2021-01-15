module engine.init._09_init_graphics;

import bindbc.sdl;
import engine.core, engine.util, engine.window, engine.vulkan;

void init_09_init_graphics()
{
    initWindow();
    initVulkan();
}

private void initWindow()
{
    globalWindowInit(
        Config.instance.get!string("window:title").enforceOkValue,
        vec2i(cast(int)Config.instance.get!long("window:width").enforceOkValue, cast(int)Config.instance.get!long("window:height").enforceOkValue)
    );
}

private void initVulkan()
{
    initVulkanBasic();
}