module game.scenes.defense_scene;

import std;
import game, gfm.math;

struct PathNode
{
    vec2f position;
    PathNode* next;
}

struct Andy
{
    Sprite   sprite;
    short    hp;
    PathNode pathNode;

    this(Sprite sprite, short hp, PathNode pathNode)
    {
        this.sprite   = sprite;
        this.hp       = hp;
        this.pathNode = pathNode;

        this.sprite.position = pathNode.position - (this.sprite.size / vec2f(2));
    }
}

final class DefenseScene : Scene
{
    private
    {
        Level  _level;
        Sprite _nodeSprite;
        Andy[] _andies;
        StitchedTexture[] _andyTextures;
    }

    public override
    {
        void onInit()
        {
            this._level = Resources.loadLevel("./resources/levels/first.sdl");
            this._nodeSprite = Sprite(Resources.loadAndStitchTexture("", 0));
            this._andyTextures ~= cast()Resources.loadAndStitchTexture("", 1);
        }

        void onReset()
        {
            this._andies.length = 0;
            this.spawnWave(0);
        }

        void onUpdate(uint gameTime)
        {
            const ANDY_LEVEL_1_SPEED = 20.0f; // pixels/s
            const DELTA_FLOAT        = (cast(float)gameTime / 1000.0f);
            const SPEED_THIS_FRAME   = ANDY_LEVEL_1_SPEED * DELTA_FLOAT;

            writeln(gameTime, " ", DELTA_FLOAT, " ", SPEED_THIS_FRAME);

            foreach(ref andy; this._andies)
            {
                const andyCenter = andy.sprite.position + (andy.sprite.size / 2);
                const remainingDistance = (andyCenter - andy.pathNode.position).absByElem;

                writeln("START: ", andy.sprite.position, " ", andy.pathNode, " ", remainingDistance, " ", andyCenter);

                // I'm aware of this being an issue with diagonal nodes, but we'll just avoid that for now.
                // Also duplication
                // Also its just ugly.
                if(andyCenter.x < andy.pathNode.position.x)
                    andy.sprite.position = andy.sprite.position + vec2f(min(SPEED_THIS_FRAME, remainingDistance.x), 0);
                if(andyCenter.y < andy.pathNode.position.y)
                    andy.sprite.position = andy.sprite.position + vec2f(0, min(SPEED_THIS_FRAME, remainingDistance.y));
                if(andyCenter.x > andy.pathNode.position.x)
                    andy.sprite.position = andy.sprite.position - vec2f(min(SPEED_THIS_FRAME, remainingDistance.x), 0);
                if(andyCenter.y > andy.pathNode.position.y)
                    andy.sprite.position = andy.sprite.position - vec2f(0, min(SPEED_THIS_FRAME, remainingDistance.y));

                if(remainingDistance == vec2f(0))
                {
                    if(andy.pathNode.next !is null)
                        andy.pathNode = *andy.pathNode.next;
                }

                writeln("END: ", andy.sprite.position, " ", andy.pathNode);
            }
        }

        void onDraw(Renderer renderer)
        {
            // NOTE: For.. some reason, things need to be drawn in reverse order.
            foreach(ref andy; this._andies)
                renderer.draw(andy.sprite);
            this.drawPathNodes(renderer);
            this._level.onDraw(renderer);
        }
    }

    void drawPathNodes(Renderer renderer)
    {
        foreach(node; this._level.pathNodes)
        {
            this._nodeSprite.position = node.position - (this._nodeSprite.size / vec2f(2, 2));
            renderer.draw(this._nodeSprite);
        }
    }

    void spawnWave(size_t waveIndex)
    {
        const node = this._level.pathNodes[0];
        this._andies ~= Andy(Sprite(this._andyTextures[0]), 1, cast()node);
    }
}

final class Level
{
    const TILE_SIZE   = 64;
    const GRID_WIDTH  = Window.WIDTH / TILE_SIZE;
    const GRID_HEIGHT = Window.HEIGHT / TILE_SIZE;

    private
    {
        string _name;
        Sprite _background;
        PathNode[] _pathNodes;
    }

    public
    {
        this(string name, Sprite background, PathNode[] pathing)
        {
            this._name       = name;
            this._background = background;
            this._pathNodes  = pathing;
        }

        void onDraw(Renderer renderer)
        {
            renderer.draw(this._background);
        }

        @property
        const(PathNode[]) pathNodes()
        {
            return this._pathNodes;
        }
    }
}