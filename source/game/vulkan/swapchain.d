module game.vulkan.swapchain;

import std.conv : to;
import std.experimental.logger;
import game.vulkan, game.common.maths, game.graphics.window, game.common;

// The render pass for this game is static. No customisation.
struct RenderPass
{
    mixin VkWrapperJAST!VkRenderPass;

    enum COLOUR_TO_PRESENT_SUBPASS_INDEX = 0;

    static
    {
        RenderPass instance;

        void create(scope Swapchain* swapchain) // This is created before the swapchain global is set.
        {
            VkAttachmentDescription colourAttachment;
            VkAttachmentReference   colourAttachmentRef;
            VkSubpassDependency     colourCanBeWrittenDependency;
            VkSubpassDescription    colourToPresentSubpass;
            VkRenderPassCreateInfo  renderPass;

            info("Defining Render passes and attachments");
            with(colourAttachment)
            {
                format          = swapchain.format.format;
                samples         = VK_SAMPLE_COUNT_1_BIT;
                loadOp          = VK_ATTACHMENT_LOAD_OP_CLEAR;
                storeOp         = VK_ATTACHMENT_STORE_OP_STORE;
                stencilLoadOp   = VK_ATTACHMENT_LOAD_OP_DONT_CARE;
                stencilStoreOp  = VK_ATTACHMENT_STORE_OP_DONT_CARE;
                initialLayout   = VK_IMAGE_LAYOUT_UNDEFINED;
                finalLayout     = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR;
            }

            with(colourAttachmentRef)
            {
                attachment                  = 0; // colourAttachment
                colourAttachmentRef.layout  = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL;
            }

            with(colourToPresentSubpass)
            {
                pipelineBindPoint       = VK_PIPELINE_BIND_POINT_GRAPHICS;
                colorAttachmentCount    = 1;
                pColorAttachments       = &colourAttachmentRef;
            }

            with(colourCanBeWrittenDependency)
            {
                srcSubpass      = VK_SUBPASS_EXTERNAL;
                dstSubpass      = 0; // colourToPresentSubpass
                srcStageMask    = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                srcAccessMask   = 0;
                dstStageMask    = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
                srcAccessMask   = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT;
            }

            auto attachments  = [colourAttachment];
            auto subpasses    = [colourToPresentSubpass];
            auto dependencies = [colourCanBeWrittenDependency];
            with(renderPass)
            {
                attachmentCount = attachments.length.to!uint;
                subpassCount    = subpasses.length.to!uint;
                dependencyCount = dependencies.length.to!uint;
                pAttachments    = attachments.ptr;
                pSubpasses      = subpasses.ptr;
                pDependencies   = dependencies.ptr;
            }

            CHECK_VK(vkCreateRenderPass(g_device, &renderPass, null, &RenderPass.instance.handle));
            vkTrackJAST(RenderPass.instance);
        }
    }
}

struct Swapchain
{
    mixin VkSwapchainResourceWrapperJAST!VkSwapchainKHR;
    VkPresentModeKHR            presentMode;
    VkSurfaceFormatKHR          format;
    VkSurfaceCapabilitiesKHR    capabilities;
    GpuImage*[]                 images;
    GpuImageView*[]             imageViewsColour;
    Framebuffer*[]              framebuffers;

    static void create(scope ref Swapchain* ptr)
    {
        const areWeRecreating = ptr !is null;
        if(!areWeRecreating)
            ptr = new Swapchain();

        infof("%s the swapchain.", (areWeRecreating) ? "Recreating" : "Creating");

        assert(ptr !is null);
        ptr.recreateFunc = (p) => Swapchain.create(p);

        Swapchain.determineSettings(ptr);

        VkSwapchainCreateInfoKHR chainInfo;
        Swapchain.initChainInfo(ptr, chainInfo, areWeRecreating);

        if(!areWeRecreating)
            RenderPass.create(ptr);

        // Because we pass the old swapchain via chainInfo, we don't need to destroy it beforehand.
        CHECK_VK(vkCreateSwapchainKHR(g_device, &chainInfo, null, &ptr.handle));
        Swapchain.createImageResources(ptr, areWeRecreating);
    }

