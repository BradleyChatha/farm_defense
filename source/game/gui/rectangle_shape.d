module game.gui.rectangle_shape;

import game.core, game.common, game.graphics, game.gui;

class RectangleShape : Control
{
    private
    {
        VertexBuffer _verts;
        uint         _borderSize;
        Color        _colour;
        Color        _borderColour;
    }

    this(vec2f size, Color colour = Color.white, uint borderSize = 0, Color borderColour = Color.black)
    {
        this._verts.resize(5 * 6); // 1 Quad for the inside, 4 quads for the border (if we have one).
        this._borderSize   = borderSize;
        this._colour       = colour;
        this._borderColour = borderColour;
        this.size          = size;
    }

    override
    {
        void onLayoutChanged()
        {
            this._verts.lock();
                this._verts.verts[6..$].createBorderVertsAroundBox(
                    box2f(vec2f(0), this.size - vec2f(this._borderSize)),
                    this._borderSize,
                    this._borderColour
                );
                
                TexturedVertex[4] quad = [
                    TexturedVertex(vec3f(this.position,                         0), vec2f(0), this._colour),
                    TexturedVertex(vec3f(this.position + vec2f(this.size.x, 0), 0), vec2f(0), this._colour),
                    TexturedVertex(vec3f(this.position + this.size,             0), vec2f(0), this._colour),
                    TexturedVertex(vec3f(this.position + vec2f(0, this.size.y), 0), vec2f(0), this._colour),
                ];
                this._verts.verts[0..6].setQuadVerts(quad);
            this._verts.unlock();
        }

        void onModifySize(ref vec2f size)
        {
            size += vec2f(this._borderSize * 2);
        }

        void onDispose()
        {
            this._verts.dispose();
        }

        void onDraw(AddDrawCommandsFunc add)
        {
            const vertCount = (this._borderSize > 0) ? this._verts.length : 6;

            if(this.transform.isDirty)
            {
                this._verts.lock();
                    this._verts.transformAndUpload(0, vertCount, this.transform);
                this._verts.unlock();
            }

            DrawCommand[1] commands = [
                DrawCommand(
                    &this._verts,
                    0,
                    vertCount,
                    g_blankTexture,
                    true
                )
            ];
            add(commands[]);
        }
    }
}