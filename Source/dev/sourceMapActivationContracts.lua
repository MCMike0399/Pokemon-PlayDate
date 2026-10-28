-- Root-run SDK witnesses. Uses existing pinned extension records without adding
-- SchoolHouse to the campaign. Route22 uses private fixture metadata; every
-- Zone is constructed by the production importer.
SourceMapActivationContracts = {}

local function fixture()
    return assert(json.decodeFile("dev/sourceMapFixture.json"), "pinned map extension fixture missing")
end

local function scope(records, fn)
    local ids = WorldTiles:maxID()
    local sprites = playdate.graphics.sprite.spriteCount()
    SourceMaps._withRecords(records, fn)
    assert(WorldTiles:maxID() == ids, "activation witness changed production tile registry")
    assert(playdate.graphics.sprite.spriteCount() == sprites, "activation witness leaked sprites")
end

local function adapter()
    return {
        options = function()
            local options = SourceBindings.options("source", {
                dispatch = function() error("activation witness cannot dispatch") end,
                questFlag = function() return false end,
                sourceFlag = function() return false end,
            })
            -- Content-only inert actor definitions. SourceBindings, geometry,
            -- collision, warps, Zone and the registry remain production owners.
            options.objectDefinition = function(_, event)
                return { gridX = event.x, gridY = event.y, source_event_id = event.id,
                    sprite = "oak", name = event.text_id }
            end
            return options
        end,
    }
end

local function construct(name)
    local zone = SourceMaps.createZone(name, adapter(), TileRegistry(), { isolatedCatalog = true })
    assert(zone.stableID == SourceMaps.entry(name).id and zone:isSliceReady(), "generic source Zone not constructed")
    return zone
end

local function blockSchool(records)
    local manifest = records["data/sourceMaps.json"].maps
    local city = records["data/sourceMapCache/compact.json"].maps.ViridianCity
    local event = city.warps[3]
    manifest.ViridianCity.blocked_events = { event.id }
    city.blocked[tostring(event.y * city.width + event.x + 1)] = event.id
    return event.id
end

function SourceMapActivationContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then report.passed = report.passed + 1
        else report.failed = report.failed + 1; report.ok = false end
    end

    test("actual shared SourceBindings constructs a valid generic profile Zone", function()
        scope(fixture(), function()
            local school = construct("ViridianSchoolHouse")
            local door = assert(school:getEdgeDoorAt(4, 7, "down"))
            assert(door.to == "kanto_viridian_city" and door.toX == 21 and door.toY == 16)
            local route = construct("Route22")
            assert(route.width == 40 and route.height == 18)
            assert(SourceMaps.warpSpec("ViridianCity", SourceMaps.padded("ViridianCity").events.warps[3]).status == "bound")
        end)
    end)

    test("explicit source warp blocker wins even when its target is available", function()
        local records = fixture()
        blockSchool(records)
        scope(records, function()
            local event = SourceMaps.padded("ViridianCity").events.warps[3]
            local spec = SourceMaps.warpSpec("ViridianCity", event)
            assert(spec.status == "blocked" and spec.reason == "source event outside implemented parcel handlers")
            local specs = SourceBindings.specs("ViridianCity", SourceMaps.padded("ViridianCity"), function() return false end)
            assert(specs[event.id].status == "blocked", "shared binding reopened a blocked warp")
            local city = construct("ViridianCity")
            assert(city.collision[event.y + 1][event.x + 1] == 1, "actual Zone reopened a blocked warp")
            for _, door in ipairs(city.doors) do
                assert(door.source_event_id ~= event.id, "actual Zone installed a blocked door")
            end
        end)
    end)

    test("blocked exterior ingress safely closes both generic room return mats", function()
        local records = fixture()
        blockSchool(records)
        scope(records, function()
            local school = construct("ViridianSchoolHouse")
            for _, event in ipairs(SourceMaps.padded("ViridianSchoolHouse").events.warps) do
                local spec = SourceMaps.warpSpec("ViridianSchoolHouse", event)
                assert(spec.status == "blocked" and spec.reason == "original target map outside reviewed Pewter slice")
                assert(school.collision[event.y + 1][event.x + 1] == 1)
                assert(school:bindingAt(event.x, event.y).id == event.id)
                for _, door in ipairs(school.doors) do
                    assert(door.source_event_id ~= event.id, "return crossed a blocked ingress")
                end
                -- Blocked source door queries deliberately fail loudly. A nil
                -- result would hide an unsupported warp from callers.
                for _, query in ipairs({ school.getDoorAt, school.getEdgeDoorAt }) do
                    local ok, problem = pcall(query, school, event.x, event.y, "down")
                    assert(not ok and tostring(problem):find("unresolved source warp: " .. event.id, 1, true))
                end
            end
        end)
    end)

    test("source metadata blocker protects reciprocal ingress before cache collision", function()
        local records = fixture()
        -- Keep the ordinary cache open to prove the explicit target declaration
        -- itself is enforced, rather than relying only on the collision cache.
        records["data/sourceMaps.json"].maps.ViridianCity.blocked_events = { "pokered:VIRIDIAN_CITY:warps:3" }
        scope(records, function()
            local room = SourceMaps.padded("ViridianSchoolHouse")
            assert(SourceMaps.warpSpec("ViridianSchoolHouse", room.events.warps[1]).status == "blocked")
        end)
    end)

    test("horizontal connection blockers are directional and honored on either side", function()
        local records = fixture()
        local maps = records["data/sourceMapCache/compact.json"].maps
        maps.ViridianCity.blocked_connections = { "west:ROUTE_22" }
        scope(records, function()
            assert(SourceMaps.connection("ViridianCity", 0, 16, "left") == nil)
            assert(SourceMaps.connection("Route22", 39, 8, "right"), "directed source gate changed the reverse edge")
        end)
        records = fixture()
        records["data/sourceMapCache/compact.json"].maps.Route22.blocked_connections = { "east:VIRIDIAN_CITY" }
        scope(records, function()
            assert(SourceMaps.connection("Route22", 39, 8, "right") == nil)
            assert(SourceMaps.connection("ViridianCity", 0, 16, "left"))
        end)
    end)

    test("vertical source gate is enforced while the original opposite direction stays valid", function()
        local records = fixture()
        records["data/sourceMapCache/compact.json"].maps.ViridianCity.blocked_connections = { "north:ROUTE_2" }
        scope(records, function()
            assert(SourceMaps.connection("ViridianCity", 20, 0, "up") == nil)
            local reverse = assert(SourceMaps.connection("Route2", 10, 71, "down"))
            assert(reverse.to == "kanto_viridian_city" and reverse.x == 20 and reverse.y == 0)
        end)
    end)

    test("production Viridian and Route2 keep both accepted campaign connections", function()
        local north = assert(SourceMaps.connection("ViridianCity", 20, 0, "up"))
        assert(north.to == "kanto_route2" and north.x == 10 and north.y == 71)
        local south = assert(SourceMaps.connection("Route2", 10, 71, "down"))
        assert(south.to == "kanto_viridian_city" and south.x == 20 and south.y == 0)
    end)

    test("new campaign connections and museum ingresses use the installed shared projections", function()
        assert(#SourceMaps.names() == 30)
        assert(SourceMaps.entry("Route22") and SourceMaps.entry("Route3"))
        assert(SourceMaps.connection("ViridianCity", 0, 16, "left").to == "kanto_route_22")
        assert(SourceMaps.connection("PewterCity", 39, 18, "right").to == "kanto_route_3")
        local city = SourceMaps.padded("PewterCity")
        for index = 1, 2 do
            assert(SourceMaps.warpSpec("PewterCity", city.events.warps[index]).status == "bound")
        end
        for _, name in ipairs({ "Museum1F", "Museum2F" }) do
            assert(SourceMaps.entry(name), "museum geometry not installed")
        end
    end)

    test("unknown binding adapters still fail the real Zone constructor", function()
        scope(fixture(), function()
            local definition = SourceMaps.padded("ViridianSchoolHouse")
            local ok, problem = pcall(Zone.fromMapDefinition, definition, TileRegistry(), {
                spawn = SourceMaps.entry("ViridianSchoolHouse").spawn,
                bindingAdapter = {},
            })
            assert(not ok and tostring(problem):find("unreviewed source binding adapter", 1, true))
        end)
    end)
    return report
end
