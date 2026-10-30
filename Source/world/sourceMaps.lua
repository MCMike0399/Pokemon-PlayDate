-- Shared source definition importer. Existing slice names are compatibility
-- facades; authored Pallet keeps its own Zone adapter and connection seam.
SourceMaps = {}
local revision <const> = "af519899719f0754965776faac0e836a3b906e6d"
local manifest
local compact, tileGrids
local recordOverrides
local runtimeDefinitions
local validatedCells <const> = setmetatable({}, { __mode = "k" })
local packedRows <const> = setmetatable({}, { __mode = "k" })

-- Empty proxies preserve indexed readers without exposing their string backing.
-- Normal writes fail; raw writes are rejected by the constructor integrity check.
local rowMetatable <const> = {
    __metatable = "immutable source row",
    __index = function(row, index)
        local bytes = packedRows[row]
        if type(index) == "number" and index % 1 == 0 and index >= 1 and index <= #bytes then
            return string.byte(bytes, index)
        end
    end,
    __len = function(row)
        return #packedRows[row]
    end,
    __newindex = function()
        error("immutable source row", 2)
    end,
    __pairs = function(row)
        local bytes = packedRows[row]
        local function advance(_, index)
            index = index + 1
            if index <= #bytes then
                return index, string.byte(bytes, index)
            end
        end
        return advance, nil, 0
    end,
}
local function packedRow(bytes)
    local row = setmetatable({}, rowMetatable)
    packedRows[row] = bytes
    return row
end
local warpResolvers = {}
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
    local data
    if recordOverrides and recordOverrides[path] then
        data = copy(recordOverrides[path])
    elseif ShippedDataPolicy and ShippedDataPolicy.maps() then
        data = ShippedDataPolicy.readBundleJSON(path)
    else
        data = json.decodeFile(path)
    end
    assert(data, "missing pinned source record: " .. path)
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
        if not (ShippedDataPolicy and ShippedDataPolicy.maps() and not recordOverrides) then
            for name, descriptor in pairs(data.maps) do
                local entry = assert(catalogue()[name], "generated map outside source manifest")
                for _, field in ipairs({ "id", "key", "width", "height", "padding", "source_sha256" }) do
                    assert(descriptor[field] == entry[field], "generated source descriptor differs from manifest")
                end
                if GameBootstrap then
                    GameBootstrap.yieldIfDue()
                end
            end
            for name in pairs(catalogue()) do
                assert(data.maps[name], "generated source descriptor missing")
            end
        end
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

function SourceMaps._isQualifiedCompact(data)
    return SourceMaps._isSharedCompact(data) and not recordOverrides
        and ShippedDataPolicy and ShippedDataPolicy.maps()
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

