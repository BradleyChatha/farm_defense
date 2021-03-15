module bindings.vma;

import bindbc.sdl.config : expandEnum;
import engine.vulkan;

extern(C):

alias VmaAllocatorCreateFlags = VkFlags;
alias VmaAllocationCreateFlags = VkFlags;
alias VmaRecordFlags = VkFlags;
alias VmaAllocator = VmaAllocator_T*;
alias VmaPool = VmaPool_T*;
alias VmaAllocation = void*;

alias PFN_vmaAllocateDeviceMemoryFunction = void function(VmaAllocator allocator, uint memoryType, VkDeviceMemory memory, VkDeviceSize size, void* pUserData);
alias PFN_vmaFreeDeviceMemoryFunction = void function(VmaAllocator allocator, uint memoryType, VkDeviceMemory memory, VkDeviceSize size, void* pUserData);

VkResult vmaCreateAllocator(const VmaAllocatorCreateInfo* pCreateInfo, VmaAllocator* pAllocator);
void vmaDestroyAllocator(VmaAllocator allocator);
VkResult vmaCreateBuffer(VmaAllocator allocator, const VkBufferCreateInfo* pBufferCreateInfo, const VmaAllocationCreateInfo* pAllocationCreateInfo, VkBuffer* pBuffer, VmaAllocation* pAllocation, VmaAllocationInfo* pAllocationInfo);
void vmaDestroyBuffer(VmaAllocator allocator, VkBuffer buffer, VmaAllocation allocation);
VkResult vmaCreateImage(VmaAllocator  allocator, const VkImageCreateInfo*  pImageCreateInfo, const VmaAllocationCreateInfo*  pAllocationCreateInfo, VkImage  *  pImage, VmaAllocation  *  pAllocation, VmaAllocationInfo*  pAllocationInfo);
void vmaDestroyImage(VmaAllocator allocator, VkImage image, VmaAllocation allocation);
VkResult vmaMapMemory(VmaAllocator allocator, VmaAllocation allocation, void** ppData);
void vmaUnmapMemory(VmaAllocator allocator, VmaAllocation allocation);
VkResult vmaFlushAllocation(VmaAllocator allocator, VmaAllocation allocation, VkDeviceSize offset, VkDeviceSize size);
VkResult vmaInvalidateAllocation(VmaAllocator allocator, VmaAllocation allocation, VkDeviceSize offset, VkDeviceSize size);
void vmaSetCurrentFrameIndex(VmaAllocator allocator, uint frameIndex);

struct VmaDeviceMemoryCallbacks {
    /// Optional, can be null.
    PFN_vmaAllocateDeviceMemoryFunction pfnAllocate;
    /// Optional, can be null.
    PFN_vmaFreeDeviceMemoryFunction pfnFree;
    /// Optional, can be null.
    void* pUserData;
}

struct VmaVulkanFunctions {
    PFN_vkGetPhysicalDeviceProperties  vkGetPhysicalDeviceProperties;
    PFN_vkGetPhysicalDeviceMemoryProperties  vkGetPhysicalDeviceMemoryProperties;
    PFN_vkAllocateMemory  vkAllocateMemory;
    PFN_vkFreeMemory  vkFreeMemory;
    PFN_vkMapMemory  vkMapMemory;
    PFN_vkUnmapMemory  vkUnmapMemory;
    PFN_vkFlushMappedMemoryRanges  vkFlushMappedMemoryRanges;
    PFN_vkInvalidateMappedMemoryRanges  vkInvalidateMappedMemoryRanges;
    PFN_vkBindBufferMemory  vkBindBufferMemory;
    PFN_vkBindImageMemory  vkBindImageMemory;
    PFN_vkGetBufferMemoryRequirements  vkGetBufferMemoryRequirements;
    PFN_vkGetImageMemoryRequirements  vkGetImageMemoryRequirements;
    PFN_vkCreateBuffer  vkCreateBuffer;
    PFN_vkDestroyBuffer  vkDestroyBuffer;
    PFN_vkCreateImage  vkCreateImage;
    PFN_vkDestroyImage  vkDestroyImage;
    PFN_vkCmdCopyBuffer  vkCmdCopyBuffer;
}

struct VmaRecordSettings
{
    /// Flags for recording. Use #VmaRecordFlagBits enum.
    VmaRecordFlags flags;
    /** \brief Path to the file that should be written by the recording.

    Suggested extension: "csv".
    If the file already exists, it will be overwritten.
    It will be opened for the whole time #VmaAllocator object is alive.
    If opening this file fails, creation of the whole allocator object fails.
    */
    const(char)* pFilePath;
}

