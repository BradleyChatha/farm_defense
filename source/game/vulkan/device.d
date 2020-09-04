module game.vulkan.device;

import std.conv     : to;
import std.typecons : Nullable, Flag;
import std.experimental.logger;
import game.vulkan, erupted;

struct DeviceMemoryType
{
    VkMemoryType type;
    uint         index;
}

struct PhysicalDevice
{
    mixin VkWrapperJAST!VkPhysicalDevice;

    VkExtensionProperties[]             extentions;
    VkLayerProperties[]                 layers;
    VkPhysicalDeviceProperties          properties;
    VkPhysicalDeviceFeatures            features;
    VkPhysicalDeviceMemoryProperties    memoryProperties;
    Nullable!int                        graphicsQueueIndex;
    Nullable!int                        presentQueueIndex;
    Nullable!int                        transferQueueIndex;
    VkSurfaceCapabilitiesKHR            capabilities;
    VkSurfaceFormatKHR[]                formats;
    VkPresentModeKHR[]                  presentModes;
    Surface                             surface;
    VkStringArrayJAST                   enabledExtentions;

    this(VkPhysicalDevice handle, Surface surface)
    {
        import asdf;

        this.handle  = handle;
        this.surface = surface;

        // Get misc data about the gpu.
        this.extentions = vkGetArrayJAST!(VkExtensionProperties, vkEnumerateDeviceExtensionProperties)(handle, null);
        this.layers     = vkGetArrayJAST!(VkLayerProperties, vkEnumerateDeviceLayerProperties)(handle);
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

        // Get memory properties.
        vkGetPhysicalDeviceMemoryProperties(handle, &this.memoryProperties);

        // Log information to console so I can examine things.
        info("[Physical Device]");
        info("Extentions:");
        foreach(ext; this.extentions)
            infof("\t %s - v%s", ext.extensionName.ptr.asSlice, ext.specVersion);

        info("Layers:");
        foreach(lay; this.layers)
            infof("\t %s", lay.layerName.ptr.asSlice);

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

    DeviceMemoryType getMemoryType(VkMemoryPropertyFlags flags)
    {
        DeviceMemoryType bestFit;

        foreach(i, type; this.memoryProperties.memoryTypes[0..this.memoryProperties.memoryTypeCount])
        {
            if((type.propertyFlags & flags) == flags)
            {
                if(bestFit == DeviceMemoryType.init
                || type.propertyFlags == flags)
                {
                    bestFit.type  = type;
                    bestFit.index = i.to!uint;
                }
            }
        }

        if(bestFit != DeviceMemoryType.init)
            return bestFit;

        throw new Exception("GPU not supported.");
    }
}

struct LogicalDevice
{
    mixin VkWrapperJAST!VkDevice;
    GraphicsQueue* graphics;
    PresentQueue*  present;
    TransferQueue* transfer;

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
        this.graphics = new GraphicsQueue(this, graphicsIndex);
        this.present  = new PresentQueue(this, presentIndex);
        this.transfer = new TransferQueue(this, transferIndex);
    }
}