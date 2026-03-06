local gfx <const> = playdate.graphics

local tileImages = nil
local tilemap = nil
local tilemapSprite = nil

local function loadAndScale(path)
    local img = gfx.image.new(path)
    return img:scaledImage(2)
end

function generateTileImages()
    tileImages = gfx.imagetable.new(7)

    -- Load tile images from files, scaled 2x for native feel
    -- 1=Grass, 2=Path, 3=Wall, 4=Water, 5=Tree, 6=Door, 7=Fence
    tileImages:setImage(1, loadAndScale("images/tiles/grass"))
    tileImages:setImage(2, loadAndScale("images/tiles/path"))
    tileImages:setImage(3, loadAndScale("images/tiles/wall"))
    tileImages:setImage(4, loadAndScale("images/tiles/water"))
    tileImages:setImage(5, loadAndScale("images/tiles/tree"))
    tileImages:setImage(6, loadAndScale("images/tiles/door"))
    tileImages:setImage(7, loadAndScale("images/tiles/fence"))
end

function setupOverworld()
    generateTileImages()

    tilemap = gfx.tilemap.new()
    tilemap:setImageTable(tileImages)
    tilemap:setSize(MAP_WIDTH, MAP_HEIGHT)

    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            tilemap:setTileAtPosition(x, y, palletTownTiles[y][x])
        end
    end

    tilemapSprite = gfx.sprite.new()
    tilemapSprite:setTilemap(tilemap)
    tilemapSprite:setCenter(0, 0)
    tilemapSprite:moveTo(0, 0)
    tilemapSprite:setZIndex(-1)
    tilemapSprite:add()

    -- Add wall sprites from collision layer
    local ts = TILE_SIZE
    local emptyImage = gfx.image.new(ts, ts)
    for y = 1, MAP_HEIGHT do
        for x = 1, MAP_WIDTH do
            if palletTownCollision[y][x] == 1 then
                local wallSprite = gfx.sprite.new(emptyImage)
                wallSprite:setCenter(0, 0)
                wallSprite:moveTo((x - 1) * ts, (y - 1) * ts)
                wallSprite:setCollideRect(0, 0, ts, ts)
                wallSprite:add()
            end
        end
    end
end

function getMapPixelSize()
    return MAP_WIDTH * TILE_SIZE, MAP_HEIGHT * TILE_SIZE
end

function getOverworldTileSize()
    return TILE_SIZE
end

function cleanupOverworld()
    if tilemapSprite then
        tilemapSprite:remove()
    end
    gfx.sprite.removeAll()
end
