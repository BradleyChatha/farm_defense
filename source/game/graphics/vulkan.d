module game.graphics.vulkan;

import std.conv : to;
import std.string : fromStringz;
import std.typecons : Flag, Nullable;
import std.experimental.logger;
import erupted, erupted.vulkan_lib_loader, bindbc.sdl;
import game.graphics.window, game.graphics.sdl, game.common.util, game.graphics.renderer;

// ALIASES //
alias VulkanIsOptional    = Flag!"IsVulkanThingOptional";
alias VulkanIsPrimary     = Flag!"primaryYesSecondaryNo";
alias VulkanStartSignaled = Flag!"startSignaled";
alias VkString            = const(char)*;

// FREE STANDING HELPER FUNCS //
void CHECK_VK(VkResult result)
{
    import std.conv      : to;
    import std.exception : enforce;

    enforce(result == VkResult.VK_SUCCESS, result.to!string);
}

// CUSTOM DATA TYPES //
struct VulkanOptionalString
{
    string           name;
    VulkanIsOptional isOptional;

    this(const(char)* name, VulkanIsOptional isOptional)
    {
        this.isOptional = isOptional;
        this.name       = name.fromStringz().idup;
    }
}

struct VulkanResourceArray(T)
{
    import std.traits : isPointer;

    T[] data;
    alias data this;

    void cleanup(void delegate(T) func)
    {
        info("Cleaning up ", T.stringof);
        foreach(value; this.data)
            func(value);

        // Keep the previous data so we can overwrite it, without losing the memory address
        static if(!isPointer!T)
            this.data.length = 0;
    }

    static if(isPointer!T)
    {
        void recreate(void delegate(T) func)
        {
            info("Recreating ", T.stringof);
            foreach(value; this.data)
                func(value);
        }
    }
}

// VULKAN WRAPPER TYPES // These wrappers are thin PoD structs around Vulkan resources, abstractions are for a higher level part of the codebase //

struct VulkanToggleableProperties(T)
{
    VulkanOptionalString[] wanted;
    T[]                    available;
    T[]                    enabled;
    const(char)*[]         enabledRaw;
}
alias VulkanLayerInfo     = VulkanToggleableProperties!VkLayerProperties;
alias VulkanExtensionInfo = VulkanToggleableProperties!VkExtensionProperties;

struct VulkanInstance
{
    VulkanLayerInfo      layers;
    VulkanExtensionInfo  extensions;
    VkInstance           handle;
}

struct VulkanSurface
{
    VkSurfaceKHR handle;
}

struct VulkanQueue
{
    Nullable!int familyIndex;
    VkQueue      handle;
}

struct VulkanSwapChainSupport
{
    VkSurfaceCapabilitiesKHR capabilities;
    VkSurfaceFormatKHR[]     formats;
    VkPresentModeKHR[]       presentModes;
}

struct VulkanPhysicalDevice
{
    VkPhysicalDevice            handle;
    VulkanExtensionInfo         extensions;
    VkPhysicalDeviceProperties  properties;
    VkPhysicalDeviceFeatures    features;
    VulkanQueue                 graphicsQueue; // Handle is always invalid.
    VulkanQueue                 presentQueue;  // Handle is always invalid.
    VulkanSwapChainSupport      swapchainSupport;
}

struct VulkanLogicalDevice
{
    VkDevice          handle;
    VulkanQueue       graphicsQueue;
    VulkanQueue       presentQueue;
    VulkanCommandPool graphicsPool; // This is just a default one, I can of course allocate seperate ones as needed.
}

struct VulkanDevice
{
    VulkanPhysicalDevice* physical;
    VulkanLogicalDevice*  logical;
}

struct VulkanImage
{
    VkImage            handle;
    VkSurfaceFormatKHR format;
    VkExtent2D         extent;
    VulkanSwapchain*   swapchain;
}

enum VulkanImageViewType
{
    colour2D
}

struct VulkanImageView
{
    VkImageView         handle;
    VulkanImageViewType type;
    VulkanSwapchain*    swapchain;

    VulkanImageView* delegate() recreateFunc;
}

struct VulkanSwapchain
{
    VkSwapchainKHR         handle;
    VulkanDevice           device;
    VkSurfaceFormatKHR     format;
    VkPresentModeKHR       presentMode;
    VkExtent2D             extent;
    VulkanImage*[]         images;
    VulkanImageView*[]     imageColourViews;
    VulkanFramebuffer*[]   framebuffers;
    VulkanCommandBuffer*[] graphicsBuffers;
    VulkanSemaphore[]      imageAvailableSemaphores;
    VulkanSemaphore[]      renderFinishedSemaphores;
    VulkanFence[]          fences;

    VulkanSwapchain* delegate() recreateFunc;
}

enum VulkanShaderType
{
    vertex   = VK_SHADER_STAGE_VERTEX_BIT,
    fragment = VK_SHADER_STAGE_FRAGMENT_BIT
}

struct VulkanShaderModule
{
    VkShaderModule                  handle;
    VulkanShaderType                type;
    VkPipelineShaderStageCreateInfo stage;
    VulkanDevice                    device;
}

struct VulkanRenderPass
{
    VkRenderPass handle;
    VulkanDevice device;
}

struct VulkanPipelineLayout
{
    VkPipelineLayout handle;
}

struct VulkanPipeline
{
    VkPipeline           handle;
    VulkanPipelineLayout layout;
    VulkanRenderPass     renderPass;
    VulkanDevice         device;

    VulkanPipeline* delegate() recreateFunc;
}

struct VulkanFramebuffer
{
    VkFramebuffer   handle;
    VulkanPipeline* pipeline;
    VulkanDevice    device;

    VulkanFramebuffer* delegate() recreateFunc;
}

struct VulkanCommandPool
{
    VkCommandPool handle;
    VulkanDevice  device;
}

struct VulkanCommandBuffer
{
    VkCommandBuffer handle;
}

struct VulkanSemaphore
{
    VkSemaphore  handle;
    VulkanDevice device;
}

struct VulkanFence
{
    VkFence      handle;
    VulkanDevice device;
}

enum VulkanBufferType
{
    error,
    vertex
}

struct VulkanBuffer
{
    VkBuffer           handle;
    VulkanDevice       device;
    VulkanBufferType   type;
    VulkanDeviceMemory memory;
}

struct VulkanDeviceMemory
{
    VkDeviceMemory handle;
    VulkanDevice   device;
    size_t         size;
}

// Pipeline builder //

struct VulkanPipelineBuilder
{
    static struct Subpass
    {
        VkAttachmentReference[] colourRefs;
        VkSubpassDescription    info;
    }

    static struct SubpassBuilder
    {
        VulkanPipelineBuilder parent;
        Subpass               subpass;
        size_t                index;

        this(VulkanPipelineBuilder parent, size_t index)
        {
            this.parent = parent;
            this.subpass.info.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS;
            this.index = index;
        }

        SubpassBuilder usesAttachment(uint index)
        {
            assert(index < this.parent._attachments.length);

            VkAttachmentReference attachRef;
            attachRef.attachment = index;

            final switch(this.parent._attachments[index].type) with(AttachmentType)
            {
                case colour: 
                    attachRef.layout         = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL; 
                    this.subpass.colourRefs ~= attachRef;
                    break;
            }

            return this;
        }

