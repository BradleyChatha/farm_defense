module game.gui.image;

import game.core, game.common, game.graphics, game.gui;


final class Image : Control
{
    private
    {
        Texture      _texture;
        VertexBuffer _verts;
    }

    this(Texture texture, vec2f size = vec2f(float.nan), Color colour = Color.white)
    {
        this._texture = texture;
        auto sizef = (size == vec2f(float.nan)) ? vec2f(texture.size) : size;
        VertexBuffer.quad(this._verts, sizef, vec2f(texture.size), colour);
        this.size = sizef;
    }

    override
    {
        void onDispose()
        {
            this._verts.dispose();
        }

        void onDraw(AddDrawCommandsFunc add)
        {
            if(this.transform.isDirty)
            {
                this._verts.lock();
                    this._verts.transformAndUpload(0, this._verts.length, this.transform);
                this._verts.unlock();
            }

            DrawCommand[1] commands = [
                DrawCommand(
                    &this._verts,
                    0,
                    this._verts.length,
                    this._texture,
                    true
                )
            ];
            add(commands[]);
        }
    }
}