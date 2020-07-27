module game.vulkan;

import std.experimental.logger, core.stdcpp.vector, std.typecons, std.file : fread = read;
import erupted, bindbc.sdl;
import game.graphics.window;

void CHECK_VK(VkResult result)
{
    import std.conv      : to;
    import std.exception : enforce;

    enforce(result == VkResult.VK_SUCCESS, result.to!string);
}

void CHECK_SDL(Args...)(Args)
{
    import std.string    : fromStringz;
    import std.exception : enforce;

    const error = SDL_GetError().fromStringz;
    enforce(error.length == 0, error);
}

bool contains(ref vector!(const(char)*) array, const(char)* text)
{
    import core.stdc.string : strcmp;

    foreach(arrayText; array)
    {
        if(strcmp(arrayText, text) == 0)
            return true;
    }

    return false;
}

Vulkan.VkStringArray getUseable(R)(ref Vulkan.VkStringArray wantedList, ref vector!R availableList, const(char)* delegate(ref R value) getName)
{
    import std.algorithm    : canFind;
    import core.stdc.string : strcmp;
    import std.string       : fromStringz;
    import std.exception    : enforce;

    auto wantedCopy = wantedList;
    auto newWanted  = Vulkan.VkStringArray(0);
    foreach(wanted; wantedCopy)
    {
        bool isAvailable = false;
        foreach(available; availableList)
        {
            if(strcmp(getName(available), (wanted[0] == ':') ? wanted + 1 : wanted) == 0)
            {
                isAvailable = true;
                break;
            }
        }

        if(wanted[0] == ':')
        {
            if(isAvailable)
            {
                info("Using OPTIONAL: ", wanted.fromStringz);
                newWanted.push_back(wanted + 1);
            }
            else
                infof("OPTIONAL %s not found", wanted.fromStringz);
        }
        else
        {
            enforce(isAvailable, "Missing REQUIRED: "~wanted.fromStringz);

            info("Using REQUIRED: ", wanted.fromStringz);
            newWanted.push_back(wanted);
        }
    }

    return newWanted;
}

struct QueueFamilyIndicies
{
    Nullable!uint graphics;
    Nullable!uint present;
}

struct VulkanDevice
{
    VkPhysicalDevice        physicalDevice;
    VkDevice                logicalDevice;
    QueueFamilyIndicies     queueFamilies;
    VkQueue                 graphicsQueue;
    VkQueue                 presentQueue;
    Vulkan.VkStringArray    enabledExtensions   = Vulkan.VkStringArray(0);
    Vulkan.VkStringArray    availableExtensions = Vulkan.VkStringArray(0);
}

struct SwapChainSupport
{
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR[]     formats;
    VkPresentModeKHR[]       presentModes;
}

struct SwapChain
{
    SwapChainSupport   support;
    VkSurfaceFormatKHR format;
    VkPresentModeKHR   presentMode;
    VkSwapchainKHR     handle;
    VkImage[]          images;
    VkImageView[]      imageViews;
}

final class Vulkan
{
    private static
    {
        alias VkArray(T)            = vector!T; // Using vector so I can accurately follow the C++ styled guides.
        alias VkStringArray         = VkArray!(const(char)*);
        alias VkExtInfoArray        = VkArray!(VkExtensionProperties);
        alias VkLayerInfoArray      = VkArray!(VkLayerProperties);
        alias VkPhysicalDeviceArray = VkArray!(VkPhysicalDevice);
        alias VkFrameBufferArray    = VkArray!(VkFramebuffer);

        const VkApplicationInfo APP_INFO =
        {
            sType:              VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pApplicationName:   "Farm Defense",
            applicationVersion: VK_MAKE_VERSION(1, 0, 0),
            pEngineName:        "None",
            engineVersion:      VK_MAKE_VERSION(1, 0, 0),
            apiVersion:         VK_API_VERSION_1_0
        };

        VkInstance              _instance;
        VkSurfaceKHR            _surface;
        VkStringArray           _extensions          = VkStringArray(0);
        VkStringArray           _layers              = VkStringArray(0);
        VkFrameBufferArray      _framebuffers        = VkFrameBufferArray(0);
        VulkanDevice            _graphicsDevice;
        VkExtInfoArray          _availableExtensions = VkExtInfoArray(0);
        VkPhysicalDeviceArray   _availableDevices    = VkPhysicalDeviceArray(0);
        VkLayerInfoArray        _availableLayers     = VkLayerInfoArray(0);
        SwapChain               _swapChain;
        VkPipelineLayout        _pipelineLayout;
        VkRenderPass            _renderPass;
        VkPipeline              _pipeline;
    }

