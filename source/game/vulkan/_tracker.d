module game.vulkan._tracker;

import std.experimental.logger;
import std.traits : isType, isCallable, Parameters, isPointer;
import std.meta   : AliasSeq;
import containers.hashset;
import game.vulkan;

private const SYMBOL_PREFIX = "__set_";
private enum SymbolNameOf(alias VkType) = (isPointer!VkType) ? SYMBOL_PREFIX~VkType.stringof[0..$-1]~"PTR" : SYMBOL_PREFIX~VkType.stringof;

private mixin template GenericTracking(alias VkType, alias DestroyFunc)
if(isType!VkType && isCallable!DestroyFunc)
{
    mixin("private HashSet!VkType "~SymbolNameOf!VkType~";");

    bool vkTrackJAST(VkType value)
    {
        tracef("Begin tracking %s", value.toString());
        return mixin(SymbolNameOf!VkType~".insert(value)");
    }

    bool vkUntrackJAST(VkType value)
    {
        tracef("Stop tracking %s", value.toString());
        return mixin(SymbolNameOf!VkType~".remove(value)");
    }

    void vkDestroyJAST(string FILE = __FILE__, size_t LINE = __LINE__, string FUNC = __PRETTY_FUNCTION__)
                      (VkType value)
    {
        tracef("Destroying tracked %s from %s:%s:%s", value.toString(), FILE, LINE, FUNC);
        const untracked = vkUntrackJAST(value);
        assert(untracked, "Value was not being tracked by the tracker.");

        alias Params = Parameters!DestroyFunc;
        static if(is(Params[0] == VkInstance))
            DestroyFunc(g_vkInstance, value.handle, null);
        else static if(is(Params[0] == VkDevice))
            DestroyFunc(g_device, value.handle, null);
        else static if(is(Params[0] == VkType))
            DestroyFunc(value);
        else static assert(false, "Don't know how to handle destroy func automatically: "~typeof(DestroyFunc).stringof);
    }
}

private mixin template SwapchainResourceTracking(alias VkType, alias DestroyFunc, alias RecreateFunc)
if(isType!VkType && isCallable!DestroyFunc)
{
    static assert(isPointer!VkType, "Swapchain resources must be pointers, to properly handle swapchain recreation.");

    mixin GenericTracking!(VkType, DestroyFunc);

    void vkRecreateJAST(VkType value)
    {
        tracef("Recreating tracked %s", value.toString());
        RecreateFunc(value);
        tracef("New handle is %s", value.handle);
    }
}

void vkDestroyAllJAST()
{
    import std.array : array;

    info("Destroying all tracked Vulkan objects.");
    static foreach(member; __traits(allMembers, game.vulkan._tracker))
    {{
        static if(member.length >= SYMBOL_PREFIX.length 
               && member[0..SYMBOL_PREFIX.length] == SYMBOL_PREFIX
        )
        {
            mixin("foreach(value; "~member~"[].array){ vkDestroyJAST(value); }");
        }
    }}
}

void vkRecreateAllJAST()
{
    import std.array : array;

    info("Recreating all tracked Vulkan objects.");
    static foreach(member; __traits(allMembers, game.vulkan._tracker))
    {{
        static if(member.length >= SYMBOL_PREFIX.length 
               && member[0..SYMBOL_PREFIX.length] == SYMBOL_PREFIX
        )
        {
            alias VkType = Parameters!(typeof(typeof(__traits(getMember, game.vulkan._tracker, member)).insert))[0];
            static if(__traits(compiles, vkRecreateJAST(VkType.init)))
                mixin("foreach(value; "~member~"[].array){ vkRecreateJAST(value); }");
        }
    }}
}

private void genericRecreate(T)(T value)
{
    value.recreateFunc(value);
}

template wrapperNameOf(alias VkType)
{
    const wrapperNameOf = debugTypeOf!VkType~"_WRAPPER";
}

mixin template GenericWrapper(alias VkType, alias DestroyFunc) 
{
    const NAME = wrapperNameOf!VkType;

    // When do we reach the point of too many mixins?
    mixin("struct "~NAME~" { mixin VkWrapperJAST!VkType; }");
    mixin("mixin GenericTracking!("~NAME~", DestroyFunc);");
}

template wrapperOf(alias VkType)
{
    mixin("alias wrapperOf = "~wrapperNameOf!VkType~";");
}

void vkDestroyCommandBufferJAST(CommandBuffer buffer)
{
    vkFreeCommandBuffers(g_device, buffer.pool, 1, &buffer.handle);
}

void vkDestroyImageJAST(GpuImage* image)
{
    vkDestroyImage(g_device, image.handle, null);
    
    if(image.memory !is null)
        g_gpuAllocator.deallocate(image.memory);
}

mixin GenericTracking           !(ShaderModule,             vkDestroyShaderModule                                               );
mixin GenericTracking           !(Surface,                  vkDestroySurfaceKHR                                                 );
mixin GenericTracking           !(Fence,                    vkDestroyFence                                                      );
mixin GenericTracking           !(Semaphore,                vkDestroySemaphore                                                  );
mixin GenericWrapper            !(VkDescriptorSetLayout,    vkDestroyDescriptorSetLayout                                        );
mixin GenericWrapper            !(VkPipelineLayout,         vkDestroyPipelineLayout                                             );
mixin GenericTracking           !(RenderPass,               vkDestroyRenderPass                                                 );
mixin GenericWrapper            !(VkDescriptorPool,         vkDestroyDescriptorPool                                             );
mixin GenericTracking           !(CommandBuffer,            vkDestroyCommandBufferJAST                                          );
mixin GenericTracking           !(CommandPool,              vkDestroyCommandPool                                                );
mixin GenericTracking           !(Sampler*,                 vkDestroySampler                                                    );
mixin SwapchainResourceTracking !(GpuImageView*,            vkDestroyImageView,             genericRecreate!(GpuImageView*)     );
mixin GenericTracking           !(GpuImage*,                vkDestroyImageJAST                                                  );
mixin SwapchainResourceTracking !(PipelineBase*,            vkDestroyPipeline,              genericRecreate!(PipelineBase*)     );
mixin SwapchainResourceTracking !(DescriptorPool*,          vkDestroyDescriptorPool,        genericRecreate!(DescriptorPool*)   );
mixin SwapchainResourceTracking !(Framebuffer*,             vkDestroyFramebuffer,           genericRecreate!(Framebuffer*)      );
mixin GenericTracking           !(GpuCpuBuffer*,            vkDestroyBuffer                                                     );
mixin GenericTracking           !(GpuBuffer*,               vkDestroyBuffer                                                     );
mixin GenericWrapper            !(VkDeviceMemory,           vkFreeMemory                                                        );