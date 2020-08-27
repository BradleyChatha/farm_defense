module game.vulkan.command;

import std.experimental.logger;
import std.typecons : Flag;
import arsd.color;
import game.vulkan;

alias IsPrimaryBuffer = Flag!"isPrimaryBuffer";
alias ResetOnSubmit   = Flag!"isBufferSingleUse";

private CommandPoolManager*[uint] g_managersByQueueIndex;

struct CommandPoolManager
{
    private
    {
        CommandPool[VkCommandPoolCreateFlagBits] _poolsByFlag;
        LogicalDevice                            _device;
        uint                                     _queueIndex;
    }

    this(LogicalDevice device, uint queueIndex)
    {
        infof("Creating pool manager for queue family %s", queueIndex);
        this._device     = device;
        this._queueIndex = queueIndex;
    }

    static CommandPoolManager* getByQueueIndex(LogicalDevice device, uint queueIndex)
    {
        scope ptr = (queueIndex in g_managersByQueueIndex);
        if(ptr !is null)
            return *ptr;

        auto manager = new CommandPoolManager(device, queueIndex);
        g_managersByQueueIndex[queueIndex] = manager;

        return manager;
    }

    CommandPool get(VkCommandPoolCreateFlagBits flags)
    {
        scope ptr = (flags in this._poolsByFlag);
        if(ptr !is null)
            return *ptr;

        auto pool = CommandPool(this._device, this._queueIndex, flags);
        this._poolsByFlag[flags] = pool;
        
        return pool;
    }
}

struct CommandPool
{
    mixin VkWrapperJAST!VkCommandPool;
    VkCommandPoolCreateFlagBits flags;
    uint                        queueIndex;

    this(LogicalDevice device, uint queueIndex, VkCommandPoolCreateFlagBits flags)
    {
        infof("Creating pool for queue family %s with flags %s", queueIndex, flags);

        VkCommandPoolCreateInfo info = 
        {
            queueFamilyIndex: queueIndex,
            flags:            flags
        };

        this.queueIndex = queueIndex;
        CHECK_VK(vkCreateCommandPool(device, &info, null, &this.handle));
    }

    CommandBuffer[] allocate(uint count, IsPrimaryBuffer isPrimary = IsPrimaryBuffer.yes)
    {
        infof("Allocating %s %s command buffers with flags %s.", count, (isPrimary) ? "primary" : "secondary", this.flags);

        VkCommandBufferAllocateInfo info = 
        {
            commandPool:        this,
            level:              (isPrimary) ? VK_COMMAND_BUFFER_LEVEL_PRIMARY : VK_COMMAND_BUFFER_LEVEL_SECONDARY,
            commandBufferCount: count
        };

        // This function will be called *after* LogicalDevice is constructed, so we can safely use g_device now.
        auto handles = new VkCommandBuffer[count];
        CHECK_VK(vkAllocateCommandBuffers(g_device, &info, handles.ptr));

        auto buffers = new CommandBuffer[count];
        foreach(i, handle; handles)
            buffers[i] = CommandBuffer(handle, this.queueIndex);

        return buffers;
    }
}

struct CommandBuffer
{
    mixin VkWrapperJAST!VkCommandBuffer;
    VkCommandPoolCreateFlagBits flags;
    uint                        queueIndex;

    this(VkCommandBuffer handle, uint queueIndex)
    {
        this.handle     = handle;
        this.queueIndex = queueIndex;
    }

    void begin(ResetOnSubmit resetOnSubmit)
    {
        VkCommandBufferBeginInfo info;

        if(resetOnSubmit)
            info.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;

        vkBeginCommandBuffer(this, &info);
    }

    void end()
    {
        vkEndCommandBuffer(this);
    }

    void insertDebugMarker(string name, Color colour = Color(0, 0, 0, 0))
    {
        import std.string : toStringz;

        VkDebugMarkerMarkerInfoEXT info;
        info.pMarkerName = name.toStringz;
        info.color       = [colour.r, colour.g, colour.b, colour.a];

        vkCmdDebugMarkerInsertEXT(this, &info);
    }

    void pushDebugRegion(string name, Color colour = Color(0, 0, 0, 0))
    {
        import std.string : toStringz;

        VkDebugMarkerMarkerInfoEXT info;
        info.pMarkerName = name.toStringz;
        info.color       = [colour.r, colour.g, colour.b, colour.a];

        vkCmdDebugMarkerBeginEXT(this, &info);
    }

    void popDebugRegion()
    {
        vkCmdDebugMarkerEndEXT(this);
    }
}