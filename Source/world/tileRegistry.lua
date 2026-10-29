-- Stable content keys are persistent identity. Numeric IDs are local render slots.
Class("TileRegistry")
local stores = setmetatable({}, { __mode = "k" })
-- Opaque handles retain normalized snapshots, never caller-owned tables.
local preparedBatches <const> = setmetatable({}, { __mode = "k" })
local BASE_COUNT <const> = 37
local SOLID <const> = {
    false, false, true, true, true, false, true, false, true, true,
    false, false, true, true, true, true, true, false, false, false,
    true, true, true, true, false, true, false, true, true, true,
    true, false, true, true, true, true, true,
}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
local function same(a, b)
    if a == b then
        return true
    end
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function plain(value, seen)
    seen = seen or {}
    local kind = type(value)
    assert(kind == "table" or kind == "string" or kind == "number" or kind == "boolean", "tile metadata must be plain data")
    if kind == "number" then assert(value == value and value > -math.huge and value < math.huge, "nonfinite metadata") end
    if kind == "table" then
        assert(getmetatable(value) == nil and not seen[value], "tile metadata must be acyclic plain data")
        seen[value] = true
        for key, item in pairs(value) do
            assert(type(key) == "string" or type(key) == "number", "invalid metadata key")
            plain(item, seen)
        end
        seen[value] = nil
    end
