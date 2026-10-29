local gfx <const> = playdate.graphics
local assert <const> = assert
local error <const> = error
local ipairs <const> = ipairs
local pairs <const> = pairs
local pcall <const> = pcall
local TILE_SIZE <const> = TILE_SIZE

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
function WorldView:_wall(x, y, width)
    -- No image is needed: the sprite exists only for SDK collision queries.
    -- Size the bounds as well as the collide rect to cover the entire run.
    local wall = gfx.sprite.new()
    local pixelWidth = width * TILE_SIZE
    wall:setSize(pixelWidth, TILE_SIZE)
    wall:setCenter(0, 0)
    wall:moveTo(x * TILE_SIZE, y * TILE_SIZE)
    wall:setCollideRect(0, 0, pixelWidth, TILE_SIZE)
    return wall
end
function WorldView:_wallRow(y, blocked, previousRuns)
    local walls, runs = {}, {}
    local x = 1
    while x <= self.zone.width do
        if blocked[x] then
            local first = x
            repeat
                x = x + 1
            until x > self.zone.width or not blocked[x]
            local last = x - 1
            local run = previousRuns and previousRuns[first]
            if not run or run.last ~= last then
                run = {
                    last = last,
                    wall = self:_wall(first - 1, y - 1, last - first + 1),
                }
            end
            runs[first] = run
            for column = first, last do
                walls[column] = run.wall
            end
        else
            x = x + 1
        end
    end
    return walls, runs
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
    self.walls, self.wallRuns = {}, {}
    local tileIDs = {}
    for y = 1, zone.height do
        local blocked = {}
        for x = 1, zone.width do
            tileIDs[#tileIDs + 1] = zone.tiles[y][x]
            if zone.collision[y][x] == 1 then
                blocked[x] = true
            end
        end
        self.walls[y], self.wallRuns[y] = self:_wallRow(y, blocked)
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
        for _, row in ipairs(self.wallRuns) do
            for _, run in pairs(row) do
                run.wall:add()
            end
        end
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

    local rows = {}
    for i, change in ipairs(plan) do
        assert(self.zone.registry:has(change.id) and images:getImage(change.id),
            "tile image missing from registry palette")
        old[i] = { x = change.x, y = change.y, id = self:tileAt(change.x, change.y) }
        local y, x = change.y + 1, change.x + 1
        local blocked = change.collision == 1
        local row = rows[y]
        if not row and blocked ~= (self.walls[y][x] ~= nil) then
            row = { walls = self.walls[y], runs = self.wallRuns[y], blocked = {} }
            for column in pairs(row.walls) do
                row.blocked[column] = true
            end
            rows[y] = row
        end
        if row then
            row.blocked[x] = blocked
        end
    end

    -- Prepare only changed collision rows. Exact run boundaries retain their
    -- objects and registration; tile-only edits do not touch wall ownership.
    local removed, created = {}, {}
    for y, row in pairs(rows) do
        row.nextWalls, row.nextRuns = self:_wallRow(y, row.blocked, row.runs)
        for first, run in pairs(row.runs) do
            if row.nextRuns[first] ~= run then
                removed[#removed + 1] = { wall = run.wall, visible = run.wall:isVisible() }
            end
        end
        for first, run in pairs(row.nextRuns) do
            if row.runs[first] ~= run then
                created[#created + 1] = run.wall
            end
        end
    end
    if #removed > 0 then
        -- Attach policy and visibility do not describe actual SDK membership.
        -- A root may remove attached walls or register an offscreen wall.
        local present = {}
        for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
            present[sprite] = true
        end
        for _, item in ipairs(removed) do
            item.present = present[item.wall] == true
        end
    end

    local function restore()
        for _, wall in ipairs(created) do
            wall:remove()
        end
        for y, row in pairs(rows) do
            self.walls[y], self.wallRuns[y] = row.walls, row.runs
        end
        for _, item in ipairs(removed) do
            if item.present then
                item.wall:add()
            else
                item.wall:remove()
            end
            item.wall:setVisible(item.visible)
        end
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
        for _, item in ipairs(removed) do
            item.wall:remove()
        end
        if self.attached then
            for _, wall in ipairs(created) do
                wall:add()
            end
        end
        for y, row in pairs(rows) do
            self.walls[y], self.wallRuns[y] = row.nextWalls, row.nextRuns
        end
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
    for _, row in ipairs(self.wallRuns) do
        for _, run in pairs(row) do
            run.wall:remove()
        end
    end
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
