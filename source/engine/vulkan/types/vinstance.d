module engine.vulkan.types.vinstance;

import engine.vulkan;

struct VInstance
{
    VkInstance handle;
    VStringAndVersion[string] layers;
    VStringAndVersion[string] extensions;
}