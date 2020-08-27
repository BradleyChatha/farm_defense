module game.vulkan.pipeline;

import std.conv : to;
import std.experimental.logger;
import game.common.util, game.vulkan, game.graphics.window, game.common.maths;

struct Pipeline(VertexT)
{
    mixin VkSwapchainResourceWrapperJAST!VkPipeline;

    static void create(
        scope ref   typeof(this)*                       ptr,
                    VkVertexInputBindingDescription     vertexBinding,
                    VkVertexInputAttributeDescription[] vertexAttributes
    )
    {
        const areWeRecreating = ptr !is null;
        if(!areWeRecreating)
            ptr = new typeof(this)();
        infof("%s a %s.", (areWeRecreating) ? "Recreating" : "Creating", typeof(this).stringof);

        // Just to pass the invariant for now.
        int dummy;
        ptr.handle       = cast(VkPipeline)&dummy;
        ptr.recreateFunc = (p) => create(p, vertexBinding, vertexAttributes);

        // ALL Vulkan structs we're populating.
        VkPipelineVertexInputStateCreateInfo vertInputState;
        VkPipelineViewportStateCreateInfo    viewport;

        info("Defining vertex state.");
        with(vertInputState)
        {
            vertexBindingDescriptionCount   = 1;
            vertexAttributeDescriptionCount = vertexAttributes.length.to!uint;
            pVertexBindingDescriptions      = &vertexBinding;
            pVertexAttributeDescriptions    = vertexAttributes.ptr;
        }

        info("Defining viewport and scissor rect.");
        VkRect2D scissor;
        scissor.offset = VkOffset2D(0, 0);
        scissor.extent = Window.size.toExtent;

        VkViewport view;
        view.x        = 0;
        view.y        = 0;
        view.width    = Window.size.x;
        view.height   = Window.size.y;
        view.minDepth = 0.0f;
        view.maxDepth = 1.0f;
    
        with(viewport)
        {
            viewport.viewportCount = 1;
            viewport.scissorCount  = 1;
            viewport.pViewports    = &view;
            viewport.pScissors     = &scissor;
        }

        infof("Scissor:  %s", scissor);
        infof("Viewport: %s", view);
    }
}

struct PipelineBuilder(VertexT)
{
    static assert(__traits(hasMember, VertexT, "defineAttributes"), "Vertex type "~VertexT.stringof~" must have a function called `defineAttributes`");

    VkVertexInputAttributeDescription[] vertexAttributes;
    VkVertexInputBindingDescription     vertexBinding;

    PipelineBuilder initialSetup()
    {
        info("Initial Setup.");

        infof("Allowing Vertex Type %s to define its attributes.", VertexT.stringof);
        VertexAttributeBuilder vertexAttributeBuilder;
        VertexT.defineAttributes(Ref(vertexAttributeBuilder));
        this.vertexAttributes = vertexAttributeBuilder.build();

        info("Defining Vertex binding.");
        this.vertexBinding.binding   = 0;
        this.vertexBinding.stride    = VertexT.sizeof;
        this.vertexBinding.inputRate = VK_VERTEX_INPUT_RATE_VERTEX;
        infof("Binding: %s", this.vertexBinding);

        return this;
    }

    Pipeline!(VertexT)* build()
    {
        typeof(return) ptr = null;
        typeof(return).create(
            ptr,
            this.vertexBinding,
            this.vertexAttributes
        );
        
        return ptr;
    }
}

struct VertexAttributeBuilder
{
    private VkVertexInputAttributeDescription[] _attributes;

    VkVertexInputAttributeDescription[] build()
    {
        return this._attributes;
    }

    InputBuilder location(uint loc) return
    {
        infof("\t[Start location %s]", loc);
        // InputBuilder must never outlive this struct in order for this to be safe.
        return InputBuilder(&this, loc);
    }

    static struct InputBuilder
    {
        private VertexAttributeBuilder*           _builder;
        private VkVertexInputAttributeDescription _info;

        this(VertexAttributeBuilder* builder, uint location)
        {
            this._builder       = builder;
            this._info.binding  = 0;
            this._info.location = location;
        }

        InputBuilder format(VkFormat format_)
        {
            infof("\t\tFormat: %s", format_);
            this._info.format = format_;
            return this;
        }
        
        InputBuilder offset(uint offset_)
        {
            infof("\t\tOffset: %s", offset_);
            this._info.offset = offset_;
            return this;
        }

        VertexAttributeBuilder build()
        {
            info("\t\t[End]");
            this._builder._attributes ~= this._info;
            return *this._builder;
        }
    }
}