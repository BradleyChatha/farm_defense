module game.vulkan.tracker;

import std.experimental.logger;
import std.traits : isType, isCallable, Parameters, isPointer;
import std.meta   : AliasSeq;
import containers.hashset;
import game.vulkan;

private struct IsGeneric;
private struct IsSwapchainResource;

private const SYMBOL_PREFIX = "__set_";
private enum SymbolNameOf(alias VkType) = (isPointer!VkType) ? SYMBOL_PREFIX~VkType.stringof[0..$-1] : SYMBOL_PREFIX~VkType.stringof;

private mixin template GenericTracking(alias VkType, alias DestroyFunc)
if(isType!VkType && isCallable!DestroyFunc)
{
    mixin("private HashSet!VkType "~SymbolNameOf!VkType~";");

    bool vkTrackJAST(VkType value)
    {
        infof("Begin tracking %s %s", VkType.stringof, value);
        return mixin(SymbolNameOf!VkType~".insert(value)");
    }

    bool vkUntrackJAST(VkType value)
    {
        infof("Stop tracking %s %s", VkType.stringof, value);
        return mixin(SymbolNameOf!VkType~".remove(value)");
    }

    void vkDestroyJAST(VkType value)
    {
        infof("Destroying tracked %s %s", VkType.stringof, value);
        assert(vkUntrackJAST(value), "Value was not being tracked by the tracker.");

        alias Params = Parameters!DestroyFunc;
        static if(is(Params[0] == VkInstance))
            DestroyFunc(g_vkInstance, value.handle, null);
        else static if(is(Params[0] == VkDevice))
            DestroyFunc(g_device, value.handle, null);
        else static assert(false, "Don't know how to handle destroy func automatically: "~DestroyFunc.stringof);
    }
}

private mixin template SwapchainResourceTracking(alias VkType, alias DestroyFunc, alias RecreateFunc)
if(isType!VkType && isCallable!DestroyFunc)
{
    static assert(isPointer!VkType, "Swapchain resources must be pointers, to properly handle swapchain recreation.");

    mixin GenericTracking!(VkType, DestroyFunc);

    void vkRecreateJAST(VkType value)
    {
        infof("Recreating tracked %s %s", VkType.stringof, value);
        RecreateFunc(value);
    }
}

void vkDestroyAllJAST()
{
    info("Destroying all tracked Vulkan objects.");
    static foreach(member; __traits(allMembers, game.vulkan.tracker))
    {{
        static if(member.length >= SYMBOL_PREFIX.length 
               && member[0..SYMBOL_PREFIX.length] == SYMBOL_PREFIX
        )
        {
            mixin("foreach(value; "~member~"){ vkDestroyJAST(value); }");
        }
    }}
}

void vkRecreateAllJAST()
{
    info("Recreating all tracked Vulkan objects.");
    static foreach(member; __traits(allMembers, game.vulkan.tracker))
    {{
        static if(member.length >= SYMBOL_PREFIX.length 
               && member[0..SYMBOL_PREFIX.length] == SYMBOL_PREFIX
        )
        {
            alias VkType = Parameters!(typeof(typeof(__traits(getMember, game.vulkan.tracker, member)).insert))[0];
            static if(__traits(compiles, vkRecreateJAST(VkType.init)))
                mixin("foreach(value; "~member~"){ vkDestroyJAST(value); }");
        }
    }}
}

private void genericRecreate(T)(T value)
{
    value.recreateFunc(value);
}

mixin GenericTracking!(Surface, vkDestroySurfaceKHR);
mixin SwapchainResourceTracking!(GpuImageView*, vkDestroyImageView, genericRecreate!(GpuImageView*));