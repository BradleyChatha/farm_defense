module game.scenes.defense_scene;

import std;
import game, gfm.math, arsd.color;

struct PathNode
{
    vec2f position;
    PathNode* next;
}

// I'm sure Andy doesn't mind being the villain >:)
struct Andy
{
    Sprite   sprite;
    short    hp;
    PathNode pathNode;
    bool     dead;

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

// It was a hard choice between Laura and Debbie, but Laura won due to the potential of chicken projectiles.
struct Laura
{
    enum RANGE    = 64 * 4;
    enum DAMAGE   = 1;
    enum COOLDOWN = 1500;
    Sprite sprite;
    uint cooldown;

    bool isInRange(vec2f point)
    {
        const centerPoint = this.sprite.position + (this.sprite.size / vec2f(2));
        const difference  = sqrt(pow(centerPoint.x - point.x, 2) + pow(centerPoint.y - point.y, 2));

        return difference <= this.RANGE;
    }
}

struct Chicken
{
    Sprite sprite;
    vec2f  targetPosition;
}

final class DefenseScene : Scene
{
    const ANDY_LEVELS = 1;

    private
    {
        Level     _level;
        Sprite    _nodeSprite;
        Andy[]    _andies;
        Laura[]   _lauras;
        Chicken[] _chickens;
        size_t    _hp;
        size_t    _waveCount;
        size_t    _deadCount;
        size_t    _activeChickens;

        StitchedTexture[ANDY_LEVELS] _andyTextures;
        float[ANDY_LEVELS] _andySpeeds = 
        [
            // pixels/s
            128.0f
        ];

        Sprite _selectedCellSprite;
        StitchedTexture _lauraTexture;
        StitchedTexture _chickenTexture;
    }

