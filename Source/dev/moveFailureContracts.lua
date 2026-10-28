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
    RulesRNG.restore(saved)
    return report
end
