module game.vulkan.device;

import std.conv     : to;
import std.typecons : Nullable;
import std.experimental.logger;
import game.vulkan, erupted;

struct PhysicalDevice
{
    mixin VkWrapperJAST!(VkPhysicalDevice, VK_DEBUG_REPORT_OBJECT_TYPE_PHYSICAL_DEVICE_EXT);

    VkExtensionProperties[]     extentions;
    VkPhysicalDeviceProperties  properties;
    VkPhysicalDeviceFeatures    features;
    Nullable!int                graphicsQueueIndex;
    Nullable!int                presentQueueIndex;
    Nullable!int                transferQueueIndex;
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

        // Get misc data about the gpu.
        this.extentions = vkGetArrayJAST!(VkExtensionProperties, vkEnumerateDeviceExtensionProperties)(handle, null);
        vkGetPhysicalDeviceProperties(handle, &this.properties);
        vkGetPhysicalDeviceFeatures(handle, &this.features);

        // Find the queue families for graphics, present, and transfer.
        auto queueFamilies = vkGetArrayJAST!(VkQueueFamilyProperties, vkGetPhysicalDeviceQueueFamilyProperties)(handle);
        foreach(i, family; queueFamilies)
        {
            VkBool32 canPresent;
            vkGetPhysicalDeviceSurfaceSupportKHR(handle, i.to!uint, surface, &canPresent);
        
            if((family.queueFlags & VK_QUEUE_GRAPHICS_BIT) && this.graphicsQueueIndex.isNull)
                this.graphicsQueueIndex = i.to!uint;
            else if(canPresent && this.presentQueueIndex.isNull)
                this.presentQueueIndex = i.to!uint;
            
            if((family.queueFlags & VK_QUEUE_TRANSFER_BIT) && this.transferQueueIndex.isNull)
                this.transferQueueIndex = i.to!uint;
        }

        // Get colour support and present.
        this.updateCapabilities();
        this.formats = vkGetArrayJAST!(VkSurfaceFormatKHR, vkGetPhysicalDeviceSurfaceFormatsKHR)(handle, surface);
        this.presentModes = vkGetArrayJAST!(VkPresentModeKHR, vkGetPhysicalDeviceSurfacePresentModesKHR)(handle, surface);

        // Log information to console so I can examine things.
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

    void updateCapabilities()
    {
        vkGetPhysicalDeviceSurfaceCapabilitiesKHR(this, this.surface, &this.capabilities);
    }
}

struct LogicalDevice
{
    mixin VkWrapperJAST!(VkDevice, VK_DEBUG_REPORT_OBJECT_TYPE_DEVICE_EXT);
    GraphicsQueue graphics;
    PresentQueue  present;
    TransferQueue transfer;

    this(PhysicalDevice gpu)
    {
        import std.conv : to;
        import containers.hashset;

        // Create a queue for each unique family index.
        const graphicsIndex  = gpu.graphicsQueueIndex.get();
        const presentIndex   = gpu.presentQueueIndex.get();
        const transferIndex  = gpu.transferQueueIndex.get();
        auto  indexSet       = HashSet!int();
        indexSet.insert(graphicsIndex);
        indexSet.insert(presentIndex);
        indexSet.insert(transferIndex);

        const priority = 1.0f;
        VkDeviceQueueCreateInfo[] queueCreateInfos;
        foreach(index; indexSet)
        {
            VkDeviceQueueCreateInfo info = 
            {
                queueFamilyIndex: index,
                queueCount:       1,
                pQueuePriorities: &priority
            };
            queueCreateInfos ~= info;
        }

        // Define features we want to use.
        VkPhysicalDeviceFeatures features;
        // TODO:

        // Create the device.
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

        // Create the queues.
        this.graphics = GraphicsQueue(this, graphicsIndex);
        this.present  = PresentQueue(this, presentIndex);
        this.transfer = TransferQueue(this, transferIndex);
    }
}