        VulkanPipelineBuilder end()
        {
            this.parent._subpasses ~= this.subpass;
            return this.parent;
        }
    }

    static enum AttachmentType
    {
        colour
    }

    static struct Attachment
    {
        VkAttachmentDescription info;
        AttachmentType          type;
    }

    static struct AttachmentBuilder
    {
        VulkanPipelineBuilder parent;
        Attachment            attachment;

        this(VulkanPipelineBuilder parent)
        {
            this.parent = parent;

            this.attachment.info.format         = this.parent._swapchain.format.format;
            this.attachment.info.samples        = VK_SAMPLE_COUNT_1_BIT;
            this.attachment.info.loadOp         = VK_ATTACHMENT_LOAD_OP_CLEAR;
            this.attachment.info.storeOp        = VK_ATTACHMENT_STORE_OP_STORE;
            this.attachment.info.stencilLoadOp  = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
            this.attachment.info.stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE;
            this.attachment.info.initialLayout  = VK_IMAGE_LAYOUT_UNDEFINED;
            this.attachment.info.finalLayout    = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
        }

        AttachmentBuilder usedForColour()
        {
            this.attachment.type = AttachmentType.colour;
            return this;
        }

        AttachmentBuilder endsAsPresent()
        {
            this.attachment.info.finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
            return this;
        }

        VulkanPipelineBuilder end()
        {
            this.parent._attachments ~= this.attachment;
            return this.parent;
        }
    }

    static struct RasterizerConfigurator
    {
        VulkanPipelineBuilder parent;

        VulkanPipelineBuilder end()
        {
            return this.parent;
        }
    }

    static struct Dependency
    {
        VkSubpassDependency value;
    }

    static struct DependencyBuilder
    {
        VulkanPipelineBuilder parent;
        Dependency            value;

        DependencyBuilder subpass(uint destSubpass)
        {
            this.value.value.dstSubpass = destSubpass;
            return this;
        }

        DependencyBuilder dependsOn(uint sourceSubpass)
        {
            this.value.value.srcSubpass = sourceSubpass;
            return this;
        }

        DependencyBuilder waitUntilSourceColourAvailable()
        {
            this.value.value.srcStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            this.value.value.srcAccessMask = 0;
            return this;
        }

        DependencyBuilder waitUntilSubpassColourWritable()
        {
            this.value.value.dstStageMask  = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
            this.value.value.dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            return this;
        }

        VulkanPipelineBuilder end()
        {
            this.parent._dependencies ~= this.value;
            return this.parent;
        }
    }

    private
    {
        VulkanSwapchain*    _swapchain;
        Attachment[]        _attachments;
        Subpass[]           _subpasses;
        Dependency[]        _dependencies;
        VulkanShaderModule  _vertexShader;
        VulkanShaderModule  _fragmentShader;

        VkPipelineInputAssemblyStateCreateInfo _inputAssemblyInfo;
        VkViewport                             _viewport;
        VkRect2D                               _scissor;
        VkPipelineRasterizationStateCreateInfo _rasterInfo;
        VkPipelineColorBlendStateCreateInfo    _blending;
    }

    this(VulkanSwapchain* swapchain)
    {
        assert(swapchain !is null);
        this._swapchain = swapchain;

        // Set defaults
        this._inputAssemblyInfo.primitiveRestartEnable = VK_FALSE;

        this._viewport.minDepth = 0.0f;
        this._viewport.maxDepth = 1.0f;

        this._rasterInfo.depthClampEnable        = VK_FALSE;
        this._rasterInfo.rasterizerDiscardEnable = VK_FALSE;
        this._rasterInfo.polygonMode             = VK_POLYGON_MODE_FILL;
        this._rasterInfo.lineWidth               = 1.0f;
        this._rasterInfo.cullMode                = VK_CULL_MODE_BACK_BIT;
        this._rasterInfo.frontFace               = VK_FRONT_FACE_CLOCKWISE;
        this._rasterInfo.depthBiasEnable         = VK_FALSE;
        this._rasterInfo.depthBiasClamp          = 0.0f;

        this._blending.logicOpEnable             = VK_FALSE;

        this._scissor.extent                     = swapchain.extent;
    }

    size_t toHash() const @safe pure nothrow
    {
        enum PRIME_NUMBER = 31;

        // WARNING: If any of the builders ever populate any of the pointer fields
        //          then this function must be updated to ignore them.

        size_t hash;
        hash = cast(size_t)this._swapchain; // There will only ever be one Swapchain* per swapchain, so this is a safe assumption to hash with.
        foreach(attach; this._attachments)
        {
            hash = (hash * PRIME_NUMBER) + (cast(uint)attach.type * 10 * this._attachments.length);
            hash = (hash * PRIME_NUMBER) + attach.info.hashOf;
        }

        foreach(subpass; this._subpasses)
        {
            hash = (hash * PRIME_NUMBER) + (subpass.info.hashOf * this._subpasses.length);
            
            foreach(attach; subpass.colourRefs)
                hash = (hash * PRIME_NUMBER) + (attach.attachment * this._attachments.length);
        }

        hash = (hash * PRIME_NUMBER) + this._inputAssemblyInfo.hashOf;
        hash = (hash * PRIME_NUMBER) + cast(size_t)((this._viewport.width + this._viewport.height * PRIME_NUMBER) * (this._viewport.x + this._viewport.y + 1)) * PRIME_NUMBER;
        hash = (hash * PRIME_NUMBER) + ((this._scissor.offset.x + this._scissor.offset.y * PRIME_NUMBER) * (this._scissor.extent.width + this._scissor.extent.height + 1)) * PRIME_NUMBER;
        hash = (hash * PRIME_NUMBER) + this._rasterInfo.hashOf;
        hash = (hash * PRIME_NUMBER) + this._blending.hashOf;
        hash = (hash * PRIME_NUMBER) + cast(size_t)this._vertexShader.handle * 10;
        hash = (hash * PRIME_NUMBER) + cast(size_t)this._fragmentShader.handle * 1000;

        return hash;
    }

    AttachmentBuilder startAttachment(size_t expectedIndex)
    {
        assert(expectedIndex == this._attachments.length);
        return AttachmentBuilder(this);
    }

    SubpassBuilder startSubpass()
    {
        return SubpassBuilder(this, this._subpasses.length);
    }

    DependencyBuilder startDependency()
    {
        return DependencyBuilder(this);
    }

    RasterizerConfigurator configRasterizer()
    {
        return RasterizerConfigurator(this);
    }

    VulkanPipelineBuilder drawsTriangles()
    {
        this._inputAssemblyInfo.topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST;
        return this;
    }

    VulkanPipelineBuilder setViewport(float x, float y, float width, float height)
    {
        this._viewport.x      = x;
        this._viewport.y      = y;
        this._viewport.width  = width;
        this._viewport.height = height;

        return this;
    }

    VulkanPipelineBuilder setScissor(int x, int y, uint width, uint height)
    {
        this._scissor.offset.x      = x;
        this._scissor.offset.y      = y;
        this._scissor.extent.width  = width;
        this._scissor.extent.height = height;

        return this;
    }

    VulkanPipelineBuilder setVertexShader(VulkanShaderModule shader)
    {
        assert(shader.type == VulkanShaderType.vertex);
        this._vertexShader = shader;
        return this;
    }

