module game.scenes.defense_scene;

import std;
import game, gfm.math, arsd.color;

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

    @property
    uint level()
    {
        switch(this.hp)
        {
            case 1:
            default: return 0;
        }
    }
}

final class DefenseScene : Scene
{
    const ANDY_LEVELS = 1;

    private
    {
        Level  _level;
        Sprite _nodeSprite;
        Andy[] _andies;
        size_t _hp;
        size_t _waveCount;
        size_t _deadCount;

        StitchedTexture[ANDY_LEVELS] _andyTextures;
        float[ANDY_LEVELS] _andySpeeds = 
        [
            // pixels/s
            128.0f
        ];
    }

    public override
    {
        void onInit()
        {
            this._level           = Resources.loadLevel("./resources/levels/first.sdl");
            this._nodeSprite      = Sprite(Resources.loadAndStitchTexture("", 0));
            this._andyTextures[0] = cast()Resources.loadAndStitchTexture("./resources/images/dynamic/andies/level_0.png", 1);
        }

        void onReset()
        {
            this._hp = 100;
            this._andies.length = 0;
            this._waveCount = 0;
            this.spawnWave(1);
        }

        void onUpdate(uint gameTime)
        {
            this.doUserInput();
            this.doPathFinding(gameTime);
            this.doChecks();
        }

        void onDraw(Renderer renderer)
        {
            // NOTE: BGFX automatically sorts draws by depth (z axis), so order or render
            //       doesn't matter, only the zIndex of each sprite.
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
        this._andies.length = waveIndex;

        foreach(i; 0..waveIndex)
        {
            auto andy = &this._andies[i];
            *andy     = Andy(Sprite(this._andyTextures[0]), 1, cast()node);

            auto texture    = this._andyTextures[andy.level];
            auto sprite     = &andy.sprite;
            sprite.color    = Color.red;
            sprite.position = sprite.position - (sprite.size * vec2f(i));
            sprite.texture  = texture.atlas;
            sprite.size     = texture.area.zw;
            sprite.zIndex   = 0.00001; // Sprites default to 0, so this will render over every sprite that doesn't have a specific z-index.
        }

        this._waveCount = waveIndex + 1;
        this._deadCount = 0;
    }

    void doPathFinding(uint gameTime)
    {
        const DELTA_FLOAT = (cast(float)gameTime / 1000.0f);

        foreach(ref andy; this._andies)
        {
            const SPEED_THIS_FRAME  = this._andySpeeds[andy.level] * DELTA_FLOAT;
            const andyCenter        = andy.sprite.position + (andy.sprite.size / 2);
            const remainingDistance = (andyCenter - andy.pathNode.position).absByElem;

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
                {
                    andy.pathNode = *andy.pathNode.next;
                    continue;
                }

                // Andy has reached end alive
                this._hp -= 1;
                andy.sprite.position = vec2f(float.nan);
                andy.pathNode.position = vec2f(float.nan);
                this._deadCount++;
            }
        }
    }

    void doChecks()
    {
        if(this._hp == 0)
        {
            this.onReset();
            return;
        }

        if(this._deadCount == this._andies.length)
            this.spawnWave(this._waveCount);
    }

    void doUserInput()
    {
        // Normally I'd setup a proper input manager thing, but honestly that's just a waste of time atm for this project.
        // Again, maybe if someone's interested in me developing this past a fun little prototype, then I'm probably going
        // to rewrite it all anyway, so I'll do things properly then.
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