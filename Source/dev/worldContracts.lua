-- Actual SDK/production module contracts; no replacement Playdate environment.
WorldContracts = {}
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function rejects(fn)
    local ok = pcall(fn)
    assert(not ok, "expected rejection")
end
local function grid(code)
    local rows = {}
    for i = 1, 16 do rows[i] = string.rep(code, 16) end
    return rows
end
local function entry(key, code, collision)
    return { key = key, grid = grid(code), collision = collision,
        terrain = { land_passable = collision == 0, grass = false, counter = false, warp_tile = false, water_candidate = false } }
end
local function sameImage(a, b)
    local aw, ah = a:getSize()
    local bw, bh = b:getSize()
    equal(aw, bw); equal(ah, bh)
    for y = 0, ah - 1 do for x = 0, aw - 1 do equal(a:sample(x, y), b:sample(x, y), "pixel " .. x .. "," .. y) end end
end
local function withView(zone, fn)
    local view = WorldView(zone, { attach = false })
    local ok, problem = pcall(fn, view)
    view:dispose()
    if not ok then error(problem, 0) end
end

function WorldContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end
    test("registry reserves base IDs and rejects conflicting keys atomically", function()
        local registry = TileRegistry()
        equal(registry:maxID(), 37); equal(registry:id("base:37"), 37)
        local values = registry:registerBatch({ entry("test:a", "1", 0), entry("test:b", "#", 1) })
        equal(values[1], 38); equal(values[2], 39)
        equal(registry:registerBatch({ entry("test:a", "1", 0) })[1], 38)
        rejects(function() registry:registerBatch({ entry("test:c", ".", 0), entry("test:a", "2", 0) }) end)
        equal(registry:maxID(), 39); equal(registry:has("test:c"), false)
        local bad = entry("test:a", "1", 0); bad.terrain.grass = true
        rejects(function() registry:registerBatch({ bad }) end)
        rejects(function() registry:id(999) end)
        rejects(function() registry:registerBatch({ entry("base:1", ".", 0) }) end)
    end)
    test("registry returned definitions cannot mutate stored pixels or terrain", function()
        local registry = TileRegistry()
        registry:registerBatch({ entry("test:immutable", "1", 0) })
        local value = registry:entry("test:immutable")
        value.grid[1] = string.rep("#", 16); value.terrain.grass = true
        equal(registry:entry("test:immutable").grid[1], string.rep("1", 16))
        equal(registry:entry("test:immutable").terrain.grass, false)
        local bad = entry("test:cycle", ".", 0); bad.terrain.loop = bad.terrain
        rejects(function() registry:registerBatch({ bad }) end)
    end)
    test("all 37 authored images retain exact SDK pixels with imported palette", function()
        local registry = TileRegistry()
        registry:registerBatch({ entry("test:extra", "2", 0) })
        local before, after = TileFactory.generateAll(), TileFactory.generateAll(registry)
        for id = 1, 37 do sameImage(before:getImage(id), after:getImage(id)) end
        sameImage(after:getImage(38), TileFactory.renderGrid(grid("2"), nil, { 0, 0 }))
    end)
    test("explicit imported phase uniform and mixed runs match independent byte vectors", function()
        local gfx = playdate.graphics
        local light = { 0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF }
        local dark = { 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA }
        for _, rows in ipairs({ grid("1"), grid("2"), {
            "1.22###111..22##", "11112222....####", "#12.#12.#12.#12.", "..111.22##11.2.#",
            "21111##22..12.#.", ".1.2.#.1.2.#.1.2", "##222111...#12..", "1.22###111..22##",
            "11112222....####", "#12.#12.#12.#12.", "..111.22##11.2.#", "21111##22..12.#.",
            ".1.2.#.1.2.#.1.2", "##222111...#12..", "1.22###111..22##", "11112222....####",
        } }) do
            local image = TileFactory.renderGrid(rows, nil, { 0, 0 })
            for y = 0, 31 do for x = 0, 31 do
                local code = rows[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1)
                local white = code == "."
                if code == "1" or code == "2" then
                    local bytes = code == "1" and light or dark
                    white = (bytes[y % 8 + 1] & (0x80 >> (x % 8))) ~= 0
                end
                equal(image:sample(x, y), white and gfx.kColorWhite or gfx.kColorBlack, "explicit shade pixel")
            end end
        end
    end)
    test("SDK explicit phase asymmetric bit order and row phase are independent of rectangle splits", function()
        local gfx = playdate.graphics
        local pattern = { 0x7f, 0xbf, 0xdf, 0xef, 0xf7, 0xfb, 0xfd, 0xfe }
        for _, split in ipairs({ false, true }) do
            local image = gfx.image.new(32, 32, gfx.kColorWhite)
            gfx.pushContext(image)
            if split then
                for y = 0, 15 do for x = 0, 7 do gfx.setPattern(pattern, 0, 0); gfx.fillRect(x * 4, y * 2, 4, 2) end end
            else gfx.setPattern(pattern, 0, 0); gfx.fillRect(0, 0, 32, 32) end
            Shade.reset(); gfx.popContext()
            for y = 0, 31 do for x = 0, 31 do
                equal(image:sample(x, y), x % 8 == y % 8 and gfx.kColorBlack or gfx.kColorWhite, "asymmetric SDK pixel")
            end end
        end
    end)
    test("imported dimensions IDs collisions and event bounds reject before registry mutation", function()
        for _, mutate in ipairs({
            function(value) value.tile_ids[1][1] = 999 end,
            function(value) table.remove(value.tile_ids[1]) end,
            function(value) value.collision[1][1] = 9 end,
            function(value) value.collision[1][1] = 1 - value.collision[1][1] end,
            function(value) value.events.objects[1].x = 99 end,
            function(value) value.grids[2].stable_id = value.grids[1].stable_id end,
        }) do
            local registry, value = TileRegistry(), PilotWorld.definition("Route1")
            mutate(value)
            rejects(function() Zone.fromMapDefinition(value, registry, { terrainFixture = true }) end)
            equal(registry:maxID(), 37)
        end
        rejects(function() Zone({ name = "bad", tiles = {{999}}, width = 1, height = 1 }) end)
    end)
    test("imported numeric IDs bypass legacy roof grass transforms and expose terrain", function()
        local definition, registry = PilotWorld.definition("Route1"), TileRegistry()
        local zone = Zone.fromMapDefinition(definition, registry, { terrainFixture = true })
        for y = 1, zone.height do
            for x = 1, zone.width do
                assert(zone.tiles[y][x] >= 38)
                equal(registry:key(zone.tiles[y][x]), definition.grids[definition.tile_ids[y][x]].stable_id)
            end
        end
        equal(zone:isTallGrass(10, 35), true); equal(zone:isTallGrass(-1, 35), false)
        local terrain = zone:terrainAt(10, 35); terrain.grass = false
        equal(zone:isTallGrass(10, 35), true)
    end)
    test("unbound pilot actors warps and scripts are explicit blockers", function()
        local blocked = PilotWorld.create("ViridianMart", { registry = TileRegistry() })
        equal(blocked:isCampaignReady(), false)
        rejects(function() blocked:assertEnterable() end)
        local zone = PilotWorld.create("ViridianMart", { registry = TileRegistry(), terrainFixture = true })
        equal(zone.collision[8][4], 1)
        assert(zone:bindingAt(3, 7).kind == "warps")
        rejects(function() zone:getDoorAt(3, 7) end)
        local manager = NPCManager()
        zone:spawnNPCs(manager)
        local npc = assert(manager:getNPCAt(0, 5))
        assert(npc.source_id and npc.name:find("unresolved"))
        rejects(function() npc:faceTowards(1, 5) end)
        manager:clear()
        rejects(function() zone:rollEncounter() end)
    end)
    test("setTile updates actual SDK tilemap walls terrain and reset together", function()
        local zone = Zone({ id = "contract:mutation", name = "mutation", tileRows = { "Fo IW" }, registry = TileRegistry() })
        withView(zone, function(view)
            equal(view:tileAt(0, 0), 25); equal(view:hasWallAt(0, 0), false)
            zone:setTile(0, 0, "base:26")
            equal(zone.tiles[1][1], 26); equal(zone.collision[1][1], 1)
            equal(zone:terrainAt(0, 0).land_passable, false)
            equal(view:tileAt(0, 0), 26); equal(view:hasWallAt(0, 0), true)
            local payload = zone:exportDeltas()
            equal(payload.tiles[1].key, "base:26"); equal(payload.tile_count, 1)
            rejects(function() zone:setTile(-1, 0, "base:25") end)
            rejects(function() zone:setTile(0, 0, 999) end)
            equal(view:tileAt(0, 0), 26)
            zone:resetDeltas()
            equal(zone.tiles[1][1], 25); equal(zone.collision[1][1], 0)
            equal(zone:terrainAt(0, 0).land_passable, true)
            equal(view:tileAt(0, 0), 25); equal(view:hasWallAt(0, 0), false)
            equal(zone:exportDeltas().tile_count, 0)
        end)
    end)
    test("renderer rejection leaves domain data and mutation journal unchanged", function()
        local zone = Zone({ id = "contract:reject", tileRows = { "Fo" }, registry = TileRegistry() })
        zone:attachView({ applyTiles = function() error("deliberate view rejection") end })
        rejects(function() zone:setTile(0, 0, "base:26") end)
        equal(zone.tiles[1][1], 25); equal(zone.collision[1][1], 0)
        equal(zone:terrainAt(0, 0).land_passable, true); equal(zone:exportDeltas().tile_count, 0)
    end)
    test("stable key deltas roundtrip after runtime image IDs change", function()
        local definition = PilotWorld.definition("ViridianMart")
        local first, second = TileRegistry(), TileRegistry()
        local batch = {}
        for i = #definition.grids, 1, -1 do
            local value = definition.grids[i]
            batch[#batch + 1] = { key = value.stable_id, grid = value.grid, collision = value.terrain.land_passable and 0 or 1, terrain = value.terrain }
        end
        second:registerBatch(batch)
        local a = Zone.fromMapDefinition(definition, first, { terrainFixture = true })
        local b = Zone.fromMapDefinition(definition, second, { terrainFixture = true })
        local key = definition.grids[1].stable_id
        assert(first:id(key) ~= second:id(key))
        a:setTile(2, 6, key)
        local payload = json.decode(json.encode(a:exportDeltas()))
        b:applyDeltas(payload)
        equal(first:key(a.tiles[7][3]), second:key(b.tiles[7][3]))
        payload.tiles[1].key = "unknown:key"
        rejects(function() b:applyDeltas(payload) end)
        equal(second:key(b.tiles[7][3]), key)
    end)
    test("whole world payload validation and reset are atomic across zones", function()
        local oldRegistry, oldList = zoneRegistry, zoneList
        local a = Zone({ id = "contract:a", tileRows = { "Fo" }, registry = TileRegistry() })
        local b = Zone({ id = "contract:b", tileRows = { "Fo" }, registry = TileRegistry() })
        local ok, problem = pcall(function()
            zoneRegistry, zoneList = { a = a, b = b }, { "a", "b" }
            a:setTile(0, 0, "base:26")
            local payload = WorldDeltas.export()
            equal(payload.zone_count, 1); equal(payload.zones[1].tiles[1].key, "base:26")
            local bad = json.decode(json.encode(payload)); bad.zones[1].tiles[1].key = "unknown:key"
            rejects(function() WorldDeltas.apply(bad) end)
            equal(a.tiles[1][1], 26); equal(b.tiles[1][1], 25)
            WorldDeltas.reset(); equal(a.tiles[1][1], 25)
            WorldDeltas.apply(payload); equal(a.tiles[1][1], 26)
        end)
        zoneRegistry, zoneList = oldRegistry, oldList
        if not ok then error(problem, 0) end
    end)
    test("world validation is pure defensive and revalidated before commit", function()
        local oldRegistry, oldList = zoneRegistry, zoneList
        local zone = Zone({ id = "contract:pure", tileRows = { "Fo Fo" }, registry = TileRegistry() })
        local ok, problem = pcall(function()
            zoneRegistry, zoneList = { pure = zone }, { "pure" }
            zone:setTile(0, 0, "base:26")
            local payload = WorldDeltas.export()
            local normalized = WorldDeltas.validate(payload)
            equal(zone.tiles[1][1], 26)
            payload.zones[1].tiles[1].key = "unknown:key"
            equal(normalized.zones[1].tiles[1].key, "base:26")
            normalized.zones[1].tiles[1].key = "unknown:key"
            rejects(function() WorldDeltas.apply(normalized) end)
            equal(zone.tiles[1][1], 26)
            local empty = WorldDeltas.validate({ schema = 1, zone_count = 0, zones = {} })
            equal(empty.zone_count, 0); equal(zone.tiles[1][1], 26)
            local unknown = WorldDeltas.export()
            unknown.unrecognized = false
            rejects(function() WorldDeltas.validate(unknown) end)
            unknown.unrecognized = nil
            unknown.zones[1].unrecognized = false
            rejects(function() WorldDeltas.validate(unknown) end)
            equal(zone.tiles[1][1], 26)
        end)
        zoneRegistry, zoneList = oldRegistry, oldList
        if not ok then error(problem, 0) end
    end)
    test("candidate world location uses omitted baseline and rejects new walls and unresolved maps", function()
        local oldRegistry, oldList = zoneRegistry, zoneList
        local zone = Zone({ id = "contract:location", tileRows = { "Fo IW" }, registry = TileRegistry() })
        local pilot = PilotWorld.create("ViridianMart", { registry = TileRegistry(), terrainFixture = true })
        local ok, problem = pcall(function()
            zoneRegistry, zoneList = { location = zone, pilot = pilot }, { "location", "pilot" }
            local empty = { schema = 1, zone_count = 0, zones = {} }
            local at = { zone_id = zone.stableID, x = 0, y = 0, facing = "down" }
            zone:setTile(0, 0, "base:26")
            local closed = WorldDeltas.export()
            equal(WorldDeltas.resolveLocation(at, empty).x, 0)
            rejects(function() WorldDeltas.resolveLocation(at, closed) end)
            equal(zone.tiles[1][1], 26)
            zone:setTile(1, 0, "base:25")
            local opened = WorldDeltas.export()
            at.x = 1
            rejects(function() WorldDeltas.resolveLocation(at, empty) end)
            equal(WorldDeltas.resolveLocation(at, opened).x, 1)
            at.x = 2; rejects(function() WorldDeltas.resolveLocation(at, opened) end)
            at.x = 0; at.facing = "north"; rejects(function() WorldDeltas.resolveLocation(at, empty) end)
            rejects(function() WorldDeltas.resolveLocation({ zone_id = pilot.stableID, x = 3, y = 6, facing = "up" }, empty) end)
        end)
        zoneRegistry, zoneList = oldRegistry, oldList
        if not ok then error(problem, 0) end
    end)
    test("both pilots use actual Player collision and eight frame movement", function()
        for _, scenario in ipairs({
            { name = "Route1", x = 10, y = 35, blockedX = -1, blockedY = 0, dx = 0, dy = -1 },
            { name = "ViridianMart", x = 3, y = 6, blockedX = 0, blockedY = 1, dx = 1, dy = 0 },
        }) do
            local previous, player = currentZone, nil
            local oldNoclip = DEBUG_FLAGS.noclip
            local zone = PilotWorld.create(scenario.name, { registry = TileRegistry(), terrainFixture = true })
            local manager = NPCManager()
            local ok, problem = pcall(function()
                currentZone, DEBUG_FLAGS.noclip = zone, false
                zone:spawnNPCs(manager)
                player = Player(scenario.x, scenario.y, zone.collision, manager)
                player:tryMove(scenario.blockedX, scenario.blockedY)
                equal(player.isMoving, false); equal(player.gridX, scenario.x); equal(player.gridY, scenario.y)
                player:tryMove(scenario.dx, scenario.dy); equal(player.isMoving, true)
                for i = 1, 8 do player:update() end
                equal(player.isMoving, false)
                equal(player.gridX, scenario.x + scenario.dx); equal(player.gridY, scenario.y + scenario.dy)
                equal(player.stepJustFinished, true)
            end)
            if player then player:remove(); player.grassOverlay:remove(); player.exitArrow:remove() end
            manager:clear()
            currentZone, DEBUG_FLAGS.noclip = previous, oldNoclip
            if not ok then error(problem, 0) end
        end
    end)
    if HarnessBuild and HarnessBuild.enabled then
        test("actual SDK pilot terrain render exports both independent comparison images", function()
            local manifest = PilotWorld.writeImages(HarnessBuild.output_dir)
            equal(#manifest.images, 2)
            json.encodeToFile("world-pilot-export.json", true, manifest)
        end)
    end
    return report
end
