-- Shared source definition importer. Existing slice names are compatibility
-- facades; authored Pallet keeps its own Zone adapter and connection seam.
SourceMaps = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local manifest
local compact, tileGrids
local recordOverrides
local rawCache = setmetatable({}, { __mode = "v" })

local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    local count = 0
    for key, item in pairs(value) do
        result[key] = copy(item)
        count = count + 1
        if count % 32 == 0 and GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return result
end

local function catalogue()
    if not manifest then
        local data = SourceMaps.record("data/sourceMaps.json")
        local ids, keys = {}, {}
        for name, entry in pairs(data.maps) do
            assert(type(name) == "string" and not ids[entry.id] and not keys[entry.key], "duplicate source map identity")
            assert(entry.profile == "viridian" or entry.profile == "pewter" or entry.profile == "source", "unknown source binding profile")
            ids[entry.id], keys[entry.key] = true, true
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
        end
        manifest = data.maps
    end
    return manifest
end

function SourceMaps.record(path)
    local data = assert(recordOverrides and recordOverrides[path] and copy(recordOverrides[path]) or json.decodeFile(path), "missing pinned source record: " .. path)
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

-- Generated descriptors contain no art grids or full map definitions. This
-- inventory remains cheap during provider installation and save validation.
local function compactData()
    if not compact then
        local data = SourceMaps.record("data/sourceMapCache/compact.json")
        for name, descriptor in pairs(data.maps) do
            local entry = assert(catalogue()[name], "generated map outside source manifest")
            for _, field in ipairs({ "id", "key", "width", "height", "padding", "source_sha256" }) do
                assert(descriptor[field] == entry[field], "generated source descriptor differs from manifest")
            end
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
        end
        for name in pairs(catalogue()) do assert(data.maps[name], "generated source descriptor missing") end
        compact = data
    end
    return compact
end

function SourceMaps.compact()
    return copy(compactData())
end

-- Internal provider input only. Consumers must treat this validated catalogue
-- as read-only; public compact/descriptor/tile getters still return copies.
function SourceMaps._sharedCompact()
    return compactData()
end

function SourceMaps._isSharedCompact(data)
    return compact ~= nil and data == compact
end

local function grids()
    if not tileGrids then
        tileGrids = setmetatable({}, {__mode = "v"})
    end
    local value = tileGrids[1]
    if not value then
        local data = SourceMaps.record("data/sourceMapCache/tile-grids.json")
        assert(data.manifest_sha256 == compactData().manifest_sha256, "generated source cache revisions differ")
        value = data.tiles
        tileGrids[1] = value
    end
    return value
end

function SourceMaps.tile(key)
    return copy(assert(grids()[key], "unknown canonical source tile: " .. tostring(key)))
end

function SourceMaps.withTiles(callback)
    local data = grids()
    return callback(function(key)
        return copy(assert(data[key], "unknown canonical source tile: " .. tostring(key)))
    end)
end

-- Legacy warp binding needs target warp positions and arrival collision, not
-- the target's source refs, terrain grids, objects, encounters or full layout.
function SourceMaps.destination(name)
    local data = compactData()
    local descriptor = assert(data.maps[name], "unknown source destination")
    local collision = {}
    for _, warp in ipairs(descriptor.warps) do
        for y = warp.y, math.min(warp.y + 1, descriptor.height - 1) do
            local id = assert(tonumber(descriptor.tile_rows[y + 1]:sub(warp.x * 2 + 1, warp.x * 2 + 2), 16))
            local tile = assert(data.tiles[descriptor.palette[id]])
            collision[y + 1] = collision[y + 1] or {}
            collision[y + 1][warp.x + 1] = tile.collision
        end
    end
    return { source_map_constant = descriptor.source_map_constant,
        dimensions = { cells = { descriptor.width, descriptor.height } },
        events = { warps = copy(descriptor.warps) }, collision = collision }
end

local function rawDefinition(name)
    local entry = SourceMaps.entry(name)
    local data = rawCache[name]
    if not data then
        data = SourceMaps.record(entry.path)
        assert(data.name == name and data.id == entry.id, "source map identity mismatch")
        rawCache[name] = data
    end
    return data
end

function SourceMaps.definition(name)
    return copy(rawDefinition(name))
end

local function padded(name, runtime)
    local entry = SourceMaps.entry(name)
    local original = rawDefinition(name)
    local projection = original
    if runtime then
        projection = {}
        for key, value in pairs(original) do
            if key ~= "source_refs" then
                projection[key] = value
            end
        end
    end
    local data = copy(projection)
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
        local key = ({ viridian = "adapter:viridian-slice:void", pewter = "adapter:pewter:void", source = "adapter:source:void" })[entry.profile]
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
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
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

function SourceMaps.padded(name)
    return padded(name, false)
end

function SourceMaps._runtimePadded(name)
    return padded(name, true)
end

-- Ordinary geometry is projected from the same cache used by ImportedMaps.
function SourceMaps.descriptor(name)
    return copy(assert(compactData().maps[name], "unknown source map"))
end

function SourceMaps.cell(name, x, y)
    local data = compactData()
    local d = assert(data.maps[name], "unknown source map")
    assert(type(x) == "number" and x % 1 == 0 and x >= 0 and x < d.width
        and type(y) == "number" and y % 1 == 0 and y >= 0 and y < d.height, "source cell outside map")
    local id = assert(tonumber(d.tile_rows[y + 1]:sub(x * 2 + 1, x * 2 + 2), 16))
    local cell = copy(assert(data.tiles[d.palette[id]]))
    if d.blocked[tostring(y * d.width + x + 1)] then cell.collision = 1 end
    return cell
end

function SourceMaps.isDoor(name, x, y)
    local d = assert(compactData().maps[name])
    local foot = SourceMaps.cell(name, x, y).terrain.foot_tile
    for _, id in ipairs(compactData().door_tiles[d.tileset.constant] or {}) do
        if id == foot then return true end
    end
    return false
end

local function blocksEvent(entry, id)
    for _, blocked in ipairs(entry.blocked_events or {}) do
        if blocked == id then return true end
    end
    return false
end

local function blockedWarp(entry)
    return { status = "blocked", reason = entry.profile == "viridian"
        and "source event outside implemented parcel handlers" or "original target map outside reviewed Pewter slice" }
end

function SourceMaps.warpSpec(name, event)
    local entry = SourceMaps.entry(name)
    if blocksEvent(entry, event.id) then return blockedWarp(entry) end
    local destination = event.destination
    local target = destination.kind == "last_outdoor_map" and compactData().maps[name].last_outdoor
        or SourceMaps.nameForID("pokered:" .. tostring(destination.map))
    if not target then
        return blockedWarp(entry)
    end
    local d = assert(compactData().maps[target], "LAST_MAP context outside manifest")
    local arrival = assert(d.warps[destination.warp_index], "source target warp index absent")
    -- A closed ingress also closes its return warp. Check the warp tile itself
    -- before the door's one-cell arrival advance, so an available room can be
    -- constructed while its outside entrance remains explicitly unavailable.
    if blocksEvent(SourceMaps.entry(target), arrival.id)
        or d.blocked[tostring(arrival.y * d.width + arrival.x + 1)] then
        return blockedWarp(entry)
    end
    local advance = SourceMaps.isDoor(target, arrival.x, arrival.y) and 1 or 0
    local x, y = arrival.x, arrival.y + advance
    assert(y < d.height and SourceMaps.cell(target, x, y).collision == 0, "original warp arrival is blocked")
    if entry.profile == "viridian" then
        return { status = "bound", to = d.key, toX = x, toY = y,
            facing = advance == 1 and "down" or "up", source_target_map = d.source_map_constant,
            source_target_warp = destination.warp_index, source_target_x = arrival.x, source_target_y = arrival.y,
            arrival_advance = advance, reason = "explicit LAST_MAP resolves only to original Viridian exterior" }
    end
    return { status = "bound", to = d.key, toX = x, toY = y, facing = advance == 1 and "down" or nil,
        preserveFacing = advance == 0, target_name = target, target_warp = destination.warp_index,
        source_target_x = arrival.source_x, source_target_y = arrival.source_y, arrival_advance = advance }
end

local directions = { up = "north", down = "south", left = "west", right = "east" }
function SourceMaps.connection(name, x, y, direction)
    local d = assert(compactData().maps[name], "unknown source map")
    local vertical = direction == "up" or direction == "down"
    local boundary = direction == "up" and y == 0 or direction == "down" and y == d.height - 1
        or direction == "left" and x == 0 or direction == "right" and x == d.width - 1
    if not boundary then return nil end
    for _, connection in ipairs(d.connections) do
        if connection.direction == directions[direction] then
            for _, blocked in ipairs(d.blocked_connections) do
                if blocked == connection.direction .. ":" .. connection.target_map then return nil end
            end
            local target = SourceMaps.nameForID("pokered:" .. connection.target_map)
            if not target then return nil end
            local other = compactData().maps[target]
            local adjustment = connection.entry_lateral_adjustment_cells
            local tx = vertical and x - d.padding + adjustment + other.padding
                or (direction == "left" and other.width - other.padding - 1 or other.padding)
            local ty = vertical and (direction == "up" and other.height - 1 or 0) or y + adjustment
            if tx < other.padding or tx >= other.padding + other.source_width or ty < 0 or ty >= other.height then return nil end
            return { to = other.key, x = tx, y = ty, facing = direction,
                source = d.connection_sources[direction] or "pinned source header connection" }
        end
    end
end

-- Scoped immutable-record adapter for SDK fixtures. Restores both record source
-- and all caches even when a contract fails; never installs campaign locations.
function SourceMaps._withRecords(records, fn)
    local oldManifest, oldCompact, oldGrids, oldRaw, oldOverrides = manifest, compact, tileGrids, rawCache, recordOverrides
    manifest, compact, tileGrids = nil, nil, nil
    rawCache, recordOverrides = setmetatable({}, { __mode = "v" }), records
    local ok, result = pcall(fn)
    manifest, compact, tileGrids, rawCache, recordOverrides = oldManifest, oldCompact, oldGrids, oldRaw, oldOverrides
    if not ok then error(result, 0) end
    return result
end
