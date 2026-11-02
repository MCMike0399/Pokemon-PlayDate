-- Native SDK contracts. Root imports/registers this module in private staging.
StageResetContracts = {}
local stages <const> = { "atk", "def", "spa", "spd", "spe", "acc", "eva" }
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function settle(b)
    local count = 0
    local messages = {}
    while b:phase() == "script" do
        count = count + 1
        assert(count < 300, "stage-reset script stuck: " .. tostring(b.message))
        messages[#messages + 1] = b.message
        b.machine:get("script"):advance()
    end
    return table.concat(messages, "|")
end
local function own(mon, key)
    mon.moves = { key }
    mon.pp = { [key] = moveData[key].pp }
end
local function fresh(enemy, player)
    local b = Battle(player or Pokemon("koffing", 50), enemy or Pokemon("snorlax", 100))
    settle(b)
    return b
end
local function boost(mon)
    for i, stat in ipairs(stages) do
        mon.statStages[stat] = i % 2 == 0 and -6 or 6
    end
end
local function zero(mon)
    for _, stat in ipairs(stages) do
        eq(mon.statStages[stat], 0)
    end
end
local function use(b, key, side)
    side = side or "player"
    local mon = b[side]
    b:runScript(function()
        return b:resolveTurn({ side = side, actor = mon, key = key, move = moveData[key] })
    end)
    return settle(b)
end
local function noRolls(before)
    local after = RulesRNG.snapshot()
    eq(after.rolls, before.rolls)
    eq(after.state, before.state)
end
function StageResetContracts.run()
    local saved = RulesRNG.snapshot()
    local report = { ok = true, passed = 0, failed = 0, tests = {} }
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = { name = name, ok = ok, error = not ok and tostring(problem) or nil }
        if ok then
            report.passed = report.passed + 1
        else
            report.ok = false
            report.failed = report.failed + 1
        end
    end
    test("Haze resets both active seven stages and preserves unrelated state", function()
        local b = fresh()
        own(b.player, "haze")
        local reserve = Pokemon("squirtle", 50)
        local party = Party()
        assert(party:add(b.player))
        assert(party:add(reserve))
        b.party = party
        boost(reserve)
        boost(b.player)
        boost(b.enemy)
        local p, e = b.player, b.enemy
        local stageTable, moves, pp, ivs = e.statStages, e.moves, e.pp, e.ivs
        local hp, xp, ability = e.hp, e.xp, e.abilitySlot
        e.status = "sleep"
        e.statusTurns = 2
        e.sleepDuration = 3
        e.confusion = 4
        e.flinched = true
        local state = b.conditions:of(e)
        state.focusEnergy = true
        state.foresight = true
        state.toxic = 5
        b.effects.abilityOverrides[e] = 29
        b.effects.weather = { id = "raindance", turns = 3 }
        b.conditions.sides.enemy.reflect = { turns = 4 }
        local before = RulesRNG.snapshot()
        use(b, "haze")
        zero(p)
        zero(e)
        eq(reserve.statStages.atk, 6)
        eq(e.statStages, stageTable)
        eq(e.moves, moves)
        eq(e.pp, pp)
        eq(e.ivs, ivs)
        eq(e.hp, hp)
        eq(e.xp, xp)
        eq(e.abilitySlot, ability)
        eq(e.status, "sleep")
        eq(e.statusTurns, 2)
        eq(e.sleepDuration, 3)
        eq(e.confusion, 4)
        eq(e.flinched, true)
        eq(b.conditions:of(e), state)
        eq(state.focusEnergy, true)
        eq(state.foresight, true)
        eq(state.toxic, 5)
        eq(b.effects.abilityOverrides[e], 29)
        eq(b.effects.weather.turns, 3)
        eq(b.conditions.sides.enemy.reflect.turns, 4)
        eq(p.pp.haze, 29)
        noRolls(before)
    end)
    test("Haze with no boosts succeeds through Protect without an accuracy draw", function()
        local b = fresh()
        own(b.player, "haze")
        b.conditions:of(b.enemy).protect = true
        local before = RulesRNG.snapshot()
        local text = use(b, "haze")
        assert(text:find("All stat changes were eliminated!", 1, true))
        assert(not text:find("failed", 1, true))
        zero(b.player)
        zero(b.enemy)
        eq(b.conditions:of(b.enemy).protect, true)
        noRolls(before)
    end)
    test("Stage-reset producers retain sleep flinch and exhausted PP action gates", function()
        for _, key in ipairs({ "haze", "clearSmog" }) do
            for _, gate in ipairs({ "sleep", "flinch", "pp" }) do
                local b = fresh()
                own(b.player, key)
                boost(b.enemy)
                if gate == "sleep" then
                    b.player.status = "sleep"
                    b.player.statusTurns = 2
                    b.player.sleepDuration = 2
                elseif gate == "flinch" then
                    b.player.flinched = true
                else
                    b.player.pp[key] = 0
                end
                local before = RulesRNG.snapshot()
                use(b, key)
                eq(b.enemy.statStages.atk, 6)
                eq(b.player.pp[key], gate == "pp" and 0 or moveData[key].pp)
                noRolls(before)
            end
        end
    end)
    test("Clear Smog body hit resets only defender and retains exact damage RNG", function()
        local b = fresh()
        own(b.player, "clearSmog")
        boost(b.player)
        boost(b.enemy)
        b.player.statStages.acc = -6
        local e = b.enemy
        local hp = e.hp
        local state = b.conditions:of(e)
        state.focusEnergy = true
        e.confusion = 4
        e.flinched = true
        -- One crit trial then one damage trial: accuracy zero consumes none.
        RulesRNG.seed(73)
        local expected = RulesRNG.new(73)
        expected:random(1, 16)
        expected:random(85, 100)
        use(b, "clearSmog")
        assert(e.hp < hp and e.hp > 0)
        zero(e)
        eq(b.player.statStages.atk, 6)
        eq(b.player.statStages.acc, -6)
        eq(e.confusion, 4)
        eq(e.flinched, true)
        eq(state.focusEnergy, true)
        eq(b.player.pp.clearSmog, 14)
        local actual = RulesRNG.snapshot()
        local wanted = expected:snapshot()
        eq(actual.state, wanted.state)
        eq(actual.rolls, wanted.rolls)
    end)
    test("Clear Smog Protect blocks damage reset and damage RNG but spends PP", function()
        local b = fresh()
        own(b.player, "clearSmog")
        boost(b.enemy)
        b.conditions:of(b.enemy).protect = true
        local hp = b.enemy.hp
        local before = RulesRNG.snapshot()
        use(b, "clearSmog")
        eq(b.enemy.hp, hp)
        eq(b.enemy.statStages.atk, 6)
        eq(b.player.pp.clearSmog, 14)
        noRolls(before)
    end)
    test("Clear Smog Steel immunity blocks damage reset and RNG but spends PP", function()
        local b = fresh(Pokemon("magnemite", 100))
        own(b.player, "clearSmog")
        boost(b.enemy)
        local hp = b.enemy.hp
        local before = RulesRNG.snapshot()
        use(b, "clearSmog")
        eq(b.enemy.hp, hp)
        eq(b.enemy.statStages.atk, 6)
        eq(b.player.pp.clearSmog, 14)
        noRolls(before)
    end)
    test("Clear Smog primary reset bypasses Clear Body and Shield Dust", function()
        for _, enemy in ipairs({ Pokemon("tentacool", 100), Pokemon("caterpie", 100) }) do
            local b = fresh(enemy)
            own(b.player, "clearSmog")
            boost(enemy)
            use(b, "clearSmog")
            zero(enemy)
        end
    end)
    test("Enemy Clear Smog resets player only and leaves reserves unchanged", function()
        local b = fresh(Pokemon("koffing", 5))
        own(b.enemy, "clearSmog")
        local reserve = Pokemon("squirtle", 50)
        local party = Party()
        assert(party:add(b.player))
        assert(party:add(reserve))
        b.party = party
        boost(b.player)
        boost(b.enemy)
        boost(reserve)
        use(b, "clearSmog", "enemy")
        zero(b.player)
        eq(b.enemy.statStages.atk, 6)
        eq(reserve.statStages.atk, 6)
    end)
    test("Clear Smog lethal primary hit resets before ordinary faint handling", function()
        local b = fresh(nil, Pokemon("koffing", 100))
        own(b.player, "clearSmog")
        boost(b.enemy)
        b.enemy.hp = 1
        local text = use(b, "clearSmog")
        local reset = assert(text:find("stat changes were eliminated!", 1, true))
        local faint = assert(text:find("fainted!", 1, true))
        assert(reset < faint)
        eq(b.enemy.hp, 0)
        zero(b.enemy)
    end)
    RulesRNG.restore(saved)
    return report
end
