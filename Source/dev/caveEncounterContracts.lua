-- Root-run SDK cases using the real imported Zones and encounter transaction.
CaveEncounterContracts = {}

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end

local function context()
    local game <const> = GameContext({ sessionLocationPolicy = PewterWorld.locationPolicy() })
    assert(game:recruit(Pokemon("squirtle", 10))) -- Torrent has no field draw.
    assert(game.session:activateRNG())
    return game
end

local function cell(zone, predicate)
    for y = 0, zone.height - 1 do
        for x = 0, zone.width - 1 do
            if predicate(zone:terrainAt(x, y), zone.collision[y + 1][x + 1], x, y) then
                return x, y
            end
        end
    end
    error("required source terrain absent: " .. zone.stableID)
end

local function land(zone)
    return cell(zone, function(terrain, collision, x, y)
        return collision == 0 and terrain.land_passable and not terrain.grass
            and not terrain.water_candidate and not terrain.warp_tile and not zone:getDoorAt(x, y)
    end)
end

local function prepare(game, zone, x, y)
    return FieldEncounters.prepare({ session = game.session, party = game.session:party(),
        zone = zone, x = x, y = y })
end

local function rejected(game, zone, x, y, reason)
    local before <const> = RulesRNG.toData()
    local world <const> = game.session:worldRngData()
    local plan, why = prepare(game, zone, x, y)
    equal(plan, nil)
    if reason then equal(why, reason) end
    assert(same(before, RulesRNG.toData()), "rejected policy drew rules RNG")
    assert(same(world, game.session:worldRngData()), "rejected policy drew actor RNG")
end

