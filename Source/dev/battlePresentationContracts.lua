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

-- Compare the real SDK render against the pinned asset through an independent
-- image context. These helpers never advance a presentation or battle clock.
local function substituteScene(side, withParty)
    local lead = Pokemon("snorlax", 100)
    local roster = withParty and party(lead, Pokemon("blastoise", 100)) or nil
    local battle = Battle(lead, Pokemon("snorlax", 100), nil, roster and {party=roster} or nil)
    for _ = 1, 100 do
        if battle:phase() ~= "script" then break end
        battle.machine:get("script"):advance()
    end
    assert(battle:phase() == "command")
    local scene = BattleScene(battle)
    local say = battle.say
    battle.say = function() end
    assert(battle.conditions:createSubstitute(battle[side]))
    battle.say = say
    return battle, scene, battle[side]
end
local function renderPicture(fn)
    local image = assert(gfx.image.new(112, 112, gfx.kColorWhite))
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.clearClipRect()
    local ok, problem = pcall(fn)
    gfx.clearClipRect()
    gfx.popContext()
    assert(ok, problem)
    return image
end
local function equalPictures(actual, expected)
    for y = 0, 111 do
        for x = 0, 111 do
            assert(actual:sample(x, y) == expected:sample(x, y), "picture differs at " .. x .. "," .. y)
        end
    end
