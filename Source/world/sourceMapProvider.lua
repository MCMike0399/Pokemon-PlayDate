import "world/sourceMaps"

-- One provider/cache for every manifest map. The caller supplies the existing
-- bespoke binding profiles; this module never owns story/session dispatch.
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

local function tileEntry(grid)
    return { key = grid.stable_id, grid = copy(grid.grid),
        collision = grid.terrain.land_passable and 0 or 1, terrain = copy(grid.terrain) }
end

local function descriptor(name, definition, specs)
    local entry = SourceMaps.entry(name)
    local result = {
        name = name, id = entry.id, key = entry.key, revision = definition.source_revision,
        width = entry.width, height = entry.height, padding = entry.padding,
        source_width = definition.source_dimensions.cells[1], palette = {}, tile_rows = {}, blocked = {},
    }
    for i, grid in ipairs(definition.grids) do result.palette[i] = grid.stable_id end
    assert(#result.palette <= 255, "source map compact palette overflow")
    for y, row in ipairs(definition.tile_ids) do
        local cells = {}
        for x, id in ipairs(row) do cells[x] = string.format("%02x", id) end
        result.tile_rows[y] = table.concat(cells)
    end
    -- Bound slice NPCs own occupancy through NPCManager, even when their script
    -- is blocked. Only unresolved signs and warps add permanent surface blocks.
    for _, kind in ipairs({ "warps", "background_events" }) do
        for _, event in ipairs(definition.events[kind]) do
            local spec = assert(specs[event.id], "missing explicit source surface binding")
            assert(spec.status == "bound" or spec.status == "blocked", "invalid source surface binding")
            if spec.status == "blocked" then
                result.blocked[tostring(event.y * result.width + event.x + 1)] = event.id
            end
        end
    end
    return result
end

function SourceMaps.createProvider(profiles, registry)
    registry = registry or WorldTiles
    assert(type(profiles) == "table", "explicit bespoke source binding profiles required")
    local data = { schema = 1, source_revision = SourceMaps.record("data/sourceMaps.json").source_revision,
        maps = {}, tiles = {} }
    local function profile(name)
        local entry = SourceMaps.entry(name)
        local adapter = assert(profiles[entry.profile], "missing bespoke source binding profile")
        assert(type(adapter.specs) == "function" and type(adapter.options) == "function", "explicit source specs/options required")
        return adapter, entry
    end
    local grids, residentKeys = {}, {}
    for _, name in ipairs(SourceMaps.names()) do
        local adapter, entry = profile(name)
        if entry.resident then residentKeys[entry.key] = true end
        local definition = SourceMaps.padded(name)
        data.maps[name] = descriptor(name, definition, adapter.specs(name, definition))
        for _, grid in ipairs(definition.grids) do
            local entry = tileEntry(grid)
            local previous = grids[entry.key]
            assert(not previous or same(previous, entry), "shared source tile definition differs: " .. entry.key)
            grids[entry.key] = entry
            data.tiles[entry.key] = { key = entry.key, collision = entry.collision, terrain = entry.terrain }
        end
    end
    local function ensureKeys(tiles)
        local entries, seen = {}, {}
        for _, tile in ipairs(tiles) do
            if not registry:has(tile.key) and not seen[tile.key] then
                seen[tile.key] = true
                local found
                for _, name in ipairs(SourceMaps.names()) do
                    for _, grid in ipairs(SourceMaps.padded(name).grids) do
                        if grid.stable_id == tile.key then
                            found = tileEntry(grid)
                            break
                        end
                    end
                    if found then break end
                end
                entries[#entries + 1] = assert(found, "unknown canonical source tile: " .. tile.key)
            end
        end
        if #entries > 0 then registry:registerBatch(entries) end
    end
    return ImportedMaps(data, {
        registry = registry,
        residentKeys = residentKeys,
        ensureKeys = ensureKeys,
        release = function(zone) zone:disposeView() end,
        create = function(name, desired)
            local adapter, entry = profile(name)
            local definition = SourceMaps.padded(name)
            if adapter.prepare then adapter.prepare(name, definition) end
            local options = {}
            for key, value in pairs(adapter.options(name, definition)) do options[key] = value end
            assert(options.registry == nil or options.registry == registry, "source profile registry differs")
            options.registry = registry
            options.spawn = copy(entry.spawn)
            options.sliceBindings = adapter.specs(name, definition)
            -- Retain each reviewed adapter's terrain/source representation.
            if entry.profile == "pewter" then
                options.compactTerrain = true
                definition.source_refs = nil
            end
            local zone = Zone.fromMapDefinition(definition, registry, options)
            if desired.tile_count > 0 then
                ensureKeys(desired.tiles)
                zone:applyDeltas(desired)
            end
            return zone
        end,
    })
end

-- Compatibility composition, with explicit dependencies rather than captured
-- GameContext/session owners. Bespoke script plans stay in their existing files.
function SourceMaps.legacyProfiles(dependencies)
    assert(type(dependencies) == "table" and type(dependencies.dispatch) == "function"
        and type(dependencies.questFlag) == "function" and type(dependencies.sourceFlag) == "function",
        "explicit source dispatch and flag readers required")
    local dispatch, quest, sourceFlag = dependencies.dispatch, dependencies.questFlag, dependencies.sourceFlag
    local function viridianDefinitions()
        local definitions, destinations = {}, {}
        for _, name in ipairs(SourceMaps.names("viridian")) do
            definitions[name] = SourceMaps.padded(name)
            destinations[SourceMaps.entry(name).key] = definitions[name]
        end
        return definitions, destinations
    end
    return {
        viridian = {
            specs = function(name) return KantoSlice.specs(name, viridianDefinitions()) end,
            options = function()
                local _, destinations = viridianDefinitions()
                return { bindingAdapter = MapBindings, destinations = destinations,
                    dispatch = function(id)
                        dispatch(id)
                        return nil
                    end, questFlag = quest }
            end,
            prepare = function() SliceSprites.install() end,
        },
        pewter = {
            specs = PewterSlice.specs,
            options = function()
                return { bindingAdapter = PewterBindings, dispatch = dispatch, questFlag = quest, sourceFlag = sourceFlag }
            end,
            prepare = function(_, definition) PewterSprites.installFor(definition) end,
        },
    }
end