function CaveEncounterContracts.run()
    local report <const> = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local before <const> = RulesRNG.snapshot()
        local owner <const> = GameSession.activeRNGSession()
        local ok, problem = pcall(fn)
        local active <const> = GameSession.activeRNGSession()
        if active ~= owner then
            if active then active:deactivateRNG() end
            if owner then assert(owner:activateRNG()) end
        end
        RulesRNG.restore(before)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end

    -- Exact original symptom. Before the Zone fix these three cases fail at
    -- prepare with ineligible-terrain, before the deterministic rate draw.
    for _, name in ipairs({ "MtMoon1F", "MtMoonB1F", "MtMoonB2F" }) do
        test(name .. " non-grass land reaches Blue byte 9 accepted and 10 rejected", function()
            local game <const> = context()
            local zone <const> = PewterWorld.isolated(name)
            local x, y = land(zone)
            equal(zone:isTallGrass(x, y), false)
            local policy, reason = zone:encounterPolicyAt(x, y)
            assert(policy, name .. ": " .. tostring(reason))
            equal(policy.rate.kind, "byte")
            equal(policy.rate.value, 10)
            local source <const> = SourceMaps.definition(name).encounters.grass.slots
            equal(#policy.slots, 10)
            for i, slot in ipairs(source) do
                equal(policy.slots[i].species, slot.species)
                equal(policy.slots[i].minLevel, slot.level)
                equal(policy.slots[i].maxLevel, slot.level)
                equal(policy.slots[i].weight, slot.weight_256)
            end
            local world <const> = game.session:worldRngData()
            RulesRNG.seed(230) -- First Park-Miller byte = 9, just below rate 10.
            local before <const> = RulesRNG.toData()
            local plan, why = prepare(game, zone, x, y)
            assert(plan, why)
            assert(same(before, RulesRNG.toData()), "prepare must be pure")
            local ok, result = FieldEncounters.resolve(plan)
            assert(ok, result)
            equal(result.kind, "encounter")
            equal(result.receipt.rate_roll, 9)
            equal(result.pokemon.species, source[result.receipt.slot].species)
            equal(result.pokemon.level, source[result.receipt.slot].level)
            -- Existing production weighted sampler/specimen continuation is the
            -- compatibility oracle; no alternate Pokemon constructor or SDK.
            local after <const> = RulesRNG.toData()
            RulesRNG.seed(230)
            equal(RulesRNG.random(0, 255), 9)
            local expected <const> = zone:rollEncounter(game.session)
            assert(same(PokemonCodec.encode(expected), PokemonCodec.encode(result.pokemon)))
            assert(same(after, RulesRNG.toData()))
            RulesRNG.seed(253) -- First byte = 10: exact boundary must fail.
            plan, why = prepare(game, zone, x, y)
            assert(plan, why)
            ok, result = FieldEncounters.resolve(plan)
            assert(ok, result)
            equal(result.kind, "none")
            equal(result.reason, "rate")
            equal(result.receipt.rate_roll, 10)
            equal(RulesRNG.snapshot().rolls, 1)
            assert(same(world, game.session:worldRngData()))
        end)
    end

    test("cave blocked cells and invalid coordinates reject without draws", function()
        local game <const> = context()
        for _, name in ipairs({ "MtMoon1F", "MtMoonB1F", "MtMoonB2F" }) do
            local zone <const> = PewterWorld.isolated(name)
            local x, y = cell(zone, function(_, collision) return collision ~= 0 end)
            rejected(game, zone, x, y, "ineligible-terrain")
            rejected(game, zone, -1, y, "invalid-encounter-coordinate")
            rejected(game, zone, zone.width, y, "invalid-encounter-coordinate")
        end
    end)

    test("minus-one grass tile in a zero-rate Center never draws", function()
        local game <const> = context()
        local zone <const> = PewterWorld.isolated("MtMoonPokecenter")
        local definition <const> = SourceMaps.definition("MtMoonPokecenter")
        equal(definition.tileset.grass_tile, -1)
        equal(definition.encounters.grass.rate_byte, 0)
        local x, y = land(zone)
        rejected(game, zone, x, y)
    end)

    test("terrain-only imported cave cannot activate an unbound encounter table", function()
        local game <const> = context()
        local zone <const> = Zone.fromMapDefinition(SourceMaps.padded("MtMoon1F"), TileRegistry(),
            { terrainFixture = true })
        local x, y = land(zone)
        rejected(game, zone, x, y, "unbound-encounter-policy")
    end)

    test("current source delta terrain rejects blocked and water replacements and stale plans", function()
        local game <const> = context()
        local zone <const> = PewterWorld.isolated("MtMoon1F")
        local x, y = land(zone)
        local original <const> = zone.registry:key(zone.tiles[y + 1][x + 1])
        local bx, by = cell(zone, function(terrain) return not terrain.land_passable end)
        local blocked <const> = zone.registry:key(zone.tiles[by + 1][bx + 1])
        local plan, why = prepare(game, zone, x, y)
        assert(plan, why)
        zone:setTile(x, y, blocked)
        rejected(game, zone, x, y, "ineligible-terrain")
        local before <const> = RulesRNG.toData()
        equal(FieldEncounters.resolve(plan), false)
        assert(same(before, RulesRNG.toData()))
        zone:setTile(x, y, original)
        assert(prepare(game, zone, x, y))
        equal(zone:isTallGrass(x, y), false)
        -- Destination collision remains authoritative even on valid land.
        zone.collision[y + 1][x + 1] = 1
        rejected(game, zone, x, y, "ineligible-terrain")
        zone.collision[y + 1][x + 1] = 0
        -- Use an actual pinned water cell, registered only in this private
        -- registry. Cave metadata must not turn source water into land.
        local water
        for _, grid in ipairs(SourceMaps.definition("CeruleanCity").grids) do
            if grid.terrain.water_candidate then
                water = grid
                break
            end
        end
        assert(water, "pinned Cerulean water missing")
        zone.registry:registerBatch({ { key = water.stable_id, grid = water.grid,
            terrain = water.terrain, collision = water.terrain.land_passable and 0 or 1 } })
        zone:setTile(x, y, water.stable_id)
        rejected(game, zone, x, y, "ineligible-terrain")
        zone:setTile(x, y, original)
        assert(prepare(game, zone, x, y))
    end)

    test("FOREST non-grass and outdoor non-grass reject; ordinary grass retains Blue rate", function()
        local game <const> = context()
        for _, name in ipairs({ "ViridianForest", "Route3" }) do
            local zone <const> = PewterWorld.isolated(name)
            local x, y = land(zone)
            rejected(game, zone, x, y, "ineligible-terrain")
            x, y = cell(zone, function(terrain, collision) return terrain.grass and collision == 0 end)
            local policy <const> = assert(zone:encounterPolicyAt(x, y))
            equal(policy.rate.value, SourceMaps.definition(name).encounters.grass.rate_byte)
            assert(prepare(game, zone, x, y))
        end
        local authored <const> = Zone({ name = "authored grass witness", tileRows = { "TG Fo" } })
        equal(assert(authored:encounterPolicyAt(0, 0)).rate.kind, "unit")
        rejected(game, authored, 1, 0, "ineligible-terrain")
    end)
    return report
end