    VulkanPipelineBuilder setFragmentShader(VulkanShaderModule shader)
    {
        assert(shader.type == VulkanShaderType.fragment);
        this._fragmentShader = shader;
        return this;
    }

    private VkRenderPassCreateInfo makeRenderPassInfo()
    {
        VkRenderPassCreateInfo    info;
        VkAttachmentDescription[] attachments;
        VkSubpassDescription[]    subpasses;
        VkSubpassDependency[]     dependencies;

        attachments.length = this._attachments.length;
        foreach(i, attach; this._attachments)
            attachments[i] = attach.info;

        subpasses.length = this._subpasses.length;
        foreach(i, subpass; this._subpasses)
        {
            subpass.info.colorAttachmentCount = subpass.colourRefs.length.to!uint;
            subpass.info.pColorAttachments    = subpass.colourRefs.ptr;
            subpasses[i]                      = subpass.info;
        }

        dependencies.length = this._dependencies.length;
        foreach(i, dep; this._dependencies)
            dependencies[i] = dep.value;

        info.attachmentCount = attachments.length.to!uint;
        info.subpassCount    = subpasses.length.to!uint;
        info.dependencyCount = dependencies.length.to!uint;
        info.pAttachments    = attachments.ptr;
        info.pSubpasses      = subpasses.ptr;
        info.pDependencies   = dependencies.ptr;

        return info;
    }
}

// STATIC CLASSES //
// VulkanInit      = Functions containing init routines
// VulkanResources = Responsible for creating, tracking, and destroying resources
// Vulkan          = Anything that doesn't fit above, also provides access to special values (e.g. the Window's surface).

final class Vulkan
{
    private static
    {
    }

    public static
    {
        void onInit()
        {
            debug VulkanResources.addInstanceLayer(VulkanOptionalString("VK_LAYER_KHRONOS_validation", VulkanIsOptional.yes));

            info("Initialising Vulkan");
            VulkanInit.onPreInit();
            VulkanInit.loadExtensions();
            VulkanInit.loadLayers();
            VulkanResources.createInstance();
            auto windowSurface   = VulkanResources.createWindowSurface();
            auto physicalDevices = VulkanInit.loadPhysicalDevices(windowSurface);
            auto physicalDevice  = VulkanInit.chooseBestGraphicsDevice(physicalDevices);
            auto gpuDevice       = VulkanResources.createDevice(physicalDevice);
            auto swapchain       = VulkanResources.createSwapchain(gpuDevice, windowSurface);

            VulkanShaderModule defaultFragShader;
            VulkanShaderModule defaultVertShader;
            VulkanInit.loadDefaultShaderModules(gpuDevice, Ref(defaultVertShader), Ref(defaultFragShader));

            auto defaultPipeline = 
                VulkanPipelineBuilder(swapchain)
                .startAttachment(0)
                    .usedForColour()
                    .endsAsPresent()
                .end()
                .startSubpass()
                    .usesAttachment(0)
                .end()
                .startDependency()
                    .subpass(0)
                    .dependsOn(VK_SUBPASS_EXTERNAL)
                    .waitUntilSourceColourAvailable()
                    .waitUntilSubpassColourWritable()
                .end()
                .drawsTriangles()
                .setViewport(0, 0, 0, 0)
                .setVertexShader(defaultVertShader)
                .setFragmentShader(defaultFragShader);

            auto pipeline = VulkanResources.createPipeline(defaultPipeline);
            VulkanResources.createSwapchainFramebuffers(swapchain, pipeline);
            VulkanResources.createDeviceCommandPools(gpuDevice);
            VulkanResources.allocateSwapchainCommandBuffers(swapchain, gpuDevice.logical.graphicsPool);
            VulkanResources.createSwapchainSemaphoresAndFences(swapchain);

            auto vertBuffer = VulkanResources.createBuffer(gpuDevice, VulkanBufferType.vertex, 4096);
            RendererResources.onPostVulkanInit(
                swapchain,
                pipeline,
                vertBuffer
            );
        }

        void onUninit()
        {
            info("Uninitialising Vulkan");
            VulkanResources.onUninit();
        }

        void waitUntilAllDevicesAreIdle()
        {
            foreach(device; VulkanResources._logicalDevices)
                vkDeviceWaitIdle(device.handle);
        }
    }
}

final class VulkanResources
{
    private static
    {
        // If we make something a pointer, then its something that has to be recreated with a swapchain reset, or
        // otherwise can be modified in such a way that all instances of it need to be kept up to date.
        VulkanInstance                             _instance;
        VulkanResourceArray!(VulkanFramebuffer*)   _framebuffers;
        VulkanResourceArray!(VulkanPipeline*)      _pipelines;
        VulkanResourceArray!(VulkanLogicalDevice*) _logicalDevices;
        VulkanResourceArray!(VulkanSwapchain*)     _swapchains;
        VulkanResourceArray!(VulkanImageView*)     _imageViews;
        VulkanResourceArray!VulkanSurface          _surfaces;
        VulkanResourceArray!(VulkanShaderModule)   _shaderModules;
        VulkanResourceArray!(VulkanCommandPool)    _commandPools;
        VulkanResourceArray!(VulkanSemaphore)      _semaphores;
        VulkanResourceArray!(VulkanFence)          _fences;
        VulkanResourceArray!(VulkanBuffer)         _buffers;
        VulkanResourceArray!(VulkanDeviceMemory)   _memory;
        VulkanPipeline*[size_t]                    _pipelineCache; // Key is builder's hash.

        const VkApplicationInfo APP_INFO =
        {
            sType:              VK_STRUCTURE_TYPE_APPLICATION_INFO,
            pApplicationName:   "Farm Defense",
            applicationVersion: VK_MAKE_VERSION(1, 0, 0),
            pEngineName:        "None",
            engineVersion:      VK_MAKE_VERSION(1, 0, 0),
            apiVersion:         VK_API_VERSION_1_0
        };
    }

    // INIT RELATED //
    public static
    {
        void addInstanceLayer(VulkanOptionalString layerName)
        {
            infof("Using %s layer: %s", (layerName.isOptional) ? "OPTIONAL" : "REQUIRED", layerName.name);
            this._instance.layers.wanted ~= layerName;
        }

        void addInstanceExtension(VulkanOptionalString extName)
        {
            infof("Using %s extension: %s", (extName.isOptional) ? "OPTIONAL" : "REQUIRED", extName.name);
            this._instance.extensions.wanted ~= extName;
        }

        void createInstance()
        {
            info("Creating Vulkan instance");

            VkInstanceCreateInfo info;
            info.pApplicationInfo        = &APP_INFO;
            info.enabledExtensionCount   = cast(uint)this._instance.extensions.enabled.length;
            info.enabledLayerCount       = cast(uint)this._instance.layers.enabled.length;
            info.ppEnabledExtensionNames = this._instance.extensions.enabledRaw.ptr;
            info.ppEnabledLayerNames     = this._instance.layers.enabledRaw.ptr;

            CHECK_VK(vkCreateInstance(&info, null, &this._instance.handle));
            loadInstanceLevelFunctions(this._instance.handle);
        }
    }

