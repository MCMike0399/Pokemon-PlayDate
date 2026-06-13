local gfx <const> = playdate.graphics

---@type _ImageTable
local tileImages
local tilemap = nil
local tilemapSprite = nil

-- Animated tiles: pre-rendered frames swapped into the imagetable in
-- place, so every cell of that tile type animates at once and the
-- tilemap indices never change.
--
-- Gen 1 cadence: water and flowers tick off ONE global counter, one
-- step every 21 frames at 60fps (~0.35s) — every animated tile in
-- view pulses in lockstep. HEARTBEAT = 10 reproduces that at 30fps.
-- Water oscillates +-4px (4 steps right, 4 left, like the GB's
-- byte-rotation); flowers cycle bob frames 1,2,3,1.
local WATER_ID <const>, SHORE_ID <const>, FLOWERS_ID <const> = 4, 12, 11
local HEARTBEAT <const> = 10
local WATER_SHIFTS <const> = { 0, 1, 2, 3, 4, 3, 2, 1 }
local FLOWER_SEQ <const> = { 1, 2, 3, 1 }

local animTiles = nil
local animTick = 0
local animStep = 0

local function buildAnimatedTiles()
    local water, shore, flowers = {}, {}, {}
    for i, shift in ipairs(WATER_SHIFTS) do
        water[i] = TileFactory.water(shift)
        shore[i] = TileFactory.shore(shift)
    end
    for i, frame in ipairs(FLOWER_SEQ) do
        flowers[i] = TileFactory.flowers(frame)
    end
    return { water = water, shore = shore, flowers = flowers }
end

-- Call once per frame while the overworld is on screen (keeps running
-- under dialog/debug overlays since stacked states still update)
function updateOverworldAnimations()
    if not (tilemapSprite and animTiles) then return end
    animTick = animTick + 1
    if animTick % HEARTBEAT ~= 0 then return end
    animStep = animStep + 1
    tileImages:setImage(WATER_ID, animTiles.water[(animStep % #WATER_SHIFTS) + 1])
    tileImages:setImage(SHORE_ID, animTiles.shore[(animStep % #WATER_SHIFTS) + 1])
    tileImages:setImage(FLOWERS_ID, animTiles.flowers[(animStep % #FLOWER_SEQ) + 1])
    tilemapSprite:markDirty()
end

function generateTileImages()
    tileImages = TileFactory.generateAll()
    animTiles = buildAnimatedTiles()
    animTick = 0
    animStep = 0
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

-- Swap one tile of the LIVE tilemap (story events: a starter ball taken
-- off Oak's table). Callers must also update zone.tiles themselves —
-- rebuilds read from there. Grid coords are 0-based player coords.
function setOverworldTile(gx, gy, id)
    if tilemap then
        tilemap:setTileAtPosition(gx + 1, gy + 1, id)
        if tilemapSprite then tilemapSprite:markDirty() end
    end
end
