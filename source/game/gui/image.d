module game.gui.image;

import game.core, game.common, game.graphics, game.gui;


final class Image : Control
{
    private
    {
        Texture      _texture;
        VertexBuffer _verts;
    }

    this(Texture texture)
    {
        this._texture = texture;
        VertexBuffer.quad(this._verts, vec2f(texture.size));
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
                    auto matrix = this.transform.matrix;
                    foreach(i, vert; this._verts.verts)
                    {
                        vert.position                = (matrix * vec4f(vert.position, 1)).xyz;
                        this._verts.vertsToUpload[i] = vert;
                    }
                    this._verts.upload(0, this._verts.length);
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