    public override
    {
        void onInit()
        {
            this._level                 = Resources.loadLevel("./resources/levels/first.sdl");
            this._nodeSprite            = Sprite(Resources.loadAndStitchTexture("", 0));
            this._selectedCellSprite    = Sprite(Resources.loadAndStitchTexture("./resources/images/dynamic/ui/selected_cell.png", 1));
            this._lauraTexture          = cast()Resources.loadAndStitchTexture("./resources/images/dynamic/staff/laura.png", 1);
            this._chickenTexture        = cast()Resources.loadAndStitchTexture("./resources/images/dynamic/staff/chicken.png", 1);
            this._andyTextures[0]       = cast()Resources.loadAndStitchTexture("./resources/images/dynamic/andies/level_0.png", 1);

            this._selectedCellSprite.zIndex = 0.00001; // Render above level
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
            this.doShooting(gameTime);
            this.doChickens(gameTime);
            this.doPathFinding(gameTime);
            this.doChecks();
        }

        void onDraw(Renderer renderer)
        {
            // NOTE: BGFX automatically sorts draws by depth (z axis), so order of render
            //       doesn't matter, only the zIndex of each sprite.
            foreach(ref andy; this._andies)
                renderer.draw(andy.sprite);
            
            foreach(ref laura; this._lauras)
                renderer.draw(laura.sprite);

            foreach(ref chicken; this._chickens)
                renderer.draw(chicken.sprite);

            this.drawPathNodes(renderer);
            this._level.onDraw(renderer);
            renderer.draw(this._selectedCellSprite);
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

                // Andy has reached the end alive
                this._hp -= 1;
                andy.sprite.position = vec2f(float.nan);
                andy.pathNode.position = vec2f(float.nan);
                andy.dead = true;
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

        if(this._activeChickens == 0 && this._chickens.length > 0)
            this._chickens.length = 0;
    }

    void doShooting(uint gameTime)
    {
        foreach(ref laura; this._lauras)
        {
            if(laura.cooldown > 0)
            {
                if(laura.cooldown >= gameTime)
                    laura.cooldown -= gameTime;
                else
                    laura.cooldown = 0;

                continue;
            }

            foreach(ref andy; this._andies)
            {
                const lauraCenter = laura.sprite.position + (laura.sprite.size / vec2f(2));
                const andyCenter  = andy.sprite.position + (andy.sprite.size / vec2f(2));
                if(!laura.isInRange(andyCenter))
                    continue;

                auto chicken            = Chicken(Sprite(this._chickenTexture), andyCenter);
                chicken.sprite.zIndex   = 0.00003;
                chicken.sprite.position = lauraCenter - (chicken.sprite.size / vec2f(2));
                this._chickens ~= chicken;
                this._activeChickens++;

                laura.cooldown = Laura.COOLDOWN;
                break;
            }
        }        
    }

    void doChickens(uint gameTime)
    {
        const DELTA_FLOAT   = (cast(float)gameTime / 1000.0f);
        const CHICKEN_SPEED = 180.0f;
        foreach(ref chicken; this._chickens)
        {
            // Yea, this is just the Andy code copy pasted ;(
            const SPEED_THIS_FRAME  = CHICKEN_SPEED * DELTA_FLOAT;
            const chickenCenter     = chicken.sprite.position + (chicken.sprite.size / 2);
            const remainingDistance = (chickenCenter - chicken.targetPosition).absByElem;

            // I'm aware of this being an issue with diagonal nodes, but we'll just avoid that for now.
            // Also duplication
            // Also its just ugly.
            if(chickenCenter.x < chicken.targetPosition.x)
                chicken.sprite.position = chicken.sprite.position + vec2f(min(SPEED_THIS_FRAME, remainingDistance.x), 0);
            if(chickenCenter.y < chicken.targetPosition.y)
                chicken.sprite.position = chicken.sprite.position + vec2f(0, min(SPEED_THIS_FRAME, remainingDistance.y));
            if(chickenCenter.x > chicken.targetPosition.x)
                chicken.sprite.position = chicken.sprite.position - vec2f(min(SPEED_THIS_FRAME, remainingDistance.x), 0);
            if(chickenCenter.y > chicken.targetPosition.y)
                chicken.sprite.position = chicken.sprite.position - vec2f(0, min(SPEED_THIS_FRAME, remainingDistance.y));

            if(remainingDistance == vec2f(0) && chicken.targetPosition != vec2f(-2000))
            {
                chicken.sprite.position = vec2f(-2000);
                chicken.targetPosition = vec2f(-2000);
                this._activeChickens--;
                continue;
            }

            const chickenBox = box2f(chicken.sprite.position, vec2f(chicken.sprite.size + chicken.sprite.position));
            foreach(ref andy; this._andies)
            {
                const andyBox = box2f(andy.sprite.position, vec2f(andy.sprite.size + andy.sprite.position));
                if(andyBox.intersects(chickenBox) && !andy.dead)
                {
                    andy.sprite.position = vec2f(float.nan);
                    andy.pathNode.position = vec2f(float.nan);
                    andy.dead = true;
                    this._deadCount++;

                    chicken.sprite.position = vec2f(-2000);
                    chicken.targetPosition = vec2f(-2000);
                    this._activeChickens--;
                    break;
                }
            }
        }
    }

    void doUserInput()
    {
        // Normally I'd setup a proper input manager thing, but honestly that's just a waste of time atm for this project.
        // Again, maybe if someone's interested in me developing this past a fun little prototype, then I'm probably going
        // to rewrite it all anyway, so I'll do things properly then.
        vec2i mousePos;
        const mouseButtons  = SDL_GetMouseState(&mousePos.x, &mousePos.y);
        const mouseLeftDown = mouseButtons & SDL_BUTTON!SDL_BUTTON_LEFT;
        const mouseCellPos  = mousePos / vec2i(Level.TILE_SIZE);
        const cellWorldPos  = vec2f(mouseCellPos * vec2i(Level.TILE_SIZE));

        this._selectedCellSprite.position = cellWorldPos;

        if(mouseLeftDown)
        {
            auto laura            = Laura(Sprite(this._lauraTexture));
            laura.sprite.position = cellWorldPos;
            laura.sprite.zIndex   = 0.00002;

            // I could do this a *lot* better, but meh
            bool addToList = true;
            foreach(ref existingLaura; this._lauras)
            {
                if(existingLaura.sprite.position == laura.sprite.position)
                {
                    addToList = false;
                    break;
                }
            }

            if(addToList)
                this._lauras ~= laura;
        }
    }
}

final class Level
{
    static const TILE_SIZE   = 64;
    static const GRID_WIDTH  = Window.WIDTH / TILE_SIZE;
    static const GRID_HEIGHT = Window.HEIGHT / TILE_SIZE;

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