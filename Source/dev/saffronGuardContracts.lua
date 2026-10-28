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
    return report
end
