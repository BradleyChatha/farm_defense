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
            commands[0].sortOrder = SORT_ORDER_UI;
            add(commands[]);
        }
    }

    @property
    void text(const char[] newText)
    {
        this._text.text = newText;
        this.size = this._text.size;
    }

    @property
    Text obj()
    {
        return this._text;
    }
}