/// Description of a Allocator to be created.
struct VmaAllocatorCreateInfo
{
    /// Flags for created allocator. Use #VmaAllocatorCreateFlagBits enum.
    VmaAllocatorCreateFlags flags;
    /// Vulkan physical device.
    /** It must be valid throughout whole lifetime of created allocator. */
    VkPhysicalDevice physicalDevice;
    /// Vulkan device.
    /** It must be valid throughout whole lifetime of created allocator. */
    VkDevice device;
    /// Preferred size of a single `VkDeviceMemory` block to be allocated from large heaps > 1 GiB. Optional.
    /** Set to 0 to use default, which is currently 256 MiB. */
    VkDeviceSize preferredLargeHeapBlockSize;
    /// Custom CPU memory allocation callbacks. Optional.
    /** Optional, can be null. When specified, will also be used for all CPU-side memory allocations. */
    const(VkAllocationCallbacks)* pAllocationCallbacks;
    /// Informative callbacks for `vkAllocateMemory`, `vkFreeMemory`. Optional.
    /** Optional, can be null. */
    const(VmaDeviceMemoryCallbacks)* pDeviceMemoryCallbacks;
    /** \brief Maximum number of additional frames that are in use at the same time as current frame.

    This value is used only when you make allocations with
    VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT flag. Such allocation cannot become
    lost if allocation.lastUseFrameIndex >= allocator.currentFrameIndex - frameInUseCount.

    For example, if you double-buffer your command buffers, so resources used for
    rendering in previous frame may still be in use by the GPU at the moment you
    allocate resources needed for the current frame, set this value to 1.

    If you want to allow any allocations other than used in the current frame to
    become lost, set this value to 0.
    */
    uint frameInUseCount;
    /** \brief Either null or a pointer to an array of limits on maximum number of bytes that can be allocated out of particular Vulkan memory heap.

    If not NULL, it must be a pointer to an array of
    `VkPhysicalDeviceMemoryProperties::memoryHeapCount` elements, defining limit on
    maximum number of bytes that can be allocated out of particular Vulkan memory
    heap.

    Any of the elements may be equal to `VK_WHOLE_SIZE`, which means no limit on that
    heap. This is also the default in case of `pHeapSizeLimit` = NULL.

    If there is a limit defined for a heap:

    - If user tries to allocate more memory from that heap using this allocator,
      the allocation fails with `VK_ERROR_OUT_OF_DEVICE_MEMORY`.
    - If the limit is smaller than heap size reported in `VkMemoryHeap::size`, the
      value of this limit will be reported instead when using vmaGetMemoryProperties().

    Warning! Using this feature may not be equivalent to installing a GPU with
    smaller amount of memory, because graphics driver doesn't necessary fail new
    allocations with `VK_ERROR_OUT_OF_DEVICE_MEMORY` result when memory capacity is
    exceeded. It may return success and just silently migrate some device memory
    blocks to system RAM. This driver behavior can also be controlled using
    VK_AMD_memory_overallocation_behavior extension.
    */
    const(VkDeviceSize)* pHeapSizeLimit;

    /** \brief Pointers to Vulkan functions. Can be null.

    For details see [Pointers to Vulkan functions](@ref config_Vulkan_functions).
    */
    const(VmaVulkanFunctions)* pVulkanFunctions;
    /** \brief Parameters for recording of VMA calls. Can be null.

    If not null, it enables recording of calls to VMA functions to a file.
    If support for recording is not enabled using `VMA_RECORDING_ENABLED` macro,
    creation of the allocator object fails with `VK_ERROR_FEATURE_NOT_PRESENT`.
    */
    const(VmaRecordSettings)* pRecordSettings;
    /** \brief Handle to Vulkan instance object.

    Starting from version 3.0.0 this member is no longer optional, it must be set!
    */
    VkInstance instance;
    /** \brief Optional. The highest version of Vulkan that the application is designed to use.

    It must be a value in the format as created by macro `VK_MAKE_VERSION` or a constant like: `VK_API_VERSION_1_1`, `VK_API_VERSION_1_0`.
    The patch version number specified is ignored. Only the major and minor versions are considered.
    It must be less or equal (preferably equal) to value as passed to `vkCreateInstance` as `VkApplicationInfo::apiVersion`.
    Only versions 1.0, 1.1, 1.2 are supported by the current implementation.
    Leaving it initialized to zero is equivalent to `VK_API_VERSION_1_0`.
    */
    uint vulkanApiVersion;
}

struct VmaAllocator_T
{
}