    public static
    {
        void onInit()
        {
            import erupted.vulkan_lib_loader;

            info("Initialising Vulkan");
            loadGlobalLevelFunctions();

            // : = optional
            debug this._layers.push_back(":VK_LAYER_KHRONOS_validation".ptr);

            Vulkan.onInitLoadInstance();
            Vulkan.onInitCreateSurface();
            Vulkan.onInitLoadPhysicalDevice();
            Vulkan.onInitLoadLogicalDevice();
            Vulkan.onInitCreateSwapChain();
            Vulkan.onInitCreatePipeline();
            Vulkan.onInitCreateFramebuffers();
        }

        void onUninit()
        {
            info("Destroying Vulkan instance");

            foreach(framebuffer; this._framebuffers)
                vkDestroyFramebuffer(this._graphicsDevice.logicalDevice, framebuffer, null);

            vkDestroyPipeline(this._graphicsDevice.logicalDevice, this._pipeline, null);
            vkDestroyPipelineLayout(this._graphicsDevice.logicalDevice, this._pipelineLayout, VK_NULL_HANDLE);        
            vkDestroyRenderPass(this._graphicsDevice.logicalDevice, this._renderPass, VK_NULL_HANDLE);
            foreach(view; this._swapChain.imageViews)
                vkDestroyImageView(this._graphicsDevice.logicalDevice, view, VK_NULL_HANDLE);

            vkDestroySwapchainKHR(this._graphicsDevice.logicalDevice, this._swapChain.handle, VK_NULL_HANDLE);
            vkDestroyDevice(this._graphicsDevice.logicalDevice, VK_NULL_HANDLE);
            vkDestroySurfaceKHR(this._instance, this._surface, VK_NULL_HANDLE);
            vkDestroyInstance(this._instance, VK_NULL_HANDLE);
        }
    }

    // LOADING THE INSTANCE
    private static
    {
        void onInitLoadInstance()
        {
            Vulkan.onInitLoadAvailableExtensions();
            Vulkan.onInitLoadExtensions();
            Vulkan.onInitLoadAvailableLayers();
            Vulkan.onInitLoadLayers();

            VkInstanceCreateInfo createInfo;
            createInfo.sType                   = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO;
            createInfo.pApplicationInfo        = &APP_INFO;
            createInfo.enabledExtensionCount   = cast(uint)this._extensions.length;
            createInfo.ppEnabledExtensionNames = this._extensions.data();
            createInfo.enabledLayerCount       = cast(uint)this._layers.length;
            createInfo.ppEnabledLayerNames     = this._layers.data();

            CHECK_VK(vkCreateInstance(&createInfo, null, &this._instance));
            loadInstanceLevelFunctions(this._instance);
        }

        void onInitLoadExtensions()
        {
            import std.string : fromStringz;

            info("Loading Vulkan extensions");

            uint count;
            CHECK_SDL(SDL_Vulkan_GetInstanceExtensions(Window.handle, &count, null));

            this._extensions.resize(this._extensions.size() + count);
            auto ptr = this._extensions.data() + (this._extensions.length - count); // Skip over any predefined extensions.
            CHECK_SDL(SDL_Vulkan_GetInstanceExtensions(Window.handle, &count, ptr));

            foreach(ext; this._extensions)
                info("Using REQUIRED extension: ", ext.fromStringz);
        }

        void onInitLoadAvailableExtensions()
        {
            info("Loading list of all available Vulkan extensions");

            uint count;
            CHECK_VK(vkEnumerateInstanceExtensionProperties(VK_NULL_HANDLE, &count, VK_NULL_HANDLE));

            this._availableExtensions = VkExtInfoArray(count);
            CHECK_VK(vkEnumerateInstanceExtensionProperties(VK_NULL_HANDLE, &count, this._availableExtensions.data()));

            foreach(ext; this._availableExtensions)
                infof("Found: version %s of %s", ext.specVersion, ext.extensionName);
        }

        void onInitLoadAvailableLayers()
        {
            info("Loading list of all available Vulkan layers");

            uint count;
            CHECK_VK(vkEnumerateInstanceLayerProperties(&count, VK_NULL_HANDLE));

            this._availableLayers = VkLayerInfoArray(count);
            CHECK_VK(vkEnumerateInstanceLayerProperties(&count, this._availableLayers.data()));

            foreach(layer; this._availableLayers)
                infof("Found: version %s of %s", layer.specVersion, layer.layerName);
        }

        void onInitLoadLayers()
        {
            info("Loading Vulkan layers");
            this._layers = getUseable!VkLayerProperties(this._layers, this._availableLayers, (ref l) => l.layerName.ptr);
        }
    }

