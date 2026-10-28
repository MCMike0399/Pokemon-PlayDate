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
    RulesRNG.restore(saved)
    return report
end
