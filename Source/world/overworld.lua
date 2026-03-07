local gfx <const> = playdate.graphics

local tileImages = nil
local tilemap = nil
local tilemapSprite = nil

function generateTileImages()
    tileImages = TileFactory.generateAll()
end

function setupOverworld()
    generateTileImages()

    local zone = currentZone
    local mapW, mapH = zone.width, zone.height
    local tiles = zone.tiles

    tilemap = gfx.tilemap.new()
    tilemap:setImageTable(tileImages)
    tilemap:setSize(mapW, mapH)

    for y = 1, mapH do
        for x = 1, mapW do
            tilemap:setTileAtPosition(x, y, tiles[y][x])
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
    local collision = zone.collision
    local emptyImage = gfx.image.new(ts, ts)
    for y = 1, mapH do
        for x = 1, mapW do
            if collision[y][x] == 1 then
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
    return currentZone.width * TILE_SIZE, currentZone.height * TILE_SIZE
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
