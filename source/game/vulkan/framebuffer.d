module game.vulkan.framebuffer;

import std.conv : to;
import std.experimental.logger;
import game.vulkan, game.common, game.graphics.window;

struct Framebuffer
{
    mixin VkSwapchainResourceWrapperJAST!VkFramebuffer;

    static void create(
        scope ref Framebuffer*  ptr,
        scope     GpuImageView* colourImageView,
        scope     GpuImageView* depthImageView
    )
    {
        const areWeRecreating = ptr !is null;
        if(!areWeRecreating)
            ptr = new Framebuffer();
        else
            vkDestroyFramebuffer(g_device, ptr.handle, null);
        infof("%s a %s.", (areWeRecreating) ? "Recreating" : "Creating", typeof(this).stringof);

        ptr.recreateFunc = (p) => create(ptr, colourImageView, depthImageView);

        auto attachments = [colourImageView.handle, depthImageView.handle];
        VkFramebufferCreateInfo info = 
        {
            flags:              0,
            renderPass:         g_renderPass,
            attachmentCount:    attachments.length.to!uint,
            pAttachments:       attachments.ptr,
            width:              Window.size.x,
            height:             Window.size.y,
            layers:             1
        };

        CHECK_VK(vkCreateFramebuffer(g_device, &info, null, &ptr.handle));
        vkTrackJAST(ptr);
    }
}