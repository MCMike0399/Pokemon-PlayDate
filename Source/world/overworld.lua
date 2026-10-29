local gfx <const> = playdate.graphics

-- Owns only a map view and its static wall sprites. Offscreen instances exercise
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
function WorldView:_wall(x, y)
    local wall = gfx.sprite.new(self.emptyImage)
    wall:setCenter(0, 0)
    wall:moveTo(x * TILE_SIZE, y * TILE_SIZE)
    wall:setCollideRect(0, 0, TILE_SIZE, TILE_SIZE)
    return wall
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
    self.emptyImage = gfx.image.new(TILE_SIZE, TILE_SIZE)
    self.walls = {}
    local tileIDs = {}
    for y = 1, zone.height do
        self.walls[y] = {}
        for x = 1, zone.width do
            tileIDs[#tileIDs + 1] = zone.tiles[y][x]
            if zone.collision[y][x] == 1 then self.walls[y][x] = self:_wall(x - 1, y - 1) end
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
        for _, row in ipairs(self.walls) do for _, wall in pairs(row) do wall:add() end end
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
function WorldView:hasWallAt(x, y) return self.walls[y + 1] and self.walls[y + 1][x + 1] ~= nil or false end
function WorldView:applyTiles(plan)
    assert(not self.disposed, "world view disposed")
    local old, oldImages, oldCount = {}, self.images, self.imageCount
    local images = oldImages
    if self.zone.registry:maxID() > oldCount then
        images = generateTileImages(self.zone.registry)
        self:_applyAnimationImages(images)
    end
    local replacements, present = {}, {}
    -- A retained view may have been removed from the display list by a root
    -- controller. Rollback restores actual membership, not the attach policy.
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do present[sprite] = true end
    for i, change in ipairs(plan) do
        assert(self.zone.registry:has(change.id) and images:getImage(change.id), "tile image missing from registry palette")
        old[i] = { x = change.x, y = change.y, id = self:tileAt(change.x, change.y), wall = self.walls[change.y + 1][change.x + 1] }
        old[i].present = present[old[i].wall] == true
        if change.collision == 1 then replacements[i] = old[i].wall or self:_wall(change.x, change.y) end
    end
    local function restore()
        for i, item in ipairs(old) do
            local replacement = replacements[i]
            if replacement and replacement ~= item.wall then replacement:remove() end
            self.walls[item.y + 1][item.x + 1] = item.wall
            if item.wall then
                if item.present then item.wall:add() else item.wall:remove() end
            end
            self.tilemap:setTileAtPosition(item.x + 1, item.y + 1, item.id)
        end
        self.images, self.imageCount = oldImages, oldCount
        self.tilemap:setImageTable(oldImages)
        self.sprite:markDirty()
    end
    local ok, problem = pcall(function()
        if images ~= oldImages then self.tilemap:setImageTable(images) end
        self.images, self.imageCount = images, self.zone.registry:maxID()
        for i, change in ipairs(plan) do
            local wall = old[i].wall
            if wall and wall ~= replacements[i] then wall:remove() end
            if self.attached and replacements[i] and replacements[i] ~= wall then replacements[i]:add() end
            self.walls[change.y + 1][change.x + 1] = replacements[i]
            self.tilemap:setTileAtPosition(change.x + 1, change.y + 1, change.id)
        end
        self.sprite:markDirty()
    end)
    if not ok then restore(); error(problem, 0) end
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
    for _, row in ipairs(self.walls) do for _, wall in pairs(row) do wall:remove() end end
    self.zone:detachView(self)
    self.disposed = true
end
function setupOverworld()
    currentZone:assertEnterable()
    if activeView then activeView:dispose() end
    activeView = WorldView(currentZone)
end
function getOverworldView() return activeView end
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
