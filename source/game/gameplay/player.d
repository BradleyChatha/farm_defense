module game.gameplay.player;

import game.common, game.core, game.graphics, game.gameplay, game.debug_, game.data;

/++
 + Components can have hard requirements on eachother, but meh.
 +
 + Not using the message bus for cross-component communication, since this is a very closed off system.
 +
 + Only the player will be talking to itself for the most part.
 +
 + Player needs the MapInstance so it can perform collision checks sanely, without having to hack the message bus system just for this specific case.
 +
 + Therefore we'll also just talk directly to a MapInstance instead of going through the message bus, since at this point we've lost the value of the abstraction.
 +
 + Certain actions *might* be put onto the message bus though, just in case I want to use it via console commands.
 + ++/

immutable PLAYER_TEXTURE_NAME = "t_player";
enum      PLAYER_SPEED        = 200; // Pixels per second

enum PlayerDirection
{
    none    = 0,
    up      = 1 << 0,
    down    = 1 << 1,
    left    = 1 << 2,
    right   = 1 << 3
}

abstract class PlayerComponent : IMessageHandler
{
    protected Player player;

    this(Player player)
    {
        this.player = player;
    }

    abstract void onUpdate();
}

final class Player : IMessageHandler, IDisposable
{
    mixin IDisposableBoilerplate;

    private
    {
        PlayerInput     _input;
        PlayerMovement  _movement;
        PlayerGraphics  _graphics;
        PlayerCollision _collision;

        PlayerComponent[] _components;
    }
    
    this(MapInstance map, ref InputHandler input, Camera camera, vec2f spawnPoint)
    {
        this._movement  = new PlayerMovement(this, camera);
        this._input     = new PlayerInput(this, input);
        this._collision = new PlayerCollision(this, map);
        this._graphics  = new PlayerGraphics(this);

        // Order is important.
        this._components = 
        [
            this._input,
            this._movement,
            this._collision,
            this._graphics
        ];

        this._movement.position = spawnPoint;
    }

    void onUpdate()
    {
        foreach(comp; this._components)
            comp.onUpdate();
    }

    void onDispose()
    {
        foreach(comp; this._components)
        {
            auto asDisposable = cast(IDisposable)comp;
            if(asDisposable !is null)
                asDisposable.dispose();
        }
    }

    void handleMessage(scope MessageBase message)
    {
        foreach(comp; this._components)
            comp.handleMessage(message);
    }

    @property
    DrawCommand drawCommand()
    {
        return this._graphics.drawCommand;
    }

    @property
    vec2f position()
    {
        return this._movement.transform.translation;
    }

    @property
    vec2f size()
    {
        return vec2f(this._graphics.texture.size);
    }
}

final class PlayerInput : PlayerComponent
{
    mixin IMessageHandlerBoilerplate;

    this(Player player, ref InputHandler input)
    {
        super(player);
        input.onDown(SDL_SCANCODE_W, () => player._movement.move(vec2f(0, -(PLAYER_SPEED * gametimeSecs()))));
        input.onDown(SDL_SCANCODE_A, () => player._movement.move(vec2f(-(PLAYER_SPEED * gametimeSecs()), 0)));
        input.onDown(SDL_SCANCODE_S, () => player._movement.move(vec2f(0, PLAYER_SPEED * gametimeSecs())));
        input.onDown(SDL_SCANCODE_D, () => player._movement.move(vec2f(PLAYER_SPEED * gametimeSecs(), 0)));
    }

    override void onUpdate()
    {
    }
}

final class PlayerMovement : PlayerComponent, ITransformable!(AddHooks.yes)
{
    mixin IMessageHandlerBoilerplate;
    mixin ITransformableBoilerplate;

    alias OnPlayerMove = void delegate(vec2f newPos, PlayerDirection moveDirection, Transform transform);

    OnPlayerMove[] onPlayerMove;
    Camera         camera;
    vec2f          oldPos;

    this(Player player, Camera camera)
    {
        super(player);
        this.camera = camera;
        this.oldPos = vec2f(0, 0);
    }

    void onTransformChanged()
    {
        PlayerDirection direction;
        auto            newPos = this.transform.translation;

        // Keep in mind you can stand still in one axis, hence "else if" instead of just "else".
        if(newPos.x < this.oldPos.x)
            direction |= PlayerDirection.left;
        else if(newPos.x > this.oldPos.x)
            direction |= PlayerDirection.right;

        if(newPos.y < this.oldPos.y)
            direction |= PlayerDirection.up;
        else if(newPos.y > this.oldPos.y)
            direction |= PlayerDirection.down;

        this.camera.lookAt(super.player.position + (super.player.size / 2));

        foreach(event; this.onPlayerMove)
            event(newPos, direction, this.transform);

        this.oldPos = this.transform.translation;
    }

