module engine.vulkan.init._06_select_device;

import std.algorithm : map;
import std.array : array;
import std.string : fromStringz;
import engine.vulkan, engine.core, engine.window, engine.vulkan.init.common;

private immutable LUA_GRAPHICS_RULES = "./assets/config/vulkan/graphics_rules.lua";

private struct DeviceInfo
{
    VkPhysicalDevice device;
    VkPhysicalDeviceProperties props;
    VkPhysicalDeviceFeatures features;
    VkQueueFamilyProperties[] queueFamilies;
    VStringAndVersion[] extensions;
    VkPhysicalDeviceMemoryProperties memory;
}

void _06_select_device()
{
    auto extensions = gatherExtensions();
    auto devices = gatherDeviceInfo();
    loadGraphicsRules();
    selectPhysicalDevice(devices, extensions);
    createLogicalDevice();
}

private VStringAndVersion[] gatherExtensions()
{
    VStringAndVersion[] result;

    if(g_window !is null)
        result ~= VStringAndVersion("VK_KHR_swapchain");

    return result;
}

private void loadGraphicsRules()
{
    logfTrace("06. Loading graphics rules LUA module.");
    auto guard = LuaStackGuard(g_luaState, 0);

    g_luaState.loadFile(LUA_GRAPHICS_RULES).enforceOk;
    g_luaState.newTable();
    g_luaState.pushEx!VkQueueFlagBits();
    g_luaState.rawSet(-2, 1);
    g_luaState.pushEx!VkPhysicalDeviceType();
    g_luaState.rawSet(-2, 2);
    g_luaState.pcall(1, 1).enforceOk;

    g_graphicsRulesFuncs = LuaRef(g_luaState);
}

private DeviceInfo[] gatherDeviceInfo()
{
    logfTrace("06. Gathering available devices.");
    DeviceInfo[] devices;

    foreach(device; vkGetArrayJAST!vkEnumeratePhysicalDevices(g_vkInstance.handle))
    {
        DeviceInfo info;
        info.device = device;

        vkGetPhysicalDeviceProperties(device, &info.props);
        vkGetPhysicalDeviceFeatures(device, &info.features);
        vkGetPhysicalDeviceMemoryProperties(device, &info.memory);
        info.queueFamilies = vkGetArrayJAST!vkGetPhysicalDeviceQueueFamilyProperties(device);
        info.extensions = vkGetArrayJAST!vkEnumerateDeviceExtensionProperties(device, null)
                          .map!(p => VStringAndVersion(p.extensionName.ptr.fromStringz.idup, p.specVersion))
                          .array;

        devices ~= info;
    }

    return devices;
}

private void selectPhysicalDevice(DeviceInfo[] devices, VStringAndVersion[] wantedExtensions)
{
    logfInfo("06. Executing graphics rules to determine best physical device.");

    static struct LuaQueueFamilyIndicies
    {
        int transfer;
        int graphics;
        int compute;
    }

    static struct LuaResult
    {
        int deviceIndex;
        VStringAndVersion[] enabledExtensions;
        LuaQueueFamilyIndicies queueFamilyIndicies;
    }

    auto guard = LuaStackGuard(g_luaState, 0);

    // TOP = g_graphicsRulesFuncs.determineCoreVulkanDevice
    g_luaState.push(g_graphicsRulesFuncs);
    g_luaState.push("determineCoreVulkanDevice");
    g_luaState.rawGet(-2);

    // RESULT = TOP(devices, wantedExtensions)
    g_luaState.pushEx!(FailIfCantConvert.no)(devices);
    g_luaState.pushEx!(FailIfCantConvert.no)(wantedExtensions);
    g_luaState.pcall(2, 1).enforceOk();

    auto result = g_luaState.asEx!LuaResult(-1).enforceOkValue;
    auto device = devices[result.deviceIndex];

    foreach(ext; result.enabledExtensions)
        g_device.enabledExtensions[ext.name] = ext;

    g_device.physical          = device.device;
    g_device.properties        = device.props;
    g_device.memoryProperties  = device.memory;
    g_device.features          = device.features;
    g_device.queueFamilies     = device.queueFamilies;
    g_device.allExtensions     = device.extensions;
    g_device.graphicsFamily    = VQueueFamily(result.queueFamilyIndicies.graphics, g_device.queueFamilies[result.queueFamilyIndicies.graphics]);
    g_device.transferFamily    = VQueueFamily(result.queueFamilyIndicies.transfer, g_device.queueFamilies[result.queueFamilyIndicies.transfer]);

    if(Config.instance.getOrDefault!bool(CONFIG_OPTION_REQUIRE_COMPUTE))
        g_device.computeFamily = VQueueFamily(result.queueFamilyIndicies.compute, g_device.queueFamilies[result.queueFamilyIndicies.compute]);
    
    g_luaState.pop(2); // pop RESULT and g_graphicsRulesFuncs
}

private void createLogicalDevice()
{
    import std.algorithm : uniq, map, filter;
    import std.exception : enforce;
    import std.range : array;

    logfInfo("06. Creating logical device.");

    const priority = 1.0f;
    VkDeviceQueueCreateInfo[] queueInfos;
    foreach(uniqueFamily; [g_device.graphicsFamily.index, g_device.transferFamily.index, g_device.computeFamily.index].filter!(f => f != FAMILY_NOT_FOUND).uniq)
    {
        VkDeviceQueueCreateInfo info = 
        {
            queueFamilyIndex: uniqueFamily,
            queueCount: 1,
            pQueuePriorities: &priority
        };
        queueInfos ~= info;
    }

    VkPhysicalDeviceFeatures features = 
    {
        textureCompressionBC: true
    };

    static foreach(featureMemberName; __traits(allMembers, VkPhysicalDeviceFeatures))
    {
        enforce(!mixin("features."~featureMemberName) || mixin("g_device.features."~featureMemberName), "Feature "~featureMemberName~" is not supported by this device.");
        if(mixin("features."~featureMemberName))
            logfDebug("Using feature %s", featureMemberName);
    }

    const enabledLayers = g_vkInstance.layers.byValue.filter!(l => l.isEnabled).map!(l => l.name.ptr).array;
    VkDeviceCreateInfo info = 
    {
        queueCreateInfoCount: cast(uint)queueInfos.length,
        pQueueCreateInfos: queueInfos.ptr,
        enabledLayerCount: cast(uint)enabledLayers.length,
        ppEnabledLayerNames: enabledLayers.ptr,
        enabledExtensionCount: cast(uint)g_device.enabledExtensions.length,
        ppEnabledExtensionNames: g_device.enabledExtensions.byValue.map!(e => e.name.ptr).array.ptr
    };

    CHECK_VK(vkCreateDevice(g_device.physical, &info, null, &g_device.logical));
    g_device.transfer = VQueue(g_device.transferFamily, VQueueType.transfer);
    g_device.graphics = VQueue(g_device.graphicsFamily, VQueueType.graphics);

    if(Config.instance.getOrDefault!bool(CONFIG_OPTION_REQUIRE_COMPUTE))
        g_device.compute = VQueue(g_device.computeFamily, VQueueType.compute);

    g_device.queueByType[VQueueType.transfer] = g_device.transfer;
    g_device.queueByType[VQueueType.graphics] = g_device.graphics;
    g_device.queueByType[VQueueType.compute]  = g_device.compute;
}