-- Root-run SDK contracts. No host Lua execution or replacement SDK globals.
SourceMapContracts = {}

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function same(a, b)
    equal(type(a), type(b))
    if type(a) ~= "table" then
        equal(a, b)
        return
    end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "unexpected field") end
end

local function rejects(fn)
    assert(not pcall(fn), "expected rejection")
end

local function scope(fn)
    local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
    local oldStory = Story.currentContext()
    local oldOwner, oldRng = GameSession.activeRNGSession(), RulesRNG.toData()
    local ids = WorldTiles:maxID()
    local sprites = playdate.graphics.sprite.spriteCount()
    local context = GameContext({ sessionLocationPolicy = PewterWorld.locationPolicy() })
    assert(context.session:setIntro({ stage = "done", starter = "squirtle", rivalStarter = "bulbasaur" }))
    local registry = TileRegistry()
    local provider = PewterWorld.createProvider(context, registry)
    zoneRegistry, zoneList, currentZone = {}, {}, nil
    local ok, problem = pcall(function()
        WorldDeltas._withDefinitionProvider(provider, function() fn(provider, registry, context) end)
    end)
    context.npcManager:clear()
    provider:disposeCache()
    zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
    if GameSession.activeRNGSession() == context.session then context.session:deactivateRNG() end
    if oldOwner then oldOwner:activateRNG() else RulesRNG.restoreData(oldRng) end
    Story.bind(oldStory)
    equal(WorldTiles:maxID(), ids)
    equal(playdate.graphics.sprite.spriteCount(), sprites)
    if not ok then error(problem, 0) end
end

function SourceMapContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end

    test("both live installation facades share all twelve definitions and resident Viridian Zones", function()
        local provider = WorldDeltas.definitionProvider()
        equal(PewterWorld.install(game), provider)
        local count = #zoneList
        local zones = KantoWorld.install(game)
        equal(#zoneList, count)
        equal(#provider:inventory(), 12)
        equal(provider:snapshot().capacity, 6)
        for _, name in ipairs(SourceMaps.names("viridian")) do
            local entry = SourceMaps.entry(name)
            equal(zones[entry.key], zoneRegistry[entry.key])
            assert(provider:owns(zones[entry.key]), "legacy eager map bypassed shared provider")
        end
    end)

    test("manifest loading is defensive and preserves source coordinate conventions", function()
        for _, name in ipairs(SourceMaps.names()) do
            local entry = SourceMaps.entry(name)
            local raw, padded = SourceMaps.definition(name), SourceMaps.padded(name)
            equal(padded.id, entry.id)
            equal(padded.dimensions.cells[1], entry.width)
            equal(padded.dimensions.cells[2], entry.height)
            same(padded.connections, raw.connections)
            same(padded.encounters, raw.encounters)
            same(padded.directional_rules, raw.directional_rules)
            same(padded.script, raw.script)
            for kind, events in pairs(raw.events) do
                for i, event in ipairs(events) do
                    local actual = padded.events[kind][i]
                    equal(actual.id, event.id)
                    equal(actual.x, event.x + entry.padding)
                    equal(actual.y, event.y)
                    if entry.padding > 0 or entry.profile == "pewter" then
                        equal(actual.source_x, event.x)
                        equal(actual.source_y, event.y)
                    else
                        equal(actual.source_x, nil)
                        equal(actual.source_y, nil)
                    end
                end
            end
            raw.grids[1].grid[1] = "changed"
            entry.spawn.x = -1
            assert(SourceMaps.definition(name).grids[1].grid[1] ~= "changed")
            assert(SourceMaps.entry(name).spawn.x >= 0)
        end
        rejects(function() SourceMaps.definition("Route3") end)
    end)

    test("compatibility dispatch return values remain distinct without replacing event owners", function()
        local received
        local profiles = SourceMaps.legacyProfiles({
            dispatch = function(id)
                received = id
                return true
            end,
            questFlag = function() return false end,
            sourceFlag = function() return false end,
        })
        equal(profiles.viridian.options().dispatch("viridian"), nil)
        equal(received, "viridian")
        equal(profiles.pewter.options().dispatch("pewter"), true)
        equal(received, "pewter")
    end)

    test("unloaded validation allocates no native tiles or Zones for either region", function()
        scope(function(provider, registry, context)
            local ids = registry:maxID()
            equal(#provider:inventory(), 12)
            for _, name in ipairs(SourceMaps.names()) do
                local entry = SourceMaps.entry(name)
                local location = { zone_id = entry.id, x = entry.spawn.x, y = entry.spawn.y, facing = "up" }
                same(provider:resolveLocation(location, provider:export(), context.sessionLocationPolicy), location)
            end
            equal(#provider:snapshot().cached, 0)
            equal(#zoneList, 0)
            equal(registry:maxID(), ids)
        end)
    end)

    test("every production Zone matches immutable cell keys native grids collision and foot surfaces", function()
        scope(function(provider, registry)
            for _, name in ipairs(SourceMaps.names()) do
                local entry = SourceMaps.entry(name)
                local definition = SourceMaps.padded(name)
                local surface = provider:surface(entry.id, provider:export())
                local zone = provider:ensure(entry.key)
                equal(zone.stableID, entry.id)
                same(zone.spawn, entry.spawn)
                equal(zone:isSliceReady(), true)
                for y = 0, entry.height - 1 do
                    for x = 0, entry.width - 1 do
                        local grid = definition.grids[definition.tile_ids[y + 1][x + 1]]
                        local actual = registry:entry(zone.tiles[y + 1][x + 1])
                        equal(actual.key, grid.stable_id)
                        same(actual.grid, grid.grid)
                        equal(zone.collision[y + 1][x + 1], surface.collision[y + 1][x + 1])
                        equal(zone:terrainAt(x, y).foot_tile, surface.feet[y + 1][x + 1])
                    end
                end
            end
            equal(#provider:snapshot().cached, 6)
        end)
    end)

    test("Pewter compact descriptors retain all prior identities palettes rows and blockers", function()
        scope(function(provider)
            for _, original in pairs(PewterSlice.compact().maps) do
                local descriptor = provider:descriptor(original.id)
                for _, field in ipairs({ "id", "key", "revision", "width", "height", "padding", "source_width", "palette", "tile_rows", "blocked" }) do
                    same(descriptor[field], original[field])
                end
            end
        end)
    end)

    test("one ledger owns resident Viridian changes and evicted Pewter changes across reset and reload", function()
        scope(function(provider, registry)
            local route1 = provider:ensure("kanto_route1")
            local route2 = provider:ensure("kanto_route2")
            route1:setTile(10, 35, "base:2")
            route2:setTile(8, 70, "base:2")
            local saved = WorldDeltas.export()
            equal(saved.zone_count, 2)
            provider:ensure("kanto_pewter_gym")
            provider:ensure("kanto_pewter_mart")
            equal(provider:owns(route2), false)
            rejects(function() route2:setTile(8, 70, "base:2") end)
            equal(provider:owns(route1), true)
            route2 = provider:ensure("kanto_route2")
            equal(registry:key(route2.tiles[71][9]), "base:2")
            local undo = WorldDeltas.apply({ schema = 1, zone_count = 0, zones = {} })
            equal(provider:export().zone_count, 0)
            undo()
            same(WorldDeltas.export(), saved)
            provider:disposeCache()
            equal(zoneRegistry.kanto_route1, route1)
            equal(zoneRegistry.kanto_route2, nil)
            route2 = provider:ensure("kanto_route2")
            equal(registry:key(route2.tiles[71][9]), "base:2")
        end)
    end)

    test("legacy Viridian sparse save records install through the unified provider", function()
        scope(function(provider)
            local zone = KantoSlice.create("Route1", {
                registry = TileRegistry(), dispatch = function() end, questFlag = function() return false end,
            })
            zone:setTile(10, 35, "base:2")
            local record = zone:exportDeltas()
            local world = { schema = 1, zone_count = 1, zones = { record } }
            same(provider:validate(world), world)
            provider:apply(world)
            local loaded = provider:ensure("kanto_route1")
            equal(loaded.registry:key(loaded.tiles[36][11]), "base:2")
        end)
    end)

    test("failed native view mutation preserves shared ledger tile keys and registry", function()
        scope(function(provider, registry)
            local zone = provider:ensure("kanto_route1")
            local key = registry:key(zone.tiles[36][11])
            local before = registry:maxID()
            local view = WorldView(zone, { attach = false })
            zone:attachView(view)
            local apply = view.applyTiles
            view.applyTiles = function() error("controlled source map view rejection") end
            local ok = pcall(zone.setTile, zone, 10, 35, "adapter:pewter:void")
            view.applyTiles = apply
            zone:detachView(view)
            view:dispose()
            equal(ok, false)
            equal(registry:key(zone.tiles[36][11]), key)
            equal(provider:export().zone_count, 0)
            equal(registry:maxID(), before)
        end)
    end)
    return report
end
