module game.vulkan.framefuncs;

import game.vulkan;

alias OnFrameChange = void delegate(uint swapchainImageIndex);

private static OnFrameChange[] g_onFrameChangeCallbacks;

size_t vkListenOnFrameChangeJAST(OnFrameChange func)
{
    g_onFrameChangeCallbacks ~= func;
    return g_onFrameChangeCallbacks.length - 1;
}

void vkUnlistenOnFrameChangeJAST(size_t id)
{
    // TODO: I kind of want to make a certain data structure for this first.
}

void vkEmitOnFrameChangeJAST(uint swapchainImageIndex)
{
    foreach(callback; g_onFrameChangeCallbacks)
        callback(swapchainImageIndex);
}