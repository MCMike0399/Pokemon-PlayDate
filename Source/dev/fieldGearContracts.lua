-- Two prepared behavior contracts. Root alone executes them in the real SDK.
FieldGearContracts = {}

local function bytes(values)
    local index = 0
    return {random = function(_, low, high)
        assert(low == 0 and high == 255)
        index = index + 1
        return assert(values[index], "unexpected fishing sample")
    end}
end

function FieldGearContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, reason = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(reason) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    test("field-gear: Bicycle and Cycling Road preserve source restrictions and motion", function()
        local travel = FieldTravel.empty()
        assert(not FieldCycling.toggle(travel, false, false, "ROUTE_1", "OVERWORLD"))
        assert(not FieldCycling.toggle(travel, false, true, "VIRIDIAN_MART", "MART"))
        local mounted = assert(FieldCycling.toggle(travel, false, true, "ROUTE_1", "OVERWORLD"))
        assert(mounted.travel.mode == "bicycle" and travel.mode == "walking")
        assert(FieldCycling.toggle(mounted.travel, false, true, "ROUTE_1", "OVERWORLD").travel.mode == "walking")
        local road = assert(FieldCycling.enter(travel, false, true, "ROUTE_16", "OVERWORLD", 17, 10, "map"))
        assert(road.forced and road.travel.mode == "bicycle")
        assert(not FieldCycling.toggle(road.travel, true, true, "ROUTE_17", "OVERWORLD"))
        local motion = FieldCycling.motion(road.travel, "ROUTE_17", {}, false, false)
        assert(motion.automatic == "down" and motion.accelerated)
        assert(not FieldCycling.motion(road.travel, "ROUTE_17", {a = true}, false, false).automatic)
        assert(not FieldCycling.motion(road.travel, "ROUTE_17", {b = true}, false, false).automatic)
        assert(not FieldCycling.motion(road.travel, "ROUTE_17", {}, false, true).automatic)
        assert(not FieldCycling.motion(road.travel, "ROUTE_17", {up = true}, false, false).accelerated)
        assert(not FieldCycling.motion(road.travel, "ROUTE_17", {}, true, false).accelerated)
        local gate = FieldCycling.gate("ROUTE_16_GATE_1F", 4, 10, false)
        assert(#gate.approach == 3 and gate.return_direction == "right")
        assert(not FieldCycling.gate("ROUTE_16_GATE_1F", 4, 10, true))
        local left = assert(FieldCycling.enter(road.travel, true, true, "ROUTE_18_GATE_1F", "GATE", 4, 4, "map"))
        assert(not left.forced and left.travel.mode == "walking")
        assert(not FieldCycling.enter(road.travel, true, true, "VIRIDIAN_CITY", "OVERWORLD", 1, 1, "blackout").forced)
    end)

    test("field-gear: Rod sampling, cancellation and detached specimen creation keep owner transactions", function()
        local old = FieldFishing.sample("oldRod", "VERMILION_CITY", bytes({}))
        assert(old.species == "magikarp" and old.level == 5 and old.draws == 0)
        local good = FieldFishing.sample("goodRod", "VERMILION_CITY", bytes({6, 2}))
        assert(good.species == "poliwag" and good.level == 10 and good.draws == 2)
        assert(FieldFishing.sample("goodRod", "VERMILION_CITY", bytes({6, 1})).kind == "no-bite")
        local super = FieldFishing.sample("superRod", "CERULEAN_CITY", bytes({6, 4}))
        assert(super.species == "krabby" and super.level == 15 and super.draws == 2)
        assert(FieldFishing.sample("superRod", "SAFARI_ZONE_CENTER", bytes({0})).species == "dratini")
        assert(FieldFishing.sample("superRod", "VIRIDIAN_FOREST", bytes({})).kind == "no-fish")
        local priorOwner = GameSession.activeRNGSession()
        local priorRNG = RulesRNG.toData()
        local session = GameSession.newSession({itemDefinitions = ItemData.definitions,
            validateWorld = function(value) return value end,
            resolveLocation = function(value) return value end},
            {location = {zone_id = "pallet_town", x = 5, y = 6, facing = "down"}, seed = 113})
        local ok, reason = pcall(function()
            assert(session:recruit(Pokemon("bulbasaur", 5)))
            assert(session:inventory():add("oldRod", 1))
            assert(session:activateRNG())
            local token = assert(FieldFishing.prepare(session, "oldRod", "VERMILION_CITY"))
            local before = RulesRNG.toData()
            assert(FieldFishing.cancel(token))
            assert(not FieldFishing.resolve(token))
            assert(FieldMoves.same(before, RulesRNG.toData()))
            token = assert(FieldFishing.prepare(session, "oldRod", "VERMILION_CITY"))
            assert(session:inventory():add("potion", 1))
            assert(not FieldFishing.resolve(token))
            assert(FieldMoves.same(before, RulesRNG.toData()))
            token = assert(FieldFishing.prepare(session, "oldRod", "VERMILION_CITY"))
            local accepted, result = FieldFishing.resolve(token)
            assert(accepted, result)
            assert(result.kind == "encounter" and result.pokemon.species == "magikarp" and result.pokemon.level == 5)
            assert(session:inventory():quantity("oldRod") == 1 and session:party():count() == 1)
            assert(not FieldFishing.resolve(token))
        end)
        if GameSession.activeRNGSession() == session then
            session:deactivateRNG()
        end
        if priorOwner then
            assert(priorOwner:activateRNG())
        end
        RulesRNG.restoreData(priorRNG)
        assert(ok, reason)
    end)
    return report
end
