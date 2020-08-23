module game.vulkan.device;

import std.conv     : to;
import std.typecons : Nullable;
import std.experimental.logger;
import game.vulkan, erupted;

struct PhysicalDevice
{
    mixin VkWrapperJAST!VkPhysicalDevice;

    VkExtensionProperties[]     extentions;
    VkPhysicalDeviceProperties  properties;
    VkPhysicalDeviceFeatures    features;
    Nullable!int                graphicsQueueIndex;
    Nullable!int                presentQueueIndex;
    VkSurfaceCapabilitiesKHR    capabilities;
    VkSurfaceFormatKHR[]        formats;
    VkPresentModeKHR[]          presentModes;
    Surface                     surface;
    VkStringArrayJAST           enabledExtentions;

    this(VkPhysicalDevice handle, Surface surface)
    {
        import asdf;

        this.handle  = handle;
        this.surface = surface;

        this.extentions = vkGetArrayJAST!(VkExtensionProperties, vkEnumerateDeviceExtensionProperties)(handle, null);
        vkGetPhysicalDeviceProperties(handle, &this.properties);
        vkGetPhysicalDeviceFeatures(handle, &this.features);

        auto queueFamilies = vkGetArrayJAST!(VkQueueFamilyProperties, vkGetPhysicalDeviceQueueFamilyProperties)(handle);
        foreach(i, family; queueFamilies)
        {
            VkBool32 canPresent;
            vkGetPhysicalDeviceSurfaceSupportKHR(handle, i.to!uint, surface, &canPresent);
        
            if((family.queueFlags & VK_QUEUE_GRAPHICS_BIT) && this.graphicsQueueIndex.isNull)
                this.graphicsQueueIndex = i.to!uint;
            else if(canPresent && this.presentQueueIndex.isNull)
                this.presentQueueIndex = i.to!uint;
        }

        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(handle, surface, &this.capabilities);
        this.formats = vkGetArrayJAST!(VkSurfaceFormatKHR, vkGetPhysicalDeviceSurfaceFormatsKHR)(handle, surface);
        this.presentModes = vkGetArrayJAST!(VkPresentModeKHR, vkGetPhysicalDeviceSurfacePresentModesKHR)(handle, surface);

        info("[Physical Device]");
        info("Extentions:");
        foreach(ext; this.extentions)
            infof("\t %s - v%s", ext.extensionName.ptr.asSlice, ext.specVersion);

        infof("Properties: %s",         this.properties.serializeToJsonPretty());
        infof("Features: %s",           this.features.serializeToJsonPretty());
        infof("GraphicsQueueIndex: %s", this.graphicsQueueIndex.get(-1));
        infof("PresentQueueIndex: %s",  this.presentQueueIndex.get(-1));
        infof("Capabilities: %s",       this.capabilities.serializeToJsonPretty());
        infof("Formats: %s",            this.formats.serializeToJsonPretty());
        infof("PresentModes: %s",       this.presentModes.serializeToJsonPretty());
    }

    bool setExtentions(ref VkStringArrayJAST wanted)
    {
        import std.algorithm : map;
        import std.range     : walkLength;

        this.enabledExtentions = wanted.filter(this.extentions.map!(e => e.extensionName.ptr.asSlice));
        return this.enabledExtentions.slices.length == wanted.slices.length;
    }
}

struct LogicalDevice
{
    mixin VkWrapperJAST!VkDevice;
    GraphicsQueue graphics;
    PresentQueue  present;

    this(PhysicalDevice gpu)
    {
        import std.conv : to;

        const graphicsIndex  = gpu.graphicsQueueIndex.get();
        const presentIndex   = gpu.presentQueueIndex.get();
        const uniqueIndicies = (graphicsIndex == presentIndex)
                               ? [graphicsIndex]
                               : [graphicsIndex, presentIndex];

        const priority = 1.0f;
        VkDeviceQueueCreateInfo[] queueCreateInfos;
        foreach(index; uniqueIndicies)
        {
            VkDeviceQueueCreateInfo info = 
            {
                queueFamilyIndex: index,
                queueCount:       1,
                pQueuePriorities: &priority
            };
            queueCreateInfos ~= info;
        }

        VkPhysicalDeviceFeatures features;
        // TODO:

        VkDeviceCreateInfo info = 
        {
            queueCreateInfoCount:       queueCreateInfos.length.to!uint,
            enabledLayerCount:          g_vkInstance.layers.ptrs.length.to!uint,
            enabledExtensionCount:      gpu.enabledExtentions.ptrs.length.to!uint,
            pEnabledFeatures:           &features,
            pQueueCreateInfos:          queueCreateInfos.ptr,
            ppEnabledLayerNames:        g_vkInstance.layers.ptrs.ptr,
            ppEnabledExtensionNames:    gpu.enabledExtentions.ptrs.ptr
        };

        CHECK_VK(vkCreateDevice(gpu, &info, null, &this.handle));
        loadDeviceLevelFunctions(this);

        this.graphics = GraphicsQueue(this, graphicsIndex);
        this.present  = PresentQueue(this, presentIndex);
    }
}