    private static void determineSettings(scope ref Swapchain* ptr)
    {
        import std.algorithm : filter;
        import std.exception : enforce;
        
        g_gpu.updateCapabilities();
        ptr.presentMode  = VK_PRESENT_MODE_FIFO_KHR;
        ptr.capabilities = g_gpu.capabilities;

        auto formatFilter = g_gpu.formats.filter!(f => f.format == VK_FORMAT_B8G8R8A8_SRGB && f.colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR);
        enforce(!formatFilter.empty, "Device does not support Non-Linear B8G8R8A8 SRGB");
        ptr.format = formatFilter.front;

        scope extent    = &ptr.capabilities.currentExtent;
        scope maxExtent = &ptr.capabilities.maxImageExtent;
        if(extent.width == uint.max || extent.height == uint.max)
            *extent = Window.size.toExtent;

        if(extent.width > maxExtent.width)
            extent.width = maxExtent.width;
        if(extent.height > maxExtent.height)
            extent.height = maxExtent.height;

        info("Swapchain Settings:");
        infof("\tPresent Mode: %s", ptr.presentMode);
        infof("\tFormat:       %s", ptr.format);
        infof("\tExtent:       %s", *extent);
    }

    private static void initChainInfo(
        scope ref Swapchain*               ptr,
              ref VkSwapchainCreateInfoKHR chainInfo,
                  bool                     areWeRecreating 
    )
    {
        import std.array : array;
        import containers.hashset;

        auto indexSet = HashSet!uint();
        indexSet.insert(g_gpu.graphicsQueueIndex.get());
        indexSet.insert(g_gpu.presentQueueIndex.get());
        indexSet.insert(g_gpu.transferQueueIndex.get());
        auto queueIndicies = indexSet[].array;
        const requiresConcurrency = indexSet.length > 1;

        with(chainInfo)
        {
            surface          = g_gpu.surface.handle;
            minImageCount    = ptr.capabilities.minImageCount + 1;
            imageFormat      = ptr.format.format;
            imageColorSpace  = ptr.format.colorSpace;
            imageExtent      = ptr.capabilities.currentExtent;
            imageArrayLayers = 1;
            imageUsage       = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
            preTransform     = ptr.capabilities.currentTransform;
            compositeAlpha   = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
            presentMode      = ptr.presentMode;
            clipped          = VK_TRUE;
            oldSwapchain     = (areWeRecreating) ? ptr.handle : null;

            if(requiresConcurrency)
            {
                imageSharingMode      = VK_SHARING_MODE_CONCURRENT;
                queueFamilyIndexCount = queueIndicies.length.to!uint;
                pQueueFamilyIndices   = queueIndicies.ptr;
            }
            else
                imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
        }
    }

    private static void createImageResources(scope ref Swapchain* ptr, bool areWeRecreating)
    {
        auto handles = vkGetArrayJAST!(VkImage, vkGetSwapchainImagesKHR)(g_device, ptr.handle);
        foreach(i, handle; handles)
        {
            if(areWeRecreating && ptr.images.length > i)
            {
                ptr.images[i].handle = handle;
                vkRecreateJAST(ptr.imageViewsColour[i]);
                vkRecreateJAST(ptr.framebuffers[i]);
            }
            else
            {
                ptr.images           ~= new GpuImage(handle, ptr.format.format);
                ptr.imageViewsColour ~= null;
                ptr.framebuffers     ~= null;
                
                GpuImageView.create(Ref(ptr.imageViewsColour[i]), ptr.images[i], GpuImageType.colour2D);
                Framebuffer .create(Ref(ptr.framebuffers[i]),     ptr.imageViewsColour[i]);
            }
        }

        assert(ptr.images.length == handles.length, "Need to handle when we get *less* images from swapchain recreation.");
    }
}