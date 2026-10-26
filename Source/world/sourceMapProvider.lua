import "world/sourceMaps"

-- One provider/cache for every manifest map. The caller supplies the existing
-- bespoke binding profiles; this module never owns story/session dispatch.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

function SourceMaps.createProvider(profiles, registry)
    registry = registry or WorldTiles
    assert(type(profiles) == "table", "explicit bespoke source binding profiles required")
    local data = SourceMaps.compact()
    local function profile(name)
        local entry = SourceMaps.entry(name)
        local adapter = assert(profiles[entry.profile], "missing bespoke source binding profile")
        assert(type(adapter.specs) == "function" and type(adapter.options) == "function", "explicit source specs/options required")
        return adapter, entry
    end
    local residentKeys = {}
    for _, name in ipairs(SourceMaps.names()) do
        local _, entry = profile(name)
        if entry.resident then residentKeys[entry.key] = true end
    end
    local function ensureKeys(tiles)
        local entries, seen = {}, {}
        for _, tile in ipairs(tiles) do
            if not registry:has(tile.key) and not seen[tile.key] then
                seen[tile.key] = true
                entries[#entries + 1] = SourceMaps.tile(tile.key)
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
    local function viridianDefinitions(name, definition)
        local definitions, destinations = {}, {}
        for _, target in ipairs(SourceMaps.names("viridian")) do
            local projection = SourceMaps.destination(target)
            definitions[target] = projection
            destinations[SourceMaps.entry(target).key] = projection
        end
        if name then definitions[name] = definition end
        return definitions, destinations
    end
    return {
        viridian = {
            specs = function(name, definition)
                return KantoSlice.specs(name, viridianDefinitions(name, definition))
            end,
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
