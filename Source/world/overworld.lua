local gfx <const> = playdate.graphics
local assert <const> = assert
local error <const> = error
local ipairs <const> = ipairs
local pcall <const> = pcall

-- Owns tile rendering only; Zone owns grid collision. Offscreen instances exercise
-- exactly the same SDK tilemap/registry path without tearing down the live game.
Class("WorldView")
local activeView = nil
local WATER_ID <const>, SHORE_ID <const>, FLOWERS_ID <const> = 4, 12, 11
local HEARTBEAT <const> = 10
local WATER_SHIFTS <const> = { 0, 1, 2, 3, 4, 3, 2, 1 }
local FLOWER_SEQ <const> = { 1, 2, 3, 1 }

local function animatedTiles()
    if WorldView.animationImages then
        return WorldView.animationImages
    end
    local water, shore, flowers = {}, {}, {}
    for i, shift in ipairs(WATER_SHIFTS) do
        water[i] = TileFactory.water(shift)
        shore[i] = TileFactory.shore(shift)
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    for i, frame in ipairs(FLOWER_SEQ) do
        flowers[i] = TileFactory.flowers(frame)
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    WorldView.animationImages = { water = water, shore = shore, flowers = flowers }
    return WorldView.animationImages
end
function generateTileImages(registry)
    return TileFactory.generateAll(registry or (currentZone and currentZone.registry) or WorldTiles)
end
function WorldView:_applyAnimationImages(images)
    images:setImage(WATER_ID, self.animTiles.water[(self.animStep % #WATER_SHIFTS) + 1])
    images:setImage(SHORE_ID, self.animTiles.shore[(self.animStep % #WATER_SHIFTS) + 1])
    images:setImage(FLOWERS_ID, self.animTiles.flowers[(self.animStep % #FLOWER_SEQ) + 1])
end
function WorldView:init(zone, options)
    options = options or {}
    zone:assertEnterable()
    self.zone = zone
    self.attached = options.attach ~= false
    self.images = generateTileImages(zone.registry)
    self.imageCount = zone.registry:maxID()
    self.animTiles = animatedTiles()
    self.animTick, self.animStep = 0, 0
    self.tilemap = gfx.tilemap.new()
    self.tilemap:setImageTable(self.images)
    self.tilemap:setSize(zone.width, zone.height)
    local tileIDs = {}
    for y = 1, zone.height do
        for x = 1, zone.width do
            tileIDs[#tileIDs + 1] = zone.tiles[y][x]
        end
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    self.tilemap:setTiles(tileIDs, zone.width)
    self.sprite = gfx.sprite.new()
    self.sprite:setTilemap(self.tilemap)
    self.sprite:setCenter(0, 0)
    self.sprite:moveTo(0, 0)
    self.sprite:setZIndex(-1)
    zone:attachView(self)
    if self.attached then
        self.sprite:add()
    end
end
function WorldView:updateAnimations()
    self.animTick = self.animTick + 1
    if self.animTick % HEARTBEAT ~= 0 then return end
    self.animStep = self.animStep + 1
    self:_applyAnimationImages(self.images)
    self.sprite:markDirty()
end
function WorldView:tileAt(x, y) return self.tilemap:getTileAtPosition(x + 1, y + 1) end
function WorldView:imageAt(x, y) return self.images:getImage(self:tileAt(x, y)) end
function WorldView:hasWallAt(x, y)
    local row = self.zone.collision[y + 1]
    return row ~= nil and row[x + 1] == 1
end
function WorldView:applyTiles(plan)
    assert(not self.disposed, "world view disposed")
    local old, oldImages, oldCount = {}, self.images, self.imageCount
    local images = oldImages
    if self.zone.registry:maxID() > oldCount then
        images = generateTileImages(self.zone.registry)
        self:_applyAnimationImages(images)
    end

    for i, change in ipairs(plan) do
        assert(self.zone.registry:has(change.id) and images:getImage(change.id),
            "tile image missing from registry palette")
        old[i] = { x = change.x, y = change.y, id = self:tileAt(change.x, change.y) }
    end

    local function restore()
        for _, item in ipairs(old) do
            self.tilemap:setTileAtPosition(item.x + 1, item.y + 1, item.id)
        end
        self.images, self.imageCount = oldImages, oldCount
        self.tilemap:setImageTable(oldImages)
        self.sprite:markDirty()
    end
    local ok, problem = pcall(function()
        if images ~= oldImages then
            self.tilemap:setImageTable(images)
        end
        self.images, self.imageCount = images, self.zone.registry:maxID()
        for _, change in ipairs(plan) do
            self.tilemap:setTileAtPosition(change.x + 1, change.y + 1, change.id)
        end
        self.sprite:markDirty()
    end)
    if not ok then
        restore()
        error(problem, 0)
    end
    return restore
end
function WorldView:render()
    assert(not self.disposed, "world view disposed")
    local image = gfx.image.new(self.zone.width * TILE_SIZE, self.zone.height * TILE_SIZE, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    self.tilemap:draw(0, 0)
    gfx.popContext()
    return image
end
function WorldView:dispose()
    if self.disposed then return end
    self.sprite:remove()
    self.zone:detachView(self)
    self.disposed = true
end
function setupOverworld()
    currentZone:assertEnterable()
    if activeView then activeView:dispose() end
    activeView = WorldView(currentZone)
end
function getOverworldView() return activeView end

-- Field traversal stages the complete target before publishing its session.
-- The caller keeps the old view for rollback and disposes it only on success.
function WorldView.exchangePrepared(view)
    assert(view and not view.disposed, "live prepared world view required")
    local previous = activeView
    activeView = view
    return previous
end
function updateOverworldAnimations()
    if activeView then activeView:updateAnimations() end
end
function getMapPixelSize() return currentZone.width * TILE_SIZE, currentZone.height * TILE_SIZE end
-- Compatibility entry point now keeps data, collision, terrain and view together.
function setOverworldTile(gx, gy, id)
    assert(currentZone, "no active world zone")
    return currentZone:setTile(gx, gy, id)
end

-- Scoped native-view ownership for prepared SDK contracts only.
function WorldView.withIsolation(callback)
    assert(HarnessBuild and HarnessBuild.enabled, "development view scope required")
    local previous = activeView
    activeView = nil
    local ok, result = pcall(callback)
    if activeView then activeView:dispose() end
    activeView = previous
    if not ok then error(result, 0) end
    return result
end
