-- ============================================================
-- Zone: Dart/Flutter-style declarative map definitions
-- ============================================================
-- Usage:
--   registerZone("pallet_town", Zone({
--       name = "Pallet Town",
--       spawn = { x = 5, y = 6 },
--       tileRows = {
--           "Tr Tr Tr Tr Pa Pa Tr Tr Tr Tr",
--           "Tr .  .  .  Pa Pa .  .  .  Tr",
--       },
--       npcs = {
--           { gridX=10, gridY=12, name="Prof. Oak", dialog={...}, sprite="oak" },
--       },
--       encounters = {
--           { species="rattata", minLevel=2, maxLevel=4, weight=40 },
--       },
--       warps = {
--           { label="Red's House", x=5, y=6 },
--       },
--       doors = {
--           -- stepping onto (5,5) fades out and re-enters the overworld
--           -- in zone "reds_house" at (3,7), facing up
--           { x=5, y=5, to="reds_house", toX=3, toY=7, facing="up" },
--       },
--   }))
--
-- `warps` are debug-menu teleport presets; `doors` are real tile-triggered
-- zone transitions (house doors, exit mats, stairs).
-- ============================================================

---@class Zone
---@field name string
---@field spawn { x: integer, y: integer, facing?: string }
---@field npcDefs table[]
---@field encounters table[]
---@field encounterRate number
---@field warps table[]
---@field tiles integer[][]
---@field width integer
---@field height integer
---@field collision integer[][]
Zone = Class("Zone")

-- 2-char tile codes -> IDs (readable map authoring)
-- Use "." as shorthand for grass (most common tile)
local CODES = {
    ["."]  = 1,   -- Grass (shorthand)
    Gr = 1,       -- Grass
    Pa = 2,       -- Path
    Wa = 3,       -- Wall
    Wt = 4,       -- Water
    Tr = 5,       -- Tree
    Dr = 6,       -- Door
    Fn = 7,       -- Fence
    TG = 8,       -- Tall Grass
    Rf = 9,       -- Roof
    Sg = 10,      -- Sign
    Fl = 11,      -- Flowers
    Sh = 12,      -- Shore
    LW = 13,      -- Lab Wall
    Mb = 14,      -- Mailbox
    RL = 15,      -- Roof Left (peaked edge)
    RR = 16,      -- Roof Right (peaked edge)
    WW = 17,      -- Wall Window
    -- Interior tiles
    Fo = 25,      -- Floor (wood planks)
    IW = 26,      -- Interior Wall
    Ma = 27,      -- Door Mat (exit warp)
    Tb = 28,      -- Table / counter
    Bk = 29,      -- Bookshelf
    Tv = 30,      -- TV
    Pl = 31,      -- Potted Plant
    St = 32,      -- Stairs (warp)
    Bd = 33,      -- Bed
    PC = 34,      -- PC desk
    LM = 35,      -- Lab Machine
    Vd = 36,      -- Void (black surround outside rooms)
    Pb = 37,      -- Table with a POKE BALL (starter choice)
}

-- Parse "Tr Tr Pa .  Dr Wa" -> {5, 5, 2, 1, 6, 3}
local function parseRow(str)
    local row = {}
    for code in str:gmatch("%S+") do
        local id = CODES[code]
        if not id then error("Unknown tile code: '" .. code .. "'") end
        row[#row + 1] = id
    end
    return row
end

-- Internal copies are the immutable reset/save reference; callers never receive them.
local zoneData = setmetatable({}, { __mode = "k" })
-- Only fromMapDefinition can grant ownership of its fresh cell arrays.
-- Public configuration fields (including compactTerrain) never grant trust.
local ownedConfigs <const> = setmetatable({}, { __mode = "k" })
local function deepCopy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = deepCopy(item) end
    return result
end
local function integer(value) return type(value) == "number" and value % 1 == 0 end
local function array(value, count, label)
    assert(type(value) == "table" and #value == count, label .. " length mismatch")
    local found = 0
    for key in pairs(value) do
        assert(integer(key) and key >= 1 and key <= count, label .. " has invalid index")
        found = found + 1
    end
    assert(found == count, label .. " has holes")
end
local function rectangle(value, width, height, label, validate)
    array(value, height, label)
    for y = 1, height do
        array(value[y], width, label .. " row " .. y)
        for x = 1, width do validate(value[y][x], x, y) end
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
end
local function bounds(zone, x, y)
    assert(integer(x) and integer(y) and x >= 0 and y >= 0 and x < zone.width and y < zone.height, "zone coordinate outside bounds")
end
local function captureDefinition(zone, terrain, revision, issues, blocked, compact, owned)
    if owned then
        local current, tiles, collision = {}, {}, {}
        for y = 1, zone.height do
            current[y] = terrain[y]
            tiles[y] = zone.tiles[y]
            collision[y] = zone.collision[y]
        end
        zoneData[zone] = { tiles = tiles, collision = collision,
            terrain = current, baselineTerrain = terrain, revision = revision or "authored-v1",
            issues = deepCopy(issues or {}), blocked = deepCopy(blocked or {}),
            compactTerrain = compact, touched = {} }
        return
    end
    if compact then
        local current,baseline,palette={},{},{}
        for y=1,zone.height do
            current[y],baseline[y]={},{}
            for x=1,zone.width do
                local id=zone.tiles[y][x]
                if not palette[id] then palette[id]=deepCopy(terrain[y][x]) end
                current[y][x],baseline[y][x]=palette[id],palette[id]
            end
        end
        zoneData[zone]={tiles=deepCopy(zone.tiles),collision=deepCopy(zone.collision),terrain=current,baselineTerrain=baseline,
            revision=revision or "authored-v1",issues=deepCopy(issues or {}),blocked=deepCopy(blocked or {}),compactTerrain=true, touched={}}
        return
    end
    zoneData[zone] = { tiles = deepCopy(zone.tiles), collision = deepCopy(zone.collision),
        terrain = deepCopy(terrain), baselineTerrain = deepCopy(terrain), revision = revision or "authored-v1",
        issues = deepCopy(issues or {}), blocked = deepCopy(blocked or {}), view = nil, touched = {} }
end
local function blockedAt(data, x, y) return data.blocked[y + 1] and data.blocked[y + 1][x + 1] end


function Zone:init(config)
    assert(type(config) == "table", "zone configuration required")
    local owned <const> = ownedConfigs[config]
    ownedConfigs[config] = nil
    self.name = config.name or "Unnamed"
    self.stableID = config.id or self.name
    self.registry = config.registry or WorldTiles
    self.imported = config.imported == true
    self.terrainFixture = config.terrainFixture == true
    self.spawn = deepCopy(config.spawn or { x = 1, y = 1 })
    self.npcDefs = deepCopy(config.npcs or {})
    self.encounters = deepCopy(config.encounters or {})
    self.encounterRate = config.encounterRate or 0.15
    self.warps = deepCopy(config.warps or {})
    self.doors = deepCopy(config.doors or {})

    -- Parse tile grid from string rows
    if config.tileRows then
        self.tiles = {}
        for i, rowStr in ipairs(config.tileRows) do
            local row = parseRow(rowStr)
            if i > 1 and #row ~= #self.tiles[1] then
                error(self.name .. " row " .. i .. ": " .. #row
                    .. " tiles, expected " .. #self.tiles[1])
            end
            self.tiles[i] = row
        end
        self.height = #self.tiles
        self.width = #self.tiles[1]
    else
        self.tiles = config.tiles
        self.width = config.width
        self.height = config.height
    end

    assert(integer(self.width) and integer(self.height) and self.width > 0 and self.height > 0, "invalid zone dimensions")
    if owned then
        -- The factory checked cell shape and collision while building these
        -- private arrays. Recheck the live registry once per palette entry.
        for id, terrain in pairs(owned.terrainPalette) do
            local collision, passable = self.registry:collisionPolicy(id)
            assert(terrain.land_passable == passable, "numeric zone terrain disagrees with stable tile key")
            assert(collision == (passable and 0 or 1), "numeric zone collision disagrees with stable tile key")
        end
        self.collision = config.collision
        captureDefinition(self, config.terrain, config.sourceRevision, config.bindingIssues,
            config.blockedBindings, config.compactTerrain, true)
        return
    end
    rectangle(self.tiles, self.width, self.height, "zone tiles", function(id) self.registry:id(id) end)
    if not owned then
        self.tiles = deepCopy(self.tiles)
    end
    if config.collision then
        assert(type(config.terrain) == "table", "explicit numeric zones require terrain")
        rectangle(config.collision, self.width, self.height, "zone collision", function(value)
            assert(value == 0 or value == 1, "unknown zone collision value")
        end)
        local verifiedEntries = {}
        rectangle(config.terrain, self.width, self.height, "zone terrain", function(value, x, y)
            assert(type(value) == "table" and type(value.land_passable) == "boolean", "zone terrain requires passability")
            local id=self.tiles[y][x]
            local entry = verifiedEntries[id] or self.registry:entry(id)
            verifiedEntries[id] = entry
            assert(value.land_passable == entry.terrain.land_passable, "numeric zone terrain disagrees with stable tile key")
            local blocker = config.blockedBindings and config.blockedBindings[y] and config.blockedBindings[y][x]
            assert(config.collision[y][x] == (blocker and 1 or entry.collision), "numeric zone collision disagrees with stable tile key")
        end)
        self.collision = owned and config.collision or deepCopy(config.collision)
        captureDefinition(self, config.terrain, config.sourceRevision, config.bindingIssues, config.blockedBindings, config.compactTerrain, owned)
        return
    end

    for _, row in ipairs(self.tiles) do
        for _, id in ipairs(row) do assert(id <= 37, "imported numeric tiles require explicit collision and terrain") end
    end

    -- Resolve roof corner tiles against the ground beside them: the
    -- triangle outside the roof diagonal takes the neighbor's texture
    -- (path/tall grass) instead of punching a white wedge into it.
    -- RL checks left then above; RR checks right then above.
    local ROOF_L <const>, ROOF_R <const> = 15, 16
    local CORNER_ON = {
        [ROOF_L] = { [2] = 21, [8] = 23 },  -- on path / on tall grass
        [ROOF_R] = { [2] = 22, [8] = 24 },
    }
    for y = 1, self.height do
        for x = 1, self.width do
            local id = self.tiles[y][x]
            local variants = CORNER_ON[id]
            if variants then
                local sideX = (id == ROOF_L) and x - 1 or x + 1
                local side = (sideX >= 1 and sideX <= self.width) and self.tiles[y][sideX]
                local above = (y > 1) and self.tiles[y - 1][x]
                self.tiles[y][x] = variants[side] or variants[above] or id
            end
        end
    end

    -- Scatter grass tuft variants over plain grass (IDs 18-20)
    -- Original GB Pallet Town: mostly plain, very sparse tufts,
    -- with 3-tuft clusters near signs
    local GRASS_ID <const> = 1
    local SIGN_ID <const> = 10
    -- First pass: place 3-tuft grass (grassC=20) adjacent to signs
    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == SIGN_ID then
                local neighbors = {{x-1,y},{x+1,y},{x,y-1},{x,y+1},
                                   {x-1,y-1},{x+1,y-1},{x-1,y+1},{x+1,y+1}}
                for _, n in ipairs(neighbors) do
                    local nx, ny = n[1], n[2]
                    if ny >= 1 and ny <= self.height and nx >= 1 and nx <= self.width
                       and self.tiles[ny][nx] == GRASS_ID then
                        self.tiles[ny][nx] = 20  -- grassC (3 tufts)
                    end
                end
            end
        end
    end
    -- Second pass: very sparse random tufts (~12% of remaining grass)
    for y = 1, self.height do
        for x = 1, self.width do
            if self.tiles[y][x] == GRASS_ID then
                local hash = (x * 7 + y * 13 + x * y * 3) % 17
                if hash == 0 then
                    self.tiles[y][x] = 18  -- grassA (1 tuft)
                elseif hash == 5 then
                    self.tiles[y][x] = 19  -- grassB (2 tufts)
                end
            end
        end
    end

    -- Authored terrain is determined by tile type. Read each immutable registry
    -- entry once, then keep private palette records instead of per-cell copies.
    self.collision = {}
    local terrain, entries = {}, {}
    for y = 1, self.height do
        self.collision[y], terrain[y] = {}, {}
        for x = 1, self.width do
            local id = self.tiles[y][x]
            if not entries[id] then
                entries[id] = self.registry:entry(id)
            end
            self.collision[y][x] = entries[id].collision
            terrain[y][x] = entries[id].terrain
        end
    end
    captureDefinition(self, terrain, config.sourceRevision, nil, nil, true)
end

function Zone:terrainAt(x, y)
    bounds(self, x, y)
    local data = assert(zoneData[self], "zone definition not initialized")
    local result = deepCopy(data.terrain[y + 1][x + 1])
    result.binding_blocked = blockedAt(data, x, y) ~= nil
    return result
end
function Zone:isTallGrass(x, y)
    if not integer(x) or not integer(y) or x < 0 or y < 0 or x >= self.width or y >= self.height then return false end
    return zoneData[self].terrain[y + 1][x + 1].grass == true
end
function Zone:getBindingIssues() return deepCopy(zoneData[self].issues) end
function Zone:isCampaignReady() return #zoneData[self].issues == 0 end
function Zone:isSliceReady() return zoneData[self].slicePlan ~= nil end
function Zone:sourceEventsAt(x, y)
    bounds(self, x, y)
    local plan, events = zoneData[self].slicePlan, {}
    if not plan then return events end
    for _, kind in ipairs({ "objects", "background_events", "warps" }) do
        for _, event in ipairs(plan.source.events[kind]) do
            if event.x == x and event.y == y then
                events[#events + 1] = { id = event.id, kind = kind, status = plan.specs[event.id].status }
            end
        end
    end
    return events
end
function Zone:movementRule(x, y, direction)
    local plan = assert(zoneData[self].slicePlan, "no explicit source movement binding")
    return MapBindings.movement(plan.source, x, y, direction, self)
end
function Zone:assertEnterable()
    assert(self:isCampaignReady() or self:isSliceReady() or self.terrainFixture == true, "unresolved imported world bindings: " .. self.stableID)
end
function Zone:bindingAt(x, y)
    bounds(self, x, y)
    return deepCopy(blockedAt(zoneData[self], x, y))
end
function Zone:attachView(view)
    assert(type(view) == "table" and type(view.applyTiles) == "function", "world view adapter required")
    local data = zoneData[self]
    assert(not data.view or data.view == view, "zone already has a world view")
    data.view = view
end
function Zone:detachView(view)
    if zoneData[self].view == view then zoneData[self].view = nil end
end
local function prepare(zone, changes)
    local data, result, occupied = zoneData[zone], {}, {}
    for _, change in ipairs(changes) do
        assert(type(change) == "table", "world delta tile record required")
        for key in pairs(change) do assert(key == "x" or key == "y" or key == "key", "unsupported world delta tile field") end
        bounds(zone, change.x, change.y)
        assert(type(change.key) == "string", "persistent world tiles require stable keys")
        local position = change.y * zone.width + change.x
        assert(not occupied[position], "duplicate world delta coordinate")
        occupied[position] = true
        local id = zone.registry:id(change.key)
        local entry = zone.registry:entry(id)
        result[#result + 1] = { x = change.x, y = change.y, id = id, key = entry.key,
            collision = blockedAt(data, change.x, change.y) and 1 or entry.collision, terrain = entry.terrain }
    end
    return result
end
function Zone:_commitTiles(plan)
    if next(plan) == nil then
        return function() end
    end
    local data, old, undoView = zoneData[self], {}, nil
    for i, change in ipairs(plan) do
        old[i] = { x = change.x, y = change.y, id = self.tiles[change.y + 1][change.x + 1],
            collision = self.collision[change.y + 1][change.x + 1], terrain = data.terrain[change.y + 1][change.x + 1] }
    end
    if data.view then undoView = data.view:applyTiles(plan) end
    local function assign(values)
        for _, change in ipairs(values) do
            local row <const> = change.y + 1
            -- Factory-owned rows share their reset baseline until first write.
            -- Public constructors still use independent defensive arrays.
            if self.tiles[row] == data.tiles[row] then
                local detached = {}
                for x = 1, self.width do
                    detached[x] = self.tiles[row][x]
                end
                self.tiles[row] = detached
            end
            if self.collision[row] == data.collision[row] then
                local detached = {}
                for x = 1, self.width do
                    detached[x] = self.collision[row][x]
                end
                self.collision[row] = detached
            end
            if data.terrain[row] == data.baselineTerrain[row] then
                -- Cell records stay private and immutable; detach just the row.
                local detached <const> = {}
                for x = 1, self.width do
                    detached[x] = data.terrain[row][x]
                end
                data.terrain[row] = detached
            end
            self.tiles[change.y + 1][change.x + 1] = change.id
            self.collision[change.y + 1][change.x + 1] = change.collision
            data.terrain[change.y + 1][change.x + 1] = change.terrain
            data.touched[change.y * self.width + change.x + 1] = true
        end
    end
    local ok, problem = pcall(assign, plan)
    if not ok then
        assign(old)
        if undoView then undoView() end
        error(problem, 0)
    end
    return function()
        if undoView then undoView() end
        assign(old)
    end
end
function Zone:bindDefinitionProvider(provider)
    assert(self.imported and type(provider)=="table" and type(provider.mutate)=="function","explicit imported definition provider required")
    local data=zoneData[self];assert(not data.definitionProvider or data.definitionProvider==provider,"imported provider ownership replaced")
    data.definitionProvider=provider
end
function Zone:disposeView()
    local view=zoneData[self].view;if view then view:dispose() end
end
function Zone:setTile(x, y, tileKeyOrID)
    bounds(self, x, y)
    local provider=zoneData[self].definitionProvider
    -- The immutable provider knows stable keys before their images/numeric IDs
    -- are materialized. It validates the key before its atomic registry commit.
    local key = provider and type(tileKeyOrID)=="string" and tileKeyOrID or self.registry:key(tileKeyOrID)
    if provider then return provider:mutate(self,x,y,key) end
    self:_commitTiles(prepare(self, { { x = x, y = y, key = key } }))
    return key
end
function Zone:exportDeltas()
    local data, changes = zoneData[self], {}
    for index in pairs(data.touched) do
        local x = (index - 1) % self.width + 1
        local y = (index - 1) // self.width + 1
        local id = self.registry:id(self.tiles[y][x])
        if id ~= data.tiles[y][x] then
            changes[#changes + 1] = {x = x - 1, y = y - 1, key = self.registry:key(id)}
        end
    end
    table.sort(changes, function(a, b)
        return a.y == b.y and a.x < b.x or a.y < b.y
    end)
    return { schema = 1, zone_id = self.stableID, definition_revision = data.revision, tiles = changes, tile_count = #changes }
end
function Zone:_prepareDeltas(payload, purpose)
    local data = zoneData[self]
    assert(type(payload) == "table" and payload.schema == 1 and payload.zone_id == self.stableID, "wrong world delta identity/schema")
    for key in pairs(payload) do
        assert(key == "schema" or key == "zone_id" or key == "definition_revision"
            or key == "tile_count" or key == "tiles", "unsupported world zone delta field")
    end
    assert(payload.definition_revision == data.revision, "wrong world definition revision")
    assert(integer(payload.tile_count) and payload.tile_count >= 0, "world delta count required")
    array(payload.tiles, payload.tile_count, "world delta tiles")
    local changed = prepare(self, payload.tiles)
    assert(purpose == nil or purpose == "candidate" or purpose == "apply", "unknown delta preparation")
    local function matches(x, y, id, collision, terrain)
        if self.tiles[y + 1][x + 1] ~= id or self.collision[y + 1][x + 1] ~= collision then
            return false
        end
        local current = data.terrain[y + 1][x + 1]
        for key, value in pairs(terrain) do
            if current[key] ~= value then
                return false
            end
        end
        for key in pairs(current) do
            if terrain[key] == nil then
                return false
            end
        end
        return true
    end
    local desired = {}
    local function restoreCell(x, y)
        local id = data.tiles[y][x]
        if purpose ~= "apply" or not matches(x - 1, y - 1, id,
            data.collision[y][x], data.baselineTerrain[y][x]) then
            desired[(y - 1) * self.width + x] = {
                x = x - 1, y = y - 1, id = id,
                collision = data.collision[y][x], terrain = data.baselineTerrain[y][x],
            }
        end
    end
    if purpose == "apply" then
        -- All runtime cell writes pass through _commitTiles. This index only
        -- narrows baseline comparisons; the cells remain the authoritative data.
        for index in pairs(data.touched) do
            restoreCell((index - 1) % self.width + 1, (index - 1) // self.width + 1)
        end
    elseif purpose ~= "candidate" then
        for y = 1, self.height do
            for x = 1, self.width do
                restoreCell(x, y)
            end
        end
    end
    for _, change in ipairs(changed) do
        local index = change.y * self.width + change.x + 1
        if purpose == "apply" and matches(change.x, change.y, change.id, change.collision, change.terrain) then
            desired[index] = nil
        else
            desired[index] = change
        end
    end
    if purpose == "apply" then
        local result = {}
        for _, change in pairs(desired) do
            result[#result + 1] = change
        end
        table.sort(result, function(a, b)
            return a.y == b.y and a.x < b.x or a.y < b.y
        end)
        return result
    end
    return desired
end
function Zone:applyDeltas(payload)
    self:_commitTiles(self:_prepareDeltas(payload, "apply"))
end
function Zone:resetDeltas()
    self:applyDeltas({ schema = 1, zone_id = self.stableID, definition_revision = zoneData[self].revision, tiles = {}, tile_count = 0 })
end

-- Validate every source row/event/key before adding anything to the shared registry.
function Zone.fromMapDefinition(definition, registry, options)
    options = options or {}
    registry = registry or WorldTiles
    assert(options.registry==nil or options.registry==registry,"registry option must match actual registry")
    assert(options.isolatedCatalog==nil or type(options.isolatedCatalog)=="boolean","isolated catalog flag must be boolean")
    assert(not options.isolatedCatalog or registry~=WorldTiles,"isolated catalog requires actual private registry")
    assert(type(definition) == "table" and definition.schema == 1 and type(definition.id) == "string", "invalid map definition")
    assert(type(definition.name) == "string" and #definition.name > 0, "imported map name required")
    local size = definition.dimensions and definition.dimensions.cells
    assert(type(size) == "table" and integer(size[1]) and integer(size[2]) and size[1] > 0 and size[2] > 0, "invalid imported dimensions")
    array(size, 2, "imported dimensions")
    assert(type(definition.source_revision) == "string", "imported source revision required")
    assert(options.terrainFixture == nil or type(options.terrainFixture) == "boolean", "terrain fixture flag must be boolean")
    assert(options.compactTerrain==nil or type(options.compactTerrain)=="boolean","compact terrain mode must be boolean")
    local width, height = size[1], size[2]
    local spawn = options.spawn or { x = 1, y = 1 }
    assert(type(spawn) == "table" and integer(spawn.x) and integer(spawn.y) and spawn.x >= 0 and spawn.y >= 0 and spawn.x < width and spawn.y < height, "invalid imported spawn")
    local entries, localKeys = {}, {}
    for i, entry in ipairs(definition.grids) do
        assert(entry.id == i and not localKeys[i] and type(entry.stable_id) == "string", "invalid imported local tile ID")
        assert(type(entry.terrain) == "table" and type(entry.terrain.land_passable) == "boolean", "imported terrain missing")
        entries[i] = { key = entry.stable_id, grid = entry.grid, collision = entry.terrain.land_passable and 0 or 1, terrain = entry.terrain }
        localKeys[i] = entry.stable_id
    end
    array(definition.grids, #entries, "imported grids")
    assert(#entries > 0, "imported palette is empty")
    local preparedBatch <const> = registry:prepareBatch(entries)
    array(definition.tile_ids, height, "imported tile IDs")
    array(definition.collision, height, "imported collision")
    for y = 1, height do
        local tiles, collisions = definition.tile_ids[y], definition.collision[y]
        array(tiles, width, "imported tile IDs row " .. y)
        array(collisions, width, "imported collision row " .. y)
        for x = 1, width do
            local id, collision = tiles[x], collisions[x]
            assert(integer(id) and localKeys[id], "unknown imported tile ID")
            assert(collision == 0 or collision == 1, "unknown imported collision value")
            assert(collision == entries[id].collision, "imported collision/terrain mismatch")
        end
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    local bindings=options.bindingAdapter or MapBindings
    assert(bindings==MapBindings or bindings==PewterBindings or bindings==SourceBindings,"unreviewed source binding adapter")
    local slicePlan = options.sliceBindings and bindings.prepare(definition, options.sliceBindings, options) or nil
    local issues, blocked, identities = {}, {}, {}
    local function issue(kind, id, x, y)
        assert(type(id) == "string" and #id > 0 and not identities[id], "duplicate/invalid imported binding ID")
        identities[id] = true
        if x ~= nil then
            assert(integer(x) and integer(y) and x >= 0 and y >= 0 and x < width and y < height, "imported event outside bounds")
        end
        if slicePlan and slicePlan.bound[id] then return end
        local value = { kind = kind, id = id, status = "unresolved source binding", x = x, y = y }
        issues[#issues + 1] = value
        -- A verified source NPC owns occupancy through NPCManager, including
        -- conditional visibility. Keep its behavior gap diagnostic, not a
        -- permanent collision tile after the source actor disappears.
        if slicePlan and kind == "objects" then return end
        if x ~= nil then
            assert(integer(x) and integer(y) and x >= 0 and y >= 0 and x < width and y < height, "imported event outside bounds")
            blocked[y + 1] = blocked[y + 1] or {}
            assert(not blocked[y + 1][x + 1], "overlapping unresolved bindings require explicit resolution")
            blocked[y + 1][x + 1] = value
        end
    end
    local events = assert(definition.events, "imported events required")
    for _, kind in ipairs({ "objects", "warps", "background_events" }) do
        assert(type(events[kind]) == "table", "imported event list required")
        array(events[kind], #events[kind], "imported " .. kind)
        for _, event in ipairs(events[kind]) do
            assert(type(event.id) == "string", "stable source event ID required")
            issue(kind, event.id, event.x, event.y)
        end
    end
    for _, connection in ipairs(definition.connections or {}) do issue("connection", connection.direction .. ":" .. tostring(connection.target_map)) end
    if definition.directional_rules and #definition.directional_rules.ledges > 0 then issue("directional_rules", "ledges:" .. definition.id) end
    issue("script", definition.script and definition.script.source or definition.id)
    if definition.encounters and definition.encounters.grass and definition.encounters.grass.rate_byte > 0 then issue("encounter_policy", definition.id) end
    if slicePlan then
        issues[#issues + 1] = { kind = "slice_scope", id = slicePlan.scope or "parcel-slice-only", status = slicePlan.scopeStatus or "bounded parcel slice; full campaign content incomplete" }
        for _, event in ipairs(definition.events.objects) do
            if event.movement == "WALK" then
                issues[#issues + 1] = { kind = "npc_movement", id = event.id .. ":wander", status = "source wandering descriptor retained; movement executor not integrated" }
            end
        end
    end
    local rollbackRegistry <const> = registry:checkpointRuntime()
    local ok, result = pcall(function()
        local ids <const> = registry:registerPreparedBatch(preparedBatch)
        local tiles, collision, terrain = {}, {}, {}
        local terrainPalette <const> = {}
        for y = 1, height do
            tiles[y], collision[y], terrain[y] = {}, {}, {}
            for x = 1, width do
                local localID = definition.tile_ids[y][x]
                assert(integer(localID) and entries[localID], "unknown imported tile ID")
                local solid = definition.collision[y][x]
                assert((solid == 0 or solid == 1) and solid == entries[localID].collision,
                    "imported collision/terrain mismatch")
                tiles[y][x] = ids[localID]
                collision[y][x] = blocked[y] and blocked[y][x] and 1 or solid
                local id <const> = ids[localID]
                if not terrainPalette[id] then
                    terrainPalette[id] = registry:preparedTerrain(preparedBatch, localID)
                end
                if options.compactTerrain then
                    terrain[y][x] = terrainPalette[id]
                else
                    terrain[y][x] = deepCopy(terrainPalette[id])
                end
            end
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
        end
        local config <const> = { name = definition.name, id = definition.id, registry = registry, tiles = tiles,
            width = width, height = height, collision = collision, terrain = terrain,
            imported = true, compactTerrain = options.compactTerrain == true, terrainFixture = options.terrainFixture == true,
            sourceRevision = definition.source_revision, bindingIssues = issues, blockedBindings = blocked,
            spawn = deepCopy(spawn), npcs = slicePlan and slicePlan.npcs, doors = slicePlan and slicePlan.doors,
            encounters = slicePlan and slicePlan.encounters }
        ownedConfigs[config] = {terrainPalette = terrainPalette}
        local zone <const> = Zone(config)
        zoneData[zone].slicePlan = slicePlan
        -- pokered TryDoWildEncounter permits non-grass indoor land except FOREST.
        -- FIRST_INDOOR_MAP is $25 at the pinned source revision. A missing grass
        -- tile alone says nothing about encounters (Centers also use -1).
        local firstIndoorMap <const> = 0x25
        local sourceMapID <const> = definition.source_map_id
        local tileset <const> = definition.tileset
        zoneData[zone].sourceIndoorLand = integer(sourceMapID)
            and sourceMapID >= firstIndoorMap and sourceMapID <= 255
            and type(tileset) == "table" and type(tileset.constant) == "string"
            and tileset.constant ~= "FOREST"
        return zone
    end)
    if not ok then
        rollbackRegistry()
        error(result, 0)
    end
    return result
end

WorldDeltas = {}
local definitionProvider
function WorldDeltas.installDefinitionProvider(provider)
    assert(type(provider)=="table" and type(provider.validate)=="function" and type(provider.ensure)=="function","immutable imported world provider required")
    assert(not definitionProvider or definitionProvider==provider,"world definition provider already installed")
    definitionProvider=provider
end
function WorldDeltas.definitionProvider() return definitionProvider end
-- SDK contract dependency scope; not available in ordinary production builds.
function WorldDeltas._withDefinitionProvider(provider,callback)
    assert(HarnessBuild and HarnessBuild.enabled and type(callback)=="function","development provider scope required")
    local previous=definitionProvider;definitionProvider=provider
    local ok,a,b=pcall(callback);definitionProvider=previous
    if not ok then error(a,0) end;return a,b
end
function WorldDeltas.disposeImportedCache() if definitionProvider then definitionProvider:disposeCache() end end
function WorldDeltas.zoneKey(stableID)
    for key,zone in pairs(zoneRegistry) do if zone.stableID==stableID then return key end end
    return definitionProvider and definitionProvider:keyForID(stableID)
end
function WorldDeltas.describeZone(key)
    local zone=zoneRegistry[key]
    if zone then return {key=key,id=zone.stableID,width=zone.width,height=zone.height,name=zone.name} end
    if definitionProvider and definitionProvider:hasKey(key) then
        local d=definitionProvider:descriptor(key)
        return {key=d.key,id=d.id,width=d.width,height=d.height,name=d.name}
    end
end
function WorldDeltas.ensureZone(key)
    if zoneRegistry[key] then return zoneRegistry[key] end
    if definitionProvider and definitionProvider:hasKey(key) then return definitionProvider:ensure(key) end
end
function WorldDeltas.checkpointRuntime()
    local undoProvider=definitionProvider and definitionProvider:checkpointRuntime()
    local undoTiles=WorldTiles:checkpointRuntime()
    return function() if undoProvider then undoProvider() end;undoTiles() end
end
function WorldDeltas.export()
    local zones, names = {}, {}
    for name in pairs(zoneRegistry) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local zone=zoneRegistry[name]
        if not definitionProvider or not definitionProvider:owns(zone) then
            local value = zone:exportDeltas()
            if value.tile_count > 0 then zones[#zones + 1] = value end
        end
    end
    if definitionProvider then for _,value in ipairs(definitionProvider:export().zones) do zones[#zones+1]=value end end
    table.sort(zones,function(a,b)return a.zone_id<b.zone_id end)
    return { schema = 1, zones = zones, zone_count = #zones }
end
local function prepareWorld(payload, purpose)
    assert(type(payload) == "table" and payload.schema == 1 and integer(payload.zone_count), "invalid world delta payload")
    for key in pairs(payload) do
        assert(key == "schema" or key == "zone_count" or key == "zones", "unsupported world delta field")
    end
    array(payload.zones, payload.zone_count, "world delta zones")
    local indexed, plans, occupied, normalized, provided = {}, {}, {}, {}, {}
    for _, zone in pairs(zoneRegistry) do
        if not definitionProvider or not definitionProvider:owns(zone) then
            assert(not indexed[zone.stableID] or indexed[zone.stableID] == zone, "duplicate stable world zone ID")
            indexed[zone.stableID] = zone
        end
    end
    for _, value in ipairs(payload.zones) do
        assert(type(value) == "table", "world delta zone required")
        local zone = indexed[value.zone_id]
        if not zone and definitionProvider and definitionProvider:hasID(value.zone_id) then
            provided[#provided+1]=value
        else
        assert(zone and not occupied[zone], "unknown/duplicate world delta zone")
        occupied[zone] = true
        zone:_prepareDeltas(value, "candidate")
        local tiles = {}
        for _, tile in ipairs(value.tiles) do tiles[#tiles + 1] = { x = tile.x, y = tile.y, key = tile.key } end
        table.sort(tiles, function(a, b) return a.y == b.y and a.x < b.x or a.y < b.y end)
        normalized[#normalized + 1] = { schema = 1, zone_id = zone.stableID,
            definition_revision = zoneData[zone].revision, tile_count = #tiles, tiles = tiles }
        end
    end
    local providerPlan
    if definitionProvider then
        providerPlan=definitionProvider:validate({schema=1,zone_count=#provided,zones=provided})
        for _,value in ipairs(providerPlan.zones) do normalized[#normalized+1]=value end
    end
    table.sort(normalized, function(a, b) return a.zone_id < b.zone_id end)
    if purpose ~= "validate" then
        for _, zone in pairs(indexed) do
            local value
            for _, candidate in ipairs(payload.zones) do
                if candidate.zone_id == zone.stableID then
                    value = candidate
                end
            end
            value = value or {schema = 1, zone_id = zone.stableID,
                definition_revision = zoneData[zone].revision, tile_count = 0, tiles = {}}
            plans[#plans + 1] = {zone = zone, changes = zone:_prepareDeltas(value, purpose or "apply")}
        end
    end
    return plans, {schema = 1, zone_count = #normalized, zones = normalized}, providerPlan, indexed
end
-- Validation is pure: no registry allocation, view update, or domain mutation.
-- Returned records are defensive values; apply always preflights again.
function WorldDeltas.validate(payload)
    local _, normalized = prepareWorld(payload, "validate")
    return normalized
end
function WorldDeltas.resolveLocation(location, candidateWorld, options)
    assert(type(location) == "table", "world location required")
    for key in pairs(location) do
        assert(key == "zone_id" or key == "x" or key == "y" or key == "facing", "unsupported world location field")
    end
    assert(type(location.zone_id) == "string", "stable world location ID required")
    assert(location.facing == "up" or location.facing == "down" or location.facing == "left" or location.facing == "right", "invalid world facing")
    local _, _, providerPlan, indexed = prepareWorld(candidateWorld, "validate")
    if definitionProvider and definitionProvider:hasID(location.zone_id) then
        return definitionProvider:resolveLocation(location,providerPlan,options)
    end
    local zone = indexed[location.zone_id]
    assert(zone, "unknown world location zone")
    local changes = {}
    for _, value in ipairs(candidateWorld.zones) do
        if value.zone_id == location.zone_id then
            changes = zone:_prepareDeltas(value, "candidate")
            break
        end
    end
    bounds(zone, location.x, location.y)
    local namedSlice = options and options.sliceZones and options.sliceZones[zone.stableID] == true
    assert(zone:isCampaignReady() or (namedSlice and zone:isSliceReady()), "unresolved campaign world location")
    local tile = changes[location.y * zone.width + location.x + 1]
    local collision = tile and tile.collision or zoneData[zone].collision[location.y + 1][location.x + 1]
    assert(collision == 0, "world location is blocked in candidate world")
    return { zone_id = zone.stableID, x = location.x, y = location.y, facing = location.facing }
end
-- Root opts into the source Cut occupancy policy for players only.
function WorldDeltas.resolvePlayerLocation(location,candidateWorld,options)
    return FieldWorld.resolvePlayerLocation(location,candidateWorld,options)
end
function WorldDeltas.apply(payload)
    local plans,_,providerPlan = prepareWorld(payload)
    local undo,registries={},{}
    local function checkpoint(registry)
        if not registries[registry] then registries[registry]=registry:checkpointRuntime() end
    end
    checkpoint(WorldTiles);for _,plan in ipairs(plans) do checkpoint(plan.zone.registry) end
    local restored=false
    local function rollback()
        if restored then return end;restored=true
        for i=#undo,1,-1 do undo[i]() end
        for _,restore in pairs(registries) do restore() end
    end
    local ok, problem = pcall(function()
        for _, plan in ipairs(plans) do undo[#undo + 1] = plan.zone:_commitTiles(plan.changes) end
        if definitionProvider then undo[#undo+1]=definitionProvider:apply(providerPlan) end
    end)
    if not ok then rollback();error(problem,0) end
    return rollback
end
function WorldDeltas.reset() WorldDeltas.apply({ schema = 1, zones = {}, zone_count = 0 }) end

-- Spawn NPCs defined in this zone. Defs with an `appearsIf` predicate are
-- skipped while it returns false (story-conditional NPCs).
function Zone:spawnNPCs(npcManager)
    self:assertEnterable()
    npcManager:clear()
    local created = {}
    if self.imported then
        for _, issue in ipairs(zoneData[self].issues) do
            if issue.x ~= nil and not (self:isSliceReady() and issue.kind == "objects") then
                local message = "unresolved source interaction: " .. issue.id
                local blocker = { gridX = issue.x, gridY = issue.y, name = message, source_id = issue.id, interacted = false }
                function blocker:faceTowards() error(message) end
                function blocker:getDialogLines() error(message) end
                function blocker:getBattleData() error(message) end
                function blocker:remove() end -- No sprite was invented for an unresolved source actor.
                npcManager:addNPC(blocker)
            end
        end
        if not self:isSliceReady() then return created end
    end
    for _, def in ipairs(self.npcDefs) do
        if not def.appearsIf or def.appearsIf() then
            if self.imported and self:isSliceReady() then
                assert(type(def.sprite) == "string" and SpriteFactory.npc[def.sprite], "bound source NPC sprite missing; no fallback allowed")
            end
            local npc = NPC(def.gridX, def.gridY, def.name, def.dialog, def.battleData, def.sprite, def.facing)
            if def.postBattleLines then
                npc.postBattleLines = def.postBattleLines
            end
            npc.def = def
            npc.interacted = def.interacted or false
            npcManager:addNPC(npc)
            created[def.name] = npc
        end
    end
    return created
end

-- Step-triggered warp at grid position (player coords are 0-based).
-- Edge doors are excluded: they fire on walking INTO the edge, not on
-- landing (see getEdgeDoorAt).
function Zone:getDoorAt(gx, gy)
    if self.imported then
        local issue = self:bindingAt(gx, gy)
        assert(not issue or issue.kind ~= "warps", "unresolved source warp: " .. (issue and issue.id or ""))
    end
    for _, door in ipairs(self.doors) do
        if not door.edge and door.x == gx and door.y == gy then return door end
    end
    return nil
end

-- Gen 2/3-style edge exit: a door with `edge = "down"` fires when the
-- player stands on (x, y) and walks in that direction (into the room edge).
-- `dir` nil matches any edge door at the tile (used to point the exit arrow).
function Zone:getEdgeDoorAt(gx, gy, dir)
    if self.imported and integer(gx) and integer(gy) and gx >= 0 and gy >= 0 and gx < self.width and gy < self.height then
        local issue = self:bindingAt(gx, gy)
        assert(not issue or issue.kind ~= "warps", "unresolved source warp: " .. (issue and issue.id or ""))
    end
    for _, door in ipairs(self.doors) do
        if door.edge and door.x == gx and door.y == gy
           and (dir == nil or door.edge == dir) then
            return door
        end
    end
    return nil
end

-- Pure descriptor for the normal owned encounter-attempt boundary. Existing
-- explicit checkEncounter/rollEncounter helpers below retain their old contracts.
function Zone:encounterPolicyAt(x, y)
    if not Party._integer(x, 0, self.width - 1) or not Party._integer(y, 0, self.height - 1) then
        return nil, "invalid-encounter-coordinate"
    end
    local data <const> = zoneData[self]
    local terrain <const> = data.terrain[y + 1][x + 1]
    local indoorLand <const> = self.imported and data.sourceIndoorLand
        and terrain.land_passable and not terrain.water_candidate
    if self.collision[y + 1][x + 1] ~= 0 or not (terrain.grass == true or indoorLand) then
        return nil, "ineligible-terrain"
    end
    local rate
    if self.imported then
        if not self:isSliceReady() then return nil, "unbound-encounter-policy" end
        rate = { kind = "byte", value = data.slicePlan.encounterRateByte }
    else
        rate = { kind = "unit", value = self.encounterRate }
    end
    return { rate = rate, slots = deepCopy(self.encounters) }
end

-- Check wild encounter at grid position
function Zone:checkEncounter(tileX, tileY)
    if self.imported and self:isSliceReady() then
        local rate = zoneData[self].slicePlan.encounterRateByte
        return self:isTallGrass(tileX, tileY) and RulesRNG.random(0, 255) < rate
    end
    if self.imported then
        assert(self.terrainFixture, "unresolved imported encounter policy")
        return false -- Explicit terrain-only fixture; getBindingIssues reports disabled content.
    end
    return self:isTallGrass(tileX, tileY) and RulesRNG.random() < self.encounterRate
end

-- Roll a random wild Pokemon from encounter table
function Zone:rollEncounter(session)
    if session~=nil then assert(Specimen.isActiveSession(session),"inactive-encounter-session") end
    assert(not self.imported or self:isSliceReady(), "unresolved imported species/encounter policy")
    local encounter=session~=nil and assert(Specimen.planEncounter(session)) or nil
    local planned=RulesRNG.new(1);planned:restore(RulesRNG.snapshot())
    local function create(species,level)
        local mon=assert(Specimen.create(species,level,"wild",planned,encounter))
        RulesRNG.restore(planned:snapshot())
        return mon
    end
    local total = 0
    for _, e in ipairs(self.encounters) do total = total + e.weight end
    if total == 0 then
        assert(not self.imported, "imported map has no bound encounter slots")
        local mon=create("rattata",3)
        return mon
    end

    local roll = planned:random(1, total)
    local sum = 0
    for _, e in ipairs(self.encounters) do
        sum = sum + e.weight
        if roll <= sum then
            local mon=create(e.species,planned:random(e.minLevel,e.maxLevel))
            return mon
        end
    end
    local mon=create("rattata",3)
    return mon
end

-- ============================================================
-- ZONE REGISTRY
-- ============================================================
---@type table<string, Zone>
zoneRegistry = {}
---@type string[]
zoneList = {}
---@type Zone
currentZone = nil

function registerZone(key, zone)
    for existing, value in pairs(zoneRegistry) do
        assert(value ~= zone or existing == key, "zone object already registered under another key")
        assert(not zone.imported or value == zone or value.stableID ~= zone.stableID, "duplicate stable zone ID")
    end
    assert(type(key) == "string" and (not zoneRegistry[key] or zoneRegistry[key] == zone), "duplicate/invalid zone key")
    if not zone.imported then zone.stableID = key end
    zoneRegistry[key] = zone
    zoneList[#zoneList + 1] = key
end

function getCurrentZoneKey()
    for key, zone in pairs(zoneRegistry) do
        if zone == currentZone then return key end
    end
    return zoneList[1]
end

function switchZone(key)
    local zone=WorldDeltas.ensureZone(key)
    if zone then currentZone=zone end
end