    // CLEANUP //
    public static
    {
        void onUninit()
        {
            info("Cleaning up all tracked Vulkan resources");
            VulkanResources.cleanupSwapchain();

            this._shaderModules.cleanup(m => vkDestroyShaderModule(m.device.logical.handle, m.handle, null));
            this._commandPools.cleanup(p => vkDestroyCommandPool(p.device.logical.handle, p.handle, null));
            this._semaphores.cleanup(s => vkDestroySemaphore(s.device.logical.handle, s.handle, null));
            this._fences.cleanup(f => vkDestroyFence(f.device.logical.handle, f.handle, null));
            this._buffers.cleanup(b => vkDestroyBuffer(b.device.logical.handle, b.handle, null));
            this._memory.cleanup(m => vkFreeMemory(m.device.logical.handle, m.handle, null));
            this._logicalDevices.cleanup(d => vkDestroyDevice(d.handle, null));
            this._surfaces.cleanup(s => vkDestroySurfaceKHR(this._instance.handle, s.handle, null));

            info("Destroying Vulkan instance");
            vkDestroyInstance(this._instance.handle, null);
        }

        void cleanupSwapchain()
        {
            info("Cleaning up swapchain");

            this._pipelines.cleanup((p)
            {
                vkDestroyPipeline(p.device.logical.handle, p.handle, null);
                vkDestroyPipelineLayout(p.device.logical.handle, p.layout.handle, null);
                vkDestroyRenderPass(p.device.logical.handle, p.renderPass.handle, null);
            });
            this._framebuffers.cleanup(f => vkDestroyFramebuffer(f.device.logical.handle, f.handle, null));
            this._imageViews.cleanup(v => vkDestroyImageView(v.swapchain.device.logical.handle, v.handle, null));
            this._swapchains.cleanup(c => vkDestroySwapchainKHR(c.device.logical.handle, c.handle, null));
            this._pipelineCache.clear();
        }

        void recreateSwapchain()
        {
            info("Recreating swapchain");
            Vulkan.waitUntilAllDevicesAreIdle();
            VulkanResources.cleanupSwapchain();

            // By doing things this way, we can keep all current pointers valid, while still recreating the swapchain.
            //
            // GC will clear up danglers.
            this._pipelineCache.clear();
            this._pipelines.recreate((p)
            {
                *p = *p.recreateFunc();
                this._pipelines.length -= 1;
            });
            this._swapchains.recreate((sc)
            {
                auto newSc = sc.recreateFunc();
                foreach(i, image; newSc.images)
                    *sc.images[i] = *image;
                foreach(view; newSc.imageColourViews)
                    vkDestroyImageView(view.swapchain.device.logical.handle, view.handle, null); // Since our original pointers will be recreated.

                this._imageViews.length -= newSc.images.length;

                // Transfer over data that doesn't get recreated.
                newSc.images                      = sc.images;
                newSc.graphicsBuffers             = sc.graphicsBuffers;
                newSc.device.logical.graphicsPool = sc.device.logical.graphicsPool;
                newSc.imageAvailableSemaphores    = sc.imageAvailableSemaphores;
                newSc.renderFinishedSemaphores    = sc.renderFinishedSemaphores;
                newSc.fences                      = sc.fences;
                newSc.framebuffers                = sc.framebuffers;
                *sc = *newSc;

                this._swapchains.length -= 1;
            });
            this._imageViews.recreate((iv)
            {
                *iv = *iv.recreateFunc();
                this._imageViews.length -= 1;
            });
            this._framebuffers.recreate((fb)
            {
                *fb = *fb.recreateFunc();
                this._framebuffers.length -= 1;
            });
        }
    }

