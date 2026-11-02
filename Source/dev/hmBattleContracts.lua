-- Compile-only preparation. Root owns execution in the real SDK.
HMBattleContracts = {}
local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end
local function own(mon, keys)
    mon.moves = {}
    mon.pp = {}
    for _, key in ipairs(keys) do
        mon.moves[#mon.moves + 1] = key
        mon.pp[key] = moveData[key].pp
    end
end
local function settle(battle)
    local lines = {}
    local count = 0
    while battle:phase() == "script" do
        count = count + 1
        assert(count < 300, "stuck HM script")
        assert(not battle.pendingLearning, "unexpected HM learning")
        lines[#lines + 1] = battle.message
        battle.machine:get("script"):advance()
    end
    return table.concat(lines, "|")
end
local function fresh(key, enemyKey, player, enemy, options)
    local trainerName = options and options.enemyParty and "HM CONTRACT" or nil
    local battle = Battle(player or Pokemon("venusaur", 100),
        enemy or Pokemon("snorlax", 100), trainerName, options)
    settle(battle)
    own(battle.player, {key})
    own(battle.enemy, {enemyKey or "harden"})
    battle.player.spe = 200
    battle.enemy.spe = 100
    return battle
end
local function use(battle, seed)
    RulesRNG.seed(seed or 1)
    assert(battle:selectMove(1))
    return settle(battle)
end
local function release(battle, seed)
    RulesRNG.seed(seed or 1)
    battle:update()
    eq(battle:phase(), "script")
    return settle(battle)
end
local function unchangedRNG(before)
    local after = RulesRNG.snapshot()
    eq(after.state, before.state, "RNG state")
    eq(after.rolls, before.rolls, "RNG rolls")
end
function HMBattleContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local saved = RulesRNG.snapshot()
    local function test(name, fn)
        local ok, why = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok,
            error = not ok and tostring(why) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.ok = false
            report.failed = report.failed + 1
        end
    end
    test("HM ordinary Cut Strength Surf resolve real damage PP and RNG", function()
        for _, key in ipairs({"cut", "strength", "surf"}) do
            local b = fresh(key)
            local hp = b.enemy.hp
            use(b)
            assert(b.enemy.hp < hp)
            eq(b.player.pp[key], moveData[key].pp - 1)
            eq(#b:getMoveGaps(), 0)
            eq(RulesRNG.snapshot().rolls, 4, key)
        end
    end)
    test("HM Flash changes actual accuracy with one attempt roll and PP", function()
        local b = fresh("flash")
        local hp = b.enemy.hp
        use(b)
        eq(b.enemy.statStages.acc, -1)
        eq(b.enemy.hp, hp)
        eq(b.player.pp.flash, 19)
        eq(RulesRNG.snapshot().rolls, 2)
        eq(#b:getMoveGaps(), 0)
    end)
    test("HM ordinary accuracy misses consume PP without damage or effect RNG", function()
        for _, key in ipairs({"cut", "flash", "strength", "surf"}) do
            local b = fresh(key)
            b.player.statStages.acc = -6
            b.enemy.statStages.eva = 6
            local hp = b.enemy.hp
            local text = use(b, 2)
            assert(text:find("attack missed", 1, true))
            eq(b.enemy.hp, hp)
            eq(b.enemy.statStages.acc, 0)
            eq(b.player.pp[key], moveData[key].pp - 1)
            eq(RulesRNG.snapshot().rolls, 2)
        end
    end)
    test("HM Normal immunity and Flash Keen Eye keep ordinary gates", function()
        for _, key in ipairs({"cut", "strength"}) do
            local b = fresh(key, nil, nil, Pokemon("gastly", 100))
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.player.pp[key], moveData[key].pp - 1)
            eq(RulesRNG.snapshot().rolls, 1)
        end
        local b = fresh("flash", nil, nil, Pokemon("pidgey", 100))
        b.enemy.ability = function() return 51 end -- existing Keen Eye hook
        use(b)
        eq(b.enemy.statStages.acc, 0)
        eq(b.player.pp.flash, 19)
    end)
    test("HM Surf Water Absorb heals and consumes no accuracy or damage RNG", function()
        local b = fresh("surf", nil, nil, Pokemon("vaporeon", 100))
        b.enemy.ability = function() return 11 end
        b.enemy.hp = b.enemy.maxHP - 20
        use(b)
        eq(b.enemy.hp, b.enemy.maxHP)
        eq(b.player.pp.surf, 14)
        eq(RulesRNG.snapshot().rolls, 1)
    end)
    test("HM Protect blocks each ordinary HM before accuracy damage and contact", function()
        for _, key in ipairs({"cut", "flash", "strength", "surf"}) do
            local b = fresh(key, "protect")
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.enemy.statStages.acc, 0)
            eq(b.player.pp[key], moveData[key].pp - 1)
            eq(RulesRNG.snapshot().rolls, 1)
        end
    end)
    test("HM Fly charges then automatic release consumes PP once", function()
        local b = fresh("fly")
        local hp = b.enemy.hp
        use(b)
        eq(b.conditions:lockedKey(b.player), "fly")
        eq(b.conditions:airborne(b.player), true)
        eq(b.enemy.hp, hp)
        eq(b.player.pp.fly, 14)
        eq(RulesRNG.snapshot().rolls, 1)
        release(b)
        assert(b.enemy.hp < hp)
        eq(b.player.pp.fly, 14)
        eq(b.conditions:lockedKey(b.player), nil)
        eq(b.conditions:airborne(b.player), false)
        eq(RulesRNG.snapshot().rolls, 4)
    end)
    test("HM contact Cut Strength Fly reach existing Effect Spore; Surf does not", function()
        for _, key in ipairs({"cut", "strength", "fly", "surf"}) do
            local b = fresh(key)
            b.enemy.ability = function() return 27 end
            if key == "fly" then
                use(b)
                eq(RulesRNG.snapshot().rolls, 1)
                release(b)
            else
                use(b)
            end
            eq(RulesRNG.snapshot().rolls, key == "surf" and 4 or 5, key)
        end
    end)
    test("HM Fly zero PP and forgotten slot still release stored identity", function()
        for _, forgotten in ipairs({false, true}) do
            local b = fresh("fly")
            b.player.pp.fly = 1
            use(b)
            eq(b.player.pp.fly, 0)
            if forgotten then
                own(b.player, {"harden"})
            end
            local hp = b.enemy.hp
            release(b)
            assert(b.enemy.hp < hp)
            eq(b.conditions:lockedKey(b.player), nil)
            if forgotten then
                eq(b.player.pp.fly, nil)
                eq(b.player.pp.harden, moveData.harden.pp)
            else
                eq(b.player.pp.fly, 0)
            end
        end
    end)
    test("HM Fly Protect on release clears charge without accuracy or second PP", function()
        local b = fresh("fly")
        use(b)
        own(b.enemy, {"protect"})
        local hp = b.enemy.hp
        release(b)
        eq(b.enemy.hp, hp)
        eq(b.player.pp.fly, 14)
        eq(b.conditions:airborne(b.player), false)
        eq(RulesRNG.snapshot().rolls, 1)
    end)
    test("HM Fly remains airborne before its slower release action", function()
        local b = fresh("fly", "tackle")
        use(b)
        b.player.spe = 50
        local hp = b.player.hp
        local text = release(b)
        assert(text:find("attack missed", 1, true))
        eq(b.player.hp, hp)
        eq(b.conditions:airborne(b.player), false)
        eq(b.player.pp.fly, 14)
        eq(RulesRNG.snapshot().rolls, 4)
    end)
    test("HM Fly public locked command rejections preserve RNG and PP", function()
        local b = fresh("fly")
        use(b)
        local before = RulesRNG.snapshot()
        eq(b:selectMove(0), false)
        eq(b:tryRun(), false)
        eq(b:beginSelection("bag"), false)
        eq(b:beginSelection("party"), false)
        eq(b.player.pp.fly, 14)
        unchangedRNG(before)
    end)
    test("HM Fly blocks ordinary Swift Flash Surf and Whirlwind while airborne", function()
        for _, key in ipairs({"tackle", "swift", "flash", "surf", "whirlwind"}) do
            local b = fresh("fly", key)
            local hp = b.player.hp
            local text = use(b)
            assert(text:find("attack missed", 1, true), key)
            eq(b.player.hp, hp)
            eq(b.player.statStages.acc, 0)
            eq(b.player.pp.fly, 14)
            eq(b.enemy.pp[key], moveData[key].pp - 1)
            eq(RulesRNG.snapshot().rolls, 1)
        end
    end)
    test("HM Fly permits existing Gust Twister Thunder Hurricane Sky Uppercut", function()
        for _, key in ipairs({"gust", "twister", "thunder", "hurricane", "skyUppercut"}) do
            local b = fresh("fly", key)
            local hp = b.player.hp
            use(b)
            assert(b.player.hp < hp, key)
            eq(b.enemy.pp[key], moveData[key].pp - 1)
            eq(#b:getMoveGaps(), 0)
        end
    end)
    test("HM Fly doubles final Gust Twister damage with actual attack resolution", function()
        for _, key in ipairs({"gust", "twister"}) do
            local grounded = fresh("harden", key)
            local hp = grounded.player.hp
            use(grounded)
            local ordinary = hp - grounded.player.hp
            local flying = fresh("fly", key)
            hp = flying.player.hp
            use(flying)
            eq(hp - flying.player.hp, ordinary * 2, key)
        end
    end)
    test("HM Fly Gust and Light Screen cancel without intermediate rounding loss", function()
        local ordinary = fresh("harden", "gust")
        local hp = ordinary.player.hp
        use(ordinary)
        local damage = hp - ordinary.player.hp
        local b = fresh("lightScreen")
        use(b)
        own(b.player, {"fly"})
        own(b.enemy, {"gust"})
        hp = b.player.hp
        use(b)
        eq(hp - b.player.hp, damage)
    end)
    test("HM Fly No Guard on either battler allows an ordinary attack", function()
        for _, side in ipairs({"player", "enemy"}) do
            local b = fresh("fly", "tackle")
            b[side].ability = function() return 99 end
            local hp = b.player.hp
            use(b)
            assert(b.player.hp < hp)
            eq(RulesRNG.snapshot().rolls, 3)
        end
    end)
    test("HM Fly first-turn sleep prevents PP charge and airborne state", function()
        local b = fresh("fly")
        b.player.status = "sleep"
        b.player.statusTurns = 1
        b.player.sleepDuration = 1
        use(b)
        eq(b.player.pp.fly, 15)
        eq(b.conditions:lockedKey(b.player), nil)
        eq(b.conditions:airborne(b.player), false)
        eq(RulesRNG.snapshot().rolls, 1)
    end)
    test("HM Fly release sleep freeze flinch confusion and paralysis clear airborne lock", function()
        for _, kind in ipairs({"sleep", "freeze", "flinch", "confuse", "paralyze"}) do
            local b = fresh("fly")
            use(b)
            if kind == "sleep" then
                b.player.status = "sleep"
                b.player.statusTurns = 1
                b.player.sleepDuration = 1
            elseif kind == "freeze" then
                b.player.status = "freeze"
            elseif kind == "flinch" then
                b.player.flinched = true
            elseif kind == "confuse" then
                b.player.confusion = 2
            else
                b.player.status = "paralyze"
            end
            local seed = 1
            if kind == "paralyze" or kind == "freeze" then
                for candidate = 1, 100 do
                    local rng = RulesRNG.new(candidate)
                    rng:random(1, 1)
                    local blocked
                    if kind == "paralyze" then
                        blocked = rng:random(1, 4) == 1
                    else
                        blocked = rng:random(1, 5) ~= 1
                    end
                    if blocked then
                        seed = candidate
                        break
                    end
                end
            end
            local text = release(b, seed)
            if kind == "confuse" then
                assert(text:find("hurt itself", 1, true))
            elseif kind == "paralyze" then
                assert(text:find("can't move", 1, true))
            elseif kind == "freeze" then
                assert(text:find("frozen solid", 1, true))
            end
            eq(b.conditions:lockedKey(b.player), nil)
            eq(b.conditions:airborne(b.player), false)
            eq(b.player.pp.fly, 14)
        end
    end)
    test("HM Fly release miss clears charge and spends only accuracy RNG", function()
        local b = fresh("fly")
        use(b)
        b.player.statStages.acc = -6
        b.enemy.statStages.eva = 6
        local seed
        for candidate = 1, 100 do
            local rng = RulesRNG.new(candidate)
            rng:random(1, 1)
            if rng:random(1, 100) > 31 then
                seed = candidate
                break
            end
        end
        assert(seed)
        local hp = b.enemy.hp
        local text = release(b, seed)
        assert(text:find("attack missed", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.fly, 14)
        eq(b.conditions:airborne(b.player), false)
        eq(RulesRNG.snapshot().rolls, 2)
    end)
    test("HM Fly enemy continuation has no second AI choice or PP spend", function()
        local b = fresh("harden", "fly")
        b.player.spe = 100
        b.enemy.spe = 200
        use(b)
        eq(b.conditions:airborne(b.enemy), true)
        eq(b.enemy.pp.fly, 14)
        use(b)
        eq(b.conditions:airborne(b.enemy), false)
        eq(b.enemy.pp.fly, 14)
        eq(RulesRNG.snapshot().rolls, 3)
    end)
    test("HM Fly release targets opposing replacement slot after real self KO", function()
        local p = Pokemon("venusaur", 100)
        local first = Pokemon("rattata", 100)
        local nextMon = Pokemon("snorlax", 100)
        local enemies = Party()
        assert(enemies:add(first))
        assert(enemies:add(nextMon))
        own(nextMon, {"harden"})
        local b = fresh("fly", "takeDown", p, first, {enemyParty = enemies})
        -- Opponent acts first, damaging itself before Fly prepares.
        first.spe = 300
        first.hp = 1
        use(b)
        eq(first.hp, 0)
        eq(b.enemy, nextMon)
        eq(b.conditions:lockedKey(p), "fly")
        local hp = nextMon.hp
        release(b)
        assert(nextMon.hp < hp)
        eq(p.pp.fly, 14)
        eq(first.hp, 0)
    end)
    test("HM Fly actual No Guard Roar withdrawal clears outgoing receipt", function()
        local p = Pokemon("venusaur", 100)
        local reserve = Pokemon("pidgey", 100)
        local party = Party()
        assert(party:add(p))
        assert(party:add(reserve))
        local b = fresh("fly", "roar", p, nil, {party = party})
        b.enemy.ability = function() return 99 end
        b.trainerName = "HM WITHDRAWAL"
        use(b)
        eq(b.player, reserve)
        eq(b.conditions:airborne(p), false)
        eq(b.conditions:lockedKey(p), nil)
        eq(p.pp.fly, 14)
    end)
    test("HM Fly actual Gust KO clears charge before forced replacement", function()
        local p = Pokemon("venusaur", 100)
        local reserve = Pokemon("pidgey", 100)
        local party = Party()
        assert(party:add(p))
        assert(party:add(reserve))
        local b = fresh("fly", "gust", p, nil, {party = party})
        p.hp = 1
        use(b)
        eq(p.hp, 0)
        eq(p.pp.fly, 14)
        eq(b.conditions:airborne(p), false)
        eq(b.conditions:lockedKey(p), nil)
        eq(b:phase(), "forcedSwitch")
        assert(b:chooseParty(2))
        settle(b)
        eq(b.player, reserve)
    end)
    test("HM Fly faint forced replacement and battle cleanup discard transient state", function()
        local p = Pokemon("venusaur", 100)
        local reserve = Pokemon("pidgey", 100)
        local party = Party()
        assert(party:add(p))
        assert(party:add(reserve))
        local b = fresh("fly", nil, p, nil, {party = party})
        use(b)
        p.hp = 0
        b:runScript(function()
            b:setDirection("enemy")
            eq(b:handleFaint("player"), "replacement")
            return b:finishRound()
        end)
        settle(b)
        eq(b.conditions:airborne(p), false)
        eq(b:phase(), "forcedSwitch")
        assert(b:chooseParty(2))
        settle(b)
        eq(b.player, reserve)
        eq(b.conditions:lockedKey(reserve), nil)
        local other = fresh("fly")
        use(other)
        local wire = assert(PokemonCodec.encode(other.player))
        eq(wire.charge, nil)
        eq(wire.airborne, nil)
        other:clearVolatiles()
        eq(other.conditions:airborne(other.player), false)
        eq(other.conditions:lockedKey(other.player), nil)
    end)
    RulesRNG.restore(saved)
    return report
end
