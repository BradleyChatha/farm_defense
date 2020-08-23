module game.vulkan.init;

import std.conv : to;
import std.experimental.logger;
import erupted;
import game.vulkan, game.common, game.graphics.window;

// Trying a more traditional C-style kind of API this time around.
//
// Not *too* heavily, just for functions that can't be associated with singular objects. E.g. these init routines.

void vkInitJAST()
{
    VkStringArrayJAST instanceExtensions;
    VkStringArrayJAST instanceLayers;

    info("00. Initialising Vulkan");
    vkInit_01_loadFunctions();
    vkInit_02_loadInstanceExtentions(Ref(instanceExtensions));
    vkInit_03_loadInstanceLayers(Ref(instanceLayers));
    vkInit_04_createInstance(Ref(g_vkInstance), instanceLayers, instanceExtensions);
    vkInit_05_loadPhysicalDevices(Ref(g_physicalDevices));
    vkInit_06_findSuitableGpu(Ref(g_gpu), g_physicalDevices);
    vkInit_07_createLogicalDevice(Ref(g_device), g_gpu);
}

void vkUninitJAST()
{
}

/+
 + VULKAN INIT
 + ++/
private:

void vkInit_01_loadFunctions()
{
    import erupted.vulkan_lib_loader;

    info("01. Loading global functions via erupted");
    loadGlobalLevelFunctions();
}

void vkInit_02_loadInstanceExtentions(ref VkStringArrayJAST enabled)
{
    import std.algorithm : map;
    import game.graphics.window;

    info("02. Loading instance extentions");

    VkStringArrayJAST wanted;
    wanted.add(Window.requiredExtentions);
    wanted.outputToLog("Wanted Extentions");

    auto available = vkGetArrayJAST!(VkExtensionProperties, vkEnumerateInstanceExtensionProperties)(null);
    info("\tAvailable Extentions:");
    foreach(ext; available)
        infof("\t\t%s - v%s", ext.extensionName.ptr.asSlice, ext.specVersion);

    enabled = wanted.filter(available.map!(e => e.extensionName.ptr.asSlice));
    wanted.outputToLog("Enabled Extentions");
}

void vkInit_03_loadInstanceLayers(ref VkStringArrayJAST enabled)
{
    import std.algorithm : map;

    info("03. Loading instance layers");

    VkStringArrayJAST wanted;
    wanted.add("VK_LAYER_KHRONOS_validation");
    wanted.outputToLog("Wanted Layers");

    auto available = vkGetArrayJAST!(VkLayerProperties, vkEnumerateInstanceLayerProperties);
    info("\tAvailable Layers:");
    foreach(layer; available)
        infof("\t\tv%s for spec %s %s - %s", layer.implementationVersion, layer.specVersion, layer.layerName.ptr.asSlice, layer.description.ptr.asSlice);

    enabled = wanted.filter(available.map!(l => l.layerName.ptr.asSlice));
    enabled.outputToLog("Enabled Layers");
}

void vkInit_04_createInstance(ref VulkanInstance handle, ref VkStringArrayJAST layers, ref VkStringArrayJAST extentions)
{
    info("04. Creating Vulkan Instance");

    const VkApplicationInfo appInfo =
    {
        pApplicationName:   "Farm Defense",
        applicationVersion: VK_MAKE_VERSION(1, 0, 0),
        pEngineName:        "None",
        engineVersion:      VK_MAKE_VERSION(1, 0, 0),
        apiVersion:         VK_API_VERSION_1_0
    };

    VkInstanceCreateInfo info = 
    {
        pApplicationInfo:           &appInfo,
        enabledExtensionCount:      extentions.slices.length.to!uint,
        enabledLayerCount:          layers.slices.length.to!uint,
        ppEnabledExtensionNames:    extentions.ptrs.ptr,
        ppEnabledLayerNames:        layers.ptrs.ptr
    };

    CHECK_VK(vkCreateInstance(&info, null, &handle.handle));
    loadInstanceLevelFunctions(handle);

    handle.layers = layers;
}

void vkInit_05_loadPhysicalDevices(ref PhysicalDevice[] devices)
{
    info("05. Discovering Physical Devices");

    auto surface = Window.createSurface();
    auto handles = vkGetArrayJAST!(VkPhysicalDevice, vkEnumeratePhysicalDevices)(g_vkInstance);
    devices.reserve(handles.length);

    foreach(handle; handles)
        devices ~= PhysicalDevice(handle, surface);
}

void vkInit_06_findSuitableGpu(ref PhysicalDevice gpu, PhysicalDevice[] devices)
{
    import std.algorithm : map;
    import std.exception : enforce;

    info("06. Choosing suitable Graphics Device");

    VkStringArrayJAST wanted;
    wanted.add("VK_KHR_swapchain");

    foreach(device; devices)
    {
        infof("\tTesting %s", device.properties.deviceName.ptr.asSlice);
        const allEnabled = device.setExtentions(wanted);

        // Has all the extentions we want; Can present graphics; Has at least 1 colour format and present mode.
        const isSuitable = 
            allEnabled
         && !device.graphicsQueueIndex.isNull
         && !device.presentQueueIndex.isNull
         && device.formats.length > 0
         && device.presentModes.length > 0;

        infof("\tHas mandatory capabilities? %s", isSuitable);
        if(!isSuitable)
            continue;

        gpu = device;
        break;
    }

    enforce(gpu != VK_NULL_HANDLE, "Could not find suitable graphics device.");
    infof("Chosen device called %s as graphics device.", gpu.properties.deviceName.ptr.asSlice);
}

void vkInit_07_createLogicalDevice(ref LogicalDevice device, PhysicalDevice gpu)
{
    info("07. Creating logical device.");

    device = LogicalDevice(gpu);  
}