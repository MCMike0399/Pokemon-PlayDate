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
    -- Cell probes sample the image table. A full tilemap bitmap is the
    -- malloc that large isolated maps cannot pay for beside the catalogue.
    if options.cellsOnly then
        zone:attachView(self)
        return
    end
    self.tilemap = gfx.tilemap.new()
    self.tilemap:setImageTable(self.images)
    self.tilemap:setSize(zone.width, zone.height)
    -- Growing a city index by doubling needs a second copy while the first
    -- is still live. That copy is the allocation Fly loses after the
    -- destination atlas. Maps past 1024 cells allocate the final size once.
    local count = zone.width * zone.height
    local tileIDs = count > 1024 and table.create(count, 0) or {}
    local index = 0
    for y = 1, zone.height do
        local row = zone.tiles[y]
        for x = 1, zone.width do
            index = index + 1
            tileIDs[index] = row[x]
        end
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    self.tilemap:setTiles(tileIDs, zone.width)
    self:_attachSprite()
    zone:attachView(self)
    if self.attached then
        self.sprite:add()
    end
end
function WorldView:releaseBitmaps()
    if self.disposed or not self.tilemap then return end
    -- The sprite retains the tilemap bitmap. Remove it before the next
    -- city's atlas inflates, and keep this view object for rollback.
    if self.sprite then
        self.sprite:remove()
        self.sprite = nil
    end
    self.tilemap = nil
    self.images = nil
    self.cellScratch = nil
end
function WorldView:ensureBitmaps()
    if self.disposed or self.tilemap then return end
    self.images = generateTileImages(self.zone.registry)
    self.imageCount = self.zone.registry:maxID()
    self.animTiles = self.animTiles or animatedTiles()
    self.tilemap = gfx.tilemap.new()
    self.tilemap:setImageTable(self.images)
    self.tilemap:setSize(self.zone.width, self.zone.height)
    local tileIDs = {}
    for y = 1, self.zone.height do
        for x = 1, self.zone.width do
            tileIDs[#tileIDs + 1] = self.zone.tiles[y][x]
        end
    end
    self.tilemap:setTiles(tileIDs, self.zone.width)
    self:_attachSprite()
    if self.attached ~= false then
        self.sprite:add()
    end
end
-- Imported floors remap facility cells onto registry ids above the authored
-- water, flower and shore slots. Rewriting those slots and marking the whole
-- tilemap dirty still uploads the map texture on maps that never show them.
function WorldView:_authoredMotion()
    if self.authoredMotion ~= nil then return self.authoredMotion end
    local found = false
    for _, row in ipairs(self.zone.tiles) do
        for _, id in ipairs(row) do
            if id == WATER_ID or id == SHORE_ID or id == FLOWERS_ID then
                found = true
                break
            end
        end
        if found then break end
    end
    self.authoredMotion = found
    return found
end
function WorldView:updateAnimations()
    if not self:_authoredMotion() then return end
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
        self:_composePalletField()
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
        self:_composePalletField()
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
    self.zone.registry:paintPalletField(self)
    gfx.popContext()
    return image
end
function WorldView:_attachSprite()
    self.sprite = gfx.sprite.new()
    self.sprite:setCenter(0, 0)
    self.sprite:moveTo(0, 0)
    self.sprite:setZIndex(-1)
    if self.zone.stableID == "pokered:PALLET_TOWN" then
        -- One image per tile key cannot vary by cell. The sprite image is the
        -- tilemap with grass quadrants painted per cell. Tile ids stay put,
        -- and roofs, doors, walls and rooms are not repainted.
        self:_composePalletField()
    else
        self.sprite:setTilemap(self.tilemap)
    end
end
function WorldView:_composePalletField()
    if self.zone.stableID ~= "pokered:PALLET_TOWN" or not self.tilemap or not self.sprite then return end
    local image = gfx.image.new(self.zone.width * TILE_SIZE, self.zone.height * TILE_SIZE, gfx.kColorWhite)
    local ox, oy = gfx.getDrawOffset()
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    self.tilemap:draw(0, 0)
    self.zone.registry:paintPalletField(self)
    gfx.popContext()
    gfx.setDrawOffset(ox, oy)
    self.sprite:setImage(image)
end
-- One cell, not the whole city. image.new of a 40x36 map is about 180 KiB
-- and returns "out of memory" once the 16 MiB pool is holding the tilemap.
-- The tilemap is a grid of these images, so the cell is that tile.
function WorldView:renderCell(x, y)
    assert(not self.disposed, "world view disposed")
    assert(type(x) == "number" and type(y) == "number" and x % 1 == 0 and y % 1 == 0
        and x >= 0 and y >= 0 and x < self.zone.width and y < self.zone.height,
        "world view cell is outside the map")
    local image = self.cellScratch
    if not image then
        image = gfx.image.new(TILE_SIZE, TILE_SIZE, gfx.kColorWhite)
        self.cellScratch = image
    end
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    self.images:getImage(self.zone.tiles[y + 1][x + 1]):draw(0, 0)
    gfx.popContext()
    return image
end
function WorldView:dispose()
    if self.disposed then return end
    if self.sprite then self.sprite:remove() end
    -- Fly nils this before the destination is built, then disposes on success.
    if self.zone then self.zone:detachView(self) end
    -- The sprite and tilemap own the map's bitmap. Drop those references
    -- before the next city allocates its own, or both images sit in the pool.
    self.sprite = nil
    self.tilemap = nil
    self.images = nil
    self.cellScratch = nil
    self.disposed = true
end
function releaseOverworldView()
    if not activeView then return end
    if not activeView.disposed then activeView:dispose() end
    activeView.zone = nil
    activeView = nil
end
function setupOverworld()
    currentZone:assertEnterable()
    -- switchZone already dropped the departing view and collected. The
    -- destination definition stays. Releasing it here decodes the map again
    -- beside the new tilemap, and field Cut copies the screen in that same
    -- gap. Fade length stays on DoorWarpSubstate.
    releaseOverworldView()
    if WorldDeltas and WorldDeltas.releaseInactiveZones then
        WorldDeltas.releaseInactiveZones()
    end
    collectgarbage("collect")
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