struct VmaPool_T
{
}

enum VmaMemoryUsage
{
    /** No intended memory usage specified.
    Use other members of VmaAllocationCreateInfo to specify your requirements.
    */
    VMA_MEMORY_USAGE_UNKNOWN = 0,
    /** Memory will be used on device only, so fast access from the device is preferred.
    It usually means device-local GPU (video) memory.
    No need to be mappable on host.
    It is roughly equivalent of `D3D12_HEAP_TYPE_DEFAULT`.

    Usage:

    - Resources written and read by device, e.g. images used as attachments.
    - Resources transferred from host once (immutable) or infrequently and read by
      device multiple times, e.g. textures to be sampled, vertex buffers, uniform
      (constant) buffers, and majority of other types of resources used on GPU.

    Allocation may still end up in `HOST_VISIBLE` memory on some implementations.
    In such case, you are free to map it.
    You can use #VMA_ALLOCATION_CREATE_MAPPED_BIT with this usage type.
    */
    VMA_MEMORY_USAGE_GPU_ONLY = 1,
    /** Memory will be mappable on host.
    It usually means CPU (system) memory.
    Guarantees to be `HOST_VISIBLE` and `HOST_COHERENT`.
    CPU access is typically uncached. Writes may be write-combined.
    Resources created in this pool may still be accessible to the device, but access to them can be slow.
    It is roughly equivalent of `D3D12_HEAP_TYPE_UPLOAD`.

    Usage: Staging copy of resources used as transfer source.
    */
    VMA_MEMORY_USAGE_CPU_ONLY = 2,
    /**
    Memory that is both mappable on host (guarantees to be `HOST_VISIBLE`) and preferably fast to access by GPU.
    CPU access is typically uncached. Writes may be write-combined.

    Usage: Resources written frequently by host (dynamic), read by device. E.g. textures (with LINEAR layout), vertex buffers, uniform buffers updated every frame or every draw call.
    */
    VMA_MEMORY_USAGE_CPU_TO_GPU = 3,
    /** Memory mappable on host (guarantees to be `HOST_VISIBLE`) and cached.
    It is roughly equivalent of `D3D12_HEAP_TYPE_READBACK`.

    Usage:

    - Resources written by device, read by host - results of some computations, e.g. screen capture, average scene luminance for HDR tone mapping.
    - Any resources read or accessed randomly on host, e.g. CPU-side copy of vertex buffer used as source of transfer, but also used for collision detection.
    */
    VMA_MEMORY_USAGE_GPU_TO_CPU = 4,
    /** CPU memory - memory that is preferably not `DEVICE_LOCAL`, but also not guaranteed to be `HOST_VISIBLE`.

    Usage: Staging copy of resources moved from GPU memory to CPU memory as part
    of custom paging/residency mechanism, to be moved back to GPU memory when needed.
    */
    VMA_MEMORY_USAGE_CPU_COPY = 5,
    /** Lazily allocated GPU memory having `VK_MEMORY_PROPERTY_LAZILY_ALLOCATED_BIT`.
    Exists mostly on mobile platforms. Using it on desktop PC or other GPUs with no such memory type present will fail the allocation.

    Usage: Memory for transient attachment images (color attachments, depth attachments etc.), created with `VK_IMAGE_USAGE_TRANSIENT_ATTACHMENT_BIT`.

    Allocations with this usage are always created as dedicated - it implies #VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT.
    */
    VMA_MEMORY_USAGE_GPU_LAZILY_ALLOCATED = 6,

    VMA_MEMORY_USAGE_MAX_ENUM = 0x7FFFFFFF
}
mixin(expandEnum!VmaMemoryUsage);

