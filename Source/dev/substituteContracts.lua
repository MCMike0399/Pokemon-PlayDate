-- Production action integration; Root alone executes this compiled SDK suite.
SubstituteContracts = {}
local gfx <const> = playdate.graphics
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function own(mon, keys)
    mon.moves = {}
    mon.pp = {}
    for _, key in ipairs(keys) do
        mon.moves[#mon.moves + 1] = key
        mon.pp[key] = moveData[key].pp
    end
end
local function settle(b, observe)
    local lines = {}
    local count = 0
    while b:phase() == "script" do
        count = count + 1
        assert(count < 400, "Substitute action stuck: " .. tostring(b.message))
        assert(not b.pendingLearning, "unexpected learning")
        lines[#lines + 1] = b.message or ""
        if observe then observe(b) end
        b.machine:get("script"):advance()
    end
    return table.concat(lines, "|")
end
local function fresh(keys)
    local b = Battle(Pokemon("snorlax", 100), Pokemon("snorlax", 100))
    settle(b)
    own(b.player, keys or {"substitute"})
    own(b.enemy, {"splash"})
    b.player.spe = 200
    b.enemy.spe = 100
    b.player.ability = function() return 0 end
    b.enemy.ability = function() return 0 end
    return b
end
local function use(b, seed, observe)
    RulesRNG.seed(seed or 73)
    assert(b:selectMove(1))
    return settle(b, observe)
end
local function doll(keys, hp)
    local b = fresh({"splash"})
    own(b.enemy, {"substitute"})
    use(b)
    own(b.player, keys)
    own(b.enemy, {"splash"})
    if hp then
        b.conditions:damageSubstitute(b.enemy, b.conditions:substituteHP(b.enemy) - hp)
    end
    return b
end
local function rng(seed, draws)
    local expected = RulesRNG.new(seed)
    for _, bounds in ipairs(draws) do expected:random(bounds[1], bounds[2]) end
    eq(RulesRNG.snapshot().state, expected:snapshot().state)
    eq(RulesRNG.snapshot().rolls, expected:snapshot().rolls)
end
local function hitSeed(maximum, secondary)
    for seed = 1, 1000 do
        local trial = RulesRNG.new(seed)
        trial:random(1, 1)
        if trial:random(1, 100) <= maximum then
            trial:random(1, 16)
            trial:random(85, 100)
            if not secondary or trial:random(1, 100) <= secondary then return seed end
        end
    end
    error("missing deterministic seed")
end
local function script(b, fn)
    b:runScript(fn)
    return settle(b)
end
function SubstituteContracts.run()
    local saved = RulesRNG.snapshot()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.ok = false
            report.failed = report.failed + 1
        end
    end
    test("Substitute actual command pays HP spends PP and rejects duplicate boundary and zero PP", function()
        local b = fresh()
        b.player.maxHP = 101
        b.player.hp = 26
        local text = use(b)
        eq(b.player.hp, 1)
        eq(b.conditions:substituteHP(b.player), 25)
        eq(b.player.pp.substitute, 9)
        assert(text:find("made a substitute", 1, true))
        rng(73, {{1,1}})
        text = use(b)
        eq(b.player.hp, 1)
        eq(b.player.pp.substitute, 8)
        assert(text:find("But it failed!", 1, true))
        b.conditions:clear(b.player)
        b.player.hp = 25
        use(b)
        eq(b.conditions:substituteHP(b.player), 0)
        eq(b.player.hp, 25)
        b.player.pp.substitute = 0
        RulesRNG.seed(73)
        local ok, why = b:selectMove(1)
        eq(ok, false)
        eq(why, "no-pp")
        rng(73, {})
    end)
    test("Substitute sleep flinch paralysis confusion and Disable retain BeforeMove and PP gates", function()
        for _, gate in ipairs({"sleep", "flinch", "paralyze", "confuse", "disable"}) do
            local b = fresh()
            local seed = 73
            if gate == "sleep" then
                b.player.status = "sleep"
                b.player.statusTurns = 2
                b.player.sleepDuration = 2
            elseif gate == "flinch" then
                b.player.flinched = true
            elseif gate == "disable" then
                b.conditions:of(b.player).disable = {key="substitute", turns=4}
            else
                for candidate = 1, 100 do
                    local trial = RulesRNG.new(candidate)
                    trial:random(1, 1)
                    if trial:random(1, gate == "paralyze" and 4 or 2) == 1 then
                        seed = candidate
                        break
                    end
                end
                if gate == "paralyze" then
                    b.player.status = "paralyze"
                    b.player.spe = 1000
                else
                    b.player.confusion = 2
                end
            end
            local hp = b.player.hp
            if gate == "disable" then
                eq(b:selectMove(1), false)
            else
                use(b, seed)
            end
            eq(b.player.pp.substitute, 10)
            eq(b.conditions:substituteHP(b.player), 0)
            if gate == "confuse" then
                assert(b.player.hp < hp)
            else
                eq(b.player.hp, hp)
            end
        end
    end)
    test("Substitute blocks opposing status volatile stat and ability payloads before their chance draws", function()
        for _, key in ipairs({"growl", "leer", "sing", "supersonic", "leechSeed", "thunderWave",
            "toxic", "yawn", "worrySeed", "captivate", "willOWisp", "tickle", "confuseRay"}) do
            local b = doll({key})
            b.player.getSex = function() return "male" end
            b.enemy.getSex = function() return "female" end
            if key == "worrySeed" then b.enemy.ability = function() return 17 end end
            local hp = b.enemy.hp
            local sub = b.conditions:substituteHP(b.enemy)
            local accuracy = moveData[key].accuracy
            local seed = hitSeed(accuracy == 0 and 100 or accuracy)
            local text = use(b, seed)
            assert(text:find("substitute blocked", 1, true), key .. ": " .. text)
            eq(b.enemy.hp, hp)
            eq(b.conditions:substituteHP(b.enemy), sub)
            eq(b.enemy.status, nil)
            eq(b.enemy.confusion, nil)
            for _, stage in pairs(b.enemy.statStages) do eq(stage, 0) end
            local state = b.conditions:of(b.enemy)
            eq(state.seed, nil)
            eq(state.yawn, nil)
            eq(b.effects.abilityOverrides[b.enemy], nil)
            rng(seed, accuracy == 0 and {{1,1}} or {{1,1}, {1,100}})
        end
    end)
    test("Gen V sound attacks and Infiltrator do not bypass Substitute", function()
        for _, key in ipairs({"hyperVoice", "bugBuzz", "snore"}) do
            local b = doll({key})
            b.player.ability = function() return 151 end
            if key == "snore" then
                b.player.status = "sleep"
                b.player.statusTurns = 2
                b.player.sleepDuration = 2
            end
            local hp = b.enemy.hp
            local sub = b.conditions:substituteHP(b.enemy)
            use(b)
            eq(b.enemy.hp, hp)
            assert(b.conditions:substituteHP(b.enemy) < sub)
        end
    end)
    test("Gen V explicit Disable Encore and identification bypasses reach existing target owners", function()
        for _, key in ipairs({"disable", "encore", "foresight", "odorSleuth"}) do
            local b = doll({key})
            local state = b.conditions:of(b.enemy)
            state.lastMove = "splash"
            local sub = b.conditions:substituteHP(b.enemy)
            use(b)
            eq(b.conditions:substituteHP(b.enemy), sub)
            if key == "disable" then assert(state.disable)
            elseif key == "encore" then assert(state.encore)
            else eq(state.foresight, true) end
        end
    end)
    test("Haze and Ghost Curse bypass while self and side moves preserve both dolls", function()
        local b = doll({"haze"})
        b.player.statStages.atk = 3
        b.enemy.statStages.def = 4
        local sub = b.conditions:substituteHP(b.enemy)
        use(b)
        eq(b.player.statStages.atk, 0)
        eq(b.enemy.statStages.def, 0)
        eq(b.conditions:substituteHP(b.enemy), sub)
        own(b.player, {"curse"})
        b.player.type = "ghost"
        use(b)
        eq(b.conditions:of(b.enemy).curse, true)
        eq(b.conditions:substituteHP(b.enemy), sub)
        for _, key in ipairs({"reflect", "lightScreen", "safeguard", "tailwind", "swordsDance", "rest", "rainDance", "spikes"}) do
            local x = doll({key})
            x.player.hp = x.player.maxHP - 10
            local dollHP = x.conditions:substituteHP(x.enemy)
            local text = use(x)
            assert(not text:find("substitute blocked", 1, true), key)
            eq(x.conditions:substituteHP(x.enemy), dollHP)
        end
    end)
    test("Formula fixed Psywave Endeavor Bide and OHKO primary paths intercept without body spill", function()
        for _, key in ipairs({"tackle", "sonicBoom", "seismicToss", "dragonRage", "nightShade", "superFang", "psywave", "endeavor", "guillotine"}) do
            local b = doll({key}, 1)
            -- Night Shade's Ghost immunity precedes Substitute interception.
            if key == "nightShade" then b.enemy.type = "psychic" end
            b.player.atk = 10000
            b.player.spa = 10000
            b.player.hp = 1
            b.player.ability = function() return 99 end
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.conditions:substituteHP(b.enemy), 0)
        end
        local b = doll({"bide"}, 1)
        b.conditions:of(b.player).bide = {total=10, source=b.enemy, turns=2}
        local hp = b.enemy.hp
        -- Bide's existing continuation owns release; no added attack shortcut.
        use(b)
        eq(b.enemy.hp, hp)
        eq(b.conditions:substituteHP(b.enemy), 0)
    end)
    test("Magnitude copies and two turn charge releases retain canonical Substitute routing", function()
        local b = doll({"magnitude"}, 1)
        local hp = b.enemy.hp
        use(b)
        eq(b.enemy.hp, hp)
        eq(b.conditions:substituteHP(b.enemy), 0)
        for _, key in ipairs({"cut", "surf", "strength"}) do
            local hm = doll({key}, 1)
            local bodyHP = hm.enemy.hp
            use(hm, hitSeed(moveData[key].accuracy))
            eq(hm.enemy.hp, bodyHP)
            eq(hm.conditions:substituteHP(hm.enemy), 0)
        end
        local flash = doll({"flash"})
        local flashHP = flash.conditions:substituteHP(flash.enemy)
        use(flash, hitSeed(moveData.flash.accuracy))
        eq(flash.conditions:substituteHP(flash.enemy), flashHP)
        for _, stage in pairs(flash.enemy.statStages) do
            eq(stage, 0)
        end
        for _, key in ipairs({"solarBeam", "skullBash", "fly"}) do
            b = doll({key}, 1)
            b.player.ability = function() return 99 end
            hp = b.enemy.hp
            use(b)
            eq(b.conditions:substituteHP(b.enemy), 1)
            eq(b.player.pp[key], moveData[key].pp - 1)
            use(b)
            eq(b.conditions:substituteHP(b.enemy), 0)
            eq(b.enemy.hp, hp)
            eq(b.player.pp[key], moveData[key].pp - 1)
        end
    end)
    test("Each multihit routes again after break and only body hits draw opposing secondaries", function()
        local b = doll({"twineedle"}, 1)
        b.player.atk = 1
        b.enemy.def = 1000
        local hp = b.enemy.hp
        use(b)
        eq(b.conditions:substituteHP(b.enemy), 0)
        assert(b.enemy.hp < hp)
        rng(73, {{1,1}, {1,100}, {1,16}, {85,100}, {1,16}, {85,100}, {1,100}})
    end)
    test("Intercepted contact and opposing secondaries consume no contact chance including the breaking hit", function()
        for _, ability in ipairs({9, 27, 38, 56, 83}) do
            local b = doll({"bodySlam"}, 1)
            b.enemy.ability = function() return ability end
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.player.status, nil)
            eq(b.enemy.status, nil)
            eq(b.enemy.statStages.atk, 0)
            eq(b.conditions:of(b.player).infatuation, nil)
            rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
        end
    end)
    test("Clear Smog and binding cannot apply through intact or breaking substitutes", function()
        for _, key in ipairs({"clearSmog", "bind", "wrap", "fireSpin", "clamp", "whirlpool", "sandTomb"}) do
            for _, hp in ipairs({1, 100}) do
                local b = doll({key}, hp)
                b.enemy.statStages.atk = 4
                b.player.atk = 1
                b.player.spa = 1
                b.enemy.def = 1000
                b.enemy.spd = 1000
                local seed = hitSeed(moveData[key].accuracy == 0 and 100 or moveData[key].accuracy)
                use(b, seed)
                eq(b.enemy.statStages.atk, 4)
                eq(b.conditions:of(b.enemy).trap, nil)
                local draws = {{1,1}}
                if moveData[key].accuracy ~= 0 then draws[#draws + 1] = {1,100} end
                draws[#draws + 1] = {1,16}
                draws[#draws + 1] = {85,100}
                rng(seed, draws)
            end
        end
        local b = fresh({"clearSmog"})
        b.enemy.statStages.atk = 4
        use(b)
        eq(b.enemy.statStages.atk, 0)
    end)
    test("Rapid Spin AfterSubDamage clears source hazards seed and trapping once with no speed boost", function()
        local b = doll({"rapidSpin"}, 1)
        local state = b.conditions:of(b.player)
        state.seed = "enemy"
        state.trap = {source=b.enemy, remaining=4}
        local side = b.conditions.sides.player
        side.spikes = 2
        side.toxicSpikes = 1
        side.stealthRock = 1
        local text = use(b)
        eq(state.seed, nil)
        eq(state.trap, nil)
        eq(side.spikes, nil)
        eq(side.toxicSpikes, nil)
        eq(side.stealthRock, nil)
        eq(b.player.statStages.spe, 0)
        local _, count = text:gsub("blew away the obstacles", "")
        eq(count, 1)
    end)
    test("Rage and self drops or self secondaries persist through intercepted hits", function()
        local b = doll({"rage"}, 1)
        b.conditions:of(b.enemy).rage = true
        use(b)
        eq(b.conditions:of(b.player).rage, true)
        eq(b.enemy.statStages.atk, 0)
        b = doll({"superpower"}, 1)
        use(b)
        eq(b.player.statStages.atk, -1)
        eq(b.player.statStages.def, -1)
        b = doll({"ancientPower"}, 1)
        use(b, hitSeed(100, 10))
        eq(b.player.statStages.atk, 1)
        eq(b.player.statStages.def, 1)
    end)
    test("Intercepted damage does not feed Bide Revenge or the hurt this round ledger", function()
        local b = fresh({"substitute"})
        use(b)
        own(b.player, {"bide"})
        own(b.enemy, {"tackle"})
        b.enemy.atk = 1
        b.player.def = 1000
        local hp = b.enemy.hp
        use(b)
        eq(b.conditions:of(b.player).bide.total, 0)
        use(b)
        eq(b.conditions:of(b.player).bide.total, 0)
        local text = use(b)
        assert(text:find("But it failed!", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.conditions:of(b.player).bide, nil)
        own(b.player, {"revenge"})
        local observed = false
        use(b, 73, function(current)
            if current.message and current.message:find("SUBSTITUTE took damage", 1, true) then
                observed = true
                eq(current.effects:damagedThisRound(current.player), false)
                eq(current.effects.round.attackedBy[current.player], nil)
                eq(current.effects:movePower(moveData.revenge, 60, current.player, current.enemy), 60)
            end
        end)
        eq(observed, true)
    end)
    test("Actual drain and recoil apply once to capped intercepted loss with ordinary ability gates", function()
        for _, ability in ipairs({0, 64}) do
            local b = doll({"absorb"}, 1)
            b.enemy.ability = function() return ability end
            b.player.hp = 100
            use(b)
            eq(b.player.hp, ability == 64 and 99 or 101)
        end
        for _, ability in ipairs({0, 69, 98}) do
            local b = doll({"doubleEdge"}, 25)
            b.player.atk = 10000
            b.enemy.def = 1
            b.player.hp = 100
            b.player.ability = function() return ability end
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.player.hp, ability == 0 and 92 or 100)
        end
    end)
    test("Controlled mixed multihit recoil excludes intercepted loss from the body accumulator", function()
        -- No enabled natural multihit move has recoil. This controlled fixture
        -- exercises the shared accumulator through the real command path.
        local move = moveData.doubleKick
        local original = move.drain
        local ok, problem = pcall(function()
            move.drain = -25
            local b = doll({"doubleKick"}, 25)
            b.player.atk = 100
            b.enemy.def = 100
            local sourceHP = b.player.hp
            local targetHP = b.enemy.hp
            use(b)
            local bodyLoss = targetHP - b.enemy.hp
            assert(bodyLoss > 0)
            local bodyRecoil = math.max(1, math.floor(bodyLoss / 4 + 0.5))
            eq(b.player.hp, sourceHP - 6 - bodyRecoil)
            eq(b.conditions:substituteHP(b.enemy), 0)
        end)
        move.drain = original
        assert(ok, problem)
    end)
    test("Struggle intercept recoil uses quarter max HP once and can faint the user", function()
        local b = doll({"tackle"}, 1)
        b.player.pp.tackle = 0
        b.player.hp = 1
        local hp = b.enemy.hp
        RulesRNG.seed(73)
        assert(b:selectMove(0))
        local text = settle(b)
        eq(b.enemy.hp, hp)
        eq(b.player.hp, 0)
        eq(b.conditions:substituteHP(b.enemy), 0)
        local _, count = text:gsub("damaged by recoil", "")
        eq(count, 1)
    end)
    test("Self KO into Substitute faints only the source and preserves final side accounting", function()
        for _, key in ipairs({"selfDestruct", "explosion"}) do
            local b = doll({key}, 1)
            local hp = b.enemy.hp
            b.player.heldItem = "kingsRock"
            use(b)
            rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
            eq(b.player.hp, 0)
            eq(b.enemy.hp, hp)
            assert(b.enemy:isAlive())
            eq(b.conditions:substituteHP(b.enemy), 0)
            eq(b.outcome, "defeat")
        end
    end)
    test("Miss Protect immunity absorption and Damp retain their ordering ahead of interception", function()
        for _, gate in ipairs({"miss", "protect", "immune", "absorb", "damp"}) do
            local b = doll({gate == "absorb" and "waterGun" or (gate == "damp" and "explosion" or "tackle")})
            local sub = b.conditions:substituteHP(b.enemy)
            if gate == "miss" then
                b.player.statStages.acc = -6
                b.enemy.statStages.eva = 6
            elseif gate == "immune" then
                b.enemy.type = "ghost"
            elseif gate == "absorb" then
                b.enemy.ability = function() return 11 end
            elseif gate == "damp" then
                b.enemy.ability = function() return 6 end
            else
                b.enemy.spe = 500
                own(b.enemy, {"protect"})
            end
            local seed = 73
            if gate == "miss" then
                for candidate = 1, 100 do
                    local trial = RulesRNG.new(candidate)
                    trial:random(1,1)
                    if trial:random(1,100) > 33 then
                        seed = candidate
                        break
                    end
                end
            end
            use(b, seed)
            eq(b.conditions:substituteHP(b.enemy), sub)
            if gate == "damp" then assert(b.player:isAlive()) end
        end
    end)
    test("Substitute narration distinguishes doll HP and renderer uses no Pokemon HP mutation or rules RNG", function()
        local b = doll({"tackle"})
        local hp = b.enemy.hp
        local text = use(b)
        assert(text:find("SUBSTITUTE took damage", 1, true))
        eq(b.enemy.hp, hp)
        local scene = BattleScene(b)
        local image = assert(gfx.image.new(400, 240, gfx.kColorWhite))
        local before = RulesRNG.snapshot()
        gfx.pushContext(image)
        local ok, problem = pcall(function() scene:drawPresentedPokemon(b.enemy, "enemy", 300, 20, false) end)
        gfx.popContext()
        assert(ok, problem)
        eq(RulesRNG.snapshot().rolls, before.rolls)
        eq(b.enemy.hp, hp)
    end)
    test("Voluntary switching and Roar or Whirlwind clear the outgoing doll through party ownership", function()
        for _, key in ipairs({"roar", "whirlwind", "switch"}) do
            local party = Party()
            local enemyParty = Party()
            assert(party:add(Pokemon("snorlax", 100)))
            assert(party:add(Pokemon("blastoise", 100)))
            assert(enemyParty:add(Pokemon("snorlax", 100)))
            assert(enemyParty:add(Pokemon("blastoise", 100)))
            local b = Battle(party:active(), enemyParty:active(), "TRAINER", {party=party, enemyParty=enemyParty})
            settle(b)
            own(b.player, {"substitute"})
            own(b.enemy, {"substitute"})
            b.player.spe = 200
            b.enemy.spe = 100
            use(b)
            local outgoing = key == "switch" and b.player or b.enemy
            assert(b.conditions:substituteHP(outgoing) > 0)
            own(b.enemy, {"splash"})
            if key == "switch" then
                assert(b:chooseParty(2))
                settle(b)
                eq(b.player, party:get(2))
            else
                own(b.player, {key})
                use(b)
                eq(b.enemy, enemyParty:get(2))
            end
            eq(b.conditions:substituteHP(outgoing), 0)
        end
    end)
    test("Cancellation and battle close clear substitute state and invalidate unresolved hit tokens", function()
        local b = fresh()
        assert(b:selectMove(1))
        for _ = 1, 20 do
            if b.conditions:substituteHP(b.player) > 0 then break end
            b.machine:get("script"):advance()
        end
        assert(b.conditions:substituteHP(b.player) > 0)
        local hp = b.player.hp
        local receipt = b.effects:hitSubstitute(b.enemy, b.player, moveData.tackle, 1)
        b:clearVolatiles()
        eq(b.effects:resolveSubstituteHit(receipt), false)
        eq(b.effects:afterHit(receipt), false)
        eq(b.conditions:substituteHP(b.player), 0)
        eq(b.player.hp, hp)
        eq(b.machine:get("script"):advance(), false)
    end)
    test("Intimidate is blocked but existing poison seed Yawn and weather still reach body HP", function()
        local b = doll({"splash"})
        b.player.ability = function() return 22 end
        script(b, function() b.effects:entry(b.player) end)
        eq(b.enemy.statStages.atk, 0)
        local sub = b.conditions:substituteHP(b.enemy)
        local hp = b.enemy.hp
        b.enemy.status = "poison"
        use(b)
        assert(b.enemy.hp < hp)
        eq(b.conditions:substituteHP(b.enemy), sub)
        b.enemy.status = nil
        local state = b.conditions:of(b.enemy)
        state.seed = "player"
        hp = b.enemy.hp
        use(b)
        assert(b.enemy.hp < hp)
        eq(b.conditions:substituteHP(b.enemy), sub)
        state.seed = nil
        state.yawn = {turns=1, source=b.player}
        use(b)
        eq(b.enemy.status, "sleep")
        eq(b.conditions:substituteHP(b.enemy), sub)
        b.enemy.status = nil
        b.enemy.statusTurns = 0
        b.enemy.sleepDuration = 0
        own(b.player, {"sandstorm"})
        hp = b.enemy.hp
        use(b)
        assert(b.enemy.hp < hp)
        eq(b.conditions:substituteHP(b.enemy), sub)
    end)
    test("Unsupported Trick Recycle and Baton Pass retain explicit gaps against Substitute", function()
        for _, key in ipairs({"trick", "recycle", "batonPass"}) do
            local b = doll({key})
            local hp = b.enemy.hp
            local sub = b.conditions:substituteHP(b.enemy)
            local text = use(b)
            assert(text:find("But it failed!", 1, true))
            eq(b:getMoveGaps()[1].move, key)
            eq(b.enemy.hp, hp)
            eq(b.conditions:substituteHP(b.enemy), sub)
        end
    end)
    RulesRNG.restore(saved)
    return report
end
