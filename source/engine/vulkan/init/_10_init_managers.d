module engine.vulkan.init._10_init_managers;

import engine.vulkan, engine.core;

void _10_init_managers()
{
    logfInfo("10. Initialising managers.");

    resourceGlobalInit();
    resourcePerThreadInit();
    submitGlobalInit();
    submitPerThreadInit();
}