end
local function referencePicture(path, size, drop)
    return renderPicture(function()
        gfx.setClipRect(16, 16, 80, 80)
        local image = assert(gfx.image.new(path))
        local w, h = image:getSize()
        local scale = math.min(size / w, size / h)
        image:drawScaled(16 + (80 - size) // 2 + math.floor((size - math.floor(w * scale)) / 2),
            16 + (80 - size) // 2 + drop + math.floor((size - math.floor(h * scale)) / 2), scale)
    end)
end
-- Same placement as referencePicture, without the slot clip, so a faint
-- slide can leave ink below the 80-pixel window.
local function openPicture(path, size, drop)
    return renderPicture(function()
        local image = assert(gfx.image.new(path))
        local w, h = image:getSize()
        local scale = math.min(size / w, size / h)
        image:drawScaled(16 + (80 - size) // 2 + math.floor((size - math.floor(w * scale)) / 2),
            16 + (80 - size) // 2 + drop + math.floor((size - math.floor(h * scale)) / 2), scale)
    end)
end
-- Player backs keep referencePicture's scale and horizontal center, then move
-- the lowest black row of that scaled bitmap onto the slot's last line.
local function playerBackPicture(path, size, drop)
    local image = assert(gfx.image.new(path))
    local w, h = image:getSize()
    local scale = math.min(size / w, size / h)
    local sw = math.max(1, math.floor(w * scale))
    local sh = math.max(1, math.floor(h * scale))
    local scaled = assert(gfx.image.new(sw, sh, gfx.kColorWhite))
    gfx.pushContext(scaled)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    image:drawScaled(0, 0, scale)
    gfx.popContext()
    local inkBottom = nil
    for row = sh - 1, 0, -1 do
        for col = 0, sw - 1 do
            if scaled:sample(col, row) == gfx.kColorBlack then
                inkBottom = row
                break
            end
        end
        if inkBottom ~= nil then break end
    end
    return renderPicture(function()
        gfx.setClipRect(16, 16, 80, 80)
        local dx = 16 + (80 - size) // 2 + math.floor((size - sw) / 2)
        local dy = 16 + (80 - size) // 2 + drop + math.floor((size - sh) / 2)
        if inkBottom ~= nil then
            dy = 16 + drop + 79 - inkBottom
        end
        scaled:draw(dx, dy)
    end)
end
local function lowestBlackRow(image)
    for y = 111, 0, -1 do
        for x = 0, 111 do
            if image:sample(x, y) == gfx.kColorBlack then
                return y
            end
        end
    end
    return nil
end
local function commandScene(playerSpecies, enemySpecies)
    local battle = Battle(Pokemon(playerSpecies, 50), Pokemon(enemySpecies, 5))
    for _ = 1, 100 do
        if battle:phase() ~= "script" then break end
        battle.machine:get("script"):advance()
    end
    assert(battle:phase() == "command")
    return battle, BattleScene(battle), battle.player, battle.enemy
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
        equal(image:sample(5, 5), gfx.kColorWhite)
        equal(image:sample(5, 30), gfx.kColorWhite)
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

    test("Intro HUDs appear with each presented Pokemon, including Animation OFF", function()
        for _, animations in ipairs({"ON", "OFF"}) do
            assert(GameOptions.set("battleAnimations", animations))
            local battle = Battle(Pokemon("charmander", 20), Pokemon("weepinbell", 20), "COOLTRAINER")
            battle.trainerClass = "OPP_COOLTRAINER_F"
            local scene = BattleScene(battle)
            local enemyBars, playerBars = 0, 0
            local drawHPBar = scene.drawHPBar
            scene.drawHPBar = function(self, x, ...)
                if x < 200 then
                    enemyBars = enemyBars + 1
                else
                    playerBars = playerBars + 1
                end
                drawHPBar(self, x, ...)
            end
            local image = gfx.image.new(400, 240, gfx.kColorWhite)
            local function hud(enemy, player)
                enemyBars, playerBars = 0, 0
                gfx.pushContext(image)
                local ok, problem = pcall(scene.drawBattleField, scene)
                gfx.popContext()
                assert(ok, problem)
                equal(enemyBars, enemy and 1 or 0)
                equal(playerBars, player and 1 or 0)
            end
            local function advance()
                assert(not battle.presentationRequest)
                battle.machine:get("script"):advance()
            end
            local function finishVisual(kind)
                equal(battle.presentationRequest.kind, kind)
                local duration = animations == "ON" and 20 or 1
                for _ = 1, duration do
                    scene:updatePresentation()
                end
                equal(battle.presentationRequest, nil)
            end
            hud(false, false) -- Trainer portrait / wants to battle.
            advance()
            hud(false, false)
            finishVisual("trainerExit")
            equal(scene.trainerVisible, false)
            hud(false, false) -- Enemy send-out narration, before the ball.
            advance()
            equal(battle.presentationRequest.kind, "sendout")
            if animations == "ON" then
                for _ = 1, 9 do
                    scene:updatePresentation()
                    hud(false, false) -- Ball flight has no Pokemon HUD yet.
                end
                scene:updatePresentation()
                hud(true, false) -- Pokemon materializes on frame ten.
                for _ = 11, 20 do
                    scene:updatePresentation()
                end
            else
                scene:updatePresentation()
            end
            equal(battle.presentationRequest, nil)
            hud(true, false) -- Player's Go narration still hides player HUD.
            advance()
            equal(battle.presentationRequest.kind, "sendout")
            if animations == "ON" then
                for _ = 1, 9 do
                    scene:updatePresentation()
                    hud(true, false)
                end
                scene:updatePresentation()
                hud(true, true)
                for _ = 11, 20 do
                    scene:updatePresentation()
                end
            else
                scene:updatePresentation()
            end
            equal(battle.presentationRequest, nil)
            equal(battle:phase(), "command")
            hud(true, true)
            scene:exit()
        end
        -- Wild opponents are already presented on entry; the player is not.
        local wild = Battle(Pokemon("charmander", 20), Pokemon("weepinbell", 20))
        local scene = BattleScene(wild)
        equal(scene.enemyShown, wild.enemy)
        equal(scene.playerShown, nil)
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
        battle.trainerClass = BattleState.trainerClassFor("pokered:CERULEAN_GYM:objects:1")
        equal(battle.trainerClass, "OPP_MISTY")
        equal(BattleState.trainerClassFor("pokered:SS_ANNE_2F:objects:2", {name = "BLUE"}), "OPP_RIVAL2")
        equal(BattleState.trainerClassFor(nil, {name = "MISTY"}), nil)
        for _ = 1, 12 do
            equal(battle:enemyTurn().key, "growl")
        end
        player.status = "poison"
        enemy.moves = {"thunderWave", "tackle"}
        enemy.pp.thunderWave = 10
        enemy.pp.tackle = 10
        battle.trainerClass = BattleState.trainerClassFor(nil, {class_source = "OPP_BUG_CATCHER"})
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
            equal(battle:chooseShiftParty(2), false)
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
                local invitation = battle.shiftChoice
                assert(invitation)
                assert(scene:requestSelection("party"))
                equal(scene:takeSelectionRequest().forced, false)
                assert(scene:completeSelection(true))
                equal(battle.shiftChoice, invitation)
                equal(battle:phase(), "script")
                assert(scene.shiftMenu.isActive)
                assert(scene:requestSelection("party"))
                scene:takeSelectionRequest()
                local rejected, reason = battle:chooseParty(1)
                equal(rejected, false)
                equal(reason, "already-active")
                equal(battle.player, lead)
                equal(battle.shiftChoice, invitation)
                equal(battle:chooseParty(99), false)
                equal(battle.shiftChoice, invitation)
                assert(battle:chooseParty(2))
                assert(scene:completeSelection())
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

    test("SHIFT prompt matches the Blue about-to-use text and YES/NO menu", function()
        assert(GameOptions.set("battleStyle", "SHIFT"))
        assert(GameOptions.set("battleAnimations", "OFF"))
        local lead = Pokemon("squirtle", 20)
        local reserve = Pokemon("pidgey", 20)
        local foe = Pokemon("rattata", 3)
        local incoming = Pokemon("gyarados", 20)
        local battle = Battle(lead, foe, "BLUE", {party = party(lead, reserve), enemyParty = party(foe, incoming)})
        local scene = BattleScene(battle)
        settle(battle, scene)
        foe.hp = 0
        battle:runScript(function()
            local result = battle:handleFaint("enemy")
            if result ~= "replacement" then return result end
            return battle:finishRound()
        end)
        settle(battle, scene, true)
        local prompt = "BLUE is about to use GYARADOS!\nWill RED change POKéMON?"
        equal(battle.message, prompt)
        equal(scene.shiftMenu.options[1], "YES")
        equal(scene.shiftMenu.options[2], "NO")
        equal(#scene.shiftMenu.options, 2)
        local image = gfx.image.new(400, 240, gfx.kColorWhite)
        gfx.pushContext(image)
        scene:drawBattleField()
        gfx.popContext()
        equal(scene.textCache["shift-prompt"].text, prompt)
        scene.shiftMenu.onSelect(2)
        equal(battle.shiftChoice, nil)
        equal(battle.player, lead)
        scene:exit()
    end)

    test("Surf draws droplets across the field and water columns at the target", function()
        assert(GameOptions.set("battleAnimations", "ON"))
        local battle, scene = commandScene("blastoise", "pidgeot")
        local function render(details)
            scene.activePresentation = {kind = "move", details = details}
            scene.presentationFrame = 8
            local image = gfx.image.new(400, 240, gfx.kColorWhite)
            gfx.pushContext(image)
            gfx.setDrawOffset(0, 0)
            gfx.clearClipRect()
            scene:drawPresentation()
            gfx.clearClipRect()
            gfx.popContext()
            return image
        end
        local function blackIn(image, x0, y0, x1, y1)
            local count = 0
            for y = y0, y1 do
                for x = x0, x1 do
                    if image:sample(x, y) == gfx.kColorBlack then count = count + 1 end
                end
            end
            return count
        end
        local function tallestRun(image, x0, x1, y0, y1)
            local best = 0
            for x = x0, x1 do
                local run = 0
                for y = y0, y1 do
                    if image:sample(x, y) == gfx.kColorBlack then
                        run = run + 1
                        if run > best then best = run end
                    else
                        run = 0
                    end
                end
            end
            return best
        end
        local surf = render({side = "player", moveType = "water", moveKey = "surf", targetsFoe = true})
        local wave = render({side = "player", moveType = "water", moveKey = "waterGun", targetsFoe = true})
        local agility = render({side = "player", moveType = "psychic", moveKey = "agility", targetsFoe = false})
        assert(blackIn(surf, 8, 8, 70, 150) > 20)
        equal(blackIn(wave, 8, 8, 70, 150), 0)
        assert(tallestRun(surf, 250, 399, 0, 167) > 24)
        assert(tallestRun(wave, 250, 399, 0, 167) < 16)
        assert(blackIn(agility, 70, 80, 130, 150) > 10)
        equal(blackIn(agility, 8, 8, 40, 40), 0)
        equal(scene.presentationFrame, 8)
        scene:exit()
    end)

    test("Faint slides the picture down past the slot until it leaves the field", function()
        local battle, scene, mon, enemy = commandScene("blastoise", "pidgeot")
        scene.enemyShown = enemy
        scene.playerShown = mon
        local function field()
            local image = gfx.image.new(400, 240, gfx.kColorWhite)
            gfx.pushContext(image)
            gfx.setDrawOffset(0, 0)
            gfx.clearClipRect()
            scene:drawBattleField()
            gfx.clearClipRect()
            gfx.popContext()
            return image
        end
        local function slidPixels(shown, side, frame, x0, x1, y0, y1)
            scene.enemyShown = side == "enemy" and shown or nil
            scene.playerShown = side == "player" and shown or nil
            scene.activePresentation = nil
            local plain = field()
            scene.enemyShown = side == "enemy" and shown or enemy
            scene.playerShown = side == "player" and shown or mon
            scene.activePresentation = {kind = "faint", details = {side = side, pokemon = shown}}
            scene.presentationFrame = frame
            local slid = field()
            local count = 0
            for y = y0, y1 do
                for x = x0, x1 do
                    if plain:sample(x, y) == gfx.kColorWhite and slid:sample(x, y) == gfx.kColorBlack then
                        count = count + 1
                    end
                end
            end
            return count
        end
        -- Enemy slot is y=20..100. Frame 8 has dropped 64px, so ink is below it.
        assert(slidPixels(enemy, "enemy", 8, 280, 390, 104, 160) > 30)
        -- Player slot is y=70..150. The back sprite continues past that line.
        assert(slidPixels(mon, "player", 6, 40, 140, 152, 167) > 10)
        scene.activePresentation = {kind = "faint", details = {side = "enemy", pokemon = enemy}}
        scene.presentationFrame = 0
        scene.enemyShown = enemy
        for _ = 1, 20 do scene:updateVisualEvent(scene.activePresentation) end
        equal(scene.enemyShown, nil)
        equal(scene.activePresentation, nil)
        equal(battle.presentationRequest, nil)
        scene:exit()
    end)

    test("Player back sprites share a foot line on the slot bottom", function()
        local slotX, slotY = 16, 16
        local slotBottom = slotY + 79
        local feet = {}
        for _, species in ipairs({"blastoise", "pidgeot", "venusaur", "squirtle"}) do
            local battle, scene, mon = commandScene(species, "rattata")
            local actual = renderPicture(function()
                scene:drawPresentedPokemon(mon, "player", slotX, slotY, true)
            end)
            equal(lowestBlackRow(actual), slotBottom)
            equalPictures(actual, playerBackPicture(PokemonArt.path(species, "back"), 80, 0))
            feet[species] = lowestBlackRow(actual)
            scene:exit()
        end
        equal(feet.blastoise, feet.pidgeot)
        equal(feet.pidgeot, feet.venusaur)
        equal(feet.venusaur, feet.squirtle)
        -- Squirtle is the shorter body. Centering that back leaves a black-free
        -- gap under the ink; the foot anchor puts the ink on the slot's last row.
        local centered = referencePicture(PokemonArt.path("squirtle", "back"), 80, 0)
        local centeredLow = lowestBlackRow(centered)
        assert(centeredLow < slotBottom)
        for row = centeredLow + 1, slotBottom do
            for col = slotX, slotX + 79 do
                assert(centered:sample(col, row) ~= gfx.kColorBlack)
            end
        end
        equal(feet.squirtle, slotBottom)
    end)

    test("Player send-out plants back-sprite feet on the slot bottom", function()
        local slotBottom = 16 + 79
        for _, species in ipairs({"blastoise", "pidgeot", "venusaur", "squirtle"}) do
            local battle, scene, mon = commandScene(species, "rattata")
            for _, frame in ipairs({10, 19}) do
                local size = math.min(80, math.max(4, (frame - 9) * 8))
                scene.activePresentation = {kind = "sendout", details = {side = "player", pokemon = mon}}
                scene.presentationFrame = frame
                local actual = renderPicture(function()
                    scene:drawPresentedPokemon(mon, "player", 16, 16, true)
                end)
                equal(lowestBlackRow(actual), slotBottom)
                equalPictures(actual, playerBackPicture(PokemonArt.path(species, "back"), size, 0))
                equal(scene.presentationFrame, frame)
                equal(scene.activePresentation.kind, "sendout")
            end
            scene:exit()
        end
    end)

    test("Enemy front stays on the centered reference picture", function()
        local battle, scene, _, enemy = commandScene("rattata", "blastoise")
        local actual = renderPicture(function()
            scene:drawPresentedPokemon(enemy, "enemy", 16, 16, false)
        end)
        equalPictures(actual, referencePicture(PokemonArt.path("blastoise", "front"), 80, 0))
        scene:exit()
    end)

    test("Substitute front and back render exact pinned source canvases without a numeric doll HUD", function()
        for _, side in ipairs({"enemy", "player"}) do
            local battle, scene, mon = substituteScene(side)
            local back = side == "player"
            local hp = mon.hp
            local before = RulesRNG.snapshot()
            local actual = renderPicture(function() scene:drawPresentedPokemon(mon, side, 16, 16, back) end)
            local path = "images/battle-effects/substitute-" .. (back and "back" or "front")
            local expected = back and playerBackPicture(path, 80, 0) or referencePicture(path, 80, 0)
            equalPictures(actual, expected)
            equal(mon.hp, hp)
            equal(RulesRNG.snapshot().state, before.state)
            equal(RulesRNG.snapshot().rolls, before.rolls)
            scene:exit()
        end
    end)
    test("Substitute uses the existing recall scale and player-back foot anchor without advancing its pose", function()
        local battle, scene, mon = substituteScene("player")
        local request = {kind="recall", details={side="player", pokemon=mon}}
        scene.activePresentation = request
        scene.presentationFrame = 10
        local actual = renderPicture(function() scene:drawPresentedPokemon(mon, "player", 16, 16, true) end)
        -- Frame 10 still scales to 40. Feet stay on the slot bottom instead of
        -- the size box floating to the slot center.
        equalPictures(actual, playerBackPicture("images/battle-effects/substitute-back", 40, 0))
        equal(scene.activePresentation, request)
        equal(scene.presentationFrame, 10)
        scene:exit()
    end)
    test("Substitute shares the faint slide without moving the presentation clock", function()
        local battle, scene, mon = substituteScene("enemy")
        scene.activePresentation = {kind="faint", details={side="enemy", pokemon=mon}}
        scene.presentationFrame = 3
        local actual = renderPicture(function() scene:drawPresentedPokemon(mon, "enemy", 16, 16, false) end)
        -- Frame 3 steps three Game Boy tile rows (24px) and is not clipped
        -- back into the slot, matching SlideDownFaintedMonPic.
        equalPictures(actual, openPicture("images/battle-effects/substitute-front", 80, 24))
        assert(lowestBlackRow(actual) > 16 + 79)
        equal(scene.presentationFrame, 3)
        scene:exit()
    end)
    test("Broken or cleared Substitute restores ordinary body art and keeps body HP HUD values", function()
        for _, broken in ipairs({true, false}) do
            local battle, scene, mon = substituteScene("enemy")
            local hp = mon.hp
            if broken then
                battle.conditions:damageSubstitute(mon, battle.conditions:substituteHP(mon))
            else
                battle.conditions:clear(mon)
            end
            for _ = 1, 60 do scene:updateVitals() end
            local _, shownHP, maximum = scene:shownVitals(mon)
            equal(shownHP, hp)
            equal(maximum, mon.maxHP)
            local actual = renderPicture(function() scene:drawPresentedPokemon(mon, "enemy", 16, 16, false) end)
            equalPictures(actual, referencePicture(PokemonArt.path(mon.species, "front"), 80, 0))
            scene:exit()
        end
    end)
    test("Substitute cannot mask trainer intro visibility or the existing sendout pose", function()
        local battle, scene, mon = substituteScene("enemy")
        scene.playerShown = nil
        scene.enemyShown = nil
        scene.trainerVisible = true
        local count = 0
        local original = scene.drawPresentedPokemon
        scene.drawPresentedPokemon = function() count = count + 1 end
        renderPicture(function() scene:drawBattleField() end)
        equal(count, 0)
        scene.drawPresentedPokemon = original
        scene.activePresentation = {kind="sendout", details={side="enemy", pokemon=mon}}
        scene.presentationFrame = 10
        local actual = renderPicture(function() scene:drawPresentedPokemon(mon, "enemy", 16, 16, false) end)
        equalPictures(actual, referencePicture(PokemonArt.path(mon.species, "front"), 8, 0))
        equal(scene.presentationFrame, 10)
        scene:exit()
    end)
    test("Substitute art cannot follow a withdrawn identity into the replacement slot", function()
        local battle, scene, outgoing = substituteScene("player", true)
        battle.enemy.moves = {"splash"}
        battle.enemy.pp = {splash=moveData.splash.pp}
        assert(battle:chooseParty(2))
        local incoming = battle.player
        assert(incoming ~= outgoing)
        settle(battle, scene)
        local actual = renderPicture(function() scene:drawPresentedPokemon(outgoing, "player", 16, 16, true) end)
        equalPictures(actual, playerBackPicture(PokemonArt.path(outgoing.species, "back"), 80, 0))
        equal(battle.conditions:substituteHP(incoming), 0)
        scene:exit()
    end)

    for key, value in pairs(saved) do
        GameOptions.set(key, value)
    end
    RulesRNG.restore(rng)
    return report
end
