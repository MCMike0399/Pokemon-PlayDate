import "world/sourceBindings"

-- One provider/cache for every manifest map. The caller supplies the existing
-- bespoke binding profiles; this module never owns story/session dispatch.
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end

local function ensureKeys(registry, tiles)
    local needed, seen = {}, {}
    for _, tile in ipairs(tiles) do
        if not registry:has(tile.key) and not seen[tile.key] then
            seen[tile.key] = true
            needed[#needed + 1] = tile.key
        end
    end
    if #needed == 0 then
        return
    end
    SourceMaps.withTiles(function(tileData)
        local entries = {}
        for _, key in ipairs(needed) do
            entries[#entries + 1] = tileData(key)
            if GameBootstrap then
                GameBootstrap.yieldIfDue()
            end
        end
        registry:registerBatch(entries)
    end)
end

-- Shared construction only: no provider registration, cache ownership or pinning.
-- Profiles supply bespoke bindings; the manifest supplies identity and defaults.
function SourceMaps.createZone(name, adapter, registry, overrides, desired)
    local entry = SourceMaps.entry(name)
    if BootTrace then
        BootTrace.mark("map." .. name .. ".definition.begin")
    end
    local definition = SourceMaps._runtimePadded(name)
    if BootTrace then
        BootTrace.mark("map." .. name .. ".definition.end")
    end
    local options = {}
    for key, value in pairs(adapter.options(name, definition)) do options[key] = value end
    for key, value in pairs(overrides or {}) do options[key] = value end
    registry = registry or options.registry or WorldTiles
    assert(options.registry == nil or options.registry == registry, "source profile registry differs")
    options.registry = registry
    options.spawn = copy(options.spawn or entry.spawn)
    options.hasEvent = options.hasEvent or function() return false end
    if BootTrace then
        BootTrace.mark("map." .. name .. ".art.begin")
    end
    if not options.isolatedCatalog and adapter.prepare then adapter.prepare(name, definition) end
    if BootTrace then
        BootTrace.mark("map." .. name .. ".art.end")
    end
    options.sliceBindings = SourceBindings.specs(name, definition, options.hasEvent)
    options.bindingAdapter = SourceBindings
    -- Terrain is immutable per tile key. Public accessors still return copies;
    -- cells keep private shared records instead of duplicating every flag.
    options.compactTerrain = true
    definition.source_refs = nil
    if BootTrace then
        BootTrace.mark("map." .. name .. ".zone.begin")
    end
    local zone = Zone.fromMapDefinition(definition, registry, options)
    if BootTrace then
        BootTrace.mark("map." .. name .. ".zone.end")
    end
    if desired and desired.tile_count > 0 then
        ensureKeys(registry, desired.tiles)
        zone:applyDeltas(desired)
    end
    return zone
end

function SourceMaps.isolated(name)
    local function forbidden() error("catalog source events cannot execute") end
    -- Catalog exporters may inspect visibility later; retain the historical
    -- all-false flag projection without reading live story/session predicates.
    local function absent() return false end
    local profiles = SourceMaps.legacyProfiles({ dispatch = forbidden, questFlag = absent, sourceFlag = absent })
    return SourceMaps.createZone(name, profiles[SourceMaps.entry(name).profile], TileRegistry(), { isolatedCatalog = true })
end

function SourceMaps.createProvider(profiles, registry)
    registry = registry or WorldTiles
    assert(type(profiles) == "table", "explicit bespoke source binding profiles required")
    local data = SourceMaps._sharedCompact()
    local function profile(name)
        local entry = SourceMaps.entry(name)
        local adapter = assert(profiles[entry.profile], "missing bespoke source binding profile")
        assert(type(adapter.options) == "function", "explicit source content options required")
        return adapter, entry
    end
    for _, name in ipairs(SourceMaps.names()) do
        profile(name)
        if GameBootstrap then
            GameBootstrap.yieldIfDue()
        end
    end
    return ImportedMaps(data, {
        registry = registry,
        ensureKeys = function(tiles) ensureKeys(registry, tiles) end,
        release = function(zone) zone:disposeView() end,
        create = function(name, desired)
            local adapter = profile(name)
            return SourceMaps.createZone(name, adapter, registry, { spawn = SourceMaps.entry(name).spawn }, desired)
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
    return {
        source = {
            -- Reuse immutable NPC/trainer/art resolvers, never their geometry.
            -- Unknown source art fails explicitly until its resolver is added.
            options = function()
                return SourceBindings.options("source", { dispatch = dispatch, questFlag = quest, sourceFlag = sourceFlag })
            end,
            prepare = SourceActors.installArt,
        },
        viridian = {
            options = function()
                return SourceBindings.options("viridian", {
                    dispatch = function(id)
                        dispatch(id)
                        return nil
                    end, questFlag = quest })
            end,
            prepare = function(_, definition)
                local sources = {}
                for _, event in ipairs(definition.events.objects) do
                    sources[#sources + 1] = event.sprite
                end
                SliceSprites.install(sources)
            end,
        },
        pewter = {
            options = function()
                return SourceBindings.options("pewter", { dispatch = dispatch, questFlag = quest, sourceFlag = sourceFlag })
            end,
            prepare = function(_, definition) PewterSprites.installFor(definition) end,
        },
    }
end
