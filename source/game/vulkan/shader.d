module game.vulkan.shader;

import std.file : fread = read;
import std.experimental.logger;
import game.vulkan, erupted, game.common.maths;

enum ShaderModuleType
{
    UNKNOWN,
    vertex,
    fragment
}

struct ShaderModule
{
    mixin VkWrapperJAST!VkShaderModule;
    ShaderModuleType                type;
    VkPipelineShaderStageCreateInfo pipelineStage;

    this(ref ubyte[] byteCode, ShaderModuleType type)
    {
        // We have to pass it as a uint*, except we also have to specify
        // the length in bytes. So we need to align to 4 bytes.
        if(byteCode.length % 4 != 0)
            byteCode.length += (byteCode.length % 4);

        // Create the shader
        VkShaderModuleCreateInfo info;
        info.codeSize = byteCode.length;         // In bytes
        info.pCode    = cast(uint*)byteCode.ptr; // As uint*

        CHECK_VK(vkCreateShaderModule(g_device, &info, null, &this.handle));

        // Generate information needed for pipeline creation.
        VkShaderStageFlagBits stageMask;
        final switch(type) with(ShaderModuleType)
        {
            case UNKNOWN:  assert(false, "Unknown shader type, literally.");
            case vertex:   stageMask = VK_SHADER_STAGE_VERTEX_BIT;   break;
            case fragment: stageMask = VK_SHADER_STAGE_FRAGMENT_BIT; break;
        }
        
        this.pipelineStage.stage   = stageMask;
        this.pipelineStage.module_ = this.handle;
        this.pipelineStage.pName   = "main";
        this.type                  = type;

        vkTrackJAST(this);
    }

    this(string file, ShaderModuleType type)
    {
        infof("Loading %s shader from file %s", type, file);
        auto buffer = cast(ubyte[])fread(file);
        this(buffer, type);
    }
}

struct Shader(PushConstantsT_, UniformStructT_)
{
    // Forwarding, so other types can get this info easily.
    alias PushConstantsT = PushConstantsT_;
    alias UniformStructT = UniformStructT_;
    
    static assert(PushConstantsT.sizeof <= 128, "The Vulkan spec mandates that 128 bytes is the minimum supported length, so we're using that as our maximum length.");

    ShaderModule vertex;
    ShaderModule fragment;

    this(ref ubyte[] vertexBytes, ref ubyte[] fragmentBytes)
    {
        this.vertex   = ShaderModule(vertexBytes, ShaderModuleType.vertex);
        this.fragment = ShaderModule(fragmentBytes, ShaderModuleType.fragment);
    }

    this(string vertexFile, string fragmentFile, string debugName)
    {
        this.vertex   = ShaderModule(vertexFile, ShaderModuleType.vertex);
        this.fragment = ShaderModule(fragmentFile, ShaderModuleType.fragment);

        this.vertex.debugName   = debugName~" - VERTEX";
        this.fragment.debugName = debugName~" - FRAGMENT";
    }
}