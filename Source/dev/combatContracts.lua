-- Production rules/controller contracts. No replacement SDK or altered source.
CombatContracts = {}
local function equal(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function own(mon, keys, amount)
    mon.moves, mon.pp = {}, {}
    for i, key in ipairs(keys) do mon.moves[i] = key; mon.pp[key] = amount or moveData[key].maxPP end
end
local function settle(battle)
    local messages, count = {}, 0
    while battle:phase() == "script" do
        count = count + 1; assert(count <= 200, "battle did not settle within200 messages")
        messages[#messages + 1] = battle.message
        battle.machine:get("script"):advance()
    end
    return table.concat(messages, "|")
end
local function fresh(player, enemy, trainer)
    local battle = Battle(player or Pokemon("charmander", 5), enemy or Pokemon("squirtle", 5), trainer)
    settle(battle)
    return battle
end
local function one(battle, side, key)
    battle:runScript(function()
        return battle:resolveTurn({side = side, actor=battle[side], key = key, move = moveData[key]})
    end)
    return settle(battle)
end
local function seedFor(low, high, predicate)
    for seed = 1, 10000 do if predicate(RulesRNG.new(seed):random(low, high)) then return seed end end
    error("no seed found for bounded contract fixture")
end
local function fingerprint(battle)
    local r = RulesRNG.snapshot()
    local fields = {battle:phase(), battle.message, battle.runAttempts, battle.outcome or "none", r.state, r.rolls,
        battle.player.hp, battle.enemy.hp}
    for _, mon in ipairs({battle.player, battle.enemy}) do
        for _, key in ipairs(mon.moves) do fields[#fields + 1] = key .. ":" .. tostring(mon.pp[key]) end
    end
    return table.concat(fields, "|")
end
local function exitContext(player, enemy, npc)
    -- Actual context/controller, with a minimal world State callback instead
    -- of rebuilding the global map while a contract command is executing.
    local game = GameContext()
    assert(game:recruit(player))
    assert(game.session:setIntro({stage="done", starter="charmander", rivalStarter="squirtle"}))
    local entry
    game.machine:register("overworld", {enter = function(_, options) entry = options end})
    game.machine:register("learning", LearningState(game))
    local state = BattleState(game)
    game.machine:register("battle", state)
    game.machine:change("overworld")
    if npc then npc:bindSession(game, "contract:terminal-trainer") end
    assert(FieldBattle.start(game, player, enemy, npc))
    equal(state.battle.session, game.session)
    equal(state.battle.party, game.session:party())
    settle(state.battle)
    return game, state, function() return entry end
end

function CombatContracts.run()
    local rng = RulesRNG.snapshot()
    local offsetX, offsetY = playdate.display.getOffset()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end

    test("Public move commands reject invalid inputs and phase without mutation or RNG", function()
        local b = fresh()
        for _, index in ipairs({-1, 99, 1.5, "1", false, math.huge, -math.huge, 0/0}) do
            local before = fingerprint(b)
            local ok, reason = b:selectMove(index)
            equal(ok, false); equal(reason, "invalid-index"); equal(fingerprint(b), before, "rejected index")
        end
        local before = fingerprint(b)
        equal(b:selectMove(nil), false); equal(fingerprint(b), before)
        local ok, reason = b:selectStruggle(); equal(ok, false); equal(reason, "moves-available")
        equal(fingerprint(b), before)
        assert(b:selectMove(1)); before = fingerprint(b)
        local ok, reason = b:selectMove(1); equal(ok, false); equal(reason, "wrong-phase")
        equal(fingerprint(b), before)
        local ok, reason = b:tryRun(); equal(ok, false); equal(reason, "wrong-phase")
        equal(fingerprint(b), before)
    end)

    test("Public exhausted or fainted commands reject before changing phase or RNG", function()
        local b = fresh(); b.player.pp[b.player.moves[1]] = 0
        local before = fingerprint(b)
        local ok, reason = b:selectMove(1); equal(ok, false); equal(reason, "no-pp")
        equal(fingerprint(b), before)
        b.player.hp = 0; before = fingerprint(b)
        local ok, reason = b:selectMove(2); equal(ok, false); equal(reason, "fainted")
        equal(b:tryRun(), false); equal(fingerprint(b), before)
    end)

    test("Both sides spend PP only on their scheduled attempt", function()
        local p, e = Pokemon("charmander", 5), Pokemon("bulbasaur", 5)
        own(p, {"growl"}, 4); own(e, {"growl"}, 4)
        p.spe, e.spe = 1, 100
        local b = fresh(p, e); assert(b:selectMove(1))
        equal(b.attackerSide, "enemy"); equal(e.pp.growl, 3); equal(p.pp.growl, 4)
        settle(b); equal(p.pp.growl, 3); equal(e.pp.growl, 3)
    end)

    test("Fainting before a scheduled turn does not spend its PP", function()
        local p, e = Pokemon("charmander", 100), Pokemon("rattata", 1)
        own(p, {"tackle"}, 4); own(e, {"growl"}, 4)
        p.spe, e.spe, e.hp = 100, 1, 1
        local b = fresh(p, e); assert(b:selectMove(1)); settle(b)
        equal(b.outcome, "victory"); equal(p.pp.tackle, 3); equal(e.pp.growl, 4)
    end)

    test("Sleep blocks every remaining turn including0 boundary, then wakes and spends PP", function()
        local b = fresh(); own(b.player, {"growl"}, 4)
        b.player.status, b.player.statusTurns, b.player.sleepDuration = "sleep", 1, 1
        one(b, "player", "growl")
        equal(b.player.status, "sleep"); equal(b.player.statusTurns, 0); equal(b.player.pp.growl, 4)
        local text = one(b, "player", "growl")
        equal(b.player.status, nil); equal(b.player.statusTurns, 0); equal(b.player.pp.growl, 3)
        assert(text:find("woke up", 1, true), "wake narration missing")
    end)

    test("Sleep, freeze, flinch, paralysis and confusion skips do not spend PP", function()
        for _, gate in ipairs({"sleep", "freeze", "flinch", "paralyze", "confusion"}) do
            local b = fresh(); own(b.player, {"growl"}, 4)
            if gate == "sleep" then b.player.status, b.player.statusTurns, b.player.sleepDuration = "sleep", 2, 2
            elseif gate == "flinch" then b.player.flinched = true
            elseif gate == "confusion" then b.player.confusion = 1; RulesRNG.seed(1)
            elseif gate == "freeze" then b.player.status = "freeze"; RulesRNG.seed(seedFor(1, 5, function(x) return x > 1 end))
            else b.player.status = "paralyze"; RulesRNG.seed(seedFor(1, 4, function(x) return x == 1 end)) end
            one(b, "player", "growl")
            equal(b.player.pp.growl, 4, gate .. " skipped PP")
        end
    end)

    test("BeforeMove priority counts sleep before flinch and confusion before paralysis", function()
        local b = fresh(); own(b.player, {"growl"}, 4)
        b.player.status, b.player.statusTurns, b.player.flinched, b.player.sleepDuration = "sleep", 1, true, 1
        one(b, "player", "growl")
        equal(b.player.statusTurns, 0); equal(b.player.flinched, true); equal(b.player.pp.growl, 4)
        one(b, "player", "growl")
        equal(b.player.status, nil); equal(b.player.flinched, false); equal(b.player.pp.growl, 4)
        b.player.status, b.player.confusion = "paralyze", 1
        RulesRNG.seed(1); one(b, "player", "growl")
        equal(RulesRNG.snapshot().rolls, 2, "confusion self-hit coin+variance precede any paralysis coin")
        equal(b.player.pp.growl, 4)
    end)

    test("Enemy skip and miss obey the same PP rules as the player", function()
        local b = fresh(); own(b.enemy, {"growl"}, 4)
        b.enemy.flinched = true; one(b, "enemy", "growl"); equal(b.enemy.pp.growl, 4)
        b.enemy.statStages.acc, b.player.statStages.eva = -6, 6
        RulesRNG.seed(seedFor(1, 100, function(x) return x > 34 end))
        local text = one(b, "enemy", "growl")
        equal(b.enemy.pp.growl, 3); equal(b.player.statStages.atk, 0)
        assert(text:find("missed", 1, true), "enemy miss expected")
    end)

    test("Miss and type immunity spend PP but deal no damage", function()
        local b = fresh(Pokemon("machop", 25), Pokemon("gastly", 100))
        own(b.player, {"seismicToss"}, 4)
        local hp = b.enemy.hp
        local text = one(b, "player", "seismicToss")
        equal(b.player.pp.seismicToss, 3); equal(b.enemy.hp, hp); equal(b.lastDamage, 0)
        assert(text:find("doesn't affect", 1, true), "fixed-damage immunity narration")
        own(b.player, {"growl"}, 4); b.player.statStages.acc, b.enemy.statStages.eva = -6, 6
        RulesRNG.seed(seedFor(1, 100, function(x) return x > 34 end))
        text = one(b, "player", "growl")
        equal(b.player.pp.growl, 3); equal(b.enemy.statStages.atk, 0)
        assert(text:find("missed", 1, true), "player miss expected")
    end)

    test("Fixed damage ignores resistance but honors Normal/Ghost and Fighting/Ghost immunity", function()
        local b = fresh(Pokemon("machop", 25), Pokemon("bulbasaur", 100))
        own(b.player, {"seismicToss"}, 4); local hp = b.enemy.hp
        one(b, "player", "seismicToss"); equal(hp - b.enemy.hp, 25, "fixed25 despite Fighting resistance")
        local b = fresh(Pokemon("charmander", 50), Pokemon("magneton", 100))
        own(b.player, {"dragonRage"}, 4); local hp = b.enemy.hp
        one(b, "player", "dragonRage"); equal(hp - b.enemy.hp, 40, "fixed40 despite Steel resistance")
        local b = fresh(Pokemon("charmander", 50), Pokemon("gastly", 100))
        own(b.player, {"sonicBoom"}, 4); local hp = b.enemy.hp
        RulesRNG.seed(seedFor(1, 100, function(x) return x <= 90 end))
        one(b, "player", "sonicBoom"); equal(b.enemy.hp, hp); equal(b.lastDamage, 0)
    end)

    test("Enemy choices filter exhausted moves and become Struggle when all exhausted", function()
        local b = fresh()
        own(b.enemy, {"tackle", "tailWhip"}, 2); b.enemy.pp.tackle, b.enemy.pp.tailWhip = 0, 1
        for seed = 1, 32 do
            RulesRNG.seed(seed); equal(b:enemyTurn().key, "tailWhip", "only PP-available enemy move")
        end
        one(b, "enemy", "tailWhip"); equal(b.enemy.pp.tailWhip, 0)
        local turn = b:enemyTurn(); equal(turn.move, moveData.struggle); equal(turn.key, nil)
        local hp = b.enemy.hp
        b:runScript(function() return b:resolveTurn(turn) end); settle(b)
        equal(b.enemy.hp, hp - math.max(1, math.floor(b.enemy.maxHP / 4 + 0.5)))
        equal(b.enemy.pp.tackle, 0); equal(b.enemy.pp.tailWhip, 0)
    end)

    test("Struggle independent damage vector is typeless, non-STAB and always hit", function()
        local p, e = Pokemon("rattata", 50), Pokemon("gastly", 50)
        p.atk, p.level, e.def = 100, 50, 100
        e.type, e.type2 = "ghost", "rock"
        RulesRNG.seed(1)
        local result = calcDamage(p, e, moveData.struggle)
        -- Base24, known seed1 noncrit +85% variance =>20. Normal STAB,
        -- Ghost immunity and Rock resistance must not modify this vector.
        equal(result.damage, 20); equal(result.isCrit, false); equal(result.isSTAB, false)
        equal(result.effectiveness, 1); equal(moveData.struggle.power, 50)
        equal(moveData.struggle.accuracy, 0); equal(moveData.struggle.noPP, true)
        equal(moveData.struggle.struggleRecoil, true)
        p.statStages.acc, e.statStages.eva = -6, 6
        local before = RulesRNG.snapshot().rolls
        equal(checkAccuracy(moveData.struggle, p, e), true); equal(RulesRNG.snapshot().rolls, before)
    end)

    test("Struggle recoil rounds maxHP/4 rather than using damage dealt", function()
        local b = fresh(Pokemon("charmander", 5), Pokemon("gastly", 100))
        own(b.player, {"scratch"}, 1); b.player.pp.scratch = 0
        equal(b.player.maxHP, 18)
        local hp, enemyHP = b.player.hp, b.enemy.hp
        one(b, "player", "struggle")
        equal(b.player.hp, hp - 5, "18/4 rounds to5")
        assert(b.enemy.hp < enemyHP, "Struggle must damage Ghost")
        equal(b.player.pp.scratch, 0); equal(b.player.pp.struggle, nil)
    end)

    test("BattleScene FIGHT routes exhaustion to Struggle and rejects partial0PP slot", function()
        local b = fresh(); own(b.player, {"scratch", "growl"}, 1)
        b.player.pp.scratch, b.player.pp.growl = 0, 0; b.player.spe, b.enemy.spe = 100, 1
        local scene = BattleScene(b); for _ = 1, 21 do scene:update() end
        scene:enter(); scene.mainMenu.onSelect(1)
        equal(b:phase(), "script"); equal(scene.inMoveSelect, false); equal(scene.moveMenu.isActive, false)
        assert(b.message:find("STRUGGLE", 1, true), "FIGHT should narrate Struggle")
        local b = fresh(); own(b.player, {"scratch", "growl"}, 1); b.player.pp.scratch = 0
        local scene = BattleScene(b); scene:enter(); scene.mainMenu.onSelect(1)
        equal(scene.inMoveSelect, true); local before = fingerprint(b)
        scene.moveMenu.onSelect(1)
        equal(scene.moveMenu.isActive, true); equal(scene.inMoveSelect, true); equal(fingerprint(b), before)
    end)

    test("Speed ties use a reproducible random tie break, never a fixed player advantage", function()
        local seen = {}
        local function first(seed)
            local p, e = Pokemon("charmander", 5), Pokemon("charmander", 5)
            own(p, {"growl"}, 4); own(e, {"growl"}, 4); p.spe, e.spe = 20, 20
            local b = fresh(p, e); RulesRNG.seed(seed); assert(b:selectMove(1)); return b.attackerSide
        end
        for seed = 1, 64 do local side = first(seed); seen[side] = true; equal(first(seed), side) end
        assert(seen.player and seen.enemy, "equal-speed order must include both sides")
    end)

    test("Overkill drain heals from actual3 HP removed with GenV rounding", function()
        local b = fresh(Pokemon("oddish", 100), Pokemon("rattata", 5))
        own(b.player, {"absorb"}, 4); b.player.hp = b.player.maxHP - 20; b.enemy.hp = 3
        local hp = b.player.hp
        one(b, "player", "absorb")
        equal(b.lastDamage, 3); equal(b.player.hp, hp + 2, "round(3/2)=2")
        equal(b.player.pp.absorb, 3); equal(b.outcome, "victory")
    end)

    test("Overkill recoil uses actual6 HP removed and rounds quarter to2", function()
        local b = fresh(Pokemon("rhyhorn", 100), Pokemon("rattata", 5))
        own(b.player, {"takeDown"}, 4); b.enemy.hp = 6
        local hp = b.player.hp
        RulesRNG.seed(seedFor(1, 100, function(x) return x <= 85 end))
        one(b, "player", "takeDown")
        equal(b.lastDamage, 6); equal(b.player.hp, hp - 2); equal(b.player.pp.takeDown, 3)
    end)

    test("Simultaneous Struggle faint follows GenV last-fainted winner and awards no dead-player XP", function()
        local b = fresh(Pokemon("charmander", 5), Pokemon("gastly", 5))
        b.player.hp, b.enemy.hp = 1, 1
        local xp, level = b.player.xp, b.player.level
        local text = one(b, "player", "struggle")
        equal(b.player.hp, 0); equal(b.enemy.hp, 0); equal(b.outcome, "victory")
        equal(b.machine:get("ended").won, true); equal(b.player.xp, xp); equal(b.player.level, level)
        assert(not text:find("EXP", 1, true), "fainted player must not earn XP and revive through stat growth")
        local b = fresh(Pokemon("gastly", 5), Pokemon("charmander", 5))
        b.player.hp, b.enemy.hp = 1, 1; one(b, "enemy", "struggle")
        equal(b.player.hp, 0); equal(b.enemy.hp, 0); equal(b.outcome, "defeat")
    end)

    test("Residual cohorts complete before matchup; later burn stops after terminal poison cohort", function()
        -- Level 100 isolates residual ordering from victory XP's legitimate
        -- level-up HP increase; progression has separate production contracts.
        local b = fresh(Pokemon("charmander", 100), Pokemon("squirtle", 100))
        b.player.status, b.enemy.status = "burn", "poison"
        b.player.hp, b.enemy.hp = 1, 1
        b:runScript(function() return b:endOfRoundStatus() end); settle(b)
        equal(b.outcome, "victory"); equal(b.enemy.hp, 0); equal(b.player.hp, 1, "battle ends before later burn event")
        local b = fresh(); b.player.status, b.enemy.status = "poison", "poison"
        b.player.hp, b.enemy.hp, b.player.spe, b.enemy.spe = 1, 1, 100, 1
        local xp=b.player.xp
        b:runScript(function() return b:endOfRoundStatus() end); settle(b)
        equal(b.outcome, "defeat"); equal(b.enemy.hp, 0);equal(b.player.hp,0);equal(b.player.xp,xp)
        for _,key in ipairs({"hp","atk","def","spa","spd","spe"})do equal(b.player.evs[key],0)end
    end)

    test("Terminal events distinguish run/victory/defeat and emit once", function()
        for _, kind in ipairs({"victory", "defeat", "run"}) do
            local b = fresh(); local count, actualWon, actualKind = 0
            b:on("battleEnd", function(won, outcome) count = count + 1; actualWon, actualKind = won, outcome end)
            b:runScript(function() return kind end)
            equal(b.outcome, kind); equal(b:phase(), "ended")
            if kind ~= "run" then equal(count, 0); assert(b:emitEnd()) end
            equal(actualWon, kind == "victory"); equal(actualKind, kind); equal(count, 1)
            equal(b:emitEnd(), false); equal(count, 1)
            local before = fingerprint(b); equal(b:selectMove(1), false); equal(b:tryRun(), false); equal(fingerprint(b), before)
        end
    end)

    test("Actual BattleState owner exit does not suppress a later terminal observer", function()
        local gfx = playdate.graphics
        local sprites = gfx.sprite.getAllSprites()
        local x, y = gfx.getDrawOffset()
        local ok, problem = pcall(function()
            local game = GameContext()
            local p, e = Pokemon("charmander", 100), Pokemon("magikarp", 1)
            assert(game:recruit(p))
            game.machine:register("overworld", {})
            game.machine:register("learning", LearningState(game))
            local owner = BattleState(game)
            game.machine:register("battle", owner)
            game.machine:change("battle", p, e)
            local b, calls = owner.battle, 0
            b:on("battleEnd", function(won, kind)
                calls = calls + 1
                equal(won, true); equal(kind, "victory")
                equal(game.machine:getCurrent(), "overworld", "owner exits before later observer")
            end)
            settle(b); e.hp = 0; b:setDirection("player")
            b:runScript(function() return b:handleFaint() end); settle(b)
            assert(b:emitEnd()); equal(calls, 1)
            equal(game.lastBattleOutcome.kind, "victory"); equal(game.lastBattleOutcome.enemy_hp, 0)
            equal(b.emittingEnd, false); equal(owner.battle, nil)
            b:emit("battleEnd", true, "victory"); equal(calls, 1, "terminal listeners cleaned after all observers")
        end)
        gfx.sprite.removeAll()
        for _, sprite in ipairs(sprites) do sprite:add() end
        gfx.setDrawOffset(x, y)
        if not ok then error(problem, 0) end
    end)

    test("Throwing terminal observer still releases listener ownership exactly once", function()
        local b = fresh()
        b:on("battleEnd", function() error("expected terminal observer failure") end)
        b:runScript(function() return "victory" end)
        local ok = pcall(function() b:emitEnd() end)
        equal(ok, false); equal(b.emittingEnd, false); equal(b.endEmitted, true)
        equal(b:emitEnd(), false)
        b:emit("battleEnd", true, "victory") -- must not rethrow a stale observer
    end)

    test("Real run command preserves PP and distinguishes refusal from terminal escape", function()
        local b = fresh(nil, nil, "BLUE")
        local pp, enemyPP = b.player.pp[b.player.moves[1]], b.enemy.pp[b.enemy.moves[1]]
        assert(b:tryRun()); settle(b)
        equal(b:phase(), "command"); equal(b.outcome, nil); equal(b.runAttempts, 0)
        equal(b.player.pp[b.player.moves[1]], pp); equal(b.enemy.pp[b.enemy.moves[1]], enemyPP)
        local b = fresh(); b.player.spe, b.enemy.spe = 10, 10; RulesRNG.seed(2)
        local kind; b:on("battleEnd", function(_, outcome) kind = outcome end)
        assert(b:tryRun()); settle(b); equal(b.outcome, "run"); equal(kind, "run")
    end)

    test("Ordinary battle return preserves major status/sleep0 while clearing battle transients", function()
        for _, status in ipairs({"poison", "burn", "paralyze", "freeze", "sleep"}) do
            local p, e = Pokemon("charmander", 5), Pokemon("squirtle", 5)
            local game, state, entry = exitContext(p, e)
            p.status, p.statusTurns, p.confusion, p.flinched, p.statStages.atk = status, 0, 2, true, -6
            p.sleepDuration = status == "sleep" and 3 or 0
            e.confusion, e.flinched, e.statStages.def = 2, true, 6
            local battle <const> = state.battle
            battle:runScript(function() return "run" end)
            settle(battle)
            equal(battle.endEmitted, true)
            equal(p.status, status); equal(p.statusTurns, 0); equal(p.confusion, nil); equal(p.flinched, false)
            equal(p.statStages.atk, 0); equal(e.statStages.def, 0); equal(e.confusion, nil)
            equal(game.machine:getCurrent(), "overworld"); equal(entry(), nil)
            state:exit()
        end
    end)

    test("Blackout restores supported player even when terminal narrative is victory", function()
        local p, e = Pokemon("charmander", 5), Pokemon("squirtle", 5)
        p.status, p.statusTurns, p.pp.scratch = "sleep", 0, 0
        p.sleepDuration = 3
        local npc = NPC(1000, 1000, "TEST", {}, nil, "rival"); npc:remove(); npc.def = {}
        local game, state, entry = exitContext(p, e, npc)
        assert(game.session:setIntro({stage="rival_fight",starter="charmander",rivalStarter="squirtle"}))
        local xp = p.xp
        p.hp = 0 -- Faint after admitted entry, as in a final recoil victory.
        local battle <const> = state.battle
        battle:runScript(function() return "victory" end)
        settle(battle)
        assert(battle:emitEnd())
        equal(npc.interacted, true); equal(npc.def.interacted, nil); equal(game.session:trainerDefeated("contract:terminal-trainer"), true); equal(Story.get(game).rivalOutcome, true)
        equal(Story.get(game).stage, "goodbye"); equal(entry().respawn, true)
        equal(p.hp, p.maxHP); equal(p.status, nil); equal(p.statusTurns, 0); equal(p.pp.scratch, moveData.scratch.maxPP)
        equal(p.xp, xp, "blackout must not fabricate XP"); equal(game.machine:getCurrent(), "overworld")
        equal(game.lastBattleOutcome.kind, "victory"); equal(game.lastBattleOutcome.won, true)
        equal(game.lastBattleOutcome.blackout, true); equal(game.lastBattleOutcome.player_hp, 0)
        state:exit()
    end)

    test("Forced battle exit clears stages/volatiles/listeners without curing major status", function()
        local p, e = Pokemon("charmander", 5), Pokemon("squirtle", 5)
        local _, state = exitContext(p, e)
        p.status, p.statusTurns, p.confusion, p.flinched, p.statStages.atk = "poison", 0, 2, true, 3
        local b = state.battle; local calls = 0; b:on("battleEnd", function() calls = calls + 1 end)
        state:exit(); b:emit("battleEnd", true, "victory")
        equal(calls, 0); equal(p.status, "poison"); equal(p.statusTurns, 0)
        equal(p.confusion, nil); equal(p.flinched, false); equal(p.statStages.atk, 0)
    end)

    test("Applying a non-sleep status normalizes the durable turn counter", function()
        local b = fresh(); b:setDirection("player"); b.enemy.statusTurns = 3
        b:runScript(function() ApplyStatus(DEFENDER, "poison"):apply(b) end); settle(b)
        equal(b.enemy.status, "poison"); equal(b.enemy.statusTurns, 0)
    end)

    RulesRNG.restore(rng)
    playdate.display.setOffset(offsetX, offsetY)
    return report
end