    // CREATE //
    public static
    {
        VulkanSurface createWindowSurface()
        {
            info("Creating Window Surface");

            VkSurfaceKHR handle;
            CHECK_SDL(SDL_Vulkan_CreateSurface(Window.handle, this._instance.handle, &handle));

            this._surfaces ~= VulkanSurface(handle);
            return this._surfaces[$-1];
        }

        VulkanDevice createDevice(scope return VulkanPhysicalDevice* physicalDevice)
        {
            import std.algorithm : canFind;

            assert(!physicalDevice.graphicsQueue.familyIndex.isNull);
            assert(!physicalDevice.presentQueue.familyIndex.isNull);

            info("Creating logical device from physical device ", physicalDevice.properties.deviceName);

            const graphicsIndex = physicalDevice.graphicsQueue.familyIndex.get();
            const presentIndex  = physicalDevice.presentQueue.familyIndex.get();
            const uniqueQueueIndicies = (graphicsIndex == presentIndex)
                                        ? [graphicsIndex]
                                        : [graphicsIndex, presentIndex];

            const priority = 1.0f;
            VkDeviceQueueCreateInfo[] queueCreateInfos;
            foreach(index; uniqueQueueIndicies)
            {
                VkDeviceQueueCreateInfo info;
                info.queueFamilyIndex = index;
                info.queueCount       = 1;
                info.pQueuePriorities = &priority;

                queueCreateInfos ~= info;
            }

            VkPhysicalDeviceFeatures deviceFeatures;
            // TODO:

            VkDeviceCreateInfo deviceInfo;
            deviceInfo.queueCreateInfoCount     = cast(uint)queueCreateInfos.length;
            deviceInfo.pQueueCreateInfos        = queueCreateInfos.ptr;
            deviceInfo.enabledLayerCount        = cast(uint)this._instance.layers.enabledRaw.length;
            deviceInfo.ppEnabledLayerNames      = this._instance.layers.enabledRaw.ptr;
            deviceInfo.enabledExtensionCount    = cast(uint)physicalDevice.extensions.enabledRaw.length;
            deviceInfo.ppEnabledExtensionNames  = physicalDevice.extensions.enabledRaw.ptr;
            deviceInfo.pEnabledFeatures         = &deviceFeatures;

            auto logicalDevice = new VulkanLogicalDevice;
            CHECK_VK(vkCreateDevice(physicalDevice.handle, &deviceInfo, null, &logicalDevice.handle));
            loadDeviceLevelFunctions(logicalDevice.handle);

            logicalDevice.graphicsQueue = physicalDevice.graphicsQueue;
            logicalDevice.presentQueue  = physicalDevice.presentQueue;
            this._logicalDevices       ~= logicalDevice; // Register for cleanup.

            vkGetDeviceQueue(
                logicalDevice.handle,
                logicalDevice.graphicsQueue.familyIndex.get(),
                0,
                &logicalDevice.graphicsQueue.handle
            );

            vkGetDeviceQueue(
                logicalDevice.handle,
                logicalDevice.presentQueue.familyIndex.get(),
                0,
                &logicalDevice.presentQueue.handle
            );

            return VulkanDevice(physicalDevice, logicalDevice);
        }

        VulkanSwapchain* createSwapchain(
                         VulkanDevice     device, 
                         VulkanSurface    surface,
            scope return VulkanSwapchain* oldSwapchain       = null,
            lazy const   uint             widthIfNotDefined  = Window.width,
            lazy const   uint             heightIfNotDefined = Window.height
        )
        {
            info("Creating swapchain for device");

            // Stay up-to-date, for example, becauase the window changes size.
            vkGetPhysicalDeviceSurfaceCapabilitiesKHR(device.physical.handle, surface.handle, &device.physical.swapchainSupport.capabilities);

            auto swapchain        = new VulkanSwapchain;
            auto swapchainSupport = device.physical.swapchainSupport;
            swapchain.device      = device;

            // Determine swapchain settings
            swapchain.presentMode = VK_PRESENT_MODE_FIFO_KHR;
            foreach(format; swapchainSupport.formats)
            {
                if(format.format     == VK_FORMAT_B8G8R8A8_SRGB
                && format.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
                {
                    swapchain.format = format;
                    break;
                }
            }

            if(swapchain.format == VkSurfaceFormatKHR.init)
                fatal("Device does not support Non-Linear B8G8R8A8 SRGB");

            if(swapchainSupport.capabilities.currentExtent.width == uint.max
            || swapchainSupport.capabilities.currentExtent.height == uint.max)
            {
                swapchainSupport.capabilities.currentExtent = VkExtent2D(widthIfNotDefined, heightIfNotDefined);
            }
            swapchain.extent = swapchainSupport.capabilities.currentExtent;

            if(swapchain.extent.width != swapchainSupport.capabilities.minImageExtent.width)
                swapchain.extent.width = swapchainSupport.capabilities.minImageExtent.width;
            if(swapchain.extent.height != swapchainSupport.capabilities.minImageExtent.height)
                swapchain.extent.height = swapchainSupport.capabilities.minImageExtent.height;

            infof("Final swapchain size (%s, %s)", swapchain.extent.width, swapchain.extent.height);

            // Create Swapchain
            VkSwapchainCreateInfoKHR swapchainInfo;
            swapchainInfo.surface          = surface.handle;
            swapchainInfo.minImageCount    = swapchainSupport.capabilities.minImageCount + 1;
            swapchainInfo.imageFormat      = swapchain.format.format;
            swapchainInfo.imageColorSpace  = swapchain.format.colorSpace;
            swapchainInfo.imageExtent      = swapchain.extent;
            swapchainInfo.imageArrayLayers = 1;
            swapchainInfo.imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
            swapchainInfo.preTransform     = swapchainSupport.capabilities.currentTransform;
            swapchainInfo.compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
            swapchainInfo.presentMode      = swapchain.presentMode;
            swapchainInfo.clipped          = VK_TRUE;
            swapchainInfo.oldSwapchain     = (oldSwapchain is null) ? VK_NULL_HANDLE : oldSwapchain.handle;

            uint[2] indicies =
            [
                device.logical.graphicsQueue.familyIndex.get(),
                device.logical.presentQueue.familyIndex.get()
            ];

            if(indicies[0] != indicies[1])
            {
                swapchainInfo.imageSharingMode      = VK_SHARING_MODE_CONCURRENT;
                swapchainInfo.queueFamilyIndexCount = indicies.length;
                swapchainInfo.pQueueFamilyIndices   = indicies.ptr;
            }
            else
                swapchainInfo.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;

            CHECK_VK(vkCreateSwapchainKHR(device.logical.handle, &swapchainInfo, null, &swapchain.handle));

            auto handles = VulkanResources.getVkArray!(VkImage, vkGetSwapchainImagesKHR)
                                                      (device.logical.handle, swapchain.handle);

            swapchain.images.length           = handles.length;
            swapchain.imageColourViews.length = handles.length;
            foreach(i, handle; handles)
            {
                swapchain.images[i]           = new VulkanImage(handle, swapchain.format, swapchain.extent, swapchain);
                swapchain.imageColourViews[i] = VulkanResources.createImageView(swapchain.images[i], VulkanImageViewType.colour2D);
            }

            swapchain.recreateFunc = () => VulkanResources.createSwapchain(device, surface, null, widthIfNotDefined, heightIfNotDefined);

            this._swapchains ~= swapchain;
            return swapchain;
        }

        VulkanImageView* createImageView(
            VulkanImage*        image,
            VulkanImageViewType type
        )
        {
            info("Creating image view");
            VkImageViewType    viewType;
            VkImageAspectFlags aspectMask;
            switch(type) with(VulkanImageViewType)
            {
                case colour2D:
                    viewType    = VK_IMAGE_VIEW_TYPE_2D;
                    aspectMask |= VK_IMAGE_ASPECT_COLOR_BIT;
                    break;

                default: assert(false, "Unsupported image view type");
            }

            VkImageViewCreateInfo info;
            info.image                           = image.handle;
            info.viewType                        = viewType;
            info.format                          = image.swapchain.format.format;
            info.components.r                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.g                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.b                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            info.components.a                    = VK_COMPONENT_SWIZZLE_IDENTITY;
            info.subresourceRange.aspectMask     = aspectMask;
            info.subresourceRange.baseMipLevel   = 0;
            info.subresourceRange.levelCount     = 1;
            info.subresourceRange.baseArrayLayer = 0;
            info.subresourceRange.layerCount     = 1;

            auto view = new VulkanImageView();
            CHECK_VK(vkCreateImageView(image.swapchain.device.logical.handle, &info, null, &view.handle));

            view.type         = type;
            view.swapchain    = image.swapchain;
            view.recreateFunc = () => VulkanResources.createImageView(image, type);

            this._imageViews ~= view;
            return view;
        }

        VulkanShaderModule createShaderModule(
            ref ubyte[]          shaderByteCode,
                VulkanShaderType type,
                VulkanDevice     device,
                string           entryPoint = "main"
        )
        {
            import std.string : toStringz;

            // We have to pass it as a uint*, except we also have to specify
            // the length in bytes. So we need to align to 4 bytes.
            if(shaderByteCode.length % 4 != 0)
                shaderByteCode.length += (shaderByteCode.length % 4);

            VulkanShaderModule shader;
            shader.device = device;

            VkShaderModuleCreateInfo info;
            info.codeSize = shaderByteCode.length; // In bytes
            info.pCode    = cast(uint*)shaderByteCode.ptr; // As uint*

            CHECK_VK(vkCreateShaderModule(device.logical.handle, &info, null, &shader.handle));

            VkShaderStageFlagBits stageMask;
            final switch(type) with(VulkanShaderType)
            {
                case vertex:   stageMask = VK_SHADER_STAGE_VERTEX_BIT;   break;
                case fragment: stageMask = VK_SHADER_STAGE_FRAGMENT_BIT; break;
            }

            shader.stage.stage   = stageMask;
            shader.stage.module_ = shader.handle;
            shader.stage.pName   = entryPoint.toStringz;
            shader.type          = type;

            this._shaderModules ~= shader;
            return shader;
        }

        VulkanPipeline* createPipeline(
            VulkanPipelineBuilder builder
        )
        {
            info("Pipeline has hash ", builder.toHash);

            auto ptr = (builder.toHash() in this._pipelineCache);
            if(ptr !is null)
            {
                info("Pipeline is cached, returning...");
                return *ptr;
            }

            info("Pipeline wasn't cached, continuing.");

            auto pipeline   = new VulkanPipeline;
            pipeline.device = builder._swapchain.device;

            auto stages = 
            [
                builder._vertexShader.stage,
                builder._fragmentShader.stage
            ];
            assert(builder._vertexShader   != VulkanShaderModule.init);
            assert(builder._fragmentShader != VulkanShaderModule.init);

            // We'll only ever have one vertex type pre-rewrite.
            import game.graphics.renderer : Vertex;
            VkVertexInputBindingDescription bindInfo;
            bindInfo.binding   = 0;
            bindInfo.stride    = Vertex.sizeof;
            bindInfo.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;

            VkVertexInputAttributeDescription[2] attributes;
            with(&attributes[0])
            {
                binding  = 0;
                location = 0;
                format   = VK_FORMAT_R32G32_SFLOAT;
                offset   = Vertex.position.offsetof;
            }
            with(&attributes[1])
            {
                binding  = 0;
                location = 1;
                format   = VK_FORMAT_R8G8B8A8_UINT;
                offset   = Vertex.colour.offsetof;
            }

            VkPipelineVertexInputStateCreateInfo vertInfo;
            vertInfo.vertexBindingDescriptionCount   = 1;
            vertInfo.vertexAttributeDescriptionCount = attributes.length.to!uint;
            vertInfo.pVertexBindingDescriptions      = &bindInfo;
            vertInfo.pVertexAttributeDescriptions    = attributes.ptr;

            if(builder._viewport.width == 0)
                builder._viewport.width = Window.width;
            if(builder._viewport.height == 0)
                builder._viewport.height = Window.height;

            if(builder._scissor.extent.width == 0)
                builder._scissor.extent.width = Window.width;
            if(builder._scissor.extent.height == 0)
                builder._scissor.extent.height = Window.height;

            VkPipelineViewportStateCreateInfo viewInfo;
            viewInfo.viewportCount = 1;
            viewInfo.scissorCount  = 1;
            viewInfo.pViewports    = &builder._viewport;
            viewInfo.pScissors     = &builder._scissor;

            VkPipelineMultisampleStateCreateInfo multisampleInfo;
            multisampleInfo.sampleShadingEnable  = VK_FALSE;
            multisampleInfo.rasterizationSamples = VK_SAMPLE_COUNT_1_BIT;

            VkPipelineColorBlendAttachmentState framebufferBlend;
            framebufferBlend.colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT;
            framebufferBlend.blendEnable    = VK_FALSE;

            auto blendingInfo            = builder._blending;
            blendingInfo.attachmentCount = 1;
            blendingInfo.pAttachments    = &framebufferBlend;

            info("Creating pipeline layout");
            VkPipelineLayoutCreateInfo layoutInfo;
            CHECK_VK(vkCreatePipelineLayout(pipeline.device.logical.handle, &layoutInfo, null, &pipeline.layout.handle));

            info("Creating render pass info");
            auto renderPassInfo = builder.makeRenderPassInfo();
            pipeline.renderPass.device = pipeline.device;
            CHECK_VK(vkCreateRenderPass(pipeline.device.logical.handle, &renderPassInfo, null, &pipeline.renderPass.handle));

            VkGraphicsPipelineCreateInfo info;
            info.stageCount             = 2;
            info.pStages                = stages.ptr;
            info.pVertexInputState      = &vertInfo;
            info.pInputAssemblyState    = &builder._inputAssemblyInfo;
            info.pViewportState         = &viewInfo;
            info.pRasterizationState    = &builder._rasterInfo;
            info.pMultisampleState      = &multisampleInfo;
            info.pColorBlendState       = &blendingInfo;
            info.layout                 = pipeline.layout.handle;
            info.renderPass             = pipeline.renderPass.handle;
            info.subpass                = 0;

            infof("Creating graphics pipeline");
            CHECK_VK(vkCreateGraphicsPipelines(pipeline.device.logical.handle, null, 1, &info, null, &pipeline.handle));

            pipeline.recreateFunc = () => VulkanResources.createPipeline(builder);
            
            this._pipelines ~= pipeline;
            this._pipelineCache[builder.toHash()] = pipeline;
            return pipeline;
        }

        VulkanFramebuffer* createFramebuffer(
            VulkanDevice       device,
            VulkanPipeline*    pipeline,
            VulkanImageView*[] attachments,
            uint               width = 0,
            uint               height = 0
        )
        {
            infof("Creating framebuffer (%s, %s)", width, height);

            auto framebuffer         = new VulkanFramebuffer();
            framebuffer.device       = device;
            framebuffer.pipeline     = pipeline;
            framebuffer.recreateFunc = () => VulkanResources.createFramebuffer(device, pipeline, attachments, width, height);

            auto vkAttachments = new VkImageView[attachments.length];
            foreach(i, attachment; attachments)
                vkAttachments[i] = attachment.handle;

            VkFramebufferCreateInfo info;
            info.renderPass      = pipeline.renderPass.handle;
            info.attachmentCount = vkAttachments.length.to!uint;
            info.pAttachments    = vkAttachments.ptr;
            info.width           = (width == 0) ? Window.width : width;
            info.height          = (height == 0) ? Window.height : height;
            info.layers          = 1;

            CHECK_VK(vkCreateFramebuffer(device.logical.handle, &info, null, &framebuffer.handle));
            this._framebuffers ~= framebuffer;

            return framebuffer;
        }

        void createSwapchainFramebuffers(
            scope VulkanSwapchain* swapchain,
                  VulkanPipeline*  pipeline
        )
        {
            info("Creating default framebuffers for swapchain");

            swapchain.framebuffers.length = swapchain.images.length;
            foreach(i; 0..swapchain.images.length)
            {
                auto attachments = 
                [
                    swapchain.imageColourViews[i]
                ];

                swapchain.framebuffers[i] = VulkanResources.createFramebuffer(
                    swapchain.device, 
                    pipeline, 
                    attachments, 
                    0, 
                    0
                );
            }
        }

        VulkanCommandPool createCommandPool(
            VulkanQueue queue,
            VulkanDevice device
        )
        {
            info("Creating command pool");

            VkCommandPoolCreateInfo info;
            info.queueFamilyIndex = queue.familyIndex.get();
            info.flags            = VK_COMMAND_POOL_CREATE_TRANSIENT_BIT | VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT; // TODO

            VulkanCommandPool pool;
            pool.device = device;
            CHECK_VK(vkCreateCommandPool(device.logical.handle, &info, null, &pool.handle));

            this._commandPools ~= pool;
            return pool;
        }

        void createDeviceCommandPools(
            VulkanDevice device
        )
        {
            device.logical.graphicsPool = VulkanResources.createCommandPool(device.logical.graphicsQueue, device);
        }

        void allocateCommandBuffers(
                      VulkanCommandPool      pool,
            scope ref VulkanCommandBuffer*[] buffers,
                      VulkanIsPrimary        isPrimary = VulkanIsPrimary.yes
        )
        {
            infof("Allocating %s command buffers", buffers.length);

            VkCommandBufferAllocateInfo info;
            info.commandPool        = pool.handle;
            info.level              = (isPrimary) ? VK_COMMAND_BUFFER_LEVEL_PRIMARY : VK_COMMAND_BUFFER_LEVEL_SECONDARY;
            info.commandBufferCount = cast(uint)buffers.length;

            VkCommandBuffer[] handles = new VkCommandBuffer[buffers.length];
            CHECK_VK(vkAllocateCommandBuffers(pool.device.logical.handle, &info, handles.ptr));

            foreach(i, ref buffer; buffers)
            {
                buffer = new VulkanCommandBuffer();
                buffer.handle = handles[i];
            }
        }

        void allocateSwapchainCommandBuffers(
            scope VulkanSwapchain*  swapchain,
                  VulkanCommandPool pool
        )
        {
            swapchain.graphicsBuffers.length = swapchain.framebuffers.length;
            VulkanResources.allocateCommandBuffers(pool, Ref(swapchain.graphicsBuffers));
        }

        VulkanSemaphore createSemaphore(
            VulkanDevice device
        )
        {
            info("Creating semaphore");
            VulkanSemaphore semaphore;
            semaphore.device = device;

            VkSemaphoreCreateInfo info;
            CHECK_VK(vkCreateSemaphore(device.logical.handle, &info, null, &semaphore.handle));

            this._semaphores ~= semaphore;
            return semaphore;
        }

        void createSwapchainSemaphoresAndFences(
            scope VulkanSwapchain* swapchain
        )
        {
            swapchain.imageAvailableSemaphores.length = swapchain.framebuffers.length;
            swapchain.renderFinishedSemaphores.length = swapchain.framebuffers.length;
            swapchain.fences.length                   = swapchain.framebuffers.length;

            foreach(ref sem; swapchain.imageAvailableSemaphores)
                sem = VulkanResources.createSemaphore(swapchain.device);
            foreach(ref sem; swapchain.renderFinishedSemaphores)
                sem = VulkanResources.createSemaphore(swapchain.device);
            foreach(ref fence; swapchain.fences)
                fence = VulkanResources.createFence(swapchain.device);
        }
                
        VulkanFence createFence(
            VulkanDevice device,
            VulkanStartSignaled startSignaled = VulkanStartSignaled.yes
        )
        {
            info("Creating fence");
            VulkanFence fence;
            fence.device = device;

            VkFenceCreateInfo info;
            info.flags = (startSignaled) ? VK_FENCE_CREATE_SIGNALED_BIT : 0;
            CHECK_VK(vkCreateFence(device.logical.handle, &info, null, &fence.handle));

            this._fences ~= fence;
            return fence;
        }

        VulkanBuffer createBuffer(
            VulkanDevice     device,
            VulkanBufferType type,
            size_t           size
        )
        {
            VkBufferCreateInfo info;
            info.size        = size;
            info.sharingMode = VK_SHARING_MODE_EXCLUSIVE;

            final switch(type) with(VulkanBufferType)
            {
                case error: assert(false);
                case vertex: info.usage = VK_BUFFER_USAGE_VERTEX_BUFFER_BIT; break;
            }

            VulkanBuffer buffer;
            buffer.device = device;
            buffer.memory.device = device;
            CHECK_VK(vkCreateBuffer(device.logical.handle, &info, null, &buffer.handle));

            VkMemoryPropertyFlags            properties = VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT;
            VkPhysicalDeviceMemoryProperties physicalMemory;
            VkMemoryRequirements             requirements;

            vkGetBufferMemoryRequirements(device.logical.handle, buffer.handle, &requirements);
            vkGetPhysicalDeviceMemoryProperties(device.physical.handle, &physicalMemory);

            uint i;
            for(i = 0; i < physicalMemory.memoryTypeCount; i++)
            {
                if(requirements.memoryTypeBits & (1 << i)
                && physicalMemory.memoryTypes[i].propertyFlags & properties)
                    break;
            }
            assert(i != physicalMemory.memoryTypeCount);

            VkMemoryAllocateInfo allocInfo;
            allocInfo.allocationSize  = requirements.size;
            allocInfo.memoryTypeIndex = i;

            CHECK_VK(vkAllocateMemory(device.logical.handle, &allocInfo, null, &buffer.memory.handle));
            vkBindBufferMemory(device.logical.handle, buffer.handle, buffer.memory.handle, 0);

            this._buffers ~= buffer;
            this._memory  ~= buffer.memory;

            buffer.memory.size = requirements.size;
            return buffer;
        }
    }
    
    // HELPERS //
    public static
    {
        T[] getVkArray(T, alias Func, Args...)(Args args)
        {
            import std.format : format;
            import std.traits : Parameters, ReturnType;

            enum PARAMS_AUTO_ADDED  = 2; // Count ptr and data ptr.
            enum FUNC_PARAM_COUNT   = Parameters!Func.length;
            enum EXPECTED_ARG_COUNT = FUNC_PARAM_COUNT - PARAMS_AUTO_ADDED;

            static assert(
                EXPECTED_ARG_COUNT == args.length,
                "Param count mismatch, expected %s but got %s"
                    .format(EXPECTED_ARG_COUNT, args.length)
            );

            static if(is(ReturnType!Func == SDL_bool))
                alias CHECK = CHECK_SDL;
            else static if(is(ReturnType!Func == VkResult))
                alias CHECK = CHECK_VK;

            uint count;
            T[]  data;

            static if(__traits(compiles, &CHECK))
            {
                CHECK(Func(args, &count, null));
                data.length = count;
                CHECK(Func(args, &count, data.ptr));
            }
            else
            {
                Func(args, &count, null);
                data.length = count;
                Func(args, &count, data.ptr);
            }

            return data;
        }
    }
}

private final class VulkanInit
{
    static immutable DEFAULT_FRAG_SHADER = "./resources/shaders/shader.spv.frag";
    static immutable DEFAULT_VERT_SHADER = "./resources/shaders/shader.spv.vert";

