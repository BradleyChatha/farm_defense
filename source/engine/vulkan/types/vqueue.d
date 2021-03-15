module engine.vulkan.types.vqueue;

import engine.vulkan, engine.vulkan.types._vkhandlewrapper, engine.core;

enum VQueueType
{
    ERROR,
    transfer,
    graphics,
    present,
    compute
}

struct VQueue
{
    mixin VkWrapper!VkQueue;
    VQueueType type;
    VQueueFamily family;

    this(VQueueFamily family, VQueueType type)
    {
        import std.format : format;

        logfTrace("Creating a %s queue from family %s", type, family);
        vkGetDeviceQueue(g_device.logical, family.index, 0, &this.handle);
        this.debugName = "%s (#%s) queue 0".format(type, family.index);
        this.family = family;
    }
}

alias UniqueIndexBuffer = uint[VQueueType.max];
uint[] findUniqueIndicies(VQueue[] queues, ref return UniqueIndexBuffer buffer)
{
    size_t count;
    foreach(queue; queues)
    {
        bool add = true;
        for(ptrdiff_t i = count; i >= 0; i--)
        {
            if(queue.family.index == buffer[i])
            {
                add = false;
                break;
            }
        }

        if(!add)
            continue;

        assert(count < buffer.length);
        buffer[count++] = queue.family.index;
    }

    return buffer[0..count];
}