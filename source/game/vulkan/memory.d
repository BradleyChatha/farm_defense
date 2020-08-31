module game.vulkan.memory;

import std.conv : to;
import std.experimental.logger;
import game.vulkan, game.common;

struct GpuCpuBuffer
{
    mixin VkWrapperJAST!VkBuffer;
    ubyte[]         data;
    GpuMemoryRange  memoryRange;
    GpuMemoryBlock* memoryBlock;
}

struct GpuMemoryRange
{
    VkDeviceMemory memoryHandle;
    size_t         offset;
    size_t         length;
}

/++
 + Giant chunk of GPU memory of any memory type, managed with in bitmapped blocks.
 +
 + Notes:
 +  Data can only be mapped if the memory type is HOST_VISIBLE.
 +
 + Issues:
 +  This block allocator doesn't perform defragging, which for this game won't be an issue (hopefully).
 + ++/
struct GpuMemoryBlock
{
    enum BLOCK_SIZE      = 1024 * 1024 * 256;
    enum PAGE_SIZE       = 512;
    enum PAGES_PER_BLOCK = BLOCK_SIZE / PAGE_SIZE;

    alias Bookkeeper = BitmappedBookkeeper!PAGES_PER_BLOCK;

    VkDeviceMemory handle;
    Bookkeeper     bookkeeper;

    this(uint memoryTypeIndex)
    {
        infof("Creating new memory block for memory type %s", memoryTypeIndex);
        VkMemoryAllocateInfo info = 
        {
            allocationSize:  BLOCK_SIZE,
            memoryTypeIndex: memoryTypeIndex
        };

        CHECK_VK(vkAllocateMemory(g_device, &info, null, &this.handle));
        vkTrackJAST(wrapperOf!VkDeviceMemory(this.handle));

        this.bookkeeper.setup();
    }

    void map(ref ubyte[] mapped)
    {
        info("Mapping memory");

        void* ptr;
        CHECK_VK(vkMapMemory(g_device, this.handle, 0, BLOCK_SIZE, 0, &ptr));
        mapped = cast(ubyte[])ptr[0..BLOCK_SIZE];
    }

    bool allocate(size_t amount, ref GpuMemoryRange memory)
    {
        const PAGE_COUNT = amountDivideMagnitudeRounded(amount, PAGE_SIZE);
        assert(PAGE_COUNT != 0);

        size_t bitIndex;
        auto couldAllocate = this.bookkeeper.markNextNBits(Ref(bitIndex), PAGE_COUNT);
        if(!couldAllocate)
        {
            info("Failed");
            return false;
        }

        // Get page range.
        const startBit  = bitIndex % 8;
        const endBit    = (bitIndex + PAGE_COUNT) % 8;
        const startByte = bitIndex / 8;
        const endByte   = (bitIndex + PAGE_COUNT) / 8;
        const firstPage = (PAGE_SIZE * startByte * 8) + (PAGE_SIZE * startBit);
        const lastPage  = (PAGE_SIZE * endByte * 8)   + (PAGE_SIZE * endBit);

        infof(
            "Allocating %s bytes (%s pages) of byte range %s..%s (bits %s[%s]..%s[%s]) of host coherent memory.",
            amount, PAGE_COUNT, firstPage, lastPage, startByte, startBit, endByte, endBit
        );
        memory = GpuMemoryRange(this.handle, firstPage, amount);
        return true;
    }

    void deallocate(ref GpuMemoryRange memory)
    {
        assert(memory.memoryHandle == this.handle);

        // Calculate things.
        const startPage = memory.offset / PAGE_SIZE;
        const endPage   = amountDivideMagnitudeRounded(memory.offset + memory.length, PAGE_SIZE);
        const startByte = startPage / 8;
        const startBit  = startPage % 8;
        const endByte   = endPage   / 8;
        const endBit    = endPage   % 8;
        infof(
            "Deallocating %s bytes (%s pages) of page range %s..%s (bits %s[%s]..%s[%s]) of host coherent memory.",
            memory.length, (endPage - startPage), startPage, endPage, startByte, startBit, endByte, endBit
        );

        this.bookkeeper.setBitRange!false(startPage, endPage - startPage);
        memory = GpuMemoryRange.init;
    }
}

// Block allocator using HOST COHERENT+VISIBLE memory.
struct GpuCpuMemoryAllocator
{
    struct BlockInfo
    {
        GpuMemoryBlock* block;
        ubyte[]         mappedData;
    }

    uint         memoryTypeIndex;
    VkMemoryType memoryType;
    BlockInfo[]  blocks;

    void init()
    {
        this.memoryType = g_gpu.getMemoryType(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, Ref(this.memoryTypeIndex));
    }

    GpuCpuBuffer* allocate(size_t amount, VkBufferUsageFlags usage)
    {
        assert(amount <= GpuMemoryBlock.BLOCK_SIZE, "Allocating too much >:(");

        GpuCpuBuffer* allocation = new GpuCpuBuffer;
        while(allocation.data is null)
        {
            foreach(i, info; this.blocks)
            {
                if(info.block.allocate(amount, Ref(allocation.memoryRange)))
                {
                    allocation.data        = info.mappedData[allocation.memoryRange.offset..allocation.memoryRange.offset + allocation.memoryRange.length];
                    allocation.memoryBlock = info.block;
                    assert(allocation.data.length == allocation.memoryRange.length);
                    assert(allocation.data.length == amount);
                    break;
                }
            }

            if(allocation.memoryRange.memoryHandle == VK_NULL_HANDLE)
            {
                info("No blocks available, creating new one...");
                this.blocks ~= BlockInfo(new GpuMemoryBlock(this.memoryTypeIndex));
                this.blocks[$-1].block.map(this.blocks[$-1].mappedData);
            }
        }

        auto index = cast(uint)g_gpu.transferQueueIndex.get();
        VkBufferCreateInfo info = 
        {                  
            flags:                 0,
            size:                  allocation.memoryRange.length,
            usage:                 usage,
            sharingMode:           VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 1,
            pQueueFamilyIndices:   &index
        };

        CHECK_VK(vkCreateBuffer(g_device, &info, null, &allocation.handle));
        CHECK_VK(vkBindBufferMemory(g_device, allocation.handle, allocation.memoryRange.memoryHandle, allocation.memoryRange.offset));
        vkTrackJAST(allocation);

        return allocation;
    }

    void deallocate(ref GpuCpuBuffer* buffer)
    {
        buffer.memoryBlock.deallocate(buffer.memoryRange);
        vkDestroyJAST(buffer);
        buffer = null;
    }
}