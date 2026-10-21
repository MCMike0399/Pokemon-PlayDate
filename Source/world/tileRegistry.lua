-- Stable content keys are persistent identity. Numeric IDs are local render slots.
Class("TileRegistry")
local stores = setmetatable({}, { __mode = "k" })
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
    return { key = entry.key, grid = copy(entry.grid), collision = entry.collision, terrain = copy(entry.terrain), kind = "grid" }
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
function TileRegistry:validateBatch(entries)
    assert(type(entries) == "table", "tile batch required")
    local length, found = #entries, 0
    for key in pairs(entries) do
        assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= length, "invalid tile batch index")
        found = found + 1
    end
    assert(found == length, "tile batch has holes")
    local store, pending = stores[self], {}
    local normalized = {}
    for i, value in ipairs(entries) do
        local entry = imported(value)
        local existing = store.keys[entry.key] and store.entries[store.keys[entry.key]] or pending[entry.key]
        assert(not existing or same(existing, entry), "conflicting duplicate tile key: " .. entry.key)
        pending[entry.key] = entry
        normalized[i] = entry
    end
    return normalized
end
function TileRegistry:registerBatch(entries)
    local normalized = self:validateBatch(entries)
    local store, ids = stores[self], {}
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
function TileRegistry:renderImported(value, renderer)
    local id = self:id(value)
    assert(id > BASE_COUNT, "base images are provided by TileFactory")
    local store = stores[self]
    if not store.images[id] then store.images[id] = renderer(copy(store.entries[id].grid), nil, { 0, 0 }) end
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
