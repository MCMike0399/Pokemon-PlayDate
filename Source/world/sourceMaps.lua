-- Shared source definition importer. Existing slice names are compatibility
-- facades; authored Pallet keeps its own Zone adapter and connection seam.
SourceMaps = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local manifest
local rawCache = setmetatable({}, { __mode = "v" })

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function catalogue()
    if not manifest then
        local data = SourceMaps.record("data/sourceMaps.json")
        local ids, keys = {}, {}
        for name, entry in pairs(data.maps) do
            assert(type(name) == "string" and not ids[entry.id] and not keys[entry.key], "duplicate source map identity")
            assert(entry.profile == "viridian" or entry.profile == "pewter", "unknown source binding profile")
            ids[entry.id], keys[entry.key] = true, true
        end
        manifest = data.maps
    end
    return manifest
end

function SourceMaps.record(path)
    local data = assert(json.decodeFile(path), "missing pinned source record: " .. path)
    assert(data.schema == 1 and data.source_revision == revision, "unverified source record: " .. path)
    return data
end

function SourceMaps.entry(name)
    return copy(assert(catalogue()[name], "map outside source manifest"))
end

function SourceMaps.names(profile)
    local result = {}
    for name, entry in pairs(catalogue()) do
        if not profile or entry.profile == profile then result[#result + 1] = name end
    end
    table.sort(result)
    return result
end

function SourceMaps.nameForID(id, profile)
    for name, entry in pairs(catalogue()) do
        if entry.id == id and (not profile or entry.profile == profile) then return name end
    end
end

function SourceMaps.definition(name)
    local entry = SourceMaps.entry(name)
    local data = rawCache[name]
    if not data then
        data = SourceMaps.record(entry.path)
        assert(data.name == name and data.id == entry.id, "source map identity mismatch")
        rawCache[name] = data
    end
    return copy(data)
end

function SourceMaps.padded(name)
    local entry = SourceMaps.entry(name)
    local data = SourceMaps.definition(name)
    local width, height = table.unpack(data.dimensions.cells)
    assert(entry.height == height and entry.width >= width, "source manifest dimensions differ")
    assert(entry.padding == math.max(0, (entry.width - width) // 2), "source manifest padding differs")
    data.source_dimensions = copy(data.dimensions)
    data.runtime_adapter.padding_cells = { entry.padding, 0 }
    data.runtime_adapter.source_name = name
    if entry.width ~= width then
        local grid = {}
        for y = 1, 16 do grid[y] = string.rep("#", 16) end
        local id = #data.grids + 1
        local key = entry.profile == "viridian" and "adapter:viridian-slice:void" or "adapter:pewter:void"
        data.grids[id] = { id = id, stable_id = key, grid = grid, terrain = {
            foot_tile = -1, land_passable = false, grass = false, counter = false,
            warp_tile = false, water_candidate = false, adapter_padding = true,
        } }
        for y = 1, height do
            local tiles, collision = {}, {}
            for x = 1, entry.width do tiles[x], collision[x] = id, 1 end
            for x = 1, width do
                tiles[x + entry.padding] = data.tile_ids[y][x]
                collision[x + entry.padding] = data.collision[y][x]
            end
            data.tile_ids[y], data.collision[y] = tiles, collision
        end
    end
    -- Viridian historically adds source_x/y only to padded rooms. Preserve that
    -- observable shape while Pewter retains source coordinates for every event.
    if entry.width ~= width or entry.profile == "pewter" then
        for _, events in pairs(data.events) do
            for _, event in ipairs(events) do
                event.source_x, event.source_y = event.x, event.y
                event.x = event.x + entry.padding
            end
        end
    end
    data.dimensions.cells = { entry.width, height }
    data.dimensions.playdate_pixels = { entry.width * 32, height * 32 }
    return data
end
