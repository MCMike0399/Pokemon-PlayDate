-- Prepared native SDK witnesses. Root applies the owner patch and registration,
-- then executes these against real maps, NPCMotion, dialogs and session owners.
VermilionAmbientContracts = {}
local FAN <const> = "pokered:POKEMON_FAN_CLUB:objects:"
local PIKACHU <const> = "EVENT_PIKACHU_FAN_BOAST"
local SEEL <const> = "EVENT_SEEL_FAN_BOAST"
local function eq(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end
local function same(a, b)
    eq(type(a), type(b))
    if type(a) ~= "table" then
        eq(a, b)
        return
    end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil, "extra field " .. tostring(key)) end
end
local function drain(g)
    for _ = 1, 512 do
        if g.machine:getCurrent() ~= "dialog" then return end
        local state <const> = g.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("ordinary dialogue did not settle")
end
local function scene(name, fn, quest)
    local data <const> = assert(json.decodeFile("data/vermilionPreparation/" .. name .. ".json"))
    local occupied = {}
    for _, group in pairs(data.events) do
        for _, event in ipairs(group) do occupied[event.x .. ":" .. event.y] = true end
    end
    local options
    for y, row in ipairs(data.collision) do
        for x, solid in ipairs(row) do
            if solid == 0 and not occupied[(x - 1) .. ":" .. (y - 1)] then
                options = {x=x - 1, y=y - 1, quest=quest}
                break
            end
        end
        if options then break end
    end
    KantoServicesContracts.withScene(name, assert(options), function(g)
        g.machine:register("event", EventState(g))
        g.machine:register("pokedex", PokedexState(g))
        fn(g, g.machine:get("event"))
    end)
