module game.gameplay.enemymanager;

import game.core, game.common, game.data, game.graphics, game.gameplay;

final class EnemyManager
{
    private
    {
        Map         _map;
        SpriteBatch _sprites;
    }

    this(Map map)
    {
        // TODO: Get sprite atlas stuff up and running, and modify SpriteBatch to directly support SpriteAtlas instead of just a Texture.
        //       Want to get gameplay going though before graphics, so it can wait.
        this._map     = map;
        this._sprites = new SpriteBatch(assetsGet!Texture("t_enemies"), AllowTransparency.yes);
    }
}