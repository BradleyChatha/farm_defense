module game.gameplay.player;

import game.common, game.core, game.graphics, game.gameplay, game.debug_;

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
        PlayerInput    _input;
        PlayerMovement _movement;
        PlayerGraphics _graphics;
        MapInstance    _map;

        PlayerComponent[] _components;
    }
    
    this(MapInstance map, ref InputHandler input, Camera camera)
    {
        this._map      = map;
        this._movement = new PlayerMovement(this, camera);
        this._input    = new PlayerInput(this, input);
        this._graphics = new PlayerGraphics(this);

        // Order is important.
        this._components = 
        [
            this._input,
            this._movement,
            this._graphics
        ];
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