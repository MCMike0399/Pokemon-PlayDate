-- One prepared SDK contract per new behavior. Root alone executes these.
FieldTravelContracts = {}
local gfx <const> = playdate.graphics

local function cell(water)
    return {
        binding_blocked = false, occupied = false, adapter_padding = false,
        water_candidate = water, foot_tile = water and 0x14 or 0,
        land_passable = not water
    }
end

local function runtimeScene(fn)
    local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
    local oldStory = Story.currentContext()
    local oldOwner, oldRNG = GameSession.activeRNGSession(), RulesRNG.toData()
    local oldWorld = WorldDeltas.export()
    local drawX, drawY = gfx.getDrawOffset()
    local oldSprites = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        oldSprites[sprite] = {visible = sprite:isVisible(), enabled = sprite:updatesEnabled()}
        sprite:setVisible(false)
        sprite:setUpdatesEnabled(false)
    end
    local g = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()})
    local provider = PewterWorld.createProvider(g, TileRegistry())
    zoneRegistry, zoneList = {}, {}
    local priorProvider = WorldDeltas.definitionProvider()
    for _, key in ipairs(oldList) do
        if not priorProvider or not priorProvider:owns(oldRegistry[key]) then
            zoneRegistry[key] = oldRegistry[key]
            zoneList[#zoneList + 1] = key
        end
    end
    local ok, reason = pcall(function()
        WorldDeltas._withDefinitionProvider(provider, function()
            WorldView.withIsolation(function()
                Story.bind(g)
                local mon = Pokemon("squirtle", 5)
                assert(g:recruit(mon))
                assert(g.session:setIntro({stage = "done", starter = "squirtle", rivalStarter = "bulbasaur"}))
                assert(g.session:inventory():add("hm03", 1))
                assert(Teaching.complete(assert(Teaching.prepare(g.session, mon, "hm03")), "learn"))
                assert(g.session:setQuestFlag("BADGE_SOUL", true))
                assert(g.session:activateRNG())
                g.machine:register("overworld", OverworldState(g))
                g.machine:register("party", PartyState(g))
                g.machine:register("fieldTravel", FieldTravelState(g))
                fn(g, mon, provider)
            end)
        end)
    end)
    for _, state in ipairs(g.machine.stack) do
        pcall(state.exit, state)
    end
    g.machine.stack = {}
    g.npcManager:clear()
    if g.player then
        g.player:remove()
        g.player.grassOverlay:remove()
        g.player.exitArrow:remove()
    end
    provider:disposeCache()
    zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
    Story.bind(oldStory)
    WorldDeltas.apply(oldWorld)
    local active = GameSession.activeRNGSession()
    if active ~= oldOwner then
        if active then
            active:deactivateRNG()
        end
        if oldOwner then
            assert(oldOwner:activateRNG())
        end
    end
    RulesRNG.restoreData(oldRNG)
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        if not oldSprites[sprite] then
            sprite:remove()
        end
    end
    for sprite, value in pairs(oldSprites) do
        sprite:add()
        sprite:setVisible(value.visible)
        sprite:setUpdatesEnabled(value.enabled)
    end
    gfx.setDrawOffset(drawX, drawY)
    assert(ok, reason)
end

local function bank(zone)
    local deltas = {down = {0, 1}, up = {0, -1}, left = {-1, 0}, right = {1, 0}}
    for y = 1, zone.height - 2 do
        for x = 1, zone.width - 2 do
            local from = zone:terrainAt(x, y)
            for facing, delta in pairs(deltas) do
                local to = zone:terrainAt(x + delta[1], y + delta[2])
                if from.land_passable and not from.binding_blocked and not from.water_candidate
                    and to.water_candidate and not to.binding_blocked and to.foot_tile == 0x14 then
                    local occupied = false
                    for _, npc in ipairs(zone.npcDefs) do
                        occupied = occupied or npc.gridX == x and npc.gridY == y
                    end
                    if not occupied then
                        return {x = x, y = y, facing = facing}, delta
                    end
                end
            end
        end
    end
    error("source Fuchsia bank witness missing")
end

function FieldTravelContracts.run()
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
    test("field-travel: Surf enters water, lands, and respects source pair barriers", function()
        local travel = FieldTravel.empty()
        local position = {zone_id = "pokered:FUCHSIA_CITY", x = 3, y = 4, facing = "down"}
        local before = Party._primitive(travel)
        local plan = assert(FieldTravel.surf(travel, position, cell(false), cell(true), "OVERWORLD", {}))
        assert(plan.travel.mode == "surfing" and plan.location.y == 5)
        assert(FieldMoves.same(travel, before))
        local step = assert(FieldTravel.surfStep(plan.travel, plan.location, cell(true), cell(true), "OVERWORLD"))
        assert(step.travel.mode == "surfing" and step.location.y == 6)
        local landing = assert(FieldTravel.surfStep(step.travel, step.location, cell(true), cell(false), "OVERWORLD"))
        assert(landing.travel.mode == "walking" and landing.location.y == 7)
        local shore = cell(false)
        shore.foot_tile = 0x32
        local coastal = assert(FieldTravel.surf(travel, position, cell(false), shore, "OVERWORLD", {}))
        assert(coastal.travel.mode == "surfing")
        assert(FieldTravel.surfStep(coastal.travel, position, shore, shore, "OVERWORLD").travel.mode == "surfing")
        assert(not FieldTravel.surf(travel, position, cell(false), shore, "SHIP_PORT", {}))
        local blocked = cell(false)
        blocked.foot_tile = 0x05
        assert(not FieldTravel.surfStep(plan.travel, plan.location, cell(true), blocked, "CAVERN"))
        blocked = cell(true)
        blocked.binding_blocked = true
        assert(not FieldTravel.surf(travel, position, cell(false), blocked, "OVERWORLD", {}))
        assert(not FieldTravel.surf(travel, position, cell(false), cell(true), "OVERWORLD", {forcedBicycle = true}))
        runtimeScene(function(g, mon, provider)
            currentZone = provider:ensure(SourceMaps.entry("FuchsiaCity").key)
            local entry, delta = bank(currentZone)
            g.machine:change("overworld", {entry = entry})
            local origin = g.session:location()
            g.machine:push("party")
            local party = g.machine:get("party")
            party:actions()
            assert(FieldTravelState.open(g, party, mon, "surf"))
            local state = g.machine:get("fieldTravel")
            state.menu.onSelect(2)
            state:complete()
            for _ = 1, 7 do
                state:update()
                assert(g.player.gridX == origin.x and g.player.gridY == origin.y)
                assert(g.session:fieldTravelData().mode == "walking")
                assert(FieldMoves.same(g.session:location(), origin))
            end
            state:update()
            assert(g.session:fieldTravelData().mode == "surfing")
            assert(g.player.gridX == origin.x + delta[1] and g.player.gridY == origin.y + delta[2])
            local wire = assert(SessionCodec.encode(g.session, {root = "overworld", overworld = "explore", settled = true}))
            local loaded = assert(SessionCodec.decode(wire, g:getSessionDependencies()))
            assert(FieldWorld.prepareContinue(loaded))
            assert(loaded:fieldTravelData().mode == "surfing")
            assert(FieldMoves.same(loaded:location(), g.session:location()))
            g.player:tryMove(-delta[1], -delta[2])
            for _ = 1, 8 do
                g.player:updateFieldStep()
            end
            assert(g.session:fieldTravelData().mode == "walking")
            assert(g.player.gridX == origin.x and g.player.gridY == origin.y)
            g.player.facing = entry.facing
            local before = g.session:fieldTravelData()
            local request = assert(FieldTravelRuntime.step(g, true))
            assert(g.player:beginFieldStep(request))
            g.player:updateFieldStep()
            assert(g.player:cancelFieldStep("contract-cancel"))
            assert(FieldMoves.same(g.session:fieldTravelData(), before))
            request = assert(FieldTravelRuntime.step(g, true))
            assert(g.player:beginFieldStep(request))
            local capture = g.session.captureTraversal
            g.session.captureTraversal = function() return false, "injected capture rejection" end
            for _ = 1, 8 do
                g.player:updateFieldStep()
            end
            g.session.captureTraversal = capture
            assert(not g.player.fieldStepResult.ok)
            assert(g.player.gridX == origin.x and g.player.gridY == origin.y)
            assert(FieldMoves.same(g.session:fieldTravelData(), before))
        end)
    end)

    test("field-travel: Fly uses durable visited cities without granting route destinations", function()
        local travel = FieldTravel.empty()
        travel = FieldTravel.enter(travel, "pokered:CERULEAN_CITY")
        travel = FieldTravel.enter(travel, "pokered:ROUTE_4")
        travel = FieldTravel.enter(travel, "pokered:CERULEAN_CITY")
        assert(#travel.visited == 1 and #FieldTravel.destinations(travel) == 1)
        local position = {zone_id = "pokered:ROUTE_2", x = 2, y = 3, facing = "up"}
        local function arrival(entry)
            return {zone_id = entry.id, x = entry.x, y = entry.y, facing = "down"}
        end
        local plan = assert(FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", true, arrival))
        assert(plan.location.x == 19 and plan.location.y == 18)
        assert(plan.travel.mode == "walking")
        assert(not FieldTravel.fly(travel, position, "pokered:ROUTE_4", true, arrival))
        assert(not FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", false, arrival))
        assert(not FieldTravel.fly(travel, position, "pokered:CERULEAN_CITY", true, function() return nil end))
        assert(not pcall(FieldTravel.normalize, {version = 1, mode = "walking", strength = false,
            visited = {"pokered:CERULEAN_CITY", "pokered:CERULEAN_CITY"}}))
        runtimeScene(function(g, _, provider)
            currentZone = provider:ensure(SourceMaps.entry("CeruleanCity").key)
            g.machine:change("overworld", {entry = {x = 19, y = 18, facing = "down"}})
            currentZone = provider:ensure(SourceMaps.entry("PewterCity").key)
            g.machine:change("overworld", {entry = {x = 13, y = 26, facing = "down"}})
            local expected = {epoch = g.session:fieldWorldEpoch(), position = FieldTravelRuntime.position(g),
                world = WorldDeltas.export()}
            local actual = assert(FieldTravel.fly(g.session:fieldTravelData(), expected.position,
                "pokered:CERULEAN_CITY", true, function(entry)
                    return FieldTravelWorld.flyArrival(entry, expected.world, g.sessionLocationPolicy)
                end))
            local oldPlayer, oldManager, oldView = g.player, g.npcManager, getOverworldView()
            local capture = g.session.captureTraversal
            g.session.captureTraversal = function() return false, "injected Fly capture rejection" end
            assert(not FieldTravelRuntime.fly(g, expected, actual))
            g.session.captureTraversal = capture
            assert(g.player == oldPlayer and g.npcManager == oldManager and getOverworldView() == oldView)
            assert(FieldMoves.same(g.session:location(), expected.position))
            assert(FieldMoves.same(WorldDeltas.export(), expected.world))
            assert(FieldTravelRuntime.fly(g, expected, actual))
            assert(g.session:location().zone_id == "pokered:CERULEAN_CITY")
            assert(g.session:location().x == 19 and g.session:location().y == 18)
            assert(g.player.gridX == 19 and g.player.gridY == 18)
            assert(g.session:fieldTravelData().mode == "walking" and not g.session:fieldTravelData().strength)
            local wire = assert(SessionCodec.encode(g.session, {root = "overworld", overworld = "explore", settled = true}))
            assert(SessionCodec.decode(wire, g:getSessionDependencies()))
        end)
    end)
    return report
end
