-- Game behavior contracts for root's real-SDK suite. No harness/driver tests.
BattlePresentationContracts = {}
local gfx <const> = playdate.graphics

local function equal(actual, expected)
    assert(actual == expected, tostring(actual) .. " ~= " .. tostring(expected))
end

local function party(...)
    local roster = Party()
    for _, mon in ipairs({...}) do
        assert(roster:add(mon))
    end
    return roster
end

local function settle(battle, scene, stopAtShift)
    for _ = 1, 10000 do
        scene:update()
        if battle.shiftChoice then
            if stopAtShift then
                return
            end
            assert(battle:declineShift())
        elseif battle.pendingLearning then
            local receipt, mon = battle:takeLearningRequest()
            for _, choice in ipairs(mon:getPendingMoveChoices()) do
                assert(mon:resolveMoveChoice(choice.id, "decline"))
            end
            assert(battle:resumeLearning(receipt))
        elseif battle:phase() ~= "script" then
            return
        elseif not battle.presentationRequest and not scene:isVitalsBlocking() then
            battle.machine:get("script"):advance()
        end
    end
    error("battle presentation did not settle")
end

function BattlePresentationContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local saved = {}
    for _, key in ipairs({"textSpeed", "battleAnimations", "battleStyle"}) do
        saved[key] = GameOptions.get(key)
    end
    local rng = RulesRNG.snapshot()
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end

    test("HP display drains while authoritative damage remains committed", function()
        local player = Pokemon("squirtle", 20)
        local battle = Battle(player, Pokemon("rattata", 5))
        local scene = BattleScene(battle)
        local before = player.hp
        player.hp = 1
        scene:updateVitals()
        local _, shown = scene:shownVitals(player)
        assert(shown < before and shown > player.hp)
        assert(scene:isVitalsBlocking())
        for _ = 1, 60 do
            scene:updateVitals()
        end
        equal(player.hp, 1)
        equal(select(2, scene:shownVitals(player)), 1)
        assert(not scene:isVitalsBlocking())
        scene:exit()
    end)

    test("Earned EXP visibly fills before learning and ends at committed XP", function()
        local player = Pokemon("charmander", 5)
        local enemy = Pokemon("chansey", 30)
        local battle = Battle(player, enemy)
        local scene = BattleScene(battle)
        settle(battle, scene)
        local fromXP = player.xp
        enemy.hp = 0
        battle:runScript(function() return battle:handleFaint("enemy") end)
        local sawIntermediate = false
        local sawLevelEdge = false
        for _ = 1, 10000 do
            scene:update()
            local view = scene:vitals(player)
            if battle.presentationRequest and battle.presentationRequest.kind == "experience" then
                sawIntermediate = sawIntermediate or (view.xp > fromXP and view.xp < player.xp)
                sawLevelEdge = sawLevelEdge or (view.xpLevel < player.level and view.xp == player:xpForLevel(view.xpLevel + 1))
                assert(not battle.pendingLearning)
            elseif battle.pendingLearning then
                equal(view.xp, player.xp)
                break
            elseif battle:phase() ~= "script" then
                break
            elseif not battle.presentationRequest and not scene:isVitalsBlocking() then
                battle.machine:get("script"):advance()
            end
        end
        assert(sawIntermediate and sawLevelEdge)
        equal(scene:vitals(player).xp, player.xp)
        scene:exit()
    end)

    test("Learning replaces the battlefield behind every learning phase", function()
        local state = LearningState({})
        state.active = true
        state.phase = "message"
        state.pokemon = Pokemon("charmander", 7)
        state.dialog:show({"CHARMANDER learned EMBER!"})
        local image = gfx.image.new(400, 240, gfx.kColorBlack)
        gfx.pushContext(image)
        state:draw()
        gfx.popContext()
        equal(image:getPixel(5, 5), gfx.kColorWhite)
        equal(image:getPixel(5, 30), gfx.kColorWhite)
    end)

    test("Application options validate independently of Pokemon and adventure", function()
        local mon = Pokemon("bulbasaur", 5)
        local before = assert(PokemonCodec.encode(mon))
        assert(GameOptions.set("textSpeed", "SLOW"))
        assert(GameOptions.set("battleAnimations", "OFF"))
        assert(GameOptions.set("battleStyle", "SET"))
        equal(GameOptions.textSpeed(), "SLOW")
        equal(GameOptions.battleAnimations(), false)
        equal(GameOptions.battleStyle(), "SET")
        equal(GameOptions.set("textSpeed", "INVALID"), false)
        local after = assert(PokemonCodec.encode(mon))
        equal(json.encode(before), json.encode(after))
    end)

    test("Text speed changes UTF-8 reveal without splitting a character", function()
        local slow = Dialog()
        local fast = Dialog()
        assert(GameOptions.set("textSpeed", "SLOW"))
        slow:show({"Pokémon: a complete sentence."})
        slow:update()
        assert(GameOptions.set("textSpeed", "FAST"))
        fast:show({"Pokémon: a complete sentence."})
        fast:update()
        assert(fast.charIndex > slow.charIndex)
        for _ = 1, 20 do
            fast:update()
            assert(utf8.len(fast.lines[1]:sub(1, fast.charIndex)))
        end
    end)

    test("Animation OFF skips cosmetic waits and preserves RulesRNG", function()
        local battle = Battle(Pokemon("squirtle", 5), Pokemon("rattata", 5))
        local scene = BattleScene(battle)
        settle(battle, scene)
        local before = json.encode(RulesRNG.snapshot())
        assert(GameOptions.set("battleAnimations", "OFF"))
        battle:runScript(function()
            battle:present("sendout", {side = "player", pokemon = battle.player})
            battle:say("Ready!")
        end)
        scene:update()
        equal(battle.presentationRequest, nil)
        equal(scene.playerShown, battle.player)
        equal(json.encode(RulesRNG.snapshot()), before)
        assert(GameOptions.set("battleAnimations", "ON"))
        battle:runScript(function()
            battle:present("move", {side = "player", moveType = "water"})
            battle:say("Done!")
        end)
        scene:update()
        assert(battle.presentationRequest)
        for _ = 1, 30 do
            scene:update()
        end
        equal(battle.presentationRequest, nil)
        equal(json.encode(RulesRNG.snapshot()), before)
        scene:exit()
    end)

    test("Running halves step duration and keeps ordinary walking at eight frames", function()
        local oldZone = currentZone
        currentZone = nil
        local player = Player(1, 1, {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}, NPCManager())
        local ok, problem = pcall(function()
            player:tryMove(1, 0)
            for _ = 1, 7 do
                player:update()
            end
            assert(player.isMoving)
            player:update()
            assert(not player.isMoving and player.stepJustFinished)
            player.running = true
            player:tryMove(-1, 0)
            for _ = 1, 3 do
                player:update()
            end
            assert(player.isMoving)
            player:update()
            assert(not player.isMoving and player.stepJustFinished)
            equal(player.gridX, 1)
        end)
        player:remove()
        currentZone = oldZone
        assert(ok, problem)
    end)

    test("Trainer policy avoids immune damage and redundant status", function()
        local player = Pokemon("diglett", 10)
        local enemy = Pokemon("pikachu", 10)
        enemy.moves = {"thunderShock", "growl"}
        enemy.pp.thunderShock = 10
        enemy.pp.growl = 10
        local battle = Battle(player, enemy, "MISTY")
        battle.trainerClass = "OPP_MISTY"
        for _ = 1, 12 do
            equal(battle:enemyTurn().key, "growl")
        end
        player.status = "poison"
        enemy.moves = {"thunderWave", "tackle"}
        enemy.pp.thunderWave = 10
        enemy.pp.tackle = 10
        battle.trainerClass = "OPP_BUG_CATCHER"
        for _ = 1, 12 do
            equal(battle:enemyTurn().key, "tackle")
        end
    end)

    test("SHIFT offers a free change before replacement while SET does not", function()
        for _, style in ipairs({"SHIFT", "SET"}) do
            assert(GameOptions.set("battleStyle", style))
            assert(GameOptions.set("battleAnimations", "OFF"))
            local lead = Pokemon("squirtle", 20)
            local reserve = Pokemon("pidgey", 20)
            local foe = Pokemon("rattata", 3)
            local incoming = Pokemon("rattata", 4)
            local battle = Battle(lead, foe, "LASS", {party = party(lead, reserve), enemyParty = party(foe, incoming)})
            local scene = BattleScene(battle)
            settle(battle, scene)
            foe.hp = 0
            battle:runScript(function()
                local result = battle:handleFaint("enemy")
                if result ~= "replacement" then
                    return result
                end
                return battle:finishRound()
            end)
            settle(battle, scene, true)
            if style == "SHIFT" then
                assert(battle.shiftChoice)
                assert(battle:beginSelection("party"))
                assert(battle:chooseParty(2))
                settle(battle, scene)
                equal(battle.player, reserve)
                equal(reserve.hp, reserve.maxHP)
            else
                equal(battle.shiftChoice, nil)
                equal(battle.player, lead)
            end
            equal(battle.enemy, incoming)
            equal(battle:phase(), "command")
            scene:exit()
        end
    end)

    for key, value in pairs(saved) do
        GameOptions.set(key, value)
    end
    RulesRNG.restore(rng)
    return report
end
