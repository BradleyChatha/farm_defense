module game.vulkan;

public import erupted;
public import game.vulkan._events : OnFrameChangeId, OnSwapchainRecreateId; // For... some reason, types can't see these without an explicit import.
public import game.vulkan.common, game.vulkan.globals, game.vulkan.device, game.vulkan.surface, game.vulkan.instance,
              game.vulkan.queue, game.vulkan.tracker, game.vulkan.swapchain, game.vulkan.image, game.vulkan.command,
              game.vulkan.shader, game.vulkan.pipeline, game.vulkan._events;