    public static
    {
        void onPreInit()
        {
            loadGlobalLevelFunctions();
        }

        void loadExtensions()
        {
            info("Loading Vulkan Extensions");

            scope extPtr = &VulkanResources._instance.extensions;
            
            // Add all extensions required by SDL
            info("Adding Vulkan extensions required by SDL");
            const windowExtensions = VulkanResources.getVkArray
                                    !(VkString, SDL_Vulkan_GetInstanceExtensions)
                                     (Window.handle);
            foreach(str; windowExtensions)
                VulkanResources.addInstanceExtension(VulkanOptionalString(str, VulkanIsOptional.no));

            // Load all available extensions
            extPtr.available = VulkanResources.getVkArray
                              !(VkExtensionProperties, vkEnumerateInstanceExtensionProperties)
                               (null);
            
            info("Available instance extensions:");
            foreach(ext; extPtr.available)
                infof("    v%s %s", ext.specVersion, ext.extensionName);

            VulkanInit.findEnabled!("extension", VkExtensionProperties)
                                   (extPtr.wanted, extPtr.available, Ref(extPtr.enabled), Ref(extPtr.enabledRaw), a => a.extensionName.ptr.fromStringz.idup);
        }

        void loadLayers()
        {
            info("Loading Vulkan Layers");

            scope layerPtr     = &VulkanResources._instance.layers;
            layerPtr.available = VulkanResources.getVkArray
                                !(VkLayerProperties, vkEnumerateInstanceLayerProperties);

            info("Available instance layers:");
            foreach(layer; layerPtr.available)
                infof("    v%s for spec %s %s - %s", layer.implementationVersion, layer.specVersion, layer.layerName.ptr.fromStringz, layer.description);

            VulkanInit.findEnabled!("layer", VkLayerProperties)
                                   (layerPtr.wanted, layerPtr.available, Ref(layerPtr.enabled), Ref(layerPtr.enabledRaw), a => a.layerName.ptr.fromStringz.idup);
        }

        VulkanPhysicalDevice[] loadPhysicalDevices(VulkanSurface surface)
        {
            info("Loading all available physical devices");
            auto handles = VulkanResources.getVkArray!(VkPhysicalDevice, vkEnumeratePhysicalDevices)
                                                      (VulkanResources._instance.handle);

            VulkanPhysicalDevice[] devices;
            foreach(handle; handles)
            {
                // Load extensions, features, and properties.
                auto info = VulkanPhysicalDevice(handle);
                info.extensions.available = VulkanResources.getVkArray!(VkExtensionProperties, vkEnumerateDeviceExtensionProperties)
                                                                       (handle, null);
                info.extensions.wanted = 
                [
                    VulkanOptionalString("VK_KHR_swapchain".ptr, VulkanIsOptional.no)
                ];

                vkGetPhysicalDeviceProperties(info.handle, &info.properties);
                vkGetPhysicalDeviceFeatures(info.handle, &info.features);

                // Load queue family info.
                auto queueFamilies = VulkanResources.getVkArray!(VkQueueFamilyProperties, vkGetPhysicalDeviceQueueFamilyProperties)
                                                                (handle);
                foreach(i, family; queueFamilies)
                {
                    VkBool32 canPresent;
                    vkGetPhysicalDeviceSurfaceSupportKHR(handle, cast(uint)i, surface.handle, &canPresent);
                
                    if((family.queueFlags & VK_QUEUE_GRAPHICS_BIT) && info.graphicsQueue.familyIndex.isNull)
                        info.graphicsQueue.familyIndex = cast(uint)i;
                    else if(canPresent && info.presentQueue.familyIndex.isNull)
                        info.presentQueue.familyIndex = cast(uint)i;
                }

                // Find swap chain support.
                vkGetPhysicalDeviceSurfaceCapabilitiesKHR(handle, surface.handle, &info.swapchainSupport.capabilities);
                info.swapchainSupport.formats = VulkanResources.getVkArray!(VkSurfaceFormatKHR, vkGetPhysicalDeviceSurfaceFormatsKHR)
                                                                           (handle, surface.handle);
                info.swapchainSupport.presentModes = VulkanResources.getVkArray!(VkPresentModeKHR, vkGetPhysicalDeviceSurfacePresentModesKHR)
                                                                                (handle, surface.handle);

                // Print all of the data we just gathered, to help me with debugging,
                // and so I know what's going on :)
                infof("[NEW DEVICE] AS %s", info.handle);

                infof("Extensions Available:");
                foreach(ext; info.extensions.available)
                    infof("    v%s %s", ext.specVersion, ext.extensionName.ptr.fromStringz);

                VulkanInit.findEnabled!("extension", VkExtensionProperties)
                                       (info.extensions.wanted, info.extensions.available, Ref(info.extensions.enabled), Ref(info.extensions.enabledRaw), a => a.extensionName.ptr.fromStringz.idup);

                infof(
                    "\nProperties:\n"
                   ~"    apiVersion         = %s\n"
                   ~"    driverVersion      = %s\n"
                   ~"    vendorID           = %s\n"
                   ~"    deviceID           = %s\n"
                   ~"    deviceType         = %s\n"
                   ~"    deviceName         = %s\n"
                   ~"    pipelineCacheUUID  = %s",

                   info.properties.apiVersion,
                   info.properties.driverVersion,
                   info.properties.vendorID,
                   info.properties.deviceID,
                   info.properties.deviceType,
                   info.properties.deviceName,
                   info.properties.pipelineCacheUUID,
                );

                infof(
                    "\nSparse Memory Properties:\n"
                   ~"   residencyStandard2DBlockShape            = %s\n"
                   ~"   residencyStandard2DMultisampleBlockShape = %s\n"
                   ~"   residencyStandard3DBlockShape            = %s\n"
                   ~"   residencyAlignedMipSize                  = %s\n"
                   ~"   residencyNonResidentStrict               = %s",

                   info.properties.sparseProperties.residencyStandard2DBlockShape,
                   info.properties.sparseProperties.residencyStandard2DMultisampleBlockShape,
                   info.properties.sparseProperties.residencyStandard3DBlockShape,
                   info.properties.sparseProperties.residencyAlignedMipSize,
                   info.properties.sparseProperties.residencyNonResidentStrict,
                );

                // This struct is *massive*
                import asdf;
                infof(info.properties.limits.serializeToJsonPretty());

                infof(
                    "\nQueue Families:\n"
                   ~"    graphics = %s\n"
                   ~"    present  = %s",

                   info.graphicsQueue.familyIndex.get(size_t.max),
                   info.presentQueue.familyIndex.get(size_t.max)
                );

                infof(
                    "\nSwapchain Support:\n"
                   ~"    presentModes = %s\n"
                   ~"    formats      -\n%s\n"
                   ~"    capabilities -\n%s",

                   info.swapchainSupport.presentModes,
                   info.swapchainSupport.formats.serializeToJsonPretty(),
                   info.swapchainSupport.capabilities.serializeToJsonPretty()
                );

                devices ~= info;
            }

            return devices;
        }

        VulkanPhysicalDevice* chooseBestGraphicsDevice(VulkanPhysicalDevice[] devices)
        {
            info("Selecting best graphics device.");

            VulkanPhysicalDevice bestFit;
            size_t bestFitScore;

            foreach(device; devices)
            {
                infof("START device %s(%s)", device.handle, device.properties.deviceName);

                // Can show graphics; Can present graphics; Has at least 1 colour format and present mode.
                const mandatoryCheck = 
                    !device.graphicsQueue.familyIndex.isNull
                &&  !device.presentQueue.familyIndex.isNull
                &&   device.swapchainSupport.formats.length > 0
                &&   device.swapchainSupport.presentModes.length > 0;

                info("HAS MANDATORY PROPERTIES = ", mandatoryCheck);

                if(!mandatoryCheck)
                    continue;

                auto score = 1; // TODO: Add to this if we ever want to.

                infof("FINAL SCORE = %s", score);
                if(score > bestFitScore)
                {
                    bestFitScore = score;
                    bestFit = device;
                }
            }

            if(bestFit.handle is null)
                fatal("Could not determine graphics card to use.");

            infof("Chosen device %s(%s) as graphics device.", bestFit.handle, bestFit.properties.deviceName);
            
            // This struct is *fucking massive*
            auto toReturn = new VulkanPhysicalDevice;
            *toReturn = bestFit;
            return toReturn;
        }

        void loadDefaultShaderModules(VulkanDevice device, ref VulkanShaderModule vert, ref VulkanShaderModule frag)
        {
            import std.file : fread = read;

            auto vertCode = cast(ubyte[])fread(DEFAULT_VERT_SHADER);
            auto fragCode = cast(ubyte[])fread(DEFAULT_FRAG_SHADER);

            vert = VulkanResources.createShaderModule(Ref(vertCode), VulkanShaderType.vertex, device);
            frag = VulkanResources.createShaderModule(Ref(fragCode), VulkanShaderType.fragment, device);
        }
    }

    private static
    {
        void findEnabled(string Name, T)(
            VulkanOptionalString[]  wantedList, 
            T[]                     availableList, 
            ref T[]                 enabledList,
            ref const(char)*[]      rawList,
            string function(T)      nameGetter
        )
        {
            foreach(wanted; wantedList)
            {
                import std.algorithm : find;

                auto range = availableList.find!((a, b) => nameGetter(a) == b)(wanted.name);
                if(range.length == 0)
                {
                    if(!wanted.isOptional)
                        fatalf("REQUIRED %s not found: %s", Name, wanted.name);

                    continue;
                }

                infof("Enabling %s: %s", Name, wanted.name);
                enabledList ~= range[0];
                rawList     ~= nameGetter(range[0]).ptr;
            }
        }
    }
}