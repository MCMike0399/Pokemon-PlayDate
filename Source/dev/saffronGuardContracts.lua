-- Prepared actual SDK contracts. Root installs the package and facing patch.
-- No host Lua interpreter, emulated SDK or runtime acceptance claim.
SaffronGuardContracts = {}
local function eq(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function same(actual, expected)
    if type(actual) ~= "table" or type(expected) ~= "table" then
        eq(actual, expected)
        return
    end
    for key, value in pairs(actual) do same(value, expected[key]) end
    for key in pairs(expected) do assert(actual[key] ~= nil, "missing " .. tostring(key)) end
end
local function drain(game)
    for _ = 1, 128 do
        if game.machine:getCurrent() ~= "dialog" then return end
        local state <const> = game.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("guard dialog did not settle")
end
local function settle(game)
    drain(game)
    for _ = 1, 16 do
        if game.machine:getCurrent() ~= "event" then break end
        game.machine:get("event"):update()
    end
    eq(game.machine:getCurrent(), "overworld")
end
local function actor(game, id)
    for _, npc in ipairs(game.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then return npc end
    end
    error("actual source guard missing")
end
local directions = {up={0,-1}, down={0,1}, left={-1,0}, right={1,0}}
local opposite = {up="down", down="up", left="right", right="left"}
local function scene(guard, point, fn)
    KantoServicesContracts.withScene(guard.map, {x=point.x, y=point.y}, fn)
end
local function observe(game, id, mode)
    return EventState.observe(game, id, {mode=mode or "talk"})
end
function SaffronGuardContracts.run()
    local report <const> = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    local definitions <const> = SaffronGuards.definitions()
    local flag <const> = definitions.flag
    test("guard-exact-source-paragraphs", function()
        local pages <const> = EventText.pagesFrom(definitions.thirsty, SaffronGuards.text)
        eq(#pages, 2)
        eq(pages[1].text, "I'm on guard duty. Gee, I'm thirsty, though!")
        eq(pages[2].text, "Oh wait there, the road's closed.")
        local accepted <const> = EventText.pagesFrom(definitions.accepted, SaffronGuards.text)
        eq(#accepted, 2)
        eq(accepted[1].text, "Whoa, boy! I'm parched! ... Huh? I can have this drink? Gee, thanks!")
        eq(accepted[2].text, "... Glug glug... ... Gulp... If you want to go to SAFFRON CITY... ... You can go on through. I'll share this with the other guards!")
        local completed <const> = EventText.pagesFrom(definitions.completed, SaffronGuards.text)
        eq(#completed, 1)
        eq(completed[1].text, "Hi, thanks for the cool drinks!")
    end)
    for id, guard in pairs(definitions.guards) do
        if guard.active then
            for _, point in ipairs(guard.trigger) do
                for _, facing in ipairs({"up", "down", "left", "right"}) do
                    test(id .. "-entry-" .. point.x .. "-" .. facing, function()
                        scene(guard, point, function(game)
                            game.player.facing = facing
                            game.player:updateSprite()
                            local rules <const> = RulesRNG.toData()
                            local world <const> = game.session:worldRngData()
                            assert(SourceEvents.worldHook("explore", game))
                            eq(game.machine:getCurrent(), "dialog")
                            eq(game.player.facing, guard.entry_facing)
                            eq(game.player.gridY, point.y)
                            assert(not SourceEvents.worldHook("explore", game))
                            drain(game)
                            local event <const> = game.machine:get("event")
                            eq(event.phase, "move")
                            assert(game.player.isMoving)
                            for _ = 1, 7 do event:update() end
                            assert(game.player.isMoving, "source pushback must interpolate")
                            event:update()
                            eq(game.machine:getCurrent(), "overworld")
                            eq(game.player.gridY, point.y + directions[guard.entry_push][2])
                            eq(game.player.gridX, point.x + SourceMaps.entry(guard.map).padding + directions[guard.entry_push][1])
                            assert(not game.session:questFlag(flag))
                            assert(not SourceEvents.worldHook("explore", game))
                            same(RulesRNG.toData(), rules)
                            same(game.session:worldRngData(), world)
                        end)
                    end)
                end
            end
            test(id .. "-talk-push-up-restores-guard", function()
                local point = guard.trigger[1]
                for _, candidate in ipairs(guard.trigger) do
                    if math.abs(candidate.x - guard.actor.x) + math.abs(candidate.y - guard.actor.y)
                        < math.abs(point.x - guard.actor.x) + math.abs(point.y - guard.actor.y) then
                        point = candidate
                    end
                end
                scene(guard, point, function(game)
                    game.player.facing = opposite[guard.actor.facing]
                    game.player:updateSprite()
                    local npc <const> = actor(game, id)
                    local pose <const> = game.npcManager.motion:actor(npc)
                    assert(KantoWorld.tryInteract(game), "real across-counter talk required")
                    eq(game.machine:getCurrent(), "dialog")
                    settle(game)
                    eq(game.player.gridY, point.y - 1)
                    eq(npc.facing, pose.facing)
                    same(game.npcManager.motion:actor(npc), pose)
                end)
            end)
            test(id .. "-talk-turn-cancel-restores-source-pose", function()
                local point = guard.actor.facing == "down" and {x=guard.actor.x-1, y=guard.actor.y}
                    or {x=guard.actor.x, y=guard.actor.y + (guard.actor.facing == "right" and -1 or 1)}
                scene(guard, point, function(game)
                    game.player.facing = guard.actor.facing == "down" and "right"
                        or guard.actor.facing == "right" and "down" or "up"
                    game.player:updateSprite()
                    local npc <const> = actor(game, id)
                    local pose <const> = game.npcManager.motion:actor(npc)
                    assert(KantoWorld.tryInteract(game))
                    eq(game.machine:getCurrent(), "dialog")
                    assert(npc.facing ~= pose.facing, "talk must actually turn the guard")
                    game.machine:pop()
                    game.machine:pop()
                    eq(npc.facing, pose.facing)
                    same(game.npcManager.motion:actor(npc), pose)
                    eq(game.player.gridY, point.y)
                end)
            end)
            test(id .. "-trigger-pending-transport-and-unfinished-step", function()
                scene(guard, guard.trigger[1], function(game)
                    for _, key in ipairs({"pendingEdgeDoor", "pendingConnection", "isMoving"}) do
                        local previous <const> = game.player[key]
                        game.player[key] = true
                        local claimed <const> = SourceEvents.worldHook("explore", game)
                        game.player[key] = previous
                        assert(not claimed)
                        eq(game.machine:getCurrent(), "overworld")
                    end
                    assert(SourceEvents.worldHook("explore", game))
                    settle(game)
                end)
            end)
            test(id .. "-cancel-before-and-during-push-retry", function()
                scene(guard, guard.trigger[1], function(game)
                    local point <const> = guard.trigger[1]
                    assert(SourceEvents.worldHook("explore", game))
                    local callback <const> = game.machine:get("dialog").onComplete
                    game.machine:pop()
                    game.machine:pop()
                    callback()
                    eq(game.machine:getCurrent(), "overworld")
                    eq(game.player.gridY, point.y)
                    assert(not game.session:questFlag(flag))
                    assert(SourceEvents.worldHook("explore", game))
                    drain(game)
                    game.machine:get("event"):update()
                    game.machine:pop()
                    assert(not game.player.isMoving)
                    eq(game.player.gridY, point.y)
                    assert(SourceEvents.worldHook("explore", game))
                    settle(game)
                end)
            end)
            for _, replacement in ipairs({"session", "player", "zone"}) do
                test(id .. "-stale-" .. replacement, function()
                    scene(guard, guard.trigger[1], function(game)
                        assert(SourceEvents.worldHook("explore", game))
                        local callback <const> = game.machine:get("dialog").onComplete
                        game.machine:pop()
                        local original <const> = replacement == "zone" and currentZone or game[replacement]
                        if replacement == "zone" then currentZone = {} else game[replacement] = {} end
                        callback()
                        eq(game.machine:getCurrent(), "event")
                        assert(not game.player.isMoving)
                        if replacement == "zone" then currentZone = original else game[replacement] = original end
                        game.machine:pop()
                        assert(not game.session:questFlag(flag))
                    end)
                end)
            end
            test(id .. "-drink-atomic-priority-duplicate-stale", function()
                scene(guard, guard.trigger[1], function(game)
                    local bag <const> = game.session:inventory()
                    for _, item in ipairs(definitions.drinks) do assert(bag:add(item, 2)) end
                    local observation <const> = observe(game, id)
                    local snapshot <const> = bag:toData()
                    local plan <const> = SaffronGuards.plan(id, observation)
                    same(bag:toData(), snapshot)
                    same(observe(game, id), observation)
                    eq(plan.changes.items[1].id, "freshWater")
                    assert(game.session:transact(plan.expected, plan.changes))
                    eq(bag:quantity("freshWater"), 1)
                    eq(bag:quantity("sodaPop"), 2)
                    assert(game.session:questFlag(flag))
                    assert(not game.session:transact(plan.expected, plan.changes))
                    eq(bag:quantity("freshWater"), 1)
                    assert(not SourceEvents.worldHook("explore", game))
                    assert(SourceEvents.dispatch(game, id))
                    settle(game)
                    eq(bag:quantity("freshWater"), 1)
                    assert(game.session:setQuestFlag(flag, false))
                    local stale <const> = SaffronGuards.plan(id, observe(game, id))
                    assert(bag:add("lemonade", 1))
                    assert(not game.session:transact(stale.expected, stale.changes))
                    assert(not game.session:questFlag(flag))
                end)
            end)
            for index, selected in ipairs(definitions.drinks) do
                test(id .. "-drink-priority-" .. selected, function()
                    scene(guard, guard.trigger[1], function(game)
                        for position = index, #definitions.drinks do
                            assert(game.session:inventory():add(definitions.drinks[position], 1))
                        end
                        local rules <const> = RulesRNG.toData()
                        local world <const> = game.session:worldRngData()
                        local plan <const> = SaffronGuards.plan(id, observe(game, id))
                        eq(plan.changes.items[1].id, selected)
                        assert(SourceEvents.dispatch(game, id))
                        eq(game.session:inventory():quantity(selected), 0)
                        assert(game.session:questFlag(flag))
                        local event <const> = game.machine:get("event")
                        event:draw()
                        same(RulesRNG.toData(), rules)
                        same(game.session:worldRngData(), world)
                        settle(game)
                    end)
                end)
            end
            test(id .. "-drink-real-event-receipt-and-empty-party-plan", function()
                scene(guard, guard.trigger[1], function(game)
                    assert(game.session:inventory():add("sodaPop", 1))
                    assert(SourceEvents.worldHook("explore", game))
                    assert(game.session:questFlag(flag))
                    eq(game.session:inventory():quantity("sodaPop"), 0)
                    eq(game.machine:getCurrent(), "dialog")
                    settle(game)
                    eq(game.player.gridY, guard.trigger[1].y)
                    local empty <const> = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
                    assert(empty.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
                    eq(empty.session:party():count(), 0)
                    local plan <const> = SaffronGuards.plan(id, EventState.observe(empty, id, {mode="talk"}))
                    eq(plan.status, "thirsty")
                    eq(plan.expected, nil)
                end)
            end)
        else
            test(id .. "-declaration-only", function()
                eq(SaffronGuards.descriptors()[id], nil)
                assert(not SourceEvents.has(id))
            end)
        end
    end
    local SILPH_BLOCKER <const> = "pokered:SAFFRON_CITY:objects:14"
    local SILPH_SLEEPING <const> = "pokered:SAFFRON_CITY:objects:15"
    -- Pre-fix saved actor list: the corrected Fuji rule hides the door Rocket,
    -- but the old save also retained the sleeping Rocket.
    local function savedGuards()
        local world <const> = WorldDeltas.export()
        local descriptor <const> = assert(SourceActors.describe("pokered:SAFFRON_CITY", world))
        local before <const> = {quest = {EVENT_RESCUED_MR_FUJI=false, EVENT_BEAT_SILPH_CO_GIOVANNI=false}}
        local saved <const> = WorldMotionData.reconcile(nil, descriptor, before)
        for _, spec in ipairs(descriptor.actors) do
            if spec.id == SILPH_SLEEPING then
                saved.actors[#saved.actors + 1] = WorldMotionData.initial(spec)
            end
        end
        saved.count = #saved.actors
        table.sort(saved.actors, function(a, b)
            return a.id < b.id
        end)
        local index = {}
        for _, actor in ipairs(saved.actors) do
            index[actor.id] = true
        end
        assert(index[SILPH_BLOCKER], "pre-rescue save must contain the door Rocket")
        assert(index[SILPH_SLEEPING], "pre-fix save must contain the sleeping Rocket")
        local after <const> = {quest = {EVENT_RESCUED_MR_FUJI=true, EVENT_BEAT_SILPH_CO_GIOVANNI=false}}
        local location <const> = {zone_id=descriptor.zone_id, x=0, y=23, facing="left"}
        return world, descriptor, saved, location, after, before
    end
    local function saffronDoor(quest, fn)
        KantoServicesContracts.withScene("SaffronCity", {x=18, y=23, facing="up", quest=quest}, fn)
    end
    local function findActor(game, id)
        for _, npc in ipairs(game.npcManager.npcs) do
            if npc.def and npc.def.source_event_id == id then return npc end
        end
    end
    local function doorActors(quest)
        local seen <const> = {}
        saffronDoor(quest, function(game)
            seen[1] = findActor(game, SILPH_BLOCKER)
            seen[2] = findActor(game, SILPH_SLEEPING)
            seen.blocker = game.npcManager:getNPCAt(18, 22)
        end)
        return seen
    end
    test("saffron-silph-door-rocket-needs-unrescued-fuji", function()
        local before <const> = doorActors({})
        assert(before[1], "unrescued Fuji keeps the source Silph door Rocket")
        eq(before[2], nil)
        eq(before.blocker, before[1])
        local rescued <const> = doorActors({EVENT_RESCUED_MR_FUJI=true})
        eq(rescued[1], nil)
        assert(rescued[2], "Fuji rescue reveals the sleeping source Rocket")
        eq(rescued.blocker, nil)
    end)
    test("saffron-silph-guards-hide-on-source-completion", function()
        for _, fuji in ipairs({false, true}) do
            local quest <const> = {EVENT_BEAT_SILPH_CO_GIOVANNI=true}
            if fuji then quest.EVENT_RESCUED_MR_FUJI = true end
            local seen <const> = doorActors(quest)
            eq(seen[1], nil)
            eq(seen[2], nil)
            eq(seen.blocker, nil)
        end
    end)
    test("saffron-saved-guard-actor-prunes-under-corrected-visibility", function()
        local _, descriptor, saved, location, after = savedGuards()
        local canonical, dropped = WorldMotionData.normalize(saved, descriptor, location, after)
        eq(#dropped, 1)
        eq(dropped[1], SILPH_BLOCKER)
        eq(#canonical.actors, #saved.actors - 1)
        local kept = {}
        for _, actor in ipairs(canonical.actors) do
            assert(actor.id ~= SILPH_BLOCKER, "hidden guard survived saved actor normalization")
            kept[actor.id] = true
        end
        assert(kept[SILPH_SLEEPING], "still-visible sleeping Rocket must be retained")
        local missing <const> = {version=1, zone_id=saved.zone_id,
            definition_revision=saved.definition_revision, count=0, actors={}}
        for _, actor in ipairs(saved.actors) do
            if actor.id ~= SILPH_SLEEPING then
                missing.actors[#missing.actors + 1] = actor
            end
        end
        missing.count = #missing.actors
        eq(pcall(WorldMotionData.normalize, missing, descriptor, location, after), false)
    end)
    test("saffron-hidden-actor-records-require-complete-structure", function()
        local _, descriptor, saved, location, after = savedGuards()
        local function rejected(mutator)
            local payload <const> = GameSession._copy(saved)
            local hidden
            for _, actor in ipairs(payload.actors) do
                if actor.id == SILPH_BLOCKER then hidden = actor end
            end
            assert(hidden, "saved hidden guard required")
            mutator(hidden, payload)
            assert(not pcall(WorldMotionData.normalize, payload, descriptor, location, after),
                "malformed hidden actor was accepted")
        end
        rejected(function(actor) actor.x = nil end)
        rejected(function(actor) actor.delay_raw = nil end)
        rejected(function(actor) actor.x = -1 end)
        rejected(function(actor) actor.y = descriptor.height end)
        rejected(function(actor) actor.facing = "sideways" end)
        rejected(function(actor) actor.tick = 8 end)
        rejected(function(actor) actor.delay_left = 129 end)
        rejected(function(actor) actor.phase = "unknown" end)
        rejected(function(actor) actor.origin_x = actor.origin_x + 1 end)
        rejected(function(_, payload) payload.count = payload.count + 1 end)
        rejected(function(_, payload)
            payload.actors[#payload.actors + 1] = GameSession._copy(payload.actors[1])
            payload.count = #payload.actors
        end)
        rejected(function(actor) actor.id = "pokered:SAFFRON_CITY:objects:999" end)
    end)
    test("saffron-session-actor-boundary-accepts-only-proven-hidden-removal", function()
        local world, _, saved, location, after, before = savedGuards()
        local snapshot <const> = GameSession._copy(saved)
        local deps <const> = {validateActors=SourceActors.validate, hiddenActors=SourceActors.hidden}
        local canonical = GameSession._validateActors(deps, saved, world, location, after)
        same(saved, snapshot)
        eq(#canonical.actors, #saved.actors - 1)
        assert(canonical ~= saved and canonical.actors ~= saved.actors,
            "actor boundary returned a shared owner record")
        local staleFlags <const> = {validateActors=function(payload, candidateWorld, position)
            return SourceActors.validate(payload, candidateWorld, position, after)
        end, hiddenActors=SourceActors.hidden}
        assert(not pcall(GameSession._validateActors, staleFlags, saved, world, location, before),
            "stale candidate flags accepted the removal")
        local function guarded(mutate)
            return {validateActors=function(payload, candidateWorld, position, flags)
                local result = SourceActors.validate(payload, candidateWorld, position, flags)
                mutate(result)
                return result
            end, hiddenActors=SourceActors.hidden}
        end
        local function rejected(mutate, label)
            assert(not pcall(GameSession._validateActors, guarded(mutate), saved, world, location, after),
                "custom validator bypass: " .. label)
        end
        rejected(function(result)
            table.remove(result.actors, 1)
            result.count = #result.actors
        end, "visible actor deletion")
        rejected(function(result)
            result.actors = {}
            result.count = 0
        end, "whole visible collection deletion")
        rejected(function(result)
            local extra <const> = GameSession._copy(result.actors[1])
            extra.id = "pokered:SAFFRON_CITY:objects:999"
            result.actors[#result.actors + 1] = extra
            result.count = #result.actors
        end, "unknown addition")
        rejected(function(result)
            result.actors[1].origin_x = result.actors[1].origin_x + 1
        end, "survivor mutation")
        rejected(function(result)
            result.actors[1].delay_raw = nil
        end, "survivor field loss")
        rejected(function(result)
            result.count = result.count + 1
        end, "wrong count")
        rejected(function(result)
            result.definition_revision = nil
        end, "discarded envelope field")
        rejected(function(result)
            result.zone_id = result.zone_id .. "-changed"
        end, "changed retained field")
    end)
    test("saffron-migration-diagnostic-keeps-raw-and-canonical-distinct", function()
        local world, descriptor, saved, location, after = savedGuards()
        local canonical <const> = assert(WorldMotionData.normalize(saved, descriptor, location, after))
        local payload <const> = {world=world, location=location, questFlags=after.quest,
            trainerFlags={}, worldMotion={version=1, rng={seed=1}, actors=saved}}
        local encoded <const> = {world=world, location=location, questFlags=after.quest,
            trainerFlags={}, worldMotion={version=1, rng={seed=1}, actors=canonical}}
        local receipt <const> = HarnessDiagnostics._actorVisibilityMigration(payload, encoded)
        assert(receipt and receipt.reason == "source-actor-visibility", "genuine migration not reported")
        eq(#receipt.dropped, 1)
        eq(receipt.dropped[1], SILPH_BLOCKER)
        eq(HarnessDiagnostics._actorVisibilityMigration(payload, payload), nil)
        local mutated <const> = GameSession._copy(encoded)
        mutated.worldMotion.actors.actors[1].origin_x = mutated.worldMotion.actors.actors[1].origin_x + 1
        eq(HarnessDiagnostics._actorVisibilityMigration(payload, mutated), nil)
        local unproven <const> = GameSession._copy(encoded)
        table.remove(unproven.worldMotion.actors.actors, 1)
        unproven.worldMotion.actors.count = #unproven.worldMotion.actors.actors
        eq(HarnessDiagnostics._actorVisibilityMigration(payload, unproven), nil)
        local added <const> = GameSession._copy(encoded)
        local extra <const> = GameSession._copy(added.worldMotion.actors.actors[1])
        extra.id = "pokered:SAFFRON_CITY:objects:999"
        added.worldMotion.actors.actors[#added.worldMotion.actors.actors + 1] = extra
        added.worldMotion.actors.count = #added.worldMotion.actors.actors
        eq(HarnessDiagnostics._actorVisibilityMigration(payload, added), nil)
        local retained <const> = GameSession._copy(encoded)
        retained.questFlags = {EVENT_RESCUED_MR_FUJI=false}
        eq(HarnessDiagnostics._actorVisibilityMigration(payload, retained), nil)
    end)
    test("saffron-elevator-menu-confirms-a-floor-and-cancel-moves-none", function()
        local lift <const> = "pokered:SILPH_CO_ELEVATOR:background_events:1"
        local function enter(game)
            -- The elevator scene belongs to the composed midgame event chain;
            -- run the same state class main.lua registers for real play.
            game.machine:register("event", MidgameServicesState(game))
            assert(SourceEvents.dispatch(game, lift))
            -- Dispatch opens the source floor question; draining it exposes the
            -- actual floor menu on the event state.
            drain(game)
            local event <const> = game.machine:get("event")
            eq(event.phase, "silph-floor")
            eq(event.menu.isActive, true)
            eq(#event.menu.options, 11)
            return event
        end
        KantoServicesContracts.withScene("SilphCoElevator", {x=3, y=1, facing="up"}, function(game)
            local event = enter(game)
            event:handleButton("down")
            eq(event.menu.selectedIndex, 2)
            event:handleButton("a")
            eq(game.machine:getCurrent(), "overworld")
            assert(game.session:questFlag("SILPH_STORY_LIFT_V1_2") == true,
                "elevator confirm: " .. tostring(event.phase) .. "/" .. tostring(event.waiting))
            assert(not game.session:questFlag("SILPH_STORY_LIFT_V1_1"))
            -- The actual cabin exits now project to the chosen floor.
            local door <const> = SilphStoryWorld.resolveDoor(game,
                {source_event_id="pokered:SILPH_CO_ELEVATOR:warps:1"})
            eq(door.to, "pokered:SILPH_CO_2F")
        end)
        KantoServicesContracts.withScene("SilphCoElevator", {x=3, y=1, facing="up"}, function(game)
            local event = enter(game)
            event:handleButton("b")
            eq(game.machine:getCurrent(), "overworld")
            for floor = 1, 11 do
                assert(not game.session:questFlag("SILPH_STORY_LIFT_V1_" .. floor))
            end
        end)
    end)
    test("saffron-elevator-all-floors-both-exits-and-persisted-projection", function()
        KantoServicesContracts.withScene("SilphCoElevator", {x=3, y=1, facing="up"}, function(game)
            local floors <const> = SilphStory.scenes().elevator
            eq(#floors, 11)
            -- Explicit floor selection persists exactly one source flag.
            local function floorFlags()
                local values <const> = {}
                for _, other in ipairs(floors) do
                    values[other.floor] = game.session:questFlag(
                        "SILPH_STORY_LIFT_V1_" .. other.floor)
                end
                return values
            end
            for _, entry in ipairs(floors) do
                local before <const> = floorFlags()
                assert(not pcall(SilphStoryWorld.selectFloor, game.session, 0),
                    "unknown floor accepted")
                same(floorFlags(), before)
                assert(SilphStoryWorld.selectFloor(game.session, entry.floor))
                for _, other in ipairs(floors) do
                    eq(game.session:questFlag("SILPH_STORY_LIFT_V1_" .. other.floor),
                        other.floor == entry.floor)
                end
                -- The persisted floor flag selects both exits from the map id,
                -- without another menu confirmation. This is the same session.
                assert(SilphStoryWorld.enterLift(game.session, entry.map_id))
                for _, exit in ipairs({"warps:1", "warps:2"}) do
                    local door <const> = SilphStoryWorld.resolveDoor(game,
                        {source_event_id="pokered:SILPH_CO_ELEVATOR:" .. exit})
                    eq(door.to, entry.map_id)
                    eq(door.toX, entry.destination.x + SilphStory.padding(entry.map_id))
                    eq(door.toY, entry.destination.y)
                end
                local bindings <const> = SilphStoryWorld.elevatorBindings(game.session)
                for index = 1, 2 do
                    local bound <const> = assert(bindings["pokered:SILPH_CO_ELEVATOR:warps:" .. index])
                    eq(bound.to, entry.map_id)
                    eq(bound.toX, entry.destination.x + SilphStory.padding(entry.map_id))
                    eq(bound.toY, entry.destination.y)
                end
            end
            -- Floor 12 is rejected before any flag write. The floor selected
            -- above stays set. selectFloor(0) already checks a rejection
            -- leaves the current flags unchanged.
            assert(not pcall(SilphStoryWorld.selectFloor, game.session, 12))
        end)
    end)
    test("saffron-silph-guard-metadata-is-static-pure-source-conditions", function()
        local scenes <const> = SilphStory.scenes()
        assert(scenes.fuji_rescue and #scenes.fuji_rescue.hides == 1 and #scenes.fuji_rescue.shows == 1,
            "source Fuji transition missing: " .. json.encode(scenes.fuji_rescue))
        local blocker <const> = SilphStory.actorMetadata(SILPH_BLOCKER)
        eq(#blocker.visibility, 2)
        eq(blocker.visibility[1].group, "quest")
        eq(blocker.visibility[1].id, "EVENT_BEAT_SILPH_CO_GIOVANNI")
        eq(blocker.visibility[1].equals, false)
        eq(blocker.visibility[2].id, "EVENT_RESCUED_MR_FUJI")
        eq(blocker.visibility[2].equals, false)
        local sleeping <const> = SilphStory.actorMetadata(SILPH_SLEEPING)
        eq(#sleeping.visibility, 2)
        eq(sleeping.visibility[1].id, "EVENT_BEAT_SILPH_CO_GIOVANNI")
        eq(sleeping.visibility[1].equals, false)
        eq(sleeping.visibility[2].id, "EVENT_RESCUED_MR_FUJI")
        eq(sleeping.visibility[2].equals, true)
        -- Neighbouring completion toggles keep exactly one source condition.
        local worker <const> = SilphStory.actorMetadata("pokered:SAFFRON_CITY:objects:9")
        eq(#worker.visibility, 1)
        eq(worker.visibility[1].equals, true)
        eq(SilphStory.actorMetadata("pokered:SAFFRON_CITY:objects:2").visibility[1].equals, false)
    end)
    return report
end
