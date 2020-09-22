module game.data.tiled;

import std.experimental.logger;
import std.conv : to;
import asdf;
import game.common, game.core, game.graphics;

// START types for ASDF to deserialise.

struct TiledProperty
{
    string name;
    string type;
    string value;

    static TiledProperty deserialize(Asdf data)
    {
        enforce(data.kind == Asdf.Kind.null_ || data.kind == Asdf.Kind.object, "%s".format(data.kind));
        
        TiledProperty prop;
        prop.name  = data["name"].get!string(null);
        prop.type  = data["type"].get!string(null);
        prop.value = data["value"].get!string(null);

        return prop;
    }
}

struct TiledTile
{
    int id;
    string image;
    int imageheight;
    int imagewidth;
    TiledLayer objectgroup;
    double probability;
    TiledProperty[] properties;
    string type;
}

struct TiledPoint
{
    double x;
    double y;
}

struct TiledObject
{
    bool elipse;
    int gid;
    double height;
    int id;
    string name;
    bool point;
    TiledPoint[] polygon;
    TiledPoint[] polyline;
    TiledProperty[] properties;
    double rotation;
    string type;
    bool visible;
    double width;
    double x;
    double y;
}

struct TiledTileset
{
    string backgroundcolor;
    int columns;
    int firstgid;
    string image;
    int imageheight;
    int imagewidth;
    int margin;
    string name;
    string objectalignment;
    TiledProperty[] properties;
    string source;
    int spacing;
    int tilecount;
    int tiledversion;
    int tileheight;
    TiledTile[] tiles;
    int tilewidth;
    string transparentcolor;
    string type;
}

struct TiledLayer
{
    string compression;
    uint[] data;
    string draworder;
    string encoding;
    int height;
    int id;
    string image;
    TiledLayer[] layers;
    string name;
    TiledObject[] objects;
    double offsetx;
    double offsety;
    double opacity;
    TiledProperty[] properties;
    int startx;
    int starty;
    string tintcolor;
    string transparentcolor;
    string type;
    bool visible;
    int width;
}

struct TiledMap
{
    string backgroundcolor;
    int compressionlevel;
    int height;
    int hexsidelength;
    bool infinite;
    TiledLayer[] layers;
    int nextlayerid;
    int nextobjectid;
    string orientation;
    TiledProperty[] properties;
    string renderorder;
    string staggeraxis;
    string staggerindex;
    string tiledversion;
    int tileheight;
    TiledTileset[] tilesets;
    int tilewidth;
    string type;
    int width;
}

// START abstraction over the raw data types.

final class Layer
{
    enum Type
    {
        ERROR,
        tiles,
        objects
    }

    private
    {
        Type _type;

        // Type.tiles only
        uint[] _tileData;
        vec2u  _size; // in tiles.

        // Type.objects only
        TiledObject[] _objects;
    }

    private this(TiledLayer layer)
    {
        switch(layer.type)
        {
            case "tilelayer":
                this._type     = Type.tiles;
                this._tileData = layer.data;
                this._size     = vec2u(layer.width, layer.height);
                break;

            case "objectgroup": 
                this._type    = Type.objects; 
                this._objects = layer.objects;
                break;
            default: break;
        }
    }

    @property
    Type type()
    {
        return this._type;
    }

    @property
    uint[] tileData()
    {
        assert(this._type == Type.tiles);
        return this._tileData;
    }
    
    @property
    TiledObject[] objects()
    {
        assert(this._type == Type.objects);
        return this._objects;
    }

    @property
    size_t tileCount()
    {
        return this._size.x * this._size.y;
    }

    @property
    vec2u size()
    {
        return this._size;
    }
}

final class Tile
{
    enum Type
    {
        none,
        collision,
        base
    }

    private
    {
        Tileset         _tileset;
        box2f           _textureBounds;
        TiledProperty[] _properties;
        Texture         _texture;
        Type            _type;
    }