struct VmaAllocationCreateInfo
{
    /// Use #VmaAllocationCreateFlagBits enum.
    VmaAllocationCreateFlags flags;
    /** \brief Intended usage of memory.

    You can leave #VMA_MEMORY_USAGE_UNKNOWN if you specify memory requirements in other way. \n
    If `pool` is not null, this member is ignored.
    */
    VmaMemoryUsage usage;
    /** \brief Flags that must be set in a Memory Type chosen for an allocation.

    Leave 0 if you specify memory requirements in other way. \n
    If `pool` is not null, this member is ignored.*/
    VkMemoryPropertyFlags requiredFlags;
    /** \brief Flags that preferably should be set in a memory type chosen for an allocation.

    Set to 0 if no additional flags are preferred. \n
    If `pool` is not null, this member is ignored. */
    VkMemoryPropertyFlags preferredFlags;
    /** \brief Bitmask containing one bit set for every memory type acceptable for this allocation.

    Value 0 is equivalent to `UINT32_MAX` - it means any memory type is accepted if
    it meets other requirements specified by this structure, with no further
    restrictions on memory type index. \n
    If `pool` is not null, this member is ignored.
    */
    uint memoryTypeBits;
    /** \brief Pool that this allocation should be created in.

    Leave `VK_NULL_HANDLE` to allocate from default pool. If not null, members:
    `usage`, `requiredFlags`, `preferredFlags`, `memoryTypeBits` are ignored.
    */
    VmaPool pool;
    /** \brief Custom general-purpose pointer that will be stored in #VmaAllocation, can be read as VmaAllocationInfo::pUserData and changed using vmaSetAllocationUserData().

    If #VMA_ALLOCATION_CREATE_USER_DATA_COPY_STRING_BIT is used, it must be either
    null or pointer to a null-terminated string. The string will be then copied to
    internal buffer, so it doesn't need to be valid after allocation call.
    */
    void* pUserData;
    /** \brief A floating-point value between 0 and 1, indicating the priority of the allocation relative to other memory allocations.
    
    It is used only when #VMA_ALLOCATOR_CREATE_EXT_MEMORY_PRIORITY_BIT flag was used during creation of the #VmaAllocator object
    and this allocation ends up as dedicated or is explicitly forced as dedicated using #VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT.
    Otherwise, it has the priority of a memory block where it is placed and this variable is ignored.
    */
    float priority;
}

struct VmaAllocationInfo {
    /** \brief Memory type index that this allocation was allocated from.

    It never changes.
    */
    uint memoryType;
    /** \brief Handle to Vulkan memory object.

    Same memory object can be shared by multiple allocations.

    It can change after call to vmaDefragment() if this allocation is passed to the function, or if allocation is lost.

    If the allocation is lost, it is equal to `VK_NULL_HANDLE`.
    */
    VkDeviceMemory deviceMemory;
    /** \brief Offset in `VkDeviceMemory` object to the beginning of this allocation, in bytes. `(deviceMemory, offset)` pair is unique to this allocation.

    You usually don't need to use this offset. If you create a buffer or an image together with the allocation using e.g. function
    vmaCreateBuffer(), vmaCreateImage(), functions that operate on these resources refer to the beginning of the buffer or image,
    not entire device memory block. Functions like vmaMapMemory(), vmaBindBufferMemory() also refer to the beginning of the allocation
    and apply this offset automatically.

    It can change after call to vmaDefragment() if this allocation is passed to the function, or if allocation is lost.
    */
    VkDeviceSize offset;
    /** \brief Size of this allocation, in bytes.

    It never changes, unless allocation is lost.

    \note Allocation size returned in this variable may be greater than the size
    requested for the resource e.g. as `VkBufferCreateInfo::size`. Whole size of the
    allocation is accessible for operations on memory e.g. using a pointer after
    mapping with vmaMapMemory(), but operations on the resource e.g. using
    `vkCmdCopyBuffer` must be limited to the size of the resource.
    */
    VkDeviceSize size;
    /** \brief Pointer to the beginning of this allocation as mapped data.

    If the allocation hasn't been mapped using vmaMapMemory() and hasn't been
    created with #VMA_ALLOCATION_CREATE_MAPPED_BIT flag, this value is null.

    It can change after call to vmaMapMemory(), vmaUnmapMemory().
    It can also change after call to vmaDefragment() if this allocation is passed to the function.
    */
    void* pMappedData;
    /** \brief Custom general-purpose pointer that was passed as VmaAllocationCreateInfo::pUserData or set using vmaSetAllocationUserData().

    It can change after call to vmaSetAllocationUserData() for this allocation.
    */
    void* pUserData;
}

enum VmaAllocationCreateFlagBits {
    /** \brief Set this flag if the allocation should have its own memory block.

    Use it for special, big resources, like fullscreen images used as attachments.

    You should not use this flag if VmaAllocationCreateInfo::pool is not null.
    */
    VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT = 0x00000001,