-- The generated byte planes are optional only for dimensions/palettes outside
-- version 1's bounds. Invalid or missing in-range artifacts fail closed.
local function binaryCells(name, entry, record)
    local definition <const> = record.definition
    local width, height = table.unpack(definition.dimensions.cells)
    local palette <const> = #definition.grids
    if width > 128 or height > 65535 or palette > 255 then
        return false
    end
    assert(width >= 1 and width % 1 == 0 and height >= 1 and height % 1 == 0
        and palette >= 1, "invalid binary cell dimensions")
    local headerSize <const> = 138
    local expectedSize <const> = headerSize + width * height * 2
    local path <const> = "data/sourceMapCells/" .. name .. ".bin"
    local sourceFile
    if ShippedDataPolicy and ShippedDataPolicy.maps() then
        sourceFile = ShippedDataPolicy.openBundle(path)
    else
        sourceFile = playdate.file.open(path, playdate.file.kFileRead)
    end
    local file <const> = assert(sourceFile, "missing binary cells: " .. name)
    local wire, count = file:read(expectedSize + 1)
    file:close()
    assert(type(wire) == "string" and #wire == expectedSize and count == expectedSize,
        "binary cell byte count differs")
    assert(wire:sub(1, 4) == "SMC1", "unsupported binary cell version")
    local w0, w1, h0, h1, p0, p1 = string.byte(wire, 5, 10)
    assert(w0 + w1 * 256 == width and h0 + h1 * 256 == height
        and p0 + p1 * 256 == palette, "binary cell dimensions differ")
    assert(wire:sub(11, 74) == record.manifest_sha256
        and wire:sub(75, 138) == entry.source_sha256, "binary cell pins differ")
    local collisionPalette <const> = {}
    for byte = 0, 255 do
        collisionPalette[string.char(byte)] = "\2"
    end
    for id, tile in ipairs(definition.grids) do
        assert(tile.id == id and type(tile.terrain) == "table"
            and type(tile.terrain.land_passable) == "boolean", "invalid binary cell palette")
        collisionPalette[string.char(id)] = tile.terrain.land_passable and "\0" or "\1"
    end
    definition.tile_ids = {}
    definition.collision = {}
    for y = 1, height do
        local start <const> = headerSize + (y - 1) * width + 1
        local tiles <const> = wire:sub(start, start + width - 1)
        local collisionStart <const> = start + width * height
        local collision <const> = wire:sub(collisionStart, collisionStart + width - 1)
        -- Every unknown ID maps to an impossible collision byte. Both planes
        -- are checked in native string operations before their backing is kept.
        local expected <const> = tiles:gsub(".", collisionPalette)
        assert(not expected:find("\2", 1, true), "unknown binary cell tile ID")
        assert(not collision:find("[^\0\1]") and expected == collision,
            "binary cell collision differs from terrain")
        definition.tile_ids[y] = packedRow(tiles)
        definition.collision[y] = packedRow(collision)
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return true
end

