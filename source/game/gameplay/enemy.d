module game.gameplay.enemy;

import game.common, game.core, game.graphics, game.data;

// Since I have 0 clue how I want things laid out, I also don't know how much in common the Player/enemy/whatever else entities will be sharing.
//
// Hence there's a bit of code reusage, but at the benefit of I can change the "subsystem" of one entity type without it affecting the others.
// 'Tis a learning project after all <3.

private PoolAllocator g_enemyComponentAllocator;

abstract class EnemyAI
{
    protected
    {
        Enemy enemy;
    }

    public
    {
        void onInit(Spawner spawner) {}
    }
}

final class Enemy : IDisposable, ITransformable!(AddHooks.no)
{
    mixin IDisposableBoilerplate;
    mixin ITransformableBoilerplate;

    private
    {
        EnemyAI       _ai;
        EnemyMovement _movement;
        EnemyGraphics _graphics;
    }

    this(EnemyAI ai, Spawner spawner, SpriteBatch spriteBatch, string spriteName)
    {
        this._ai       = ai;
        this._movement = g_enemyComponentAllocator.make!EnemyMovement();
        this._graphics = g_enemyComponentAllocator.make!EnemyGraphics(this, spriteBatch, spriteName);
        
        this._ai.enemy = this;
        this._ai.onInit(spawner);
    }

    void onUpdate()
    {
    }

    void onDispose()
    {
        g_enemyComponentAllocator.dispose(this._movement);
        g_enemyComponentAllocator.dispose(this._graphics);
    }
}

final class EnemyMovement : ITransformable!(AddHooks.yes)
{
    mixin ITransformableBoilerplate;

    alias OnEnemyMove = void delegate(vec2f newPos, Transform transform);

    OnEnemyMove[] onMove;

    void onTransformChanged()
    {
        foreach(event; this.onMove)
            event(this.position, this.transform);
    }
}

final class EnemyGraphics : IDisposable
{
    mixin IDisposableBoilerplate;

    SpriteBatchMemory sprite;
    
    this(Enemy enemy, SpriteBatch spriteBatch, string spriteName)
    {
        spriteBatch.allocate(/*ref*/this.sprite, 1);

        // TODO: Sprite atlas -> Sprite atlas support in SpriteBatch -> Resolve sprite stuff here.
        auto transformInit = Transform.init; // Need an lvalue.
        this.sprite.updateVerts(
            0,
            transformInit,
            vec2f(spriteBatch.drawCommand.texture.size),
            rectanglef(0, 0, spriteBatch.drawCommand.texture.size.x, spriteBatch.drawCommand.texture.size.y),
        );

        enemy._movement.onMove ~= (_, transform)
        {
            this.sprite.updateVerts(0, transform);
        };
    }

    void onDispose()
    {
        this.sprite.free();
    }
}