    private this(Tileset tileset, box2f textureBounds, TiledTile tileInfo, Texture texture)
    {
        import std.algorithm : filter;

        this._tileset       = tileset;
        this._textureBounds = textureBounds;
        this._properties    = tileInfo.properties;
        this._texture       = texture;

        switch(tileInfo.type)
        {
            case "COLLISION":   this._type = Type.collision; break;
            case "PLAYER_BASE": this._type = Type.base;      break;
            case null: break;
            default: throw new Exception("Unsupported tile type: " ~ tileInfo.type);
        }
    }

    @property
    box2f textureBounds()
    {
        return this._textureBounds;
    }

    @property
    Type type()
    {
        return this._type;
    }

    @property
    TiledProperty[] properties()
    {
        return this._properties;
    }

    @property
    Tileset tileset()
    {
        return this._tileset;
    }

    @property
    Texture texture()
    {
        return this._texture;
    }
}

final class Tileset
{
    private
    {
        Tile[]  _tiles;
        int     _gid;
        Texture _texture;
    }

    private this(TiledTileset tileset)
    {
        this._tiles.length = tileset.tilecount;
        this._gid          = tileset.firstgid;

        if(tileset.image !is null)
            this._texture = assetsGet!Texture(tileset.image);

        foreach(i; 0..this._tiles.length)
            this.parseTileById(cast(int)i, tileset);
    }

    private void parseTileById(int id, TiledTileset tileset)
    {
        import std.algorithm : filter;

        assert(id < tileset.tilecount);

        box2f   textureBounds;
        Texture texture;
        auto tileDefinedFilter = tileset.tiles.filter!(t => t.id == id);

        if(tileDefinedFilter.empty || tileDefinedFilter.front.image is null)
        {
            const columns = tileset.columns;
            const tileCol = id % columns;
            const tileRow = id / columns;

            textureBounds = rectanglef(
                tileCol * tileset.tilewidth,
                tileRow * tileset.tileheight,
                tileset.tilewidth,
                tileset.tileheight
            );

            texture = this._texture;
        }
        else
        {
            texture = assetsGet!Texture(tileDefinedFilter.front.image);
            textureBounds = rectanglef(
                0,
                0,
                texture.size.x,
                texture.size.y
            );
        }

        assert(texture !is null, "Texture is null. Did the compiler modify the asset list properly?");
        this._tiles[id] = new Tile(
            this,
            textureBounds,
            (tileDefinedFilter.empty) ? TiledTile.init : tileDefinedFilter.front,
            texture
        );
    }

    Tile tileByLocalId(int id)
    {
        id -= 1; // Ids are 1 based
        assert(id < this._tiles.length);

        return this._tiles[id];
    }

    Tile tileByGlobalIdOrNull(int id)
    {
        if(id < this._gid || id > this._gid + (this._tiles.length - 1)) // - 1 because 1-based madness.
            return null;
            
        return this._tiles[id - this._gid];
    }
}

struct PathNode
{
    PathNode* next;
    vec2f position;
}

struct Spawner
{
    vec2f position;
    PathNode* firstPathNode;
}
 
final class Map : IDisposable
{
    mixin IDisposableBoilerplate;

    // Amalgamation of all layers on a single cell grid.
    //
    // e.g. if layer 0 is not collidable, but layer 1 is, then that particular cell is marked as solid.
    struct TileInfo
    {
        bool isSolid;
    }

    private
    {
        VertexBuffer  _verts;
        DrawCommand[] _drawCommands;
        DrawCommand[] _debugDrawCommands;
        Tileset[]     _tilesets;
        Layer[]       _layers;
        vec2u         _gridSize;
        vec2u         _gridTileSize;
        TileInfo[]    _grid;
        Spawner[]     _spawners;
    }

