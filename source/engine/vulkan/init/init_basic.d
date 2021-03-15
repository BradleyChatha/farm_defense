module engine.vulkan.init.init_basic;

import engine.core.logging, engine.vulkan.init;

void initVulkanBasic()
{
    logfInfo("Initialising basic Vulkan systems.");
    _00_load_funcs();
    _02_load_instance_layers_and_extensions();
    _04_load_instance();
    _06_select_device();
    _08_load_vma();
    _10_init_managers();
}