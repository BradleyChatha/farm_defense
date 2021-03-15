module engine.vulkan.types._vkhandlewrapper;

import std.typecons : Flag;
import bindings.vma;
import engine.vulkan;

package string debugTypeOf(T)()
{
    import std.uni : isUpper, toUpper;
    static assert(T.stringof[0..2] == "Vk");

    char[] buffer;
    buffer.reserve(T.stringof.length);

    foreach(ch; T.stringof[2..$])
    {
        if(ch.isUpper)
            buffer ~= "_";
        buffer ~= ch.toUpper();
    }

    const HANDLE_SUFFIX = "_HANDLE*";
    if(buffer.length >= HANDLE_SUFFIX.length && buffer[$-HANDLE_SUFFIX.length..$] == HANDLE_SUFFIX)
        buffer.length -= HANDLE_SUFFIX.length;
    
    if(buffer.length >= 6 && buffer[$-6..$] == "_K_H_R")
    {
        buffer[$-5..$-2] = "KHR";
        buffer.length -= 2;
    }

    return "VK_OBJECT_TYPE"~buffer;
}
static assert(debugTypeOf!VkSwapchainKHR == "VK_OBJECT_TYPE_SWAPCHAIN_KHR", debugTypeOf!VkSwapchainKHR);

alias VkWrapperFreeFunc(WrapperT) = void function(WrapperT*);
alias HasLifetimeInfo = Flag!"lifetimeInfo";

mixin template VkWrapper(VType, HasLifetimeInfo hasLifetime = HasLifetimeInfo.no)
{
    VType          handle;
    private string _debugName;

    static if(hasLifetime)
    {
        import engine.core.interfaces;

        mixin IDisposableBoilerplate;

        VkWrapperFreeFunc!(typeof(this)) freeImpl;
        package(engine.vulkan) size_t    allocVersion;
        package(engine.vulkan) bool      isMarkedForDeletion;

        @disable this(this) {}
        ~this()
        {
            this.dispose();
        }

        private void disposeImpl()
        {
            if(this.freeImpl !is null)
                this.freeImpl(&this);
        }
    }

    mixin("alias DebugT = "~debugTypeOf!VType~";");
    
    @property
    void debugName(string name)
    {
        this._debugName = name;

        import std.string : toStringz;
        if(vkSetDebugUtilsObjectNameEXT !is null)
        {
            VkDebugUtilsObjectNameInfoEXT info = 
            {
                objectType:   DebugT,
                objectHandle: cast(ulong)this.handle,
                pObjectName:  name.toStringz
            };
            vkSetDebugUtilsObjectNameEXT(g_device.logical, &info);
        }
    }

    @property
    string debugName()
    {
        return this._debugName;
    }

    string toString() const
    {
        import std.traits : Unqual;
        import std.format : format;
        return "%s%s with handle %s".format(Unqual!(typeof(this)).stringof, this._debugName is null ? "" : " called "~this._debugName, this.handle);
    }
}