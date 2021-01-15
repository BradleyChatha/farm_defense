module engine.vulkan.init._04_load_instance;

import std.conv : to;
import engine.core.logging, engine.vulkan;

private immutable VkApplicationInfo VULKAN_APP_INFO =
{
    pApplicationName:   "Farm Defense",
    applicationVersion: VK_MAKE_VERSION(1, 0, 0),
    pEngineName:        "None",
    engineVersion:      VK_MAKE_VERSION(1, 0, 0),
    apiVersion:         VK_API_VERSION_1_0
};

package void _04_load_instance()
{
    import std.algorithm : map, filter;
    import std.array : array;

    logfTrace("04. Loading Vulkan instance.");

    const enabledExtensions = g_vkInstance.extensions.byValue.filter!(e => e.isEnabled).map!(e => e.name.ptr).array;
    const enabledLayers     = g_vkInstance.layers.byValue.filter!(l => l.isEnabled).map!(l => l.name.ptr).array;

    VkInstanceCreateInfo info = 
    {
        pApplicationInfo:        &VULKAN_APP_INFO,
        enabledExtensionCount:   enabledExtensions.length.to!uint,
        enabledLayerCount:       enabledLayers.length.to!uint,
        ppEnabledExtensionNames: enabledExtensions.ptr,
        ppEnabledLayerNames:     enabledLayers.ptr
    };

    CHECK_VK(vkCreateInstance(&info, null, &g_vkInstance.handle));
    loadInstanceLevelFunctions(g_vkInstance.handle);
    loadDeviceLevelFunctions(g_vkInstance.handle);
}