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
        this.changeTexture(texture, size, colour);
    }

    void changeTexture(Texture texture, vec2f size = vec2f(float.nan), Color colour = Color.white)
    {
        if(texture is null)
        {
            if(this._verts.length == 0)
                this._verts.resize(6);

            this.size = vec2f(0);
            return;
        }

        this._texture = texture;
        auto sizef = (size.isNaN) ? vec2f(texture.size) : size;
        VertexBuffer.quad(this._verts, sizef, vec2f(texture.size), colour);
        this.size = sizef;
    }

    override
    {
        void onLayoutChanged()
        {
            this._verts.lock();
                auto quadVerts = this._verts.verts[0..6].getQuadVerts();
                quadVerts[1].position.x = this.size.x;
                quadVerts[2].position   = vec3f(this.size, 0);
                quadVerts[3].position.y = this.size.y;
                this._verts.verts[0..6].setQuadVerts(quadVerts);
            this._verts.unlock();
            this.transform.markDirty();
        }

        void onDispose()
        {
            this._verts.dispose();
        }

        void onDraw(AddDrawCommandsFunc add)
        {
            if(this._texture is null)
                return;

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
                    true,
                    SORT_ORDER_UI
                )
            ];
            add(commands[]);
        }
    }
}