module game.vulkan;

public import erupted;
public import game.vulkan.framefuncs : OnFrameChangeId; // For... some reason, types can't see this without an explicit import.
public import game.vulkan.common, game.vulkan.globals, game.vulkan.device, game.vulkan.surface, game.vulkan.instance,
              game.vulkan.queue, game.vulkan.tracker, game.vulkan.swapchain, game.vulkan.image, game.vulkan.command,
              game.vulkan.shader, game.vulkan.pipeline, game.vulkan.framefuncs;