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

    test("extra decoded maps load ordinary geometry from manifest/cache without regional inventories", function()
        local records = assert(json.decodeFile("dev/sourceMapFixture.json"))
        local before = #SourceMaps.names()
        local sprites, ids, count = playdate.graphics.sprite.spriteCount(), WorldTiles:maxID(), #zoneList
        local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
        local read = SourceMaps.record
        SourceMaps.record = function(path)
            assert(path ~= "data/pewterSlice/descriptors.json" and path ~= "data/pewterSlice/compact.json"
                and path ~= "data/pewterSlice/tile-grids.json" and path ~= "data/pewterSlice/doors.json",
                "ordinary extension read regional metadata")
            return read(path)
        end
        local ok, problem = pcall(function()
            SourceMaps._withRecords(records, function()
                equal(#SourceMaps.names(), 14)
                local profiles = SourceMaps.legacyProfiles({ dispatch = function() error("fixture cannot dispatch") end,
                    questFlag = function() return false end, sourceFlag = function() return false end })
                -- Test content adapter supplies only inert NPC data. Geometry,
                -- connections, warps, encounters and cells use production code.
                profiles.source.prepare = nil
                local base = profiles.source.options
                profiles.source.options = function()
                    local options = base()
                    options.objectDefinition = function(_, event)
                        return {gridX=event.x,gridY=event.y,source_event_id=event.id,sprite="oak",name=event.text_id}
                    end
                    return options
                end
                zoneRegistry, zoneList, currentZone = {}, {}, nil
                local provider = SourceMaps.createProvider(profiles, TileRegistry())
                local loaded, failure = pcall(function()
                    equal(#provider:inventory(), 14)
                    local school = provider:ensure("fixture_ViridianSchoolHouse")
                    local route = provider:ensure("fixture_Route22")
                    equal(school.width, 13)
                    equal(school.stableID, "pokered:VIRIDIAN_SCHOOL_HOUSE")
                    equal(route.stableID, "pokered:ROUTE_22")
                    local definition = SourceMaps.padded("ViridianCity")
                    local warp = SourceMaps.warpSpec("ViridianCity", definition.events.warps[3])
                    equal(warp.to, "fixture_ViridianSchoolHouse")
                    equal(warp.toX, school.spawn.x + records["dev/source-map-extension/ViridianSchoolHouse.json"].events.warps[1].x)
                    local door = assert(school:getEdgeDoorAt(6,7,"down"))
                    equal(door.to, "kanto_viridian_city")
                    equal(door.toX, 21)
                    equal(door.toY, 16)
                    local connection = assert(SourceMaps.connection("Route22",39,8,"right"))
                    equal(connection.to,"kanto_viridian_city")
                    equal(connection.x,0)
                    equal(connection.y,16)
                    WorldDeltas._withDefinitionProvider(provider, function()
                        local context = { sessionLocationPolicy = PewterWorld.locationPolicy(),
                            session = { getIntro = function() return {stage="done"} end } }
                        local door, handled = PewterWorld.connection(context,route,39,8,"right")
                        equal(handled,true)
                        equal(assert(door).to,"kanto_viridian_city")
                        equal(door.toX,0)
                        equal(door.toY,16)
                    end)
                    local inverse = assert(SourceMaps.connection("ViridianCity",0,16,"left"))
                    equal(inverse.to,"fixture_Route22")
                    equal(inverse.x,39)
                    equal(inverse.y,8)
                    local surface = provider:surface(route.stableID,provider:export())
                    for y=0,route.height-1 do
                        for x=0,route.width-1 do
                            equal(route.collision[y+1][x+1],surface.collision[y+1][x+1])
                            equal(route.registry:key(route.tiles[y+1][x+1]),SourceMaps.cell("Route22",x,y).key)
                        end
                    end
                end)
                provider:disposeCache()
                if not loaded then error(failure,0) end
            end)
        end)
        SourceMaps.record = read
        zoneRegistry,zoneList,currentZone = oldRegistry,oldList,oldZone
        equal(#SourceMaps.names(),before)
        equal(playdate.graphics.sprite.spriteCount(),sprites)
        equal(WorldTiles:maxID(),ids)
        equal(#zoneList,count)
        if not ok then error(problem,0) end
    end)

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

    test("compact warp projections match source arrivals without retaining full destination maps", function()
        for _, name in ipairs(SourceMaps.names("viridian")) do
            local definition = SourceMaps.padded(name)
            local projection = SourceMaps.destination(name)
            equal(projection.source_map_constant, definition.source_map_constant)
            same(projection.events.warps, definition.events.warps)
            for _, warp in ipairs(projection.events.warps) do
                for y = warp.y, math.min(warp.y + 1, definition.dimensions.cells[2] - 1) do
                    equal(projection.collision[y + 1][warp.x + 1], definition.collision[y + 1][warp.x + 1])
                end
            end
            equal(projection.grids, nil)
            equal(projection.tile_ids, nil)
            equal(projection.source_refs, nil)
        end
    end)

    test("provider installation and direct tile lookup never load unrelated full map definitions", function()
        scope(function(_, registry, context)
            local definition = SourceMaps.definition
            local loaded = {}
            SourceMaps.definition = function(name)
                loaded[name] = (loaded[name] or 0) + 1
                return definition(name)
            end
            local ok, problem = pcall(function()
                local provider = PewterWorld.createProvider(context, registry)
                equal(next(loaded), nil)
                equal(#provider:inventory(), 12)
                equal(next(loaded), nil)
                local route = provider:ensure("kanto_route1")
                equal(loaded.Route1, 1)
                equal(registry:has("adapter:pewter:void"), false)
                route:setTile(10, 35, "adapter:pewter:void")
                equal(registry:has("adapter:pewter:void"), true)
                equal(loaded.Route1, 1)
                for name in pairs(loaded) do equal(name, "Route1") end
                provider:disposeCache()
            end)
            SourceMaps.definition = definition
            if not ok then error(problem, 0) end
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

    test("isolated facades match every live manifest map without touching live ownership or predicates", function()
        scope(function(provider)
            local before = provider:snapshot()
            local ledger = provider:export()
            local count, ids = #zoneList, WorldTiles:maxID()
            local sprites = playdate.graphics.sprite.spriteCount()
            local npcArt = {}
            for key, value in pairs(SpriteFactory.npc) do npcArt[key] = value end
            local createProvider, sliceInstall, pewterInstall = SourceMaps.createProvider, SliceSprites.install, PewterSprites.installFor
            local ensure, materialize, pin = ImportedMaps.ensure, ImportedMaps._ensure, ImportedMaps.pin
            local registered = {}
            for key, zone in pairs(zoneRegistry) do registered[key] = zone end
            local function forbidden() error("isolated construction invoked live preparation") end
            SourceMaps.createProvider, SliceSprites.install, PewterSprites.installFor = forbidden, forbidden, forbidden
            ImportedMaps.ensure, ImportedMaps._ensure, ImportedMaps.pin = forbidden, forbidden, forbidden
            local ok, problem = pcall(function()
                local registries = {}
                for _, name in ipairs(SourceMaps.names()) do
                    local isolated = PewterWorld.isolated(name)
                    assert(isolated.registry ~= WorldTiles and not registries[isolated.registry], "fresh registry required per isolated map")
                    registries[isolated.registry] = true
                    same(isolated.spawn, SourceMaps.entry(name).spawn)
                    equal(isolated:isSliceReady(), true)
                    -- A second construction with rejecting readers detects any
                    -- eager evaluation of visibility/story predicates.
                    local profiles = SourceMaps.legacyProfiles({ dispatch = forbidden, questFlag = forbidden, sourceFlag = forbidden })
                    SourceMaps.createZone(name, profiles[SourceMaps.entry(name).profile], TileRegistry(), { isolatedCatalog = true })
                    same(provider:snapshot(), before)
                    same(provider:export(), ledger)
                    equal(#zoneList, count)
                    for key, zone in pairs(zoneRegistry) do equal(zone, registered[key]) end
                    for key, zone in pairs(registered) do equal(zoneRegistry[key], zone) end
                    equal(WorldTiles:maxID(), ids)
                    equal(playdate.graphics.sprite.spriteCount(), sprites)
                    for key, value in pairs(SpriteFactory.npc) do equal(value, npcArt[key]) end
                    for key, value in pairs(npcArt) do equal(SpriteFactory.npc[key], value) end
                end
            end)
            SourceMaps.createProvider, SliceSprites.install, PewterSprites.installFor = createProvider, sliceInstall, pewterInstall
            ImportedMaps.ensure, ImportedMaps._ensure, ImportedMaps.pin = ensure, materialize, pin
            if not ok then error(problem, 0) end
            for _, name in ipairs(SourceMaps.names()) do
                local isolated = PewterWorld.isolated(name)
                local live = provider:ensure(SourceMaps.entry(name).key)
                equal(isolated.stableID, live.stableID)
                equal(isolated:exportDeltas().definition_revision, live:exportDeltas().definition_revision)
                equal(isolated.width, live.width)
                equal(isolated.height, live.height)
                same(isolated.doors, live.doors)
                same(isolated.encounters, live.encounters)
                same(isolated:getBindingIssues(), live:getBindingIssues())
                equal(#isolated.npcDefs, #live.npcDefs)
                for i, npc in ipairs(isolated.npcDefs) do
                    for key, value in pairs(npc) do
                        if type(value) ~= "function" then same(value, live.npcDefs[i][key]) end
                    end
                end
                for y = 0, isolated.height - 1 do
                    for x = 0, isolated.width - 1 do
                        equal(isolated.registry:key(isolated.tiles[y + 1][x + 1]), live.registry:key(live.tiles[y + 1][x + 1]))
                        equal(isolated.collision[y + 1][x + 1], live.collision[y + 1][x + 1])
                        same(isolated:terrainAt(x, y), live:terrainAt(x, y))
                        same(isolated:sourceEventsAt(x, y), live:sourceEventsAt(x, y))
                    end
                end
            end
        end)
    end)

    test("all construction facades read manifest defaults and preserve explicit compatibility options", function()
        local entry = SourceMaps.entry
        SourceMaps.entry = function(name)
            local result = entry(name)
            result.spawn = { x = result.spawn.x - 1, y = result.spawn.y - 1, facing = "left" }
            return result
        end
        local ok, problem = pcall(function()
            scope(function(provider)
                for _, name in ipairs(SourceMaps.names()) do
                    local expected = SourceMaps.entry(name).spawn
                    same(provider:ensure(SourceMaps.entry(name).key).spawn, expected)
                    same(PewterWorld.isolated(name).spawn, expected)
                    if SourceMaps.entry(name).profile == "viridian" then
                        local function forbidden() error("compatibility callback evaluated during construction") end
                        local options = { registry = TileRegistry(), dispatch = forbidden, questFlag = forbidden,
                            isolatedCatalog = true, terrainFixture = true }
                        local zone = KantoSlice.create(name, options)
                        same(zone.spawn, expected)
                        equal(zone.terrainFixture, true)
                        equal(zone.registry, options.registry)
                        equal(options.spawn, nil)
                        equal(options.sliceBindings, nil)
                        options.spawn = { x = expected.x, y = expected.y, facing = "right" }
                        local override = KantoSlice.create(name, options)
                        same(override.spawn, options.spawn)
                        override.spawn.x = -1
                        equal(options.spawn.x, expected.x)
                    end
                end
            end)
        end)
        SourceMaps.entry = entry
        if not ok then error(problem, 0) end
    end)

    test("Pewter compact descriptors retain all prior identities palettes rows and blockers", function()
        scope(function(provider)
            for _, original in pairs(assert(json.decodeFile("data/pewterSlice/compact.json")).maps) do
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