    override void onUpdate()
    {
    }
}

final class PlayerGraphics : PlayerComponent, IDisposable
{
    mixin IMessageHandlerBoilerplate;
    mixin IDisposableBoilerplate;

    VertexBuffer verts;
    Texture      texture;
    DrawCommand  drawCommand;
    
    this(Player player)
    {
        super(player);

        this.texture = assetsGet!Texture(PLAYER_TEXTURE_NAME);
        VertexBuffer.quad(verts, vec2f(this.texture.size), vec2f(this.texture.size), Color.white);
        this.drawCommand = DrawCommand(
            &this.verts,
            0,
            this.verts.length,
            this.texture,
            true,
            SORT_ORDER_PLAYER
        );

        player._movement.onPlayerMove ~= (_, __, transform)
        { 
            this.verts.lock();
                this.verts.transformAndUpload(0, this.verts.length, transform);
            this.verts.unlock();
        };
    }

    void onDispose()
    {
        this.verts.dispose();
    }

    override void onUpdate(){}
}

final class PlayerCollision : PlayerComponent
{
    mixin IMessageHandlerBoilerplate;

    MapInstance map;

    this(Player player, MapInstance map)
    {
        super(player);
        this.map = map;
        player._movement.onPlayerMove ~= &this.noWalkIntoWalls;
    }

    override void onUpdate(){}

    void noWalkIntoWalls(vec2f currPos, PlayerDirection direction, Transform _)
    {
        import std;

        static bool inCollisionCode = false;
        if(inCollisionCode)
            return;

        inCollisionCode = true;
        scope(exit) inCollisionCode = false;

        if(direction == PlayerDirection.none)
            return;

        auto info = this.map.mapInfo;

        vec2f[4] cornerPositions = 
        [
            currPos,
            currPos + vec2f(super.player.size.x, 0),
            currPos + super.player.size,
            currPos + vec2f(0, super.player.size.y)
        ];

        vec2i[4] cornerCellPositions = 
        [
            info.worldToGridCoord(cornerPositions[0]),
            info.worldToGridCoord(cornerPositions[1]),
            info.worldToGridCoord(cornerPositions[2]),
            info.worldToGridCoord(cornerPositions[3])
        ];

        Map.TileInfo[4] cells = 
        [
            info.cellAt(cornerCellPositions[0]),
            info.cellAt(cornerCellPositions[1]),
            info.cellAt(cornerCellPositions[2]),
            info.cellAt(cornerCellPositions[3]),
        ];

        ref float getAxisRef(ref vec2f vect, bool xFalseYTrue)
        {
            return (xFalseYTrue) ? vect.y : vect.x;
        }

        float getAxis(vec2f vect, bool xFalseYTrue)
        {
            return (xFalseYTrue) ? vect.y : vect.x;
        }

        bool wasCollision = false;
        void collide(PlayerDirection ifDirection, size_t corner1, size_t corner2, vec2u cellOffset, bool xFalseYTrue)
        {
            if(!(direction & ifDirection))
                return;

            if(cells[corner1].isSolid)
            {
                getAxisRef(currPos, xFalseYTrue) = getAxis(info.gridToWorldCoord(cornerCellPositions[corner1] + cellOffset), xFalseYTrue);
                wasCollision = true;
            }
            else if(cells[corner2].isSolid)
            {
                getAxisRef(currPos, xFalseYTrue) = getAxis(info.gridToWorldCoord(cornerCellPositions[corner2] + cellOffset), xFalseYTrue);
                wasCollision = true;
            }

            if(wasCollision && ((direction & PlayerDirection.right) || (direction & PlayerDirection.down)))
                getAxisRef(currPos, xFalseYTrue) -= getAxis(vec2f(1, 1), xFalseYTrue);
        }

        collide(PlayerDirection.left, 0, 3, vec2u(1, 0), false);
        collide(PlayerDirection.right, 1, 2, vec2u(-1, 0), false);
        collide(PlayerDirection.down, 2, 3, vec2u(0, -1), true);
        collide(PlayerDirection.up, 0, 1, vec2u(0, 1), true);

        if(currPos.x < 0)
            currPos.x = 0;
        if(currPos.y < 0)
            currPos.y = 0;
        if(currPos.x + super.player.size.x > info.sizeInPixels.x)
            currPos.x = info.sizeInPixels.x - super.player.size.x;
        if(currPos.y + super.player.size.y > info.sizeInPixels.y)
            currPos.y = info.sizeInPixels.y - super.player.size.y;

        if(wasCollision)
            super.player._movement.position = currPos;
    }
}