    // LOADING THE PHYSICAL DEVICE & SWAP CHAIN CONFIGURATION
    private static
    {
        void onInitLoadPhysicalDevice()
        {
            Vulkan.onInitLoadAvailableDevices();

            this._graphicsDevice.enabledExtensions.push_back("VK_KHR_swapchain".ptr);

            // Use the first one that meets our requirements
            foreach(device; this._availableDevices)
            {
                VkPhysicalDeviceProperties properties;
                VkPhysicalDeviceFeatures features;
                QueueFamilyIndicies families;
                vkGetPhysicalDeviceProperties(device, &properties);
                vkGetPhysicalDeviceFeatures(device, &features);
                families = Vulkan.findDeviceFamilyIndicies(device);

                uint extensionCount;
                CHECK_VK(vkEnumerateDeviceExtensionProperties(device, VK_NULL_HANDLE, &extensionCount, VK_NULL_HANDLE));

                auto extensions = VkExtInfoArray(extensionCount);
                CHECK_VK(vkEnumerateDeviceExtensionProperties(device, VK_NULL_HANDLE, &extensionCount, extensions.data()));

                // If an exception is thrown, then it's missing some required extension, so just continue.
                auto useableExtensions = VkStringArray(0);
                try useableExtensions = getUseable!VkExtensionProperties(this._graphicsDevice.enabledExtensions, extensions, (ref e) => e.extensionName.ptr);
                catch(Exception) continue;

                auto swapChain = Vulkan.findDeviceSwapChainSupport(device);

                const isSuitable = 
                    !families.graphics.isNull
                &&  !families.present.isNull
                &&   swapChain.formats.length > 0
                &&   swapChain.presentModes.length > 0;

                if(!isSuitable)
                    continue;

                infof("Selected Physical device %s with families %s as graphics device.", device, families);

                this._graphicsDevice.physicalDevice = device;
                this._graphicsDevice.queueFamilies  = families;
                this._swapChain.support             = swapChain;
            }

            assert(this._graphicsDevice.physicalDevice != VK_NULL_HANDLE, "No device found.");
            Vulkan.onInitChooseSwapChainSettings();
        }

        SwapChainSupport findDeviceSwapChainSupport(VkPhysicalDevice device)
        {
            SwapChainSupport support;
            CHECK_VK(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device, this._surface, &support.capabilities));

            uint count;
            CHECK_VK(vkGetPhysicalDeviceSurfaceFormatsKHR(device, this._surface, &count, VK_NULL_HANDLE));

            support.formats.length = count;
            CHECK_VK(vkGetPhysicalDeviceSurfaceFormatsKHR(device, this._surface, &count, support.formats.ptr));

            CHECK_VK(vkGetPhysicalDeviceSurfacePresentModesKHR(device, this._surface, &count, VK_NULL_HANDLE));
            support.presentModes.length = count;
            CHECK_VK(vkGetPhysicalDeviceSurfacePresentModesKHR(device, this._surface, &count, support.presentModes.ptr));            

            return support;
        }

