module game.gui.label;

import game.core, game.common, game.graphics, game.gui;

final class Label : Control
{
    private
    {
        Text _text;
    }

    alias obj this;

    this(Font font)
    {
        this._text = new Text(font);
    }

    override
    {
        void onTransformChanged()
        {
            this._text.transform = this.transform;
            this._text.transform.markDirty();
        }

        void onDraw(AddDrawCommandsFunc add)
        {
            DrawCommand[1] commands = [this._text.drawCommand];
            add(commands[]);
        }
    }

    @property
    Text obj()
    {
        return this._text;
    }
}