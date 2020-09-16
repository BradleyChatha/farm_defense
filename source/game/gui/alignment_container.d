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
        void onLayoutChanged()
        {
            foreach(child; this.children)
            {
                const csize = child.size;
                const horiz = child.horizAlignment;
                const vert  = child.vertAlignment;

                vec2f position = vec2f(0);

                final switch(horiz) with(HorizAlignment)
                {
                    case left:   position.x = this.position.x;                                 break;
                    case center: position.x = this.position.x + ((this.size.x - csize.x) / 2); break;
                    case right:  position.x = (this.position.x + this.size.x) - csize.x;       break;
                }

                final switch(vert) with(VertAlignment)
                {
                    case top:    position.y = this.position.y;                                 break;
                    case center: position.y = this.position.y + ((this.size.y - csize.y) / 2); break;
                    case bottom: position.y = (this.position.y + this.size.y) - csize.y;       break;
                }

                child.position = position;
            }
        }
    }
}