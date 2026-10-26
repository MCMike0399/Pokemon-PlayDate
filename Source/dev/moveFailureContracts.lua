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
        local hp = b.enemy.hp
        attempt(b, "dragonRage"); eq(b.enemy.hp, hp - 40)
        local text = attempt(b, "splash")
        assert(text:find("But nothing happened!", 1, true))
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
    RulesRNG.restore(saved)
    return report
end