    this(string file)
    {
        import std.file : fread = read;

        auto json = cast(string)fread(file);
        auto map  = json.deserialize!TiledMap();

        this._gridSize     = vec2u(map.width, map.height);
        this._gridTileSize = vec2u(map.tilewidth, map.tileheight);
        this._grid.length  = this._gridSize.x * this._gridSize.y;

        foreach(tileset; map.tilesets)
            this._tilesets ~= new Tileset(tileset);

        foreach(layer; map.layers)
            this._layers ~= new Layer(layer);

        this.readSpawnInfo();
        this.createDrawCommands();
        this.createDebugDrawCommands();
    }

    void onDispose()
    {
        this._verts.dispose();
    }

    @property
    DrawCommand[] drawCommands()
    {
        return this._drawCommands;
    }

    @property
    DrawCommand[] debugDrawCommands()
    {
        return this._debugDrawCommands;
    }

    vec2u worldToGridCoord(vec2f world)
    {
        if(world.x < 0)
            world.x = 0;
        if(world.y < 0)
            world.y = 0;
        return vec2u(cast(uint)world.x, cast(uint)world.y) / this._gridSize;
    }

    TileInfo cellAt(vec2u gridCoord)
    {
        return this._grid[gridCoord.toIndex(this._gridSize.x)];
    }

    private void readSpawnInfo()
    {
        import std.algorithm: filter;

        struct PathNodeInfo
        {
            PathNode* node;
            int nextNodeId;
        }

        PathNodeInfo[int] pathNodes;

        // Not overly great Big O wise, but it doesn't really matter for the small data size we're working with.
        void foreachObjectOfType(string type, void delegate(TiledObject object) func)
        {
            foreach(layer; this._layers.filter!(l => l.type == Layer.Type.objects))
            {
                foreach(obj; layer.objects.filter!(o => o.type == type))
                    func(obj);
            }
        }

        TiledProperty findProperty(TiledProperty[] prop, string name, string enforceType)
        {
            auto range = prop.filter!(p => p.name == name);
            if(range.empty)
                return TiledProperty.init;

            enforce(range.front.type == enforceType || enforceType is null);
            return range.front;
        }

        foreachObjectOfType("PATH_NODE", (obj)
        {
            PathNodeInfo info;
            info.node = new PathNode(null, vec2f(obj.x, obj.y));

            auto nextNodeProp = findProperty(obj.properties, "next_node", "object");
            info.nextNodeId = (nextNodeProp == TiledProperty.init) ? -1 : nextNodeProp.value.to!int;

            pathNodes[obj.id] = info;
        });

        // After the path nodes have been created, match them together.
        // NOTE: We don't do cycle checks right now cus I'm lazy.
        foreach(info; pathNodes)
        {
            if(info.nextNodeId > 0)
                info.node.next = pathNodes[info.nextNodeId].node;
        }

        foreachObjectOfType("SPAWNER", (obj)
        {
            Spawner spawner;
            spawner.position      = vec2f(obj.x, obj.y);
            spawner.firstPathNode = pathNodes[findProperty(obj.properties, "first_path_node", "object").value.to!int].node;

            this._spawners ~= spawner;
        });
    }

