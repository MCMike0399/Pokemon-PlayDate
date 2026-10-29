-- Real SDK battle attempts; metadata tests alone cannot establish this behavior.
MoveFailureContracts = {}
local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function own(mon, key)
    mon.moves, mon.pp = { key }, { [key] = moveData[key].maxPP }
end
local function settle(battle)
    local lines = {}
    for _ = 1, 100 do
        if battle:phase() ~= "script" then return table.concat(lines, "|") end
        lines[#lines + 1] = battle.message
        battle.machine:get("script"):advance()
    end
    error("move attempt did not settle")
end
local function attempt(battle, key, side)
    side = side or "player"
    local actor = battle[side]
    own(actor, key)
    battle:runScript(function()
        return battle:resolveTurn({ side = side, actor = actor, key = key, move = moveData[key] })
    end)
    return settle(battle)
end
local function roster(...)
    local party = Party()
    for _, mon in ipairs({...}) do assert(party:add(mon)) end
    return party
end
function MoveFailureContracts.run()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local saved = RulesRNG.snapshot()
    local battles = {}
    local function fresh(enemy, dependencies, trainer)
        local b = Battle(Pokemon("pidgey", 100), enemy or Pokemon("rattata", 100), trainer, dependencies)
        battles[#battles + 1] = b
        settle(b)
        return b
    end
    local function test(name, body)
        battles = {}
        local ok, problem = pcall(body)
        for _, battle in ipairs(battles) do battle:clearVolatiles() end
        RulesRNG.restore(saved)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then report.passed = report.passed + 1 else report.failed = report.failed + 1; report.ok = false end
    end
    test("Every unsupported registry move spends PP and fails before effects or move RNG on either side", function()
        local b = fresh()
        for key in pairs(MoveSupport.gaps) do
            for _, side in ipairs({ "player", "enemy" }) do
                RulesRNG.seed(19)
                local pHP, eHP = b.player.hp, b.enemy.hp
                local text = attempt(b, key, side)
                assert(text:find("But it failed!", 1, true), key)
                eq(b[side].pp[key], moveData[key].maxPP - 1, key .. " PP")
                eq(b.player.hp, pHP, key .. " player HP")
                eq(b.enemy.hp, eHP, key .. " enemy HP")
                eq(b.player.status, nil); eq(b.enemy.status, nil)
                for _, mon in ipairs({ b.player, b.enemy }) do
                    for _, stage in pairs(mon.statStages) do eq(stage, 0, key .. " stage") end
                end
                eq(RulesRNG.snapshot().rolls, 0, key .. " move RNG")
                eq(b.outcome, nil); eq(b:phase(), "command")
                local gaps = b:getMoveGaps()
                eq(gaps[#gaps].move, key); eq(gaps[#gaps].side, side)
            end
        end
    end)
    test("Status NoEffect fallback fails and gap snapshots are bounded detached diagnostics", function()
        local b = fresh()
        local old = moveData.growl.effects
        moveData.growl.effects = { NO_EFFECT }
        local ok, problem = pcall(function()
            for _ = 1, 14 do
                assert(attempt(b, "growl"):find("But it failed!", 1, true))
            end
            local gaps = b:getMoveGaps()
            eq(#gaps, 12); eq(gaps[1].reason, "missing status effect")
            gaps[1].reason = "mutated"
            eq(b:getMoveGaps()[1].reason, "missing status effect")
        end)
        moveData.growl.effects = old
        assert(ok, problem)
    end)
    test("Supported DSL, ordinary damage, fixed damage and intentional Splash retain their paths", function()
        local b = fresh()
        attempt(b, "growl"); eq(b.enemy.statStages.atk, -1)
        RulesRNG.seed(1); attempt(b, "tackle"); assert(b.enemy.hp < b.enemy.maxHP)
        eq(b.player.pp.tackle, moveData.tackle.maxPP - 1)
        eq(#b:getMoveGaps(), 0)
        -- The seeded critical Tackle leaves Rattata with only 17 HP. Use a
        -- fresh real target so HP clamping cannot hide the fixed-40 path.
        b = fresh()
        local hp = b.enemy.hp
        assert(hp > 40, "fixed damage target must survive the full 40 HP hit")
        RulesRNG.seed(1)
        attempt(b, "dragonRage"); eq(b.enemy.hp, hp - 40)
        eq(b.lastDamage, 40)
        eq(b.player.pp.dragonRage, moveData.dragonRage.maxPP - 1)
        eq(RulesRNG.snapshot().rolls, 1, "fixed damage samples accuracy only")
        eq(RulesRNG.snapshot().state, 16807)
        eq(b.outcome, nil); eq(b:phase(), "command")
        hp = b.enemy.hp
        local before = RulesRNG.snapshot()
        local text = attempt(b, "splash")
        assert(text:find("But nothing happened!", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.splash, moveData.splash.maxPP - 1)
        eq(RulesRNG.snapshot().rolls, before.rolls)
        eq(RulesRNG.snapshot().state, before.state)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Roar uses the same real trainer replacement and queued actor cancellation as Whirlwind", function()
        local outgoing, incoming = Pokemon("rattata", 100), Pokemon("squirtle", 100)
        local party = roster(outgoing, incoming)
        local b = fresh(outgoing, { enemyParty = party }, "TRAINER")
        local displaced = { side = "enemy", actor = outgoing, key = "tackle", move = moveData.tackle }
        own(outgoing, "tackle")
        RulesRNG.seed(1)
        local text = attempt(b, "roar")
        eq(b.enemy, incoming); eq(party:active(), incoming)
        assert(text:find("SQUIRTLE was dragged out!", 1, true))
        eq(b.player.pp.roar, 19); eq(RulesRNG.snapshot().rolls, 2)
        local rolls = RulesRNG.snapshot().rolls
        eq(b:resolveTurn(displaced), nil)
        eq(outgoing.pp.tackle, 35); eq(RulesRNG.snapshot().rolls, rolls)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Roar respects real Soundproof before accuracy; Whirlwind bypasses that sound immunity", function()
        local mime = Pokemon("mr", 100, { natureId = 0, abilitySlot = "first", heldItem = "none" })
        eq(mime:ability(), 43)
        local incoming = Pokemon("squirtle", 100)
        local b = fresh(mime, { enemyParty = roster(mime, incoming) }, "TRAINER")
        RulesRNG.seed(1)
        assert(attempt(b, "roar"):find("Soundproof", 1, true))
        eq(b.enemy, mime); eq(b.player.pp.roar, 19); eq(RulesRNG.snapshot().rolls, 0)
        attempt(b, "whirlwind"); eq(b.enemy, incoming)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Roar wild escape is run without rewards; higher level and trainer without reserves fail normally", function()
        local b = fresh(Pokemon("rattata", 100))
        attempt(b, "roar"); eq(b.outcome, "run"); eq(b:getRewardSnapshot().awards, 0)
        b = fresh(Pokemon("rattata", 100)); b.player.level = 99
        assert(attempt(b, "roar"):find("But it failed!", 1, true)); eq(b.outcome, nil)
        b = fresh(nil, nil, "TRAINER")
        assert(attempt(b, "roar"):find("But it failed!", 1, true)); eq(b.outcome, nil)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Teleport escapes wild battles without rewards and fails in trainer battles through the normal action lifecycle", function()
        -- Pinned Showdown 9b136a8 gen7 override, inherited by gen5:
        -- priority 0, selfSwitch false, onTry false. Wild escape is the
        -- project's encounter extension; Showdown only models trainer battles.
        eq(moveData.teleport.priority, 0)
        eq(moveData.teleport.targetId, 7)
        for _, trainer in ipairs({ false, "TRAINER" }) do
            for _, side in ipairs({ "enemy", "player" }) do
                local player, enemy = Pokemon("pidgey", 10), Pokemon("abra", 8)
                local session = GameSession.newSession({ itemDefinitions = ItemData.definitions,
                    validateWorld = WorldDeltas.validate, resolveLocation = WorldDeltas.resolveLocation },
                    { location = { zone_id = "reds_house_2f", x = 5, y = 3, facing = "up" }, seed = 42 })
                assert(session:recruit(player))
                local reserve = Pokemon("abra", 8)
                local enemies = trainer and roster(enemy, reserve) or nil
                local b = Battle(player, enemy, trainer or nil, { session = session, enemyParty = enemies })
                battles[#battles + 1] = b
                settle(b)
                local actor, other = b[side], b[side == "player" and "enemy" or "player"]
                own(actor, "teleport"); own(other, "splash")
                -- Exercise actual command ordering: Teleport acts first, and
                -- only trainer failure lets the queued opposing action run.
                actor.spe, other.spe = 100, 1
                local xp, money = player.xp, session:inventory():money()
                local pHP, eHP = player.hp, enemy.hp
                local evs = {}; for key, value in pairs(player.evs) do evs[key] = value end
                local ended, won, kind = 0
                b:on("battleEnd", function(victory, outcome)
                    ended, won, kind = ended + 1, victory, outcome
                end)
                RulesRNG.seed(19)
                assert(b:selectMove(1))
                local text = settle(b)
                eq(actor.pp.teleport, 19)
                eq(player.hp, pHP); eq(enemy.hp, eHP)
                eq(player.xp, xp); eq(session:inventory():money(), money)
                for key, value in pairs(evs) do eq(player.evs[key], value, "escape EV " .. key) end
                eq(b:getRewardSnapshot().awards, 0)
                eq(#b:getMoveGaps(), 0)
                eq(b.effects.round, nil, "action queue released")
                -- Enemy choice consumes the sole roll; Teleport never rolls
                -- accuracy, damage, escape odds or a replacement selection.
                eq(RulesRNG.snapshot().rolls, 1)
                if trainer then
                    assert(text:find("But it failed!", 1, true))
                    eq(b.outcome, nil); eq(b:phase(), "command")
                    eq(ended, 0); eq(other.pp.splash, 39)
                    eq(b.enemy, enemy); eq(enemies:active(), enemy)
                    eq(b.effects.closed, false)
                else
                    assert(text:find(actor.name .. " fled!", 1, true))
                    eq(b.outcome, "run"); eq(b:phase(), "ended")
                    eq(ended, 1); eq(won, false); eq(kind, "run")
                    eq(other.pp.splash, 40)
                    eq(b.effects.closed, true)
                    eq(b:emitEnd(), false, "return emitted once")
                end
            end
        end
    end)
    test("Odor Sleuth identifies in singles with target-owned evasion and Ghost immunity cleanup", function()
        -- Oracle: 9b136a8 data/moves.ts odorsleuth -> foresight.condition;
        -- gen8/7/6/5 do not replace its behavior. sim/pokemon.ts addVolatile
        -- rejects a repeat without onRestart. Rare unsupported producers
        -- (Miracle Eye, reflection, Substitute, Baton Pass) are outside this case.
        eq(moveData.odorSleuth.accuracy, 0)
        eq(moveData.odorSleuth.maxPP, 40)
        for _, side in ipairs({ "player", "enemy" }) do
            local source = Pokemon("pidgey", 100)
            local target = Pokemon("gastly", 100)
            local sources = roster(source, Pokemon("pidgey", 100))
            local targets = roster(target, Pokemon("gastly", 100))
            local other = side == "player" and "enemy" or "player"
            local b = Battle(side == "player" and source or target,
                side == "player" and target or source, "TRAINER", {
                    party = side == "player" and sources or targets,
                    enemyParty = side == "player" and targets or sources,
                })
            battles[#battles + 1] = b
            settle(b)
            local first, second = b:effectiveTypes(target)
            local hp = target.hp
            source.statStages.acc = -6
            target.statStages.eva = 6
            eq(b:typeMatchup("normal", target), 0)
            eq(b:typeMatchup("fighting", target), 0)
            source.status = "sleep"
            source.statusTurns = 2
            source.sleepDuration = 2
            RulesRNG.seed(19)
            attempt(b, "odorSleuth", side)
            eq(source.pp.odorSleuth, 40, "sleep blocks before attempted PP")
            eq(b.conditions:identified(target), false)
            source.status = nil
            source.statusTurns = 0
            source.sleepDuration = 0
            b.conditions:of(target).protect = true
            RulesRNG.seed(19)
            assert(attempt(b, "odorSleuth", side):find("protected itself!", 1, true))
            eq(b.conditions:identified(target), false)
            eq(source.pp.odorSleuth, 39)
            eq(RulesRNG.snapshot().rolls, 0)
            b.conditions:of(target).protect = nil
            assert(attempt(b, "odorSleuth", side):find("was identified!", 1, true))
            eq(source.pp.odorSleuth, 39)
            eq(RulesRNG.snapshot().rolls, 0, "never-miss status uses no accuracy roll")
            eq(target.hp, hp)
            eq(target.status, nil)
            eq(target.statStages.eva, 6)
            assert(attempt(b, "odorSleuth", side):find("But it failed!", 1, true))
            eq(source.pp.odorSleuth, 39)
            eq(RulesRNG.snapshot().rolls, 0)
            source.statStages.acc = -1
            eq(accuracyThreshold(moveData.growl, source, target, b.effects), 75)
            target.statStages.eva = -2
            source.statStages.acc = -3
            eq(accuracyThreshold(moveData.sleepPowder, source, target, b.effects), 56,
                "negative evasion and user accuracy still apply")
            source.statStages.acc = -6
            target.statStages.eva = 6
            local seed = 1
            while RulesRNG.new(seed):random(1, 100) <= 33 do
                seed = seed + 1
            end
            RulesRNG.seed(seed)
            assert(attempt(b, "growl", side):find("attack missed!", 1, true))
            eq(target.statStages.atk, 0)
            eq(RulesRNG.snapshot().rolls, 1)
            source.statStages.acc = 0
            attempt(b, "growl", side)
            eq(target.statStages.atk, -1, "ordinary status ignores positive evasion")
            eq(target.statStages.eva, 6)
            eq(b:typeMatchup("normal", target), 1)
            eq(b:typeMatchup("fighting", target), 0.5, "Poison resistance survives")
            eq(b:typeMatchup("ground", target), 2)
            eq(b:typeMatchup("ghost", source), 0, "opponent is not identified")
            RulesRNG.seed(1)
            attempt(b, "sonicBoom", side)
            eq(target.hp, hp - 20, "actual Normal fixed hit")
            attempt(b, "seismicToss", side)
            eq(target.hp, hp - 120, "actual Fighting fixed hit")
            eq(target.type, first)
            eq(target.type2, second)
            local effectiveFirst, effectiveSecond = b:effectiveTypes(target)
            eq(effectiveFirst, first)
            eq(effectiveSecond, second)
            -- Withdrawing the source leaves identification on the target.
            RulesRNG.seed(1)
            attempt(b, "roar", other)
            assert(b[side] ~= source)
            eq(b.conditions:identified(target), true)
            -- Withdrawing the target clears it; its replacement inherits none.
            attempt(b, "roar", side)
            assert(b[other] ~= target)
            eq(b.conditions:identified(target), false)
            eq(b.conditions:identified(b[other]), false)
            attempt(b, "roar", side)
            eq(b[other], target)
            eq(b:typeMatchup("normal", target), 0, "return restores Ghost immunity")
            attempt(b, "odorSleuth", side)
            target:takeDamage(target.hp)
            b:setDirection(side)
            b:runScript(function()
                local result = b:handleFaint()
                eq(result, "replacement")
                return b:finishRound()
            end)
            settle(b)
            eq(b.conditions:identified(target), false, "faint cleanup")
            if b:needsForcedSwitch() then
                assert(b:chooseParty(2))
                settle(b)
            end
            attempt(b, "odorSleuth", side)
            local active = b[other]
            eq(b.conditions:identified(active), true)
            eq(#b:getMoveGaps(), 0)
            b:clearVolatiles()
            eq(b.conditions:identified(active), false, "battle cleanup")
            eq(b:typeMatchup("normal", active), 0)
        end
        local b = fresh()
        local hp = b.enemy.hp
        attempt(b, "odorSleuth")
        eq(b.conditions:identified(b.enemy), true, "non-Ghost identification")
        eq(b.enemy.hp, hp)
        eq(b:typeMatchup("fighting", b.enemy), 2, "ordinary weakness survives")
    end)
    test("Magnitude selects all seven powers before accuracy and damage without changing shared move data", function()
        -- Pinned Showdown 9b136a8 data/moves.ts, inherited through gen5.
        -- Seeds 1..100 visit each of its 100 selection buckets exactly once.
        local bands = { {5, 10}, {15, 30}, {35, 50}, {65, 70}, {85, 90}, {95, 110}, {100, 150} }
        local counts = { 0, 0, 0, 0, 0, 0, 0 }
        local shared = {}
        for key, value in pairs(moveData.magnitude) do shared[key] = value end
        for seed = 1, 100 do
            local source, target = Pokemon("geodude", 20), Pokemon("chansey", 100)
            local side = seed % 2 == 0 and "player" or "enemy"
            local b = side == "player" and Battle(source, target) or Battle(target, source)
            battles[#battles + 1] = b
            settle(b)
            b:setDirection(side)
            RulesRNG.seed(seed)
            local roll = RulesRNG.random(100)
            local band
            for index, entry in ipairs(bands) do
                if roll <= entry[1] then band = index; break end
            end
            counts[band] = counts[band] + 1
            RulesRNG.random(1, 100) -- accuracy follows selection
            local expected = calcDamage(source, target, moveData.magnitude, bands[band][2], b.effects)
            local after = RulesRNG.snapshot()
            local hp = target.hp
            RulesRNG.seed(seed)
            local text = attempt(b, "magnitude", side)
            assert(text:find("Magnitude " .. (band + 3) .. "!", 1, true))
            eq(target.hp, hp - expected.damage, "selected power damage")
            eq(b.lastDamage, expected.damage)
            eq(b.currentMove.power, bands[band][2], "active move power")
            assert(b.currentMove ~= moveData.magnitude)
            eq(source.pp.magnitude, 29)
            eq(RulesRNG.snapshot().state, after.state, "selection, accuracy, crit, damage order")
            eq(RulesRNG.snapshot().rolls, 4)
            eq(#b:getMoveGaps(), 0)
            for key, value in pairs(shared) do eq(moveData.magnitude[key], value, key) end
            for key in pairs(moveData.magnitude) do assert(shared[key] ~= nil, key) end
        end
        for index, expected in ipairs({5, 10, 20, 30, 20, 10, 5}) do
            eq(counts[index], expected, "Magnitude distribution " .. (index + 3))
        end
        -- A miss still announces its level and spends PP, without crit/damage.
        local b = fresh(Pokemon("chansey", 100))
        b.player.statStages.acc = -6
        local missSeed = 1
        while true do
            local stream = RulesRNG.new(missSeed)
            stream:random(100)
            if stream:random(1, 100) > 33 then break end
            missSeed = missSeed + 1
        end
        RulesRNG.seed(missSeed)
        local hp = b.enemy.hp
        local text = attempt(b, "magnitude")
        assert(text:find("Magnitude ", 1, true))
        assert(text:find("attack missed!", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.magnitude, 29)
        eq(RulesRNG.snapshot().rolls, 2)
        eq(#b:getMoveGaps(), 0)
        -- Selection also precedes Ground immunity; no accuracy/crit/damage.
        b = fresh(Pokemon("pidgey", 100))
        RulesRNG.seed(19)
        text = attempt(b, "magnitude")
        assert(text:find("Magnitude ", 1, true))
        assert(text:find("doesn't affect", 1, true))
        eq(b.enemy.hp, b.enemy.maxHP)
        eq(b.player.pp.magnitude, 29)
        eq(RulesRNG.snapshot().rolls, 1)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Pursuit intercepts voluntary withdrawal once at double power, including a faint before replacement", function()
        local b = fresh()
        own(b.enemy, "pursuit")
        local hp = b.player.hp
        RulesRNG.seed(19)
        RulesRNG.random(1,100) -- ordinary accuracy
        local ordinary = calcDamage(b.enemy,b.player,moveData.pursuit,40,b.effects).damage
        RulesRNG.seed(19)
        attempt(b,"pursuit","enemy")
        eq(hp-b.player.hp,ordinary,"ordinary Pursuit power40")
        for _, lethal in ipairs({false,true}) do
            local old, bench, enemy = Pokemon("pidgey",100), Pokemon("squirtle",100), Pokemon("rattata",100)
            local party=roster(old,bench)
            b=Battle(old,enemy,"TRAINER",{party=party})
            battles[#battles+1]=b
            settle(b)
            own(enemy,"pursuit")
            enemy.statStages.acc=-6
            old.statStages.eva=6
            RulesRNG.seed(19)
            RulesRNG.random(1,1) -- the opponent's single action choice
            local expected=calcDamage(enemy,old,moveData.pursuit,80,b.effects).damage
            if lethal then old.hp=1 else assert(expected<old.hp) end
            hp=old.hp
            RulesRNG.seed(19)
            assert(b:chooseParty(2))
            local text=settle(b)
            assert(text:find("used PURSUIT!",1,true))
            eq(old.hp,math.max(0,hp-expected),"outgoing takes power80 before withdrawal")
            eq(bench.hp,bench.maxHP,"incoming never takes Pursuit")
            eq(enemy.pp.pursuit,19,"one queued action only")
            eq(RulesRNG.snapshot().rolls,3,"choice, crit, damage; interception cannot miss")
            eq(b.effects.round,nil)
            if lethal then
                eq(b.player,old)
                eq(b:phase(),"forcedSwitch")
                assert(b:chooseParty(2))
                settle(b)
                eq(enemy.pp.pursuit,19,"forced replacement gives no second action")
            end
            eq(b.player,bench)
            eq(party:active(),bench)
            eq(#b:getMoveGaps(),0)
        end
    end)
    test("Disable locks the last move without PP loss and expires by pending-action timing", function()
        for _, targetPending in ipairs({true,false}) do
            local b=fresh()
            local player,enemy=b.player,b.enemy
            own(player,"splash")
            player.moves={"splash","tackle"}
            player.pp.tackle=35
            own(enemy,"disable")
            b:runScript(function()
                b:resolveTurn({side="player",actor=player,key="splash",move=moveData.splash})
            end)
            settle(b)
            local pp=player.pp.splash
            local target={side="player",actor=player,key="splash",move=moveData.splash}
            local disable={side="enemy",actor=enemy,key="disable",move=moveData.disable}
            local turns=targetPending and {disable,target} or {target,disable}
            RulesRNG.seed(19)
            b:runScript(function()return b:resolveRound(turns) end)
            settle(b)
            eq(player.pp.splash,pp-(targetPending and 0 or 1),"queued disabled action spends no PP")
            eq(enemy.pp.disable,19)
            eq(b.conditions:of(player).disable.turns,targetPending and 3 or 4)
            eq(b.conditions:of(player).disable.key,"splash")
            local before=RulesRNG.snapshot()
            local accepted,reason=b:selectMove(1)
            eq(accepted,false)
            eq(reason,"disabled-move")
            eq(RulesRNG.snapshot().rolls,before.rolls,"rejection does not roll")
            eq(#b:availableMoves(player),1)
            eq(b:availableMoves(player)[1].key,"tackle")
            eq(b:needsStruggle(player),false)
            player.moves={"splash"}
            eq(b:needsStruggle(player),true)
            own(enemy,"splash")
            local remaining=targetPending and 3 or 4
            for tick=1,remaining do
                local lockedPP=player.pp.splash
                b:runScript(function()return b:resolveRound({target}) end)
                settle(b)
                eq(player.pp.splash,lockedPP)
                eq(b.conditions:disabled(player,"splash"),tick<remaining)
            end
            assert(b:selectMove(1))
            settle(b)
            eq(#b:getMoveGaps(),0)
            -- A real last move with no remaining PP cannot be disabled.
            player.pp.splash=0
            local text=attempt(b,"disable","enemy")
            assert(text:find("But it failed!",1,true))
            eq(b.conditions:disabled(player,"splash"),false)
            b:clearVolatiles()
            eq(b.conditions.members[player],nil)
        end
    end)
    test("Encore repeats with normal PP, permits switching and ends at Gen V residual timing", function()
        for _, targetPending in ipairs({true, false}) do
            local b = fresh()
            local player, enemy = b.player, b.enemy
            own(player, "splash")
            player.moves = {"splash", "tackle"}
            player.pp.tackle = 35
            own(enemy, "encore")
            b:runScript(function()
                b:resolveTurn({side="player", actor=player, key="splash", move=moveData.splash})
            end)
            settle(b)
            local pp = player.pp.splash
            local target = {side="player", actor=player,
                key=targetPending and "tackle" or "splash",
                move=targetPending and moveData.tackle or moveData.splash}
            local encore = {side="enemy", actor=enemy, key="encore", move=moveData.encore}
            RulesRNG.seed(19)
            b:runScript(function()
                return b:resolveRound(targetPending and {encore, target} or {target, encore})
            end)
            settle(b)
            eq(player.pp.splash, pp - 1, "queued repeat spends PP")
            eq(player.pp.tackle, 35, "overridden selection spends none")
            eq(enemy.pp.encore, 4)
            eq(b.conditions:of(player).encore.turns, targetPending and 2 or 3)
            eq(b.conditions:locked(player), nil, "Encore is not a switch lock")
            eq(#b:availableMoves(player), 1)
            eq(b:availableMoves(player)[1].key, "splash")
            eq(b:selectMove(2), false, "other selection rejected")
            own(enemy, "splash")
            local remaining = targetPending and 2 or 3
            for tick = 1, remaining do
                pp = player.pp.splash
                assert(b:selectMove(1))
                settle(b)
                eq(player.pp.splash, pp - 1, "each repeat spends normal PP")
                eq(b.conditions:encoreKey(player), tick < remaining and "splash" or nil)
            end
            -- Exhaustion releases Encore at the same residual, restoring choices.
            attempt(b, "encore", "enemy")
            player.pp.splash = 1
            own(enemy, "splash")
            assert(b:selectMove(1))
            settle(b)
            eq(player.pp.splash, 0)
            eq(b.conditions:of(player).encore, nil)
            eq(b:availableMoves(player)[1].key, "tackle")
            -- A disabled encored slot leaves Struggle, without spending that PP.
            player.pp.splash = 2
            attempt(b, "encore", "enemy")
            b.conditions:of(player).disable = {key="splash", turns=4}
            own(enemy, "splash")
            eq(b:needsStruggle(player), true)
            assert(b:selectStruggle())
            settle(b)
            eq(player.pp.splash, 2)
            eq(b.conditions:of(player).lastMove, "struggle")
            eq(#b:getMoveGaps(), 0)
        end
        local old, bench = Pokemon("pidgey", 100), Pokemon("squirtle", 100)
        local b = Battle(old, Pokemon("rattata", 100), nil, {party=roster(old, bench)})
        battles[#battles + 1] = b
        settle(b)
        attempt(b, "splash")
        attempt(b, "encore", "enemy")
        assert(attempt(b, "encore", "enemy"):find("But it failed!", 1, true))
        own(b.enemy, "splash")
        assert(b:beginSelection("party"))
        assert(b:chooseParty(2))
        settle(b)
        eq(b.player, bench)
        eq(b.conditions.members[old], nil, "withdrawal clears Encore")
        -- Failed targets never acquire the condition, including last-use PP zero.
        b = fresh()
        assert(attempt(b, "encore"):find("But it failed!", 1, true))
        attempt(b, "splash", "enemy")
        b.enemy.pp.splash = 0
        assert(attempt(b, "encore"):find("But it failed!", 1, true))
        eq(b.conditions:of(b.enemy).encore, nil)
    end)
    test("Water Sport weakens Fire for both sides until its active user withdraws without a timer", function()
        local old, bench = Pokemon("pidgey", 100), Pokemon("squirtle", 100)
        local b = Battle(old, Pokemon("chansey", 100), nil, {party=roster(old, bench)})
        battles[#battles + 1] = b
        settle(b)
        attempt(b, "waterSport")
        eq(old.pp.waterSport, 14)
        eq(b.conditions:sportCount("waterSport"), 1)
        assert(attempt(b, "waterSport"):find("But it failed!", 1, true))
        for _ = 1, 6 do
            b:runScript(function() return b:resolveRound({}) end)
            settle(b)
        end
        eq(b.conditions:sportCount("waterSport"), 1, "no five-turn expiry")
        for _, side in ipairs({"player", "enemy"}) do
            b:setDirection(side)
            local source, target = b.attacker, b.defender
            eq(b:effectiveMovePower(moveData.ember, source, target), 13)
            eq(b:effectiveMovePower(moveData.waterGun, source, target), 40)
            RulesRNG.seed(19)
            RulesRNG.random(1, 100)
            local expected = calcDamage(source, target, moveData.ember, 13, b.effects).damage
            RulesRNG.seed(19)
            local hp = target.hp
            attempt(b, "ember", side)
            eq(target.hp, hp - expected, "real weakened Fire damage")
        end
        own(b.enemy, "splash")
        assert(b:beginSelection("party"))
        assert(b:chooseParty(2))
        settle(b)
        eq(b.conditions.members[old], nil)
        eq(b.conditions:sportCount("waterSport"), 0)
        eq(b:effectiveMovePower(moveData.ember, b.enemy, b.player), 40)
        eq(#b:getMoveGaps(), 0)
    end)
    test("Camouflage changes effective types to the Gen V Ground default and clears on withdrawal or battle close", function()
        local old,bench,enemy=Pokemon("pidgey",100),Pokemon("squirtle",100),Pokemon("rattata",100)
        local party=roster(old,bench)
        local b=Battle(old,enemy,"TRAINER",{party=party})
        battles[#battles+1]=b
        settle(b)
        own(enemy,"splash")
        local first,second=old.type,old.type2
        eq(first,"normal")
        eq(second,"flying")
        eq(b:typeMatchup("electric",old),2)
        RulesRNG.seed(19)
        local text=attempt(b,"camouflage")
        assert(text:find("GROUND type",1,true))
        eq(old.pp.camouflage,19)
        eq(RulesRNG.snapshot().rolls,0)
        local effective,other=b:effectiveTypes(old)
        eq(effective,"ground")
        eq(other,nil)
        eq(b:typeMatchup("electric",old),0)
        eq(b:typeMatchup("ghost",old),1)
        eq(calcDamage(old,enemy,moveData.mudSlap,20,b.effects).isSTAB,true)
        eq(old.type,first)
        eq(old.type2,second,"canonical types remain save-safe")
        text=attempt(b,"camouflage")
        assert(text:find("But it failed!",1,true))
        assert(b:chooseParty(2))
        settle(b)
        eq(b.conditions.members[old],nil)
        assert(b:chooseParty(1))
        settle(b)
        eq(b:typeMatchup("electric",old),2,"withdrawal restores Flying")
        attempt(b,"camouflage")
        eq(b:typeMatchup("electric",old),0)
        b:clearVolatiles()
        effective,other=b:effectiveTypes(old)
        eq(effective,first)
        eq(other,second,"battle close restores both types")
        eq(old.type,first)
        eq(old.type2,second)
        eq(#b:getMoveGaps(),0)
    end)
    test("Aromatherapy cures the owned living team in Gen V without blocking on Soundproof or an already healthy party", function()
        for _, side in ipairs({ "player", "enemy" }) do
            local session = GameSession.newSession({ itemDefinitions = ItemData.definitions,
                validateWorld = WorldDeltas.validate, resolveLocation = WorldDeltas.resolveLocation },
                { location = { zone_id = "reds_house_2f", x = 5, y = 3, facing = "up" }, seed = 42 })
            local players, enemies = {}, {}
            for index = 1, 6 do
                players[index] = Pokemon("mr", 100, { natureId = 0, abilitySlot = "first", heldItem = "none" })
                enemies[index] = Pokemon("mr", 100, { natureId = 0, abilitySlot = "first", heldItem = "none" })
                assert(session:recruit(players[index]))
            end
            local enemyParty = roster(table.unpack(enemies))
            local b = Battle(players[1], enemies[1], "TRAINER", { session = session, enemyParty = enemyParty })
            battles[#battles + 1] = b
            settle(b)
            local team = side == "player" and players or enemies
            local opponents = side == "player" and enemies or players
            local actor = team[1]
            eq(b.effects:effectiveAbility(actor), 43, "real Soundproof user")
            local statuses = { "burn", "sleep", "paralyze", "freeze", "poison", "badPoison" }
            for index, mon in ipairs(team) do
                mon.status = statuses[index]
                mon.statusTurns = index == 2 and 2 or 0
                mon.sleepDuration = index == 2 and 3 or 0
                mon:takeDamage(1)
            end
            opponents[1].status = "burn"
            team[2].confusion = 3
            b.conditions:of(actor).toxic = 4
            actor.statStages.atk = -1
            local hp = actor.hp
            local definition = moveData.aromatherapy
            RulesRNG.seed(19)
            local before = RulesRNG.snapshot()
            local text = attempt(b, "aromatherapy", side)
            assert(not text:find("But it failed!", 1, true))
            for _, mon in ipairs(team) do
                eq(mon.status, nil)
                eq(mon.statusTurns, 0)
                eq(mon.sleepDuration, 0)
                eq(mon.hp, mon.maxHP - 1, "cure does not heal HP")
            end
            eq(team[2].confusion, 3, "volatile confusion is not cured")
            eq(actor.statStages.atk, -1)
            eq(b.conditions:of(actor).toxic, nil)
            eq(opponents[1].status, "burn", "opposing team is unchanged")
            eq(actor.pp.aromatherapy, 4)
            eq(actor.hp, hp)
            eq(moveData.aromatherapy, definition)
            eq(definition.power, 0)
            eq(definition.targetId, 4)
            eq(definition.effects, nil, "shared move data is unchanged")
            eq(RulesRNG.snapshot().rolls, before.rolls)
            eq(RulesRNG.snapshot().state, before.state)
            -- Gen V's override returns no failure for an already healthy team.
            text = attempt(b, "aromatherapy", side)
            assert(not text:find("But it failed!", 1, true))
            eq(actor.pp.aromatherapy, 4)
            team[6]:takeDamage(team[6].hp)
            team[6].status = "poison"
            attempt(b, "aromatherapy", side)
            eq(team[6].status, "poison", "fainted reserve is not cured")
            eq(team[6].hp, 0)
            -- Existing BeforeMove and PP gates must prevent party cures.
            team[3].status = "paralyze"
            actor.status, actor.statusTurns, actor.sleepDuration = "sleep", 2, 2
            text = attempt(b, "aromatherapy", side)
            assert(text:find("fast asleep", 1, true))
            eq(actor.pp.aromatherapy, 5)
            eq(team[3].status, "paralyze")
            actor.status, actor.statusTurns, actor.sleepDuration = nil, 0, 0
            actor.pp.aromatherapy = 0
            b:runScript(function()
                b:resolveTurn({ side = side, actor = actor, key = "aromatherapy", move = definition })
            end)
            text = settle(b)
            assert(text:find("no PP left", 1, true))
            eq(team[3].status, "paralyze")
            eq(actor.pp.aromatherapy, 0)
            attempt(b, "aromatherapy", side)
            eq(team[3].status, nil)
            eq(RulesRNG.snapshot().rolls, before.rolls)
            eq(RulesRNG.snapshot().state, before.state)
            eq(b:phase(), "command")
            eq(b.outcome, nil)
            eq(#b:getMoveGaps(), 0)
            if side == "player" then
                own(b.enemy, "splash")
                assert(b:chooseParty(2))
                settle(b)
                eq(b.player, team[2])
                eq(session:party():active(), team[2])
                eq(actor.status, nil)
                eq(b.conditions.members[actor], nil, "withdrawal clears the ordinary condition owner")
            end
        end
        -- Standalone wild Battle has no separate party owner to invent.
        local b = fresh()
        b.player.status = "burn"
        b.enemy.status = "poison"
        attempt(b, "aromatherapy")
        eq(b.player.status, nil)
        eq(b.enemy.status, "poison")
        attempt(b, "aromatherapy", "enemy")
        eq(b.enemy.status, nil)
        eq(#b:getMoveGaps(), 0)
    end)
    RulesRNG.restore(saved)
    return report
end