    /** \brief Set this flag to only try to allocate from existing `VkDeviceMemory` blocks and never create new such block.

    If new allocation cannot be placed in any of the existing blocks, allocation
    fails with `VK_ERROR_OUT_OF_DEVICE_MEMORY` error.

    You should not use #VMA_ALLOCATION_CREATE_DEDICATED_MEMORY_BIT and
    #VMA_ALLOCATION_CREATE_NEVER_ALLOCATE_BIT at the same time. It makes no sense.

    If VmaAllocationCreateInfo::pool is not null, this flag is implied and ignored. */
    VMA_ALLOCATION_CREATE_NEVER_ALLOCATE_BIT = 0x00000002,
    /** \brief Set this flag to use a memory that will be persistently mapped and retrieve pointer to it.

    Pointer to mapped memory will be returned through VmaAllocationInfo::pMappedData.

    It is valid to use this flag for allocation made from memory type that is not
    `HOST_VISIBLE`. This flag is then ignored and memory is not mapped. This is
    useful if you need an allocation that is efficient to use on GPU
    (`DEVICE_LOCAL`) and still want to map it directly if possible on platforms that
    support it (e.g. Intel GPU).

    You should not use this flag together with #VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT.
    */
    VMA_ALLOCATION_CREATE_MAPPED_BIT = 0x00000004,
    /** Allocation created with this flag can become lost as a result of another
    allocation with #VMA_ALLOCATION_CREATE_CAN_MAKE_OTHER_LOST_BIT flag, so you
    must check it before use.

    To check if allocation is not lost, call vmaGetAllocationInfo() and check if
    VmaAllocationInfo::deviceMemory is not `VK_NULL_HANDLE`.

    For details about supporting lost allocations, see Lost Allocations
    chapter of User Guide on Main Page.

    You should not use this flag together with #VMA_ALLOCATION_CREATE_MAPPED_BIT.
    */
    VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT = 0x00000008,
    /** While creating allocation using this flag, other allocations that were
    created with flag #VMA_ALLOCATION_CREATE_CAN_BECOME_LOST_BIT can become lost.

    For details about supporting lost allocations, see Lost Allocations
    chapter of User Guide on Main Page.
    */
    VMA_ALLOCATION_CREATE_CAN_MAKE_OTHER_LOST_BIT = 0x00000010,
    /** Set this flag to treat VmaAllocationCreateInfo::pUserData as pointer to a
    null-terminated string. Instead of copying pointer value, a local copy of the
    string is made and stored in allocation's `pUserData`. The string is automatically
    freed together with the allocation. It is also used in vmaBuildStatsString().
    */
    VMA_ALLOCATION_CREATE_USER_DATA_COPY_STRING_BIT = 0x00000020,
    /** Allocation will be created from upper stack in a double stack pool.

    This flag is only allowed for custom pools created with #VMA_POOL_CREATE_LINEAR_ALGORITHM_BIT flag.
    */
    VMA_ALLOCATION_CREATE_UPPER_ADDRESS_BIT = 0x00000040,
    /** Create both buffer/image and allocation, but don't bind them together.
    It is useful when you want to bind yourself to do some more advanced binding, e.g. using some extensions.
    The flag is meaningful only with functions that bind by default: vmaCreateBuffer(), vmaCreateImage().
    Otherwise it is ignored.
    */
    VMA_ALLOCATION_CREATE_DONT_BIND_BIT = 0x00000080,
    /** Create allocation only if additional device memory required for it, if any, won't exceed
    memory budget. Otherwise return `VK_ERROR_OUT_OF_DEVICE_MEMORY`.
    */
    VMA_ALLOCATION_CREATE_WITHIN_BUDGET_BIT = 0x00000100,

    /** Allocation strategy that chooses smallest possible free range for the
    allocation.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT  = 0x00010000,
    /** Allocation strategy that chooses biggest possible free range for the
    allocation.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT = 0x00020000,
    /** Allocation strategy that chooses first suitable free range for the
    allocation.

    "First" doesn't necessarily means the one with smallest offset in memory,
    but rather the one that is easiest and fastest to find.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT = 0x00040000,

    /** Allocation strategy that tries to minimize memory usage.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_MEMORY_BIT = VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT,
    /** Allocation strategy that tries to minimize allocation time.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_TIME_BIT = VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT,
    /** Allocation strategy that tries to minimize memory fragmentation.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_MIN_FRAGMENTATION_BIT = VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT,

    /** A bit mask to extract only `STRATEGY` bits from entire set of flags.
    */
    VMA_ALLOCATION_CREATE_STRATEGY_MASK =
        VMA_ALLOCATION_CREATE_STRATEGY_BEST_FIT_BIT |
        VMA_ALLOCATION_CREATE_STRATEGY_WORST_FIT_BIT |
        VMA_ALLOCATION_CREATE_STRATEGY_FIRST_FIT_BIT,

    VMA_ALLOCATION_CREATE_FLAG_BITS_MAX_ENUM = 0x7FFFFFFF
}
mixin(expandEnum!VmaAllocationCreateFlagBits);