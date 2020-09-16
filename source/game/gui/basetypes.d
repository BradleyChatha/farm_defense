module game.gui.basetypes;

import game.core, game.common, game.graphics;

alias AddDrawCommandsFunc = void delegate(DrawCommand[] commands);

enum HorizAlignment
{
    left,
    center,
    right
}

enum VertAlignment
{
    top,
    center,
    bottom
}

final class Gui : IDisposable, IMessageHandler
{
    mixin IDisposableBoilerplate;
    mixin IMessageHandlerBoilerplate;

    private
    {
        alias ControlAllocator = PoolAllocatorBase!(1024 * 16); // Since we're going with the "Gui.make" thing, may as well add a little data locality here.

        ControlAllocator _allocator;
        Container        _root;
        DrawCommand[]    _commands;
        size_t           _commandCount;

        void addDrawCommands(DrawCommand[] commands)
        {
            const end = this._commandCount + commands.length;
            if(end >= this._commands.length)
                this._commands.length = end * 2;

            this._commands[this._commandCount..end] = commands[0..$];
            this._commandCount += commands.length;
        }
    }

    this()
    {
        messageBusSubscribe(this);
    }

    void onUpdate()
    {
        this._root.onUpdate();
    }

    DrawCommand[] gatherDrawCommands()
    {
        this._root.onDraw(&this.addDrawCommands);
        auto slice = this._commands[0..this._commandCount];
        this._commandCount = 0;
        return slice;
    }

    void onDispose()
    {
        messageBusUnsubscribe(this);
        this._root.dispose();
    }

    ControlT make(ControlT : Control, Args...)(Args args)
    {
        auto control = this._allocator.make!ControlT(args);
        (cast(Control)control)._gui = this; // Bypass strange accessability quirk.

        return control;
    }

    @Subscribe
    void onMouseMotion(MouseMotionMessage message)
    {
        this._root.onMouseMotion(message);
    }

    @Subscribe
    void onMouseButton(MouseButtonMessage message)
    {
        this._root.onMouseButton(message);
    }

    @Subscribe
    void onKeyButton(KeyButtonMessage message)
    {
        this._root.onKeyButton(message);
    }

    @property
    void root(Container control)
    {
        assert(control !is null);
        assert(control.gui is this, "This control must originate from this Gui instance.");
        assert(!control.isDisposed);
        this._root = control;
    }

    @property
    Container root()
    {
        return this._root;
    }
}

abstract class Control : IDisposable, ITransformable!(AddHooks.yes)
{
    mixin IDisposableBoilerplate;
    mixin ITransformableBoilerplate;

    private
    {
        Gui            _gui;
        Control        _parent;
        vec2f          _size;
        HorizAlignment _horizAlignment;
        VertAlignment  _vertAlignment;
    }


    // Override as needed.
    public
    {
        void onUpdate(){}
        void onDraw(AddDrawCommandsFunc addCommands){}
        void onDispose(){}
        void onTransformChanged(){}
        void onLayoutChanged(){}

        // Events should go down to the "lowest" children first, and *then* bubble upwards.

        void onMouseMotion(MouseMotionMessage message){}
        void onMouseButton(MouseButtonMessage message){}
        void onKeyButton(KeyButtonMessage message){}
    }

    private void onLayoutChangedImpl()
    {
        this.onLayoutChanged();

        if(this.parent !is null)
            this.parent.onLayoutChangedImpl();
    }

    final void alignWithinBox(box2f box)
    {
        vec2f position = vec2f(0);

        final switch(this.horizAlignment) with(HorizAlignment)
        {
            case left:   position.x = box.min.x;                                    break;
            case center: position.x = box.min.x + ((box.size.x - this.size.x) / 2); break;
            case right:  position.x = (box.min.x + box.size.x) - this.size.x;       break;
        }

        final switch(this.vertAlignment) with(VertAlignment)
        {
            case top:    position.y = box.min.y;                                    break;
            case center: position.y = box.min.y + ((box.size.y - this.size.y) / 2); break;
            case bottom: position.y = (box.min.y + box.size.y) - this.size.y;       break;
        }

        this.position = position;
    }

    @property
    final void size(vec2f siz)
    {
        auto oldSize = this._size;
        this._size   = siz;

        if(oldSize != siz)
            this.onLayoutChangedImpl();
    }

    @property
    final void horizAlignment(HorizAlignment alignment)
    {
        this._horizAlignment = alignment;
        this.onLayoutChangedImpl();
    }

    @property
    final void vertAlignment(VertAlignment alignment)
    {
        this._vertAlignment = alignment;
        this.onLayoutChangedImpl();
    }

    @property
    final vec2f size()
    {
        return this._size;
    }

    @property
    final HorizAlignment horizAlignment()
    {
        return this._horizAlignment;
    }

    @property
    final VertAlignment vertAlignment()
    {
        return this._vertAlignment;
    }

    @property
    final Control parent()
    {
        return this._parent;
    }

    @property
    final Gui gui()
    {
        return this._gui;
    }
}

abstract class Container : Control
{
    private
    {
        Control[] _children;
    }

    abstract
    {
    }

    override
    {
        void onUpdate()
        {
            for(size_t i = 0; i < this._children.length; i++)
            {
                auto child = this._children[i];
                if(child.isDisposed)
                {
                    this.removeChild(child);
                    i--;
                    continue;
                }

                child.onUpdate();
            }
        }

        void onDraw(AddDrawCommandsFunc addCommands)
        {
            this.dispatchEvent!((c){ c.onDraw(addCommands); return false; });
        }

        void onDispose()
        {
            foreach(child; this._children)
            {
                if(!child.isDisposed)
                    child.dispose();
            }
        }
    }

    protected final void dispatchEvent(alias Func)()
    {
        foreach(child; this._children)
        {
            if(!child.isDisposed)
            {
                const cancelEarly = Func(child);
                if(cancelEarly)
                    return;
            }
        }
    }

    final void addChild(Control control)
    {
        import std.algorithm : canFind;
        assert(!this._children.canFind(control), "Control is already a child.");

        auto oldParentAsContainer = cast(Container)control.parent;
        if(oldParentAsContainer !is null)
            oldParentAsContainer.removeChild(control);

        control._parent = this;
        this._children ~= control;
        this.onLayoutChanged();
    }

    final void removeChild(Control control)
    {
        import std.algorithm : remove, countUntil;
        this._children.remove(this._children.countUntil(control));
        this._children.length -= 1;
        this.onLayoutChanged();
    }

    @property
    final Control[] children()
    {
        return this._children;
    }
}

/// Most basic container, children are in complete control of their positioning and layout.
final class FreeFormContainer : Container {}