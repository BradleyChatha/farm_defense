module engine.vulkan.types.vbuffer;

import bindings.vma;
import engine.vulkan, engine.vulkan.types._vkhandlewrapper, engine.util;

struct VBuffer
{
    mixin VkWrapper!(VkBuffer, HasLifetimeInfo.yes);
    VAllocation allocInfo;
    size_t userAllocSize; // VMA may allocate slightly more than was asked for, so we still need to track how much the user specifically asked for.

    this(VkBuffer handle, VAllocation vmaAllocation, size_t userAllocSize)
    {
        this.handle = handle;
        this.allocInfo = vmaAllocation;
        this.userAllocSize = userAllocSize;
    }

    void uploadMapped(scope ubyte[] data, size_t offset)
    {
        const end = offset + data.length;
        assert(end <= this.userAllocSize, "Uploading out of range.");
        assert(this.isMapped, "This function only works on mapped buffers.");

        auto bufferBytePtr = (cast(ubyte*)this.allocInfo.info.pMappedData)[offset..end];
        bufferBytePtr[0..$] = data[0..$];
    }

    void upload2D(VCommandBuffer commands, scope ref VImage image, VkDeviceSize bufferOffset, box2u copyRegion, VkImageSubresourceLayers subresource)
    {
        VkBufferImageCopy copyInfo = 
        {
            bufferOffset: bufferOffset,
            imageSubresource: subresource,
            imageOffset: VkOffset3D(copyRegion.min.x, copyRegion.min.y, 0),
            imageExtent: VkExtent3D(copyRegion.width, copyRegion.height, 1)
        };

        vkCmdCopyImageToBuffer(
            commands.handle,
            image.handle,
            image.currentLayout,
            this.handle,
            1, &copyInfo
        );
    }

    bool isMapped()
    {
        return this.allocInfo.info.pMappedData !is null;
    }

    ubyte[] mappedSlice()
    {
        assert(this.isMapped, "Cannot slice a non-mapped buffer.");
        return (cast(ubyte*)this.allocInfo.info.pMappedData)[0..this.userAllocSize];
    }
}

VObjectRef!VBuffer createBuffer(
    size_t sizeInBytes,
    VkBufferUsageFlags usage,
    VkSharingMode sharing,
    VmaAllocationCreateFlags allocFlags,
    VmaMemoryUsage memoryUsage,
    scope VQueue[] sharingQueues = null
)
{
    UniqueIndexBuffer indexBuffer;
    const uniqueQueueIndicies = sharingQueues.findUniqueIndicies(indexBuffer);
    VkBufferCreateInfo bufferInfo = 
    {
        size                  : sizeInBytes,
        usage                 : usage,
        sharingMode           : sharing,
        queueFamilyIndexCount : cast(uint)uniqueQueueIndicies.length,
        pQueueFamilyIndices   : uniqueQueueIndicies.ptr
    };

    VmaAllocationCreateInfo allocInfo = 
    {
        flags : allocFlags,
        usage : memoryUsage
    };

    VkBuffer buffer;
    VAllocation alloc;
    alloc.usage = memoryUsage;

    CHECK_VK(vmaCreateBuffer(g_vkAllocator, &bufferInfo, &allocInfo, &buffer, &alloc.allocation, &alloc.info));

    auto obj = resourceMake!VBuffer(buffer, alloc, sizeInBytes);
    obj.value.freeImpl = (VBuffer* ptr)
    {
        vmaDestroyBuffer(g_vkAllocator, ptr.handle, ptr.allocInfo.allocation);
    };

    return obj;
}