    private void createDrawCommands()
    {
        import std.algorithm : filter, map, uniq;
        import std.range     : walkLength;

        struct TileInstance
        {
            Tile tile;
            vec2u gridPos;
        }

        import std.stdio;

        foreach(tileLayer; this._layers.filter!(l => l.type == Layer.Type.tiles))
        {
            // Load all tiles for this layer.
            TileInstance[] tilesThisLayer;
            tilesThisLayer.reserve(tileLayer.tileCount);
            foreach(i, globalIndex; tileLayer.tileData)
            {
                if(globalIndex == 0) // 0 = No tile here.
                    continue;

                TileInstance instance;
                instance.gridPos = vec2u(cast(uint)i % tileLayer.size.x, cast(uint)i / tileLayer.size.y);

                foreach(tileset; this._tilesets)
                {
                    instance.tile = tileset.tileByGlobalIdOrNull(globalIndex);
                    if(instance.tile !is null)
                        break;
                }
                assert(instance.tile !is null, "Seems the tile resolver is broken.");

                tilesThisLayer ~= instance;

                if(instance.tile.type == Tile.Type.collision)
                    this._grid[instance.gridPos.toIndex(this._gridSize.x)].isSolid = true;
            }

            // Group tiles by texture, and create a draw command for each of them.
            foreach(uniqueTexture; tilesThisLayer.map!(t => t.tile.texture).uniq)
            {
                auto tilesForThisTexture = tilesThisLayer.filter!(t => t.tile.texture == uniqueTexture);

                size_t tileIndex = 0;
                const vertOffset = this._verts.length;
                this._verts.resize(this._verts.length + (tilesForThisTexture.walkLength * 6));
                this._verts.lock();
                foreach(tileByTexture; tilesForThisTexture)
                {
                    const vertStart     = vertOffset + (6 * tileIndex++);
                    const vertEnd       = vertStart + 6;
                    const size          = tileByTexture.tile.textureBounds.size;
                    const startOffset   = vec2u(0, this._gridTileSize.y - cast(int)size.y); // Tiles larger than the grid size need to be moved up, to match how it looks in Tiled
                    const startPos      = (tileByTexture.gridPos * this._gridTileSize) + startOffset;
                    const texBounds     = tileByTexture.tile.textureBounds;
                    this._verts.verts[vertStart..vertEnd].setQuadVerts(
                    [
                        TexturedVertex(vec3f(startPos,                    0), texBounds.min,                           Color.white),
                        TexturedVertex(vec3f(startPos + vec2f(size.x, 0), 0), vec2f(texBounds.max.x, texBounds.min.y), Color.white),
                        TexturedVertex(vec3f(startPos + size,             0), texBounds.max,                           Color.white),
                        TexturedVertex(vec3f(startPos + vec2f(0, size.y), 0), vec2f(texBounds.min.x, texBounds.max.y), Color.white),
                    ]);
                }
                this._verts.unlock();
                this._drawCommands ~= DrawCommand(
                    &this._verts,
                    vertOffset,
                    this._verts.length - vertOffset,
                    uniqueTexture,
                    true,
                    SORT_ORDER_MAP
                );
            }

            this._verts.lock();
                this._verts.vertsToUpload[0..$] = this._verts.verts[0..$];
                this._verts.upload(0, this._verts.length);
            this._verts.unlock();
        }
    }

    private void createDebugDrawCommands()
    {
        const vertStart = this._verts.length;

        void addQuad(vec2f position, Color colour)
        {
            const size = this._gridTileSize;
            this._verts.resize(this._verts.length + 6);
            this._verts.lock();
                this._verts.verts[this._verts.length-6..$].setQuadVerts(
                [
                    TexturedVertex(vec3f(position,                    0), vec2f(0), colour),
                    TexturedVertex(vec3f(position + vec2f(size.x, 0), 0), vec2f(0), colour),
                    TexturedVertex(vec3f(position + size,             0), vec2f(0), colour),
                    TexturedVertex(vec3f(position + vec2f(0, size.y), 0), vec2f(0), colour),
                ]);
            this._verts.unlock();
        }

        void addPathNode(PathNode* pathNode)
        {
            addQuad(pathNode.position, Color(255, 255, 0, 64));
            if(pathNode.next !is null)
                addPathNode(pathNode.next);
        }

        void addSpawner(Spawner spawner)
        {
            addQuad(spawner.position, Color(0, 255, 0, 64));
            if(spawner.firstPathNode !is null)
                addPathNode(spawner.firstPathNode);
        }

        foreach(spawner; this._spawners)
            addSpawner(spawner);

        this._verts.lock();
            this._verts.vertsToUpload[vertStart..$] = this._verts.verts[vertStart..$];
            this._verts.upload(vertStart, this._verts.length - vertStart);
        this._verts.unlock();
        this._debugDrawCommands ~= DrawCommand(
            &this._verts,
            vertStart,
            this._verts.length - vertStart,
            g_blankTexture,
            true,
            SORT_ORDER_MAP
        );
    }
}