        QueueFamilyIndicies findDeviceFamilyIndicies(VkPhysicalDevice device)
        {
            uint count;
            vkGetPhysicalDeviceQueueFamilyProperties(device, &count, VK_NULL_HANDLE);

            auto families = VkArray!VkQueueFamilyProperties(count);
            vkGetPhysicalDeviceQueueFamilyProperties(device, &count, families.data());

            QueueFamilyIndicies indicies;
            foreach(i, family; families)
            {
                if((family.queueFlags & VK_QUEUE_GRAPHICS_BIT) && indicies.graphics.isNull)
                    indicies.graphics = cast(uint)i;

                VkBool32 canPresent;
                vkGetPhysicalDeviceSurfaceSupportKHR(device, cast(uint)i, this._surface, &canPresent);

                if(canPresent)
                    indicies.present = cast(uint)i;
            }

            return indicies;
        }

        void onInitChooseSwapChainSettings()
        {
            this._swapChain.format = this._swapChain.support.formats[0];
            foreach(format; this._swapChain.support.formats)
            {
                if(format.format == VK_FORMAT_B8G8R8A8_SRGB
                && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                {
                    this._swapChain.format = format;
                    break;
                }
            }

            this._swapChain.presentMode = VK_PRESENT_MODE_FIFO_KHR;

            if(this._swapChain.support.capabilities.currentExtent.width == uint.max)
            {
                this._swapChain.support.capabilities.currentExtent.width  = Window.WIDTH;
                this._swapChain.support.capabilities.currentExtent.height = Window.HEIGHT;
            }
        }

        void onInitLoadAvailableDevices()
        {
            info("Loading all avaialable physical devices");

            uint count;
            CHECK_VK(vkEnumeratePhysicalDevices(this._instance, &count, VK_NULL_HANDLE));

            this._availableDevices = VkPhysicalDeviceArray(count);
            CHECK_VK(vkEnumeratePhysicalDevices(this._instance, &count, this._availableDevices.data()));
        }
    }

    // LOADING THE LOGICAL DEVICE
    private static
    {
        void onInitLoadLogicalDevice()
        {
            import std.algorithm : canFind;

            info("Loading logical device and queues");

            const priorities = 1.0f;

            VkDeviceQueueCreateInfo[] queueInfos;
            uint[] uniqueQueueIndicies;

            uniqueQueueIndicies ~= this._graphicsDevice.queueFamilies.graphics.get();
            const presentIndex = this._graphicsDevice.queueFamilies.present.get();
            if(!uniqueQueueIndicies.canFind(presentIndex))
                uniqueQueueIndicies ~= presentIndex;

            foreach(index; uniqueQueueIndicies)
            {
                VkDeviceQueueCreateInfo queueInfo;
                queueInfo.sType            = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO;
                queueInfo.queueFamilyIndex = index;
                queueInfo.queueCount       = 1;
                queueInfo.pQueuePriorities = &priorities;

                queueInfos ~= queueInfo;
            }

            VkPhysicalDeviceFeatures deviceFeatures;

            VkDeviceCreateInfo deviceInfo;
            deviceInfo.sType                   = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO;
            deviceInfo.pQueueCreateInfos       = queueInfos.ptr;
            deviceInfo.queueCreateInfoCount    = cast(uint)queueInfos.length;
            deviceInfo.pEnabledFeatures        = &deviceFeatures;
            deviceInfo.enabledLayerCount       = cast(uint)this._layers.length;
            deviceInfo.ppEnabledLayerNames     = this._layers.data();
            deviceInfo.enabledExtensionCount   = cast(uint)this._graphicsDevice.enabledExtensions.length;
            deviceInfo.ppEnabledExtensionNames = this._graphicsDevice.enabledExtensions.data();

            CHECK_VK(vkCreateDevice(this._graphicsDevice.physicalDevice, &deviceInfo, VK_NULL_HANDLE, &this._graphicsDevice.logicalDevice));
            loadDeviceLevelFunctions(this._graphicsDevice.logicalDevice);

            vkGetDeviceQueue(
                this._graphicsDevice.logicalDevice, 
                this._graphicsDevice.queueFamilies.graphics.get(), 
                0, 
                &this._graphicsDevice.graphicsQueue
            );

            vkGetDeviceQueue(
                this._graphicsDevice.logicalDevice, 
                this._graphicsDevice.queueFamilies.present.get(), 
                0, 
                &this._graphicsDevice.presentQueue
            );
        }
    }

    // CREATING THE MAIN SURFACE
    private static
    {
        void onInitCreateSurface()
        {
            info("Creating Vulkan Surface");

            CHECK_SDL(SDL_Vulkan_CreateSurface(Window.handle, this._instance, &this._surface));
        }
    }

    // CREATING THE SWAP CHAIN
    private static
    {
        void onInitCreateSwapChain()
        {
            info("Creating Vulkan swap chain with settings: ", this._swapChain);

            const imageCount = this._swapChain.support.capabilities.minImageCount + 1;

            VkSwapchainCreateInfoKHR createInfo;
            createInfo.sType            = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
            createInfo.surface          = this._surface;
            createInfo.minImageCount    = imageCount;
            createInfo.imageFormat      = this._swapChain.format.format;
            createInfo.imageColorSpace  = this._swapChain.format.colorSpace;
            createInfo.imageExtent      = this._swapChain.support.capabilities.currentExtent;
            createInfo.imageArrayLayers = 1;
            createInfo.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;

            uint[2] indicies = [this._graphicsDevice.queueFamilies.graphics.get(), this._graphicsDevice.queueFamilies.present.get()];
            if(this._graphicsDevice.queueFamilies.graphics != this._graphicsDevice.queueFamilies.present)
            {
                createInfo.imageSharingMode      = VK_SHARING_MODE_CONCURRENT;
                createInfo.queueFamilyIndexCount = 2;
                createInfo.pQueueFamilyIndices   = indicies.ptr;
            }
            else
                createInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

            createInfo.preTransform   = this._swapChain.support.capabilities.currentTransform;
            createInfo.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
            createInfo.presentMode    = this._swapChain.presentMode;
            createInfo.clipped        = VK_TRUE;
            createInfo.oldSwapchain   = VK_NULL_HANDLE;

            CHECK_VK(vkCreateSwapchainKHR(this._graphicsDevice.logicalDevice, &createInfo, null, &this._swapChain.handle));

            uint count;
            CHECK_VK(vkGetSwapchainImagesKHR(this._graphicsDevice.logicalDevice, this._swapChain.handle, &count, null));

            this._swapChain.images.length = count;
            CHECK_VK(vkGetSwapchainImagesKHR(this._graphicsDevice.logicalDevice, this._swapChain.handle, &count, this._swapChain.images.ptr));

            Vulkan.onInitCreateImageViews();
        }

        void onInitCreateImageViews()
        {
            this._swapChain.imageViews.length = this._swapChain.images.length;

            foreach(i, image; this._swapChain.images)
            {
                VkImageViewCreateInfo createInfo;
                createInfo.sType                            = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
                createInfo.image                            = image;
                createInfo.viewType                         = VK_IMAGE_VIEW_TYPE_2D;
                createInfo.format                           = this._swapChain.format.format;
                createInfo.components.r                     = VK_COMPONENT_SWIZZLE_IDENTITY;
                createInfo.components.g                     = VK_COMPONENT_SWIZZLE_IDENTITY;
                createInfo.components.b                     = VK_COMPONENT_SWIZZLE_IDENTITY;
                createInfo.components.a                     = VK_COMPONENT_SWIZZLE_IDENTITY;
                createInfo.subresourceRange.aspectMask      = VK_IMAGE_ASPECT_COLOR_BIT;
                createInfo.subresourceRange.baseMipLevel    = 0;
                createInfo.subresourceRange.levelCount      = 1;
                createInfo.subresourceRange.baseArrayLayer  = 0;
                createInfo.subresourceRange.layerCount      = 1;

                CHECK_VK(vkCreateImageView(this._graphicsDevice.logicalDevice, &createInfo, null, &this._swapChain.imageViews[i]));
            }
        }
    }

