module game.gui.alignment_container;

import game.core, game.common, game.gui;

final class AlignmentContainer : Container
{
    this(vec2f size)
    {
        this.size = size;
    }

    override
    {
        void onTransformChanged()
        {
            this.onLayoutChanged();
        }

        void onLayoutChanged()
        {
            auto box = box2f(
                this.position,
                this.position + this.size
            );

            foreach(child; this.children)
                child.alignWithinBox(box);
        }
    }
}