local function runtimeDefinition(name, entry)
    if recordOverrides then
        return rawDefinition(name)
    end
    local record = SourceMaps.record("data/sourceMapCache/runtime-" .. name .. ".json")
    assert(record.manifest_sha256 == compactData().manifest_sha256
        and record.source_sha256 == entry.source_sha256, "runtime map cache differs from manifest")
    local definition = record.definition
    assert(definition.name == name and definition.id == entry.id, "runtime map identity mismatch")
    local width, height = table.unpack(definition.dimensions.cells)
    if binaryCells(name, entry, record) then
        validatedCells[definition] = true
        return definition
    end
    assert(#record.tile_rows == height, "runtime map row count differs")
    definition.tile_ids = {}
    definition.collision = {}
    for y, row in ipairs(record.tile_rows) do
        assert(#row == width * 2, "runtime map row width differs")
        local tiles, collision = {}, {}
        for x = 1, width do
            local id = assert(tonumber(row:sub(x * 2 - 1, x * 2), 16), "invalid runtime tile ID")
            local tile = assert(definition.grids[id], "unknown runtime tile ID")
            tiles[x] = id
            collision[x] = tile.terrain.land_passable and 0 or 1
        end
        definition.tile_ids[y] = tiles
        definition.collision[y] = collision
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return definition
end

local function padded(name, runtime)
    local entry = SourceMaps.entry(name)
    local original = runtime and runtimeDefinition(name, entry) or rawDefinition(name)
    local projection = original
    if runtime then
        projection = {}
        for key, value in pairs(original) do
            if key ~= "source_refs" then
                projection[key] = value
            end
        end
    end
    local data = runtime and not recordOverrides and projection or copy(projection)
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
        -- Padding can exceed the byte palette or native multi-return bounds.
        -- Those cases keep the ordinary dense constructor and all its checks.
        if id > 255 or entry.width > 128 then
            validatedCells[original] = nil
        end
        for y = 1, height do
            local sourceTiles, sourceCollision = data.tile_ids[y], data.collision[y]
            if validatedCells[original] then
                local left <const> = string.rep(string.char(id), entry.padding)
                local right <const> = string.rep(string.char(id), entry.width - width - entry.padding)
                data.tile_ids[y] = packedRow(left .. packedRows[sourceTiles] .. right)
                data.collision[y] = packedRow(string.rep("\1", entry.padding)
                    .. packedRows[sourceCollision] .. string.rep("\1", entry.width - width - entry.padding))
            else
                local tiles, collision = {}, {}
                for x = 1, entry.width do tiles[x], collision[x] = id, 1 end
                for x = 1, width do
                    tiles[x + entry.padding] = sourceTiles[x]
                    collision[x + entry.padding] = sourceCollision[x]
                end
                data.tile_ids[y], data.collision[y] = tiles, collision
            end
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
    if runtime and not recordOverrides and validatedCells[original] then
        local tileRows, collisionRows = {}, {}
        for y = 1, height do
            tileRows[y], collisionRows[y] = data.tile_ids[y], data.collision[y]
        end
        validatedCells[data] = {
            tiles = data.tile_ids,
            collision = data.collision,
            width = entry.width,
            height = height,
            tileRows = tileRows,
            collisionRows = collisionRows,
        }
    end
    return data
end

-- A private identity is only an eligibility hint. Check the raw planes, every
-- row identity and every extra raw key again after all callbacks and yields.
local function checkPackedCells(definition, identity)
    local dimensions = rawget(definition, "dimensions")
    local size = type(dimensions) == "table" and rawget(dimensions, "cells")
    assert(not recordOverrides and getmetatable(definition) == nil
        and getmetatable(dimensions) == nil and type(size) == "table" and getmetatable(size) == nil
        and size[1] == identity.width and size[2] == identity.height,
        "packed source dimensions changed")
    local sizeCount = 0
    for key in next, size do
        assert(key == 1 or key == 2, "packed source dimensions have invalid index")
        sizeCount = sizeCount + 1
    end
    assert(sizeCount == 2, "packed source dimensions have holes")
    local function plane(current, expected, label)
        assert(rawequal(current, expected) and getmetatable(current) == nil, label .. " replaced")
        local count = 0
        for key in next, current do
            assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= identity.height,
                label .. " has invalid index")
            count = count + 1
        end
        assert(count == identity.height, label .. " has holes")
    end
    plane(rawget(definition, "tile_ids"), identity.tiles, "packed tile plane")
    plane(rawget(definition, "collision"), identity.collision, "packed collision plane")
    for y = 1, identity.height do
        local tiles, collision = rawget(identity.tiles, y), rawget(identity.collision, y)
        assert(rawequal(tiles, identity.tileRows[y]) and rawequal(collision, identity.collisionRows[y])
            and next(tiles) == nil and next(collision) == nil
            and #packedRows[tiles] == identity.width and #packedRows[collision] == identity.width,
            "packed source row changed")
    end
end

function SourceMaps._packedCells(definition)
    local identity = validatedCells[definition]
    if recordOverrides or type(identity) ~= "table" then
        return nil
    end
    checkPackedCells(definition, identity)
    return function(y)
        return packedRows[identity.tileRows[y]], packedRows[identity.collisionRows[y]]
    end, function() checkPackedCells(definition, identity) end
end

-- Viridian's historical full-definition snapshot still goes through the strict
-- primitive copier. Materialize only the private rows before that boundary.
function SourceMaps._plainRuntimeCells(definition)
    local row, verify = SourceMaps._packedCells(definition)
    if not row then
        return definition
    end
    local result = {}
    for key, value in pairs(definition) do
        result[key] = value
    end
    result.tile_ids, result.collision = {}, {}
    for y = 1, definition.dimensions.cells[2] do
        local tiles, collision = row(y)
        result.tile_ids[y] = { string.byte(tiles, 1, #tiles) }
        result.collision[y] = { string.byte(collision, 1, #collision) }
    end
    verify()
    return result
end

function SourceMaps.padded(name)
    return padded(name, false)
end

function SourceMaps._runtimePadded(name)
    if runtimeDefinitions and runtimeDefinitions[name] then
        return runtimeDefinitions[name]
    end
    local definition = padded(name, true)
    if runtimeDefinitions then
        runtimeDefinitions[name] = definition
    end
    return definition
end

-- A load may validate actors several times before publishing a world change.
-- Keep its private immutable definition only until that load finishes.
function SourceMaps._withRuntimeDefinitions(callback)
    if runtimeDefinitions then
        return callback()
    end
    runtimeDefinitions = {}
    local results = table.pack(pcall(callback))
    runtimeDefinitions = nil
    if not results[1] then
        error(results[2], 0)
    end
    return table.unpack(results, 2, results.n)
end

-- Private values shared by validators during one load, then released together.
function SourceMaps._runtimeValue(key, create)
    if not runtimeDefinitions then
        return create()
    end
    local value = runtimeDefinitions[key]
    if value == nil then
        value = create()
        runtimeDefinitions[key] = value
    end
    return value
end

-- Ordinary geometry is projected from the same cache used by ImportedMaps.
-- A Boolean policy query avoids copying tile rows and event records merely
-- to inspect the immutable connection-blocker list.
function SourceMaps.connectionBlocked(name, direction, target)
    local descriptor = assert(compactData().maps[name], "unknown source map")
    local id = direction .. ":" .. target
    for _, blocked in ipairs(descriptor.blocked_connections) do
        if blocked == id then
            return true
        end
    end
    return false
end

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

function SourceMaps.registerScriptedWarp(id, resolver)
    assert(type(id) == "string" and type(resolver) == "function" and not warpResolvers[id],
        "unique scripted source warp required")
    warpResolvers[id] = resolver
end

function SourceMaps.resolveScriptedWarp(game, door)
    assert(currentZone and door.source_event_id:match("^(pokered:[^:]+):warps:") == currentZone.stableID,
        "scripted warp belongs to another map")
    local resolver = assert(warpResolvers[door.source_event_id], "source warp handler missing")
    local resolved, reason = resolver(game.session, door.source_event_id)
    if not resolved then
        return nil, reason or "source warp context missing"
    end
    local result = copy(resolved)
    local name = assert(SourceMaps.nameForID(result.to), "scripted destination outside source manifest")
    local entry = SourceMaps.entry(name)
    local position = {zone_id = entry.id, x = result.toX, y = result.toY,
        facing = result.preserveFacing and game.player.facing or result.facing or "down"}
    WorldDeltas.resolvePlayerLocation(position, WorldDeltas.export(), game.sessionLocationPolicy)
    result.to = entry.key
    result.source_event_id = door.source_event_id
    return result
end

function SourceMaps.warpSpec(name, event)
    local entry = SourceMaps.entry(name)
    for _, id in ipairs(entry.scripted_warps or {}) do
        if id == event.id then
            return {status = "scripted", source_event_id = id}
        end
    end
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
    -- PlayerStepOutFromDoor queues one DOWN input. The input index is
    -- decremented from 1 to 0 before CollisionCheckOnLand, so solid terrain
    -- blocks that step (home/overworld.asm:1224-1226,1844-1856).
    local door = SourceMaps.isDoor(target, arrival.x, arrival.y)
    local advance = door and arrival.y + 1 < d.height
        and SourceMaps.cell(target, arrival.x, arrival.y + 1).collision == 0 and 1 or 0
    local x, y = arrival.x, arrival.y + advance
    assert(y < d.height and not d.blocked[tostring(y * d.width + x + 1)]
        and SourceMaps.cell(target, x, y).collision == 0,
        "original warp arrival is blocked")
    if entry.profile == "viridian" then
        return { status = "bound", to = d.key, toX = x, toY = y,
            facing = door and "down" or "up", source_target_map = d.source_map_constant,
            source_target_warp = destination.warp_index, source_target_x = arrival.x, source_target_y = arrival.y,
            arrival_advance = advance, reason = "explicit LAST_MAP resolves only to original Viridian exterior" }
    end
    return { status = "bound", to = d.key, toX = x, toY = y, facing = door and "down" or nil,
        preserveFacing = not door, target_name = target, target_warp = destination.warp_index,
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
    local oldRuntime = runtimeDefinitions
    runtimeDefinitions = runtimeDefinitions and {} or nil
    manifest, compact, tileGrids = nil, nil, nil
    rawCache, recordOverrides = setmetatable({}, { __mode = "v" }), records
    local ok, result = pcall(fn)
    manifest, compact, tileGrids, rawCache, recordOverrides = oldManifest, oldCompact, oldGrids, oldRaw, oldOverrides
    runtimeDefinitions = oldRuntime
    if not ok then error(result, 0) end
    return result
end