end
local function actor(g, id)
    for _, npc in ipairs(g.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then return npc end
    end
    error("missing source actor " .. id)
end
local function seedByte(g, byte)
    local seed = ((byte + 1) * 23) % 256
    if seed == 0 then seed = 256 end
    g.session:_installWorldMotion({version=1, rng=RulesRNG.new(seed):toData(), actors=g.session:actorData()})
    return seed
end
local function snapshot(g)
    return {flags=g.session:flags(), dex=g.session:pokedex(),
        bag=g.session:inventory():toData(), world=g.session:worldRngData(),
        rules=RulesRNG.toData(), actors=g.session:actorData()}
end
local function observation(g, id)
    local before <const> = snapshot(g)
    local state <const> = EventState.observe(g, id)
    local untouched <const> = GameSession._copy(state)
    local plan <const> = SourceEvents.plan(id, state)
    same(SourceEvents.compile(SourceEvents.descriptor(id), state, id), plan)
    same(state, untouched)
    same(snapshot(g), before)
    return plan
end
function VermilionAmbientContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
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
    for _, index in ipairs({1, 2}) do
        for _, pikachu in ipairs({false, true}) do
            for _, seel in ipairs({false, true}) do
                test("fan " .. index .. " starting flags " .. tostring(pikachu) .. "/" .. tostring(seel), function()
                    scene("PokemonFanClub", function(g, event)
                        local id <const> = FAN .. index
                        local own <const> = index == 1 and PIKACHU or SEEL
                        local other <const> = index == 1 and SEEL or PIKACHU
                        local before <const> = g.session:flags().quest
                        local rng, world = RulesRNG.toData(), g.session:worldRngData()
                        local p <const> = observation(g, id)
                        local label <const> = "_PokemonFanClub" .. (index == 1 and "Pikachu" or "Seel")
                            .. "Fan" .. (before[own] and "BetterText" or "NormalText")
                        eq(p.steps[1].labels[1], label)
                        SourceEvents.dispatch(g, id)
                        eq(event.waiting, label)
                        same(g.session:flags().quest, before)
                        drain(g)
                        eq(g.machine:getCurrent(), "overworld")
                        eq(g.session:questFlag(own), false)
                        local expectedOther = before[other] == true
                        if not before[own] then expectedOther = true end
                        eq(g.session:questFlag(other), expectedOther)
                        same(RulesRNG.toData(), rng)
                        same(g.session:worldRngData(), world)
                        -- Repeat normal/set-already-true and clear branches must
                        -- use the actual repeatable transaction, not reward flags.
                        SourceEvents.dispatch(g, id)
                        drain(g)
                        eq(g.machine:getCurrent(), "overworld")
                        local wire <const> = assert(SessionCodec.encode(g.session,
                            {root="overworld", overworld="explore", settled=true}))
                        local restored <const> = assert(SessionCodec.decode(json.decode(json.encode(wire)), g:getSessionDependencies()))
                        same(restored:flags(), g.session:flags())
                    end, {[PIKACHU]=pikachu, [SEEL]=seel})
                end)
            end
        end
    end
    for _, departed in ipairs({false, true}) do
        test("gambler departure " .. tostring(departed), function()
            scene("VermilionCity", function(g, event)
                local before <const> = snapshot(g)
                observation(g, "pokered:VERMILION_CITY:objects:2")
                SourceEvents.dispatch(g, "pokered:VERMILION_CITY:objects:2")
                eq(event.waiting, departed and "_VermilionCityGambler1SSAnneDepartedText"
                    or "_VermilionCityGambler1DidYouSeeText")
                drain(g)
                same(snapshot(g), before)
            end, {EVENT_SS_ANNE_LEFT=departed})
        end)
    end
    local cries <const> = {
        {"PokemonFanClub", FAN .. 3, "pikachu", true},
        {"PokemonFanClub", FAN .. 4, "seel", true},
        {"VermilionCity", "pokered:VERMILION_CITY:objects:5", "machop", true},
        {"VermilionPidgeyHouse", "pokered:VERMILION_PIDGEY_HOUSE:objects:2", "pidgey", true},
        {"SSAnne1FRooms", "pokered:SS_ANNE_1F_ROOMS:objects:8", "wigglytuff", false},
        {"SSAnneB1FRooms", "pokered:SS_ANNE_B1F_ROOMS:objects:8", "machoke", false},
    }
    for _, case in ipairs(cries) do
        test("ordinary source cry retained without playback " .. case[3], function()
            scene(case[1], function(g, event)
                local before <const> = snapshot(g)
                observation(g, case[2])
                local npc <const> = actor(g, case[2])
                local facing <const> = g.npcManager.motion:actor(npc).facing
                assert(SourceActors.interact(g, npc, case[2]))
                local callback <const> = g.machine:get("dialog").onComplete
                drain(g)
                eq(g.machine:getCurrent(), "overworld")
                eq(#event.audioGaps, 1)
                eq(event.audioGaps[1].species, case[3])
                eq(event.audioGaps[1].wait_for_completion, case[4])
                eq(event.audioGaps[1].owner, "SourceAudio")
                eq(npc.facing, facing)
                callback()
                same(snapshot(g), before)
            end)
        end)
    end
    for _, byte in ipairs({0, 15, 16, 31, 32, 47, 48, 63, 64, 79, 80, 95, 96, 111, 112, 127, 128, 255}) do
        test("chef byte boundary " .. byte, function()
            scene("SSAnneKitchen", function(g, event)
                local id <const> = "pokered:SS_ANNE_KITCHEN:objects:7"
                local seed <const> = seedByte(g, byte)
                local rules, world = RulesRNG.toData(), g.session:worldRngData()
                observation(g, id)
                SourceEvents.dispatch(g, id)
                eq(event.waiting, "_SSAnneKitchenCook7MainCourseIsText")
                same(g.session:worldRngData(), world)
                local prefix <const> = g.machine:get("dialog")
                -- Dismiss only the prefix; inspect selected production dialog.
                while g.machine:getCurrent() == "dialog" and event.waiting == "_SSAnneKitchenCook7MainCourseIsText" do
                    prefix.dialog:advance()
                    prefix:handleInput()
                end
                local suffix <const> = byte >= 128 and "SalmonDuSaladText"
                    or (byte // 16) % 2 == 1 and "EelsAuBarbecueText" or "PrimeBeefSteakText"
                eq(event.waiting, "SSAnneKitchenCook7" .. suffix)
                eq(g.session:worldRngData().rolls, "1")
                eq(g.session:worldRngData().state, tostring(seed * 16807))
                local after <const> = snapshot(g)
                event:draw()
                event:getSnapshot()
                observation(g, id)
                same(snapshot(g), after)
                drain(g)
                same(RulesRNG.toData(), rules)
            end)
        end)
    end
    test("chef cancellation before prefix completion consumes no RNG", function()
        scene("SSAnneKitchen", function(g)
            local before <const> = snapshot(g)
            SourceEvents.dispatch(g, "pokered:SS_ANNE_KITCHEN:objects:7")
            local callback <const> = g.machine:get("dialog").onComplete
            g.machine:pop()
            g.machine:pop()
            callback()
            same(snapshot(g), before)
        end)
    end)
    for _, initiallySeen in ipairs({false, true}) do
        test("gentleman source Dex deferred seen " .. tostring(initiallySeen), function()
            scene("SSAnne2FRooms", function(g, event)
                local id <const> = "pokered:SS_ANNE_2F_ROOMS:objects:5"
                if initiallySeen then assert(g.session:markSeen("snorlax")) end
                local before <const> = snapshot(g)
                observation(g, id)
                SourceEvents.dispatch(g, id)
                same(snapshot(g), before)
                drain(g)
                eq(event.phase, "source-pokedex")
                eq(g.machine:getCurrent(), "pokedex")
                local dex <const> = g.machine:get("pokedex")
                eq(dex:entryView().species, "snorlax")
                eq(dex:entryView().details, nil)
                eq(g.session:pokedex().seen.snorlax == true, initiallySeen)
                dex:draw()
                same(snapshot(g), before)
                assert(dex:back())
                eq(g.machine:getCurrent(), "overworld")
                eq(g.session:pokedex().seen.snorlax, true)
                eq(g.session:pokedex().owned.snorlax, nil)
                same(g.session:flags(), before.flags)
                same(g.session:worldRngData(), before.world)
                same(RulesRNG.toData(), before.rules)
                same(g.session:inventory():toData(), before.bag)
            end)
        end)
    end
    test("owned Snorlax display retains full data without changing ownership", function()
        scene("SSAnne2FRooms", function(g, event)
            assert(g:recruit(Pokemon("snorlax", 5)))
            local before <const> = snapshot(g)
            SourceEvents.dispatch(g, "pokered:SS_ANNE_2F_ROOMS:objects:5")
            drain(g)
            local dex <const> = g.machine:get("pokedex")
            eq(dex:entryView().owned, true)
            assert(dex:entryView().details)
            eq(event.audioGaps[1].species, "snorlax")
            eq(event.audioGaps[1].volume_before, 0x33)
            eq(event.audioGaps[1].volume_after, 0x77)
            assert(dex:back())
            same(snapshot(g), before)
        end)
    end)
    test("cancelled Dex callback cannot mark seen", function()
        scene("SSAnne2FRooms", function(g)
            local before <const> = snapshot(g)
            SourceEvents.dispatch(g, "pokered:SS_ANNE_2F_ROOMS:objects:5")
            drain(g)
            local callback <const> = g.machine:get("pokedex").sourceDisplay.onComplete
            g.machine:pop()
            g.machine:pop()
            callback()
            same(snapshot(g), before)
        end)
    end)
    test("stale fan flag guard rejects clear atomically", function()
        scene("PokemonFanClub", function(g, event)
            SourceEvents.dispatch(g, FAN .. 1)
            assert(g.session:setQuestFlag(SEEL, true))
            drain(g)
            eq(event.phase, "failed")
            eq(g.session:questFlag(PIKACHU), true)
            eq(g.session:questFlag(SEEL), true)
        end, {[PIKACHU]=true})
    end)
    test("cancelled fan callback cannot write and restores facing", function()
        scene("PokemonFanClub", function(g)
            local npc <const> = actor(g, FAN .. 1)
            local facing <const> = g.npcManager.motion:actor(npc).facing
            local before <const> = snapshot(g)
            assert(SourceActors.interact(g, npc, FAN .. 1))
            local callback <const> = g.machine:get("dialog").onComplete
            g.machine:pop()
            g.machine:pop()
            callback()
            eq(npc.facing, facing)
            same(snapshot(g), before)
        end)
    end)
    for _, replacement in ipairs({"session", "player", "zone"}) do
        test("fan and Dex callbacks reject replaced " .. replacement, function()
            for _, case in ipairs({{"PokemonFanClub", FAN .. 1},
                {"SSAnne2FRooms", "pokered:SS_ANNE_2F_ROOMS:objects:5"}}) do
                scene(case[1], function(g, event)
                    SourceEvents.dispatch(g, case[2])
                    if case[1] == "SSAnne2FRooms" then drain(g) end
                    local callback
                    if g.machine:getCurrent() == "dialog" then
                        callback = g.machine:get("dialog").onComplete
                    else
                        callback = g.machine:get("pokedex").sourceDisplay.onComplete
                    end
                    local session, player, zone = g.session, g.player, currentZone
                    local before <const> = snapshot(g)
                    if replacement == "session" then g.session = GameContext().session
                    elseif replacement == "player" then g.player = nil
                    else currentZone = nil end
                    callback()
                    g.session, g.player, currentZone = session, player, zone
                    same(snapshot(g), before)
                    assert(event.phase ~= "complete")
                end)
            end
        end)
    end
    test("source owner rejects unguarded writes and stale seen atomically", function()
        scene("PokemonFanClub", function(g)
            local before <const> = snapshot(g)
            eq(g.session:transactSourceEffects({flags={}, seen={}},
                {flags={[PIKACHU]=true}, seen={}}), false)
            same(snapshot(g), before)
            assert(g.session:markSeen("snorlax"))
            eq(g.session:transactSourceEffects({flags={[PIKACHU]=false}, seen={snorlax=false}},
                {flags={[PIKACHU]=true}, seen={snorlax=true}}), false)
            eq(g.session:questFlag(PIKACHU), false)
            eq(g.session:pokedex().owned.snorlax, nil)
        end)
    end)
    for _, cancel in ipairs({false, true}) do
        test("moving Pidgey defers interaction, changed intent cancels " .. tostring(cancel), function()
            scene("VermilionPidgeyHouse", function(g, event)
                local id <const> = "pokered:VERMILION_PIDGEY_HOUSE:objects:2"
                local npc <const> = actor(g, id)
                local motion <const> = g.npcManager.motion
                g.player.gridX, g.player.gridY = npc.gridX, npc.gridY + 1
                g.player.facing = "up"
                local moving
                for _ = 1, 2048 do
                    motion:tick()
                    moving = motion:actor(npc)
                    if moving.phase == "moving" then break end
                end
                eq(moving.phase, "moving")
                g.player.gridX, g.player.gridY = moving.target_x, moving.target_y + 1
                g.player.facing = "up"
                eq(currentZone.collision[g.player.gridY + 1][g.player.gridX + 1], 0)
                local before <const> = g.session:worldRngData()
                local rules <const> = RulesRNG.toData()
                assert(SourceActors.interact(g, npc, id))
                eq(g.machine:getCurrent(), "overworld")
                same(g.session:worldRngData(), before)
                if cancel then g.player.facing = "down" end
                for _ = 1, 9 do
                    motion:tick()
                    if g.machine:getCurrent() == "dialog" then break end
                end
                if cancel then
                    eq(g.machine:getCurrent(), "overworld")
                    eq(#(event.audioGaps or {}), 0)
                else
                    eq(g.machine:getCurrent(), "dialog")
                    local settled <const> = g.session:worldRngData()
                    for _ = 1, 4 do
                        motion:tick()
                        event:draw()
                    end
                    same(g.session:worldRngData(), settled)
                    drain(g)
                    eq(npc.facing, moving.facing)
                    eq(#event.audioGaps, 1)
                    same(g.session:worldRngData(), settled)
                end
                same(RulesRNG.toData(), rules)
            end)
        end)
    end
    test("ordinary registry rejects overlap for every newly bound actor", function()
        SourceEvents._withSources(function()
            local data <const> = assert(json.decodeFile("data/vermilionPreparation/events.json"))
            for id, descriptor in pairs(data.events) do
                if SourceEvents.has(id, "vermilion") then
                    local candidate <const> = GameSession._copy(descriptor)
                    candidate.content = "ambient-overlap"
                    eq(pcall(SourceEvents.registerEventSource, "ambient-overlap", {[id]=candidate}), false)
                end
            end
        end)
    end)
    return report
end