    // CREATING THE PIPELINE
    private static
    {
        void onInitCreatePipeline()
        {
            auto shaders = Vulkan.onInitCreateShaders();
            auto stages  = Vulkan.onInitCreateShaderStages(shaders);

            VkPipelineVertexInputStateCreateInfo vertInfo;
            vertInfo.vertexBindingDescriptionCount   = 0;
            vertInfo.vertexAttributeDescriptionCount = 0;

            VkPipelineInputAssemblyStateCreateInfo inputInfo;
            inputInfo.topology               = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
            inputInfo.primitiveRestartEnable = VK_FALSE;

            VkViewport viewport;
            viewport.x          = 0.0f;
            viewport.y          = 0.0f;
            viewport.width      = cast(float)this._swapChain.support.capabilities.currentExtent.width;
            viewport.height     = cast(float)this._swapChain.support.capabilities.currentExtent.height;
            viewport.minDepth   = 0.0f;
            viewport.maxDepth   = 1.0f;

            VkRect2D scissor;
            scissor.offset = VkOffset2D(0, 0);
            scissor.extent = this._swapChain.support.capabilities.currentExtent;

            VkPipelineViewportStateCreateInfo viewInfo;
            viewInfo.viewportCount = 1;
            viewInfo.scissorCount  = 1;
            viewInfo.pViewports    = &viewport;
            viewInfo.pScissors     = &scissor;

            VkPipelineRasterizationStateCreateInfo rasterMouse;
            rasterMouse.depthClampEnable        = VK_FALSE;
            rasterMouse.rasterizerDiscardEnable = VK_FALSE;
            rasterMouse.polygonMode             = VK_POLYGON_MODE_FILL;
            rasterMouse.lineWidth               = 1.0f;
            rasterMouse.cullMode                = VK_CULL_MODE_BACK_BIT;
            rasterMouse.frontFace               = VK_FRONT_FACE_CLOCKWISE;
            rasterMouse.depthBiasEnable         = VK_FALSE;
            rasterMouse.depthBiasClamp          = 0.0f;

            VkPipelineMultisampleStateCreateInfo aaInfo;
            aaInfo.sampleShadingEnable  = VK_FALSE;
            aaInfo.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

            VkPipelineColorBlendAttachmentState blending;
            blending.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
            blending.blendEnable    = VK_FALSE;

            VkPipelineColorBlendStateCreateInfo globalBlending;
            globalBlending.logicOpEnable   = VK_FALSE;
            globalBlending.attachmentCount = 1;
            globalBlending.pAttachments    = &blending;

            VkPipelineLayoutCreateInfo layoutInfo;
            CHECK_VK(vkCreatePipelineLayout(this._graphicsDevice.logicalDevice, &layoutInfo, null, &this._pipelineLayout));

            Vulkan.onInitCreateRenderPass();

            VkGraphicsPipelineCreateInfo pipeline;
            pipeline.stageCount             = 2;
            pipeline.pStages                = stages.ptr;
            pipeline.pVertexInputState      = &vertInfo;
            pipeline.pInputAssemblyState    = &inputInfo;
            pipeline.pViewportState         = &viewInfo;
            pipeline.pRasterizationState    = &rasterMouse;
            pipeline.pMultisampleState      = &aaInfo;
            pipeline.pColorBlendState       = &globalBlending;
            pipeline.layout                 = this._pipelineLayout;
            pipeline.renderPass             = this._renderPass;
            pipeline.subpass                = 0;

            CHECK_VK(vkCreateGraphicsPipelines(this._graphicsDevice.logicalDevice, null, 1, &pipeline, null, &this._pipeline));

            vkDestroyShaderModule(this._graphicsDevice.logicalDevice, shaders[0], null);
            vkDestroyShaderModule(this._graphicsDevice.logicalDevice, shaders[1], null);
        }

        VkShaderModule[2] onInitCreateShaders()
        {
            auto fragCode = cast(ubyte[])fread("./resources/shaders/shader.spv.frag");
            auto vertCode = cast(ubyte[])fread("./resources/shaders/shader.spv.vert");

            // Align to 4 bytes
            if(fragCode.length % 4 != 0)
                fragCode.length += (fragCode.length % 4);
            if(vertCode.length % 4 != 0)
                vertCode.length += (vertCode.length % 4);

            ubyte[][2] codes = [fragCode, vertCode];
            VkShaderModule[2] modules;

            foreach(i, ref code; codes)
            {
                VkShaderModuleCreateInfo shaderInfo;
                shaderInfo.codeSize = code.length; // In bytes
                shaderInfo.pCode    = cast(uint*)code.ptr; // But we pass it as a uint* because reasons.

                CHECK_VK(vkCreateShaderModule(this._graphicsDevice.logicalDevice, &shaderInfo, null, &modules[i]));
            }

            return modules;
        }

        VkPipelineShaderStageCreateInfo[2] onInitCreateShaderStages(ref VkShaderModule[2] shaders)
        {
            VkPipelineShaderStageCreateInfo[2] toReturn;
            
            foreach(i, ref shader; shaders)
            {
                scope info   = &toReturn[i];
                info.stage   = (i == 0) ? VK_SHADER_STAGE_FRAGMENT_BIT : VK_SHADER_STAGE_VERTEX_BIT;
                info.module_ = shaders[i];
                info.pName   = "main";
            }

            return toReturn;
        }

        void onInitCreateRenderPass()
        {
            VkAttachmentDescription colour;
            colour.format  = this._swapChain.format.format;
            colour.samples = VK_SAMPLE_COUNT_1_BIT;
            colour.loadOp  = VK_ATTACHMENT_LOAD_OP_CLEAR;
            colour.storeOp = VK_ATTACHMENT_STORE_OP_STORE;
            colour.stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            colour.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
            colour.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
            colour.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;

            VkAttachmentReference colourRef;
            colourRef.attachment = 0;
            colourRef.layout     = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;

            VkSubpassDescription subpass;
            subpass.pipelineBindPoint    = VK_PIPELINE_BIND_POINT_GRAPHICS;
            subpass.colorAttachmentCount = 1;
            subpass.pColorAttachments    = &colourRef;

            VkRenderPassCreateInfo passInfo;
            passInfo.attachmentCount = 1;
            passInfo.pAttachments    = &colour;
            passInfo.subpassCount    = 1;
            passInfo.pSubpasses      = &subpass;

            CHECK_VK(vkCreateRenderPass(this._graphicsDevice.logicalDevice, &passInfo, null, &this._renderPass));
        }
    }

    // CREATING THE FRAMEBUFFERS
    private static
    {
        void onInitCreateFramebuffers()
        {
            this._framebuffers.resize(this._swapChain.imageViews.length);
            foreach(i, imageView; this._swapChain.imageViews)
            {
                VkImageView[1] attachments = 
                [
                    imageView
                ];

                VkFramebufferCreateInfo info;
                info.renderPass         = this._renderPass;
                info.attachmentCount    = attachments.length;
                info.pAttachments       = attachments.ptr;
                info.width              = this._swapChain.support.capabilities.currentExtent.width;
                info.height             = this._swapChain.support.capabilities.currentExtent.height;
                info.layers             = 1;

                CHECK_VK(vkCreateFramebuffer(this._graphicsDevice.logicalDevice, &info, null, &this._framebuffers[i]));
            }
        }
    }
}