end
local function imported(entry)
    assert(type(entry) == "table" and type(entry.key) == "string" and #entry.key > 0, "stable tile key required")
    for key in pairs(entry) do
        assert(key == "key" or key == "grid" or key == "collision" or key == "terrain" or key == "kind", "unknown tile definition metadata field")
    end
    assert(entry.kind == nil or entry.kind == "grid", "invalid imported tile kind")
    assert(not entry.key:match("^base:"), "base tile keys are reserved")
    assert(type(entry.grid) == "table" and #entry.grid == 16, "tile grid requires 16 rows")
    local rowCount = 0
    for key in pairs(entry.grid) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= 16, "invalid grid row index")
        rowCount = rowCount + 1
    end
    assert(rowCount == 16, "tile grid has missing rows")
    for _, row in ipairs(entry.grid) do
        assert(type(row) == "string" and #row == 16 and not row:find("[^%.12#]"), "tile grid requires 16 valid shade cells per row")
    end
    assert(entry.collision == 0 or entry.collision == 1, "explicit tile collision must be 0 or 1")
    assert(type(entry.terrain) == "table" and type(entry.terrain.land_passable) == "boolean", "explicit terrain passability required")
    assert(entry.terrain.land_passable == (entry.collision == 0), "collision/terrain disagreement")
    for _, flag in ipairs({ "grass", "counter", "water_candidate", "warp_tile" }) do
        assert(entry.terrain[flag] == nil or type(entry.terrain[flag]) == "boolean", "terrain flags must be boolean")
    end
    plain(entry.terrain)
    return { key = entry.key, grid = entry.grid, collision = entry.collision, terrain = entry.terrain, kind = "grid" }
end

-- Reviewed global imported-terrain tones. Authored art and SpriteFactory
-- retain their original renderer. Source grids are read without rewriting them.
-- Lazy terrain-only accelerator. All definitions and identity checks remain
-- inside the registry; no main import or second world-data owner is added.
local ATLAS_TILESETS <const> = {
    CAVERN = true, CLUB = true, FOREST = true, FOREST_GATE = true,
    GATE = true, GYM = true, HOUSE = true, INTERIOR = true, MART = true,
    MUSEUM = true, OVERWORLD = true, POKECENTER = true, SHIP = true,
    SHIP_PORT = true, UNDERGROUND = true,
}
local atlasRecent <const> = {}
local function terrainAtlas(tileset)
    for i, slot in ipairs(atlasRecent) do
        if slot.tileset == tileset then
            table.remove(atlasRecent, i)
            table.insert(atlasRecent, 1, slot)
            return slot
        end
    end
    -- Evict before opening another table. Failed loads also occupy one slot,
    -- avoiding repeated I/O for missing optional assets on the current route.
    if #atlasRecent == 2 then
        table.remove(atlasRecent)
    end
    local slot = { tileset = tileset }
    table.insert(atlasRecent, 1, slot)
    local path <const> = "terrainAtlases/" .. tileset:lower()
    local ok, descriptor = pcall(json.decodeFile, path .. ".json")
    if not ok or type(descriptor) ~= "table" or descriptor.schema ~= 1
        or descriptor.tileset ~= tileset
        or descriptor.source_revision ~= "af519899719f0754965776faac0e836a3b906e6d"
        or type(descriptor.entries) ~= "table"
        or type(descriptor.frame_count) ~= "number" or descriptor.frame_count % 1 ~= 0
        or descriptor.frame_count < 1 or descriptor.frame_count > 256 then
        return slot
    end
    local loaded, images = pcall(playdate.graphics.imagetable.new, path)
    if loaded and images and #images == descriptor.frame_count then
        slot.descriptor = descriptor
        slot.images = images
    end
    return slot
end
local function compiledTerrainImage(rows, policy, renderer, sourceKey)
    if not TileFactory or renderer ~= TileFactory.renderGrid
        or policy.enabled ~= true or policy.approval ~= "approved"
        or policy.preview ~= false or policy.family ~= "bayer8"
        or type(sourceKey) ~= "string" or type(rows) ~= "table" or #rows ~= 16 then
        return nil
    end
    local tileset <const> = sourceKey:match("^pokered:([A-Z_]+):cell:[%da-f%-]+$")
    if not ATLAS_TILESETS[tileset] then
        return nil
    end
    for y = 1, 16 do
        if type(rows[y]) ~= "string" or #rows[y] ~= 16 or rows[y]:find("[^%.12#]") then
            return nil
        end
    end
    local slot <const> = terrainAtlas(tileset)
    local descriptor <const> = slot.descriptor
    -- Exact policy equality includes every pattern byte, phase and approval
    -- field. Source keys alone never authorize a compiled image.
    if not descriptor or not same(policy, descriptor.policy) then
        return nil
    end
    local entry <const> = descriptor.entries[sourceKey]
    if type(entry) ~= "table" or entry.grid ~= table.concat(rows)
        or type(entry.index) ~= "number" or entry.index % 1 ~= 0
        or entry.index < 1 or entry.index > descriptor.frame_count then
        return nil
    end
    local image <const> = slot.images:getImage(entry.index)
    if not image then
        return nil
    end
    local width, height = image:getSize()
    if width ~= 32 or height ~= 32 then
        return nil
    end
    -- Never expose a mutable cached frame. Public renderImportedGrid calls
    -- without a source key still use the original fresh runtime renderer.
    return image:copy()
end

local tonePolicy
function TileRegistry.renderImportedGrid(rows, renderer, sourceKey)
    if tonePolicy == nil then
        tonePolicy = assert(json.decodeFile("data/importedTonePatterns.json"), "missing imported tone policy")
    end
    local policy = tonePolicy
    if not policy.enabled then
        return renderer(rows, nil, { 0, 0 })
    end
    assert(policy.schema == 1 and policy.phase[1] == 0 and policy.phase[2] == 0, "invalid imported tone phase")
    assert(policy.approval == "approved" or (policy.preview and HarnessBuild and HarnessBuild.enabled),
        "imported tone approval required outside private preview")
    for _, name in ipairs({ "light", "dark" }) do
        assert(type(policy[name]) == "table" and #policy[name] == 8, "eight tone pattern rows required")
        for _, value in ipairs(policy[name]) do
            assert(type(value) == "number" and value % 1 == 0 and value >= 0 and value <= 255, "invalid tone byte")
        end
    end
    local gfx <const> = playdate.graphics
    local ok, compiled = pcall(compiledTerrainImage, rows, policy, renderer, sourceKey)
    if ok and compiled then
        return compiled
    end
    local image = gfx.image.new(32, 32, gfx.kColorWhite)
    gfx.pushContext(image)
    for y, row in ipairs(rows) do
        local x = 1
        while x <= 16 do
            local shade = row:sub(x, x)
            local last = x
            while last < 16 and row:sub(last + 1, last + 1) == shade do
                last = last + 1
            end
            if shade ~= "." then
                if shade == "#" then
                    gfx.setColor(gfx.kColorBlack)
                else
                    gfx.setPattern(shade == "1" and policy.light or policy.dark, 0, 0)
                end
                gfx.fillRect((x - 1) * 2, (y - 1) * 2, (last - x + 1) * 2, 2)
            end
            x = last + 1
        end
    end
    Shade.reset()
    gfx.popContext()
    return image
end

function TileRegistry:init()
    local store = { entries = {}, keys = {}, images = {} }
    stores[self] = store
    for id = 1, BASE_COUNT do
        local key = "base:" .. id
        store.entries[id] = { key = key, collision = SOLID[id] and 1 or 0, kind = "base",
            terrain = { land_passable = not SOLID[id], grass = id == 8, water_candidate = id == 4, counter = false, warp_tile = id == 6 or id == 27 or id == 32 } }
        store.keys[key] = id
    end
end
function TileRegistry:maxID() return #stores[self].entries end
function TileRegistry:has(value)
    local store = stores[self]
    return type(value) == "string" and store.keys[value] ~= nil
        or type(value) == "number" and value % 1 == 0 and store.entries[value] ~= nil
end
function TileRegistry:id(value)
    local store = stores[self]
    local id = type(value) == "string" and store.keys[value] or value
    assert(type(id) == "number" and id % 1 == 0 and store.entries[id], "unknown tile ID/key: " .. tostring(value))
    return id
end
function TileRegistry:key(value) return stores[self].entries[self:id(value)].key end
function TileRegistry:entry(value) return copy(stores[self].entries[self:id(value)]) end
-- Read scalar collision policy without cloning the grid/terrain record.
function TileRegistry:collisionPolicy(value)
    local entry = stores[self].entries[self:id(value)]
    return entry.collision, entry.terrain.land_passable
end
local function normalizeBatch(registry, entries)
    assert(type(entries) == "table", "tile batch required")
    local length, found = #entries, 0
    for key in pairs(entries) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= length, "invalid tile batch index")
        found = found + 1
    end
    assert(found == length, "tile batch has holes")
    local store, pending = stores[registry], {}
    local normalized = {}
    for i, value in ipairs(entries) do
        local entry = imported(value)
        local existing = store.keys[entry.key] and store.entries[store.keys[entry.key]] or pending[entry.key]
        assert(not existing or same(existing, entry), "conflicting duplicate tile key: " .. entry.key)
        -- Validation above reads every incoming field. Equal private entries
        -- are immutable, so only a new definition needs a defensive snapshot.
        local retained = existing or copy(entry)
        pending[entry.key] = retained
        normalized[i] = retained
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return normalized
end
function TileRegistry:validateBatch(entries)
    -- Public validation returns detached values; only opaque preparation may
    -- retain an immutable record already held by this registry.
    return copy(normalizeBatch(self, entries))
end
function TileRegistry:prepareBatch(entries)
    local normalized <const> = normalizeBatch(self, entries)
    local handle <const> = {}
    preparedBatches[handle] = { registry = self, entries = normalized }
    return handle
end
function TileRegistry:preparedTerrain(handle, index)
    local prepared <const> = preparedBatches[handle]
    assert(prepared and prepared.registry == self, "prepared tile batch requires its original registry")
    assert(type(index) == "number" and index % 1 == 0 and prepared.entries[index], "unknown prepared tile index")
    return copy(prepared.entries[index].terrain)
end
function TileRegistry:registerPreparedBatch(handle)
    local prepared <const> = preparedBatches[handle]
    assert(prepared and prepared.registry == self, "prepared tile batch requires its original registry")
    local normalized <const> = prepared.entries
    local store, ids = stores[self], {}
    -- Preparation can yield. Recheck the entire snapshot before publishing any
    -- entry, without yielding between this check and the append-only commit.
    for _, entry in ipairs(normalized) do
        local id <const> = store.keys[entry.key]
        assert(not id or same(store.entries[id], entry), "conflicting duplicate tile key: " .. entry.key)
    end
    for i, entry in ipairs(normalized) do
        local id = store.keys[entry.key]
        if not id then
            id = #store.entries + 1
            store.entries[id] = entry
            store.keys[entry.key] = id
        end
        ids[i] = id
    end
    return ids
end
function TileRegistry:registerBatch(entries)
    return self:registerPreparedBatch(self:prepareBatch(entries))
end
function TileRegistry:renderImported(value, renderer)
    local id = self:id(value)
    assert(id > BASE_COUNT, "base images are provided by TileFactory")
    local store = stores[self]
    if not store.images[id] then
        store.images[id] = TileRegistry.renderImportedGrid(copy(store.entries[id].grid), renderer, store.entries[id].key)
    end
    return store.images[id]
end

WorldTiles = TileRegistry()

-- Runtime installation rollback only. Validation/codec never needs this seam.
-- Definitions are immutable append-only entries; preserve original image refs.
function TileRegistry:checkpointRuntime()
    local store=stores[self];local count=#store.entries;local images={}
    for key,value in pairs(store.images) do images[key]=value end
    local used=false
    return function()
        if used then return end;used=true
        for id=#store.entries,count+1,-1 do store.keys[store.entries[id].key]=nil;store.entries[id]=nil end
        store.images=images
    end
end
