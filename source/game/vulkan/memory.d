module game.vulkan.memory;

import std.conv : to;
import std.experimental.logger;
import game.vulkan, game.common.util;

struct GpuCpuBuffer
{
    mixin VkWrapperJAST!VkBuffer;
    VkDeviceMemory memoryHandle;
    size_t         memoryOffset;
    size_t         blockIndex;
    ubyte[]        data;
}

// Block allocator using HOST COHERENT+VISIBLE memory.
struct GpuCpuMemoryAllocator
{
    enum BLOCK_SIZE        = 1024 * 1024 * 256;
    enum PAGE_SIZE         = 512;
    enum PAGES_PER_BLOCK   = BLOCK_SIZE / PAGE_SIZE;
    enum BOOKKEEPING_BYTES = PAGES_PER_BLOCK / 8;

    static struct GpuMemoryBlock
    {
        VkDeviceMemory           handle;
        ubyte[]                  mappedData;
        ubyte[BOOKKEEPING_BYTES] bookkeeping;

        bool allocate(size_t amount, ref ubyte[] data, ref size_t offset)
        {
            const PAGE_COUNT = (amount + (amount % PAGE_SIZE)) / PAGE_SIZE;

            // Find available pages.
            size_t startBit;
            size_t startByte;
            size_t endBit;
            size_t endByte;
            size_t bitCount;
            foreach(byteI, bookByte; this.bookkeeping)
            {
                for(int bitI = 0; bitI < 8; bitI++)
                {
                    if((bookByte & (1 << bitI)) == 0)
                    {
                        bitCount++;
                        if(bitCount == 1)
                        {
                            startBit  = bitI;
                            startByte = byteI;
                        }
                        else
                        {
                            endBit  = bitI;
                            endByte = byteI;
                        }
                    }

                    if(bitCount == PAGE_COUNT)
                        break;
                }
                
                if(bitCount == PAGE_COUNT)
                    break;
            }

            if(bitCount != PAGE_COUNT)
            {
                info("Failed");
                return false;
            }

            if(bitCount == 1)
            {
                endBit  = startBit;
                endByte = startByte;
            }

            // Toggle bits.
            for(size_t byteI = startByte; byteI < endByte + 1; byteI++)
            {
                ubyte bookByte = this.bookkeeping[byteI];
                size_t start;
                size_t end;

                if(byteI == startByte)
                {
                    start = startBit;
                    end   = (startByte != endByte) ? 8 : endBit + 1;
                }
                else if(byteI != endByte)
                {
                    start = 0;
                    end   = 8;
                }
                else
                {
                    start = 0;
                    end   = endBit;
                }

                for(auto bitI = start; bitI < end; bitI++)
                    bookByte |= (1 << bitI);

                this.bookkeeping[byteI] = bookByte;
            }

            // Get page range.
            const firstPage = (PAGE_SIZE * startByte * 8) + (PAGE_SIZE * startBit);
            const lastPage  = (PAGE_SIZE * endByte * 8)   + (PAGE_SIZE * endBit) + PAGE_SIZE;

            infof(
                "Allocating %s bytes (%s pages) of range %s..%s (bits %s[%s]..%s[%s]) of host coherent memory.",
                amount, PAGE_COUNT, firstPage, lastPage, startByte, startBit, endByte, endBit + 1
            );
            data   = this.mappedData[firstPage..firstPage+amount];
            offset = firstPage;
            return true;
        }

        void deallocate(ref ubyte[] data)
        {
            assert(cast(size_t)data.ptr               >= cast(size_t)this.mappedData.ptr 
                && cast(size_t)data.ptr + data.length <= cast(size_t)this.mappedData.ptr + this.mappedData.length);

            // Calculate things.
            const startPage = (cast(size_t)data.ptr - cast(size_t)this.mappedData.ptr) / PAGE_SIZE;
            const endPage   = startPage + ((data.length + (data.length % PAGE_SIZE)) / PAGE_SIZE);
            const startByte = startPage / 8;
            const startBit  = startPage % 8;
            const endByte   = endPage   / 8;
            const endBit    = endPage   % 8;
            infof(
                "Deallocating %s bytes (%s pages) of page range %s..%s (bits %s[%s]..%s[%s]) of host coherent memory.",
                data.length, (endPage - startPage), startPage, endPage, startByte, startBit, endByte, endBit
            );

            // Toggle Bits (copy-pasted from above, but... meh)
            for(size_t byteI = startByte; byteI < endByte + 1; byteI++)
            {
                ubyte bookByte = this.bookkeeping[byteI];
                size_t start;
                size_t end;

                if(byteI == startByte)
                {
                    start = startBit;
                    end   = (startByte != endByte) ? 8 : endBit + 1;
                }
                else if(byteI != endByte)
                {
                    start = 0;
                    end   = 8;
                }
                else
                {
                    start = 0;
                    end   = endBit;
                }

                for(auto bitI = start; bitI < end; bitI++)
                    bookByte &= ~(1 << bitI);

                this.bookkeeping[byteI] = bookByte;
            }

            data = null;
        }
    }

    uint             memoryTypeIndex;
    VkMemoryType     memoryType;
    GpuMemoryBlock[] blocks;

    void init()
    {
        this.memoryType = g_gpu.getMemoryType(VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT, Ref(this.memoryTypeIndex));
    }

    GpuCpuBuffer* allocate(size_t amount, VkBufferUsageFlags usage)
    {
        assert(amount <= BLOCK_SIZE, "Allocating too much >:(");

        GpuCpuBuffer* allocation = new GpuCpuBuffer;
        while(allocation.data is null)
        {
            foreach(i, ref block; this.blocks)
            {
                if(block.allocate(amount, Ref(allocation.data), Ref(allocation.memoryOffset)))
                {
                    allocation.blockIndex   = i;
                    allocation.memoryHandle = block.handle;
                    break;
                }
            }

            if(allocation.data is null)
            {
                info("No blocks available, creating new one...");
                GpuMemoryBlock newBlock;
                VkMemoryAllocateInfo info = 
                {
                    allocationSize:  BLOCK_SIZE,
                    memoryTypeIndex: this.memoryTypeIndex
                };

                CHECK_VK(vkAllocateMemory(g_device, &info, null, &newBlock.handle));
                vkTrackJAST(wrapperOf!VkDeviceMemory(newBlock.handle));

                void* mapped;
                CHECK_VK(vkMapMemory(g_device, newBlock.handle, 0, BLOCK_SIZE, 0, &mapped));
                newBlock.mappedData = cast(ubyte[])mapped[0..BLOCK_SIZE];

                this.blocks ~= newBlock;
            }
        }

        auto index = cast(uint)g_gpu.transferQueueIndex.get();
        VkBufferCreateInfo info = 
        {                  
            flags:                 0,
            size:                  amount,
            usage:                 usage,
            sharingMode:           VK_SHARING_MODE_EXCLUSIVE,
            queueFamilyIndexCount: 1,
            pQueueFamilyIndices:   &index
        };

        CHECK_VK(vkCreateBuffer(g_device, &info, null, &allocation.handle));
        CHECK_VK(vkBindBufferMemory(g_device, allocation.handle, allocation.memoryHandle, allocation.memoryOffset));
        vkTrackJAST(allocation);

        return allocation;
    }

    void deallocate(ref GpuCpuBuffer* buffer)
    {
        this.blocks[buffer.blockIndex].deallocate(buffer.data);
        vkDestroyJAST(buffer);
        buffer = null;
    }
}