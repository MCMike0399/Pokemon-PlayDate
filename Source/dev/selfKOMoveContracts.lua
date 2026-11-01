-- Source-only candidate: Root registers and runs this with the actual SDK.
SelfKOMoveContracts = {}
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function own(mon, key)
    mon.moves = {key}
    mon.pp = {[key] = moveData[key].pp}
end
local function settle(b, observe)
    local lines = {}
    local count = 0
    while b:phase() == "script" do
        count = count + 1
        assert(count < 300, "self-KO script stuck: " .. tostring(b.message))
        assert(not b.pendingLearning, "unexpected learning")
        lines[#lines + 1] = b.message
        if observe then
            observe(b)
        end
        b.machine:get("script"):advance()
    end
    return table.concat(lines, "|")
end
local function fresh(key, enemyKey, enemySpecies, dependencies)
    local p = dependencies and dependencies.party:active() or Pokemon("snorlax", 100)
    local e = dependencies and dependencies.enemyParty and dependencies.enemyParty:active() or Pokemon(enemySpecies or "snorlax", 100)
    local b = Battle(p, e, dependencies and "TRAINER" or nil, dependencies)
    settle(b)
    own(p, key or "selfDestruct")
    own(e, enemyKey or "splash")
    p.spe = 200
    e.spe = 100
    -- Keep ability-dependent cases explicit and independent of specimen rolls.
    p.ability = function()
        return 0
    end
    e.ability = function()
        return 0
    end
    return b
end
local function use(b, seed, observe)
    RulesRNG.seed(seed or 73)
    assert(b:selectMove(1))
    return settle(b, observe)
end
local function rng(seed, draws)
    local expected = RulesRNG.new(seed)
    for _, bounds in ipairs(draws) do
        expected:random(bounds[1], bounds[2])
    end
    eq(RulesRNG.snapshot().state, expected:snapshot().state)
    eq(RulesRNG.snapshot().rolls, expected:snapshot().rolls)
end
function SelfKOMoveContracts.run()
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
    test("Self-KO zero PP rejects before round mutation and RNG", function()
        for _, key in ipairs({"selfDestruct", "explosion"}) do
            local b = fresh(key)
            b.player.pp[key] = 0
            local hp = b.player.hp
            RulesRNG.seed(73)
            local ok, why = b:selectMove(1)
            eq(ok, false)
            eq(why, "no-pp")
            eq(b.player.hp, hp)
            eq(b.effects.round, nil)
            rng(73, {})
        end
    end)
    test("Self-KO sleep flinch paralysis and confusion retain BeforeMove gates", function()
        for _, gate in ipairs({"sleep", "flinch", "paralysis", "confusion"}) do
            local b = fresh()
            local seed = 73
            if gate == "sleep" then
                b.player.status = "sleep"
                b.player.statusTurns = 1
                b.player.sleepDuration = 1
            elseif gate == "flinch" then
                b.player.flinched = true
            else
                -- Choose from the real stream, after the ordinary enemy-choice draw.
                for candidate = 1, 100 do
                    local trial = RulesRNG.new(candidate)
                    trial:random(1, 1)
                    if trial:random(1, gate == "paralysis" and 4 or 2) == 1 then
                        seed = candidate
                        break
                    end
                end
                if gate == "paralysis" then
                    b.player.status = "paralyze"
                    b.player.spe = 1000
                else
                    b.player.confusion = 2
                end
            end
            use(b, seed)
            assert(b.player:isAlive())
            eq(b.player.pp.selfDestruct, 5)
            eq(b.enemy.hp, b.enemy.maxHP)
            if gate == "confusion" then
                rng(seed, {{1,1}, {1,2}, {85,100}})
            elseif gate == "paralysis" then
                rng(seed, {{1,1}, {1,4}})
            else
                rng(seed, {{1,1}})
            end
        end
    end)
    test("Self-KO commits before target damage bypasses Magic Guard and preserves damage RNG", function()
        for _, key in ipairs({"selfDestruct", "explosion"}) do
            local b = fresh(key)
            b.player.ability = function()
                return 98
            end
            b.player.atk = 1
            b.enemy.def = 1000
            local before = b.enemy.hp
            local sawHit = false
            use(b, 73, function(current)
                if current.message:find("took", 1, true) then
                    sawHit = true
                    eq(current.player.hp, 0)
                    assert(current.enemy.hp < before)
                    eq(current.faintAnnounced.player, nil)
                end
            end)
            assert(sawHit)
            eq(b.player.hp, 0)
            eq(b.player.pp[key], 4)
            eq(#b:getMoveGaps(), 0)
            eq(b.outcome, "defeat")
            rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
        end
    end)
    test("Self-KO King's Rock retains its pre-faint secondary and RNG boundary", function()
        for _, key in ipairs({"selfDestruct", "explosion"}) do
            for _, flinch in ipairs({true, false}) do
                local party = Party()
                assert(party:add(Pokemon("snorlax", 100)))
                assert(party:add(Pokemon("venusaur", 100)))
                local b = fresh(key, "splash", nil, {party=party})
                b.player.heldItem = "kingsRock"
                b.player.atk = 1
                b.enemy.def = 1000
                local original = moveData[key].secondaries
                local seed
                for candidate = 1, 1000 do
                    local trial = RulesRNG.new(candidate)
                    trial:random(1, 1)
                    trial:random(1, 100)
                    trial:random(1, 16)
                    trial:random(85, 100)
                    if (trial:random(1, 100) <= 10) == flinch then
                        seed = candidate
                        break
                    end
                end
                assert(seed)
                local checked = false
                use(b, seed, function(current)
                    if not checked and current.message == current.player.name .. " fainted!" then
                        checked = true
                        eq(current.player.hp, 0)
                        assert(current.enemy.hp > 0)
                        eq(current.enemy.flinched == true, flinch)
                        rng(seed, {{1,1}, {1,100}, {1,16}, {85,100}, {1,100}})
                    end
                end)
                assert(checked, "missing actual self-faint boundary")
                eq(b.player.heldItem, "kingsRock")
                eq(moveData[key].secondaries, original)
            end
        end
    end)
    test("Self-KO Normal immunity still faints the user without hit RNG", function()
        local b = fresh("selfDestruct", "splash", "gengar")
        local text = use(b)
        assert(text:find("doesn't affect", 1, true))
        eq(b.player.hp, 0)
        eq(b.enemy.hp, b.enemy.maxHP)
        eq(b.player.pp.selfDestruct, 4)
        rng(73, {{1,1}})
    end)
    test("Self-KO Protect still faints the user without accuracy or damage RNG", function()
        local b = fresh("explosion", "protect")
        local text = use(b)
        assert(text:find("protected", 1, true))
        eq(b.player.hp, 0)
        eq(b.enemy.hp, b.enemy.maxHP)
        eq(b.enemy.pp.protect, 9)
        rng(73, {{1,1}})
    end)
    test("Self-KO accuracy miss faints the user with only the ordinary accuracy draw", function()
        local b = fresh()
        b.player.statStages.acc = -6
        local seed
        for candidate = 1, 100 do
            local trial = RulesRNG.new(candidate)
            trial:random(1, 1)
            if trial:random(1, 100) > 33 then
                seed = candidate
                break
            end
        end
        assert(seed)
        local text = use(b, seed)
        assert(text:find("attack missed", 1, true))
        eq(b.player.hp, 0)
        eq(b.enemy.hp, b.enemy.maxHP)
        rng(seed, {{1,1}, {1,100}})
    end)
    test("Self-KO airborne rejection and user No Guard retain pre-checkpoint ability lifetime", function()
        for _, noGuard in ipairs({false, true}) do
            local b = fresh("explosion", "fly")
            b.enemy.spe = 300
            b.player.atk = 1
            if noGuard then
                b.player.ability = function()
                    return 99
                end
            end
            local text = use(b)
            eq(b.player.hp, 0)
            if noGuard then
                assert(b.enemy.hp < b.enemy.maxHP)
                rng(73, {{1,1}, {1,16}, {85,100}})
            else
                assert(text:find("attack missed", 1, true))
                eq(b.enemy.hp, b.enemy.maxHP)
                rng(73, {{1,1}})
            end
        end
    end)
    test("Damp on either active side prevents self-KO after PP without hit RNG", function()
        for _, side in ipairs({"player", "enemy"}) do
            local b = fresh()
            b[side].ability = function()
                return 6
            end
            local text = use(b)
            assert(text:find("Damp", 1, true))
            eq(b.player.hp, b.player.maxHP)
            eq(b.enemy.hp, b.enemy.maxHP)
            eq(b.player.pp.selfDestruct, 4)
            eq(#b:getMoveGaps(), 0)
            rng(73, {{1,1}})
        end
    end)
    test("Damp reads current effective ability and ignores fainted holders", function()
        local b = fresh()
        b.enemy.ability = function()
            return 6
        end
        b.effects.abilityOverrides[b.enemy] = 15
        eq(b.effects:selfDestructBlocker(b.player), nil)
        b.effects.abilityOverrides[b.enemy] = nil
        eq(b.effects:selfDestructBlocker(b.player), b.enemy)
        b.enemy:takeDamage(b.enemy.hp)
        eq(b.effects:selfDestructBlocker(b.player), nil)
    end)
    test("Mold Breaker family suppresses Damp only at the explicit self-KO seam", function()
        for _, id in ipairs({104, 163, 164}) do
            local b = fresh()
            b.player.ability = function()
                return id
            end
            b.enemy.ability = function()
                return 6
            end
            b.player.atk = 1
            use(b)
            eq(b.player.hp, 0)
            assert(b.enemy.hp < b.enemy.maxHP)
            eq(b.effects:supported(id), false)
            rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
        end
    end)
    test("Self-KO simultaneous final mons award the target side in both orientations", function()
        for _, side in ipairs({"player", "enemy"}) do
            local b = fresh(side == "player" and "selfDestruct" or "splash",
                side == "enemy" and "explosion" or "splash", "blastoise")
            local user = b[side]
            local target = side == "player" and b.enemy or b.player
            target.hp = 1
            user.spe = 300
            local xp = b.player.xp
            local text = use(b)
            eq(b.player.hp, 0)
            eq(b.enemy.hp, 0)
            eq(b.outcome, side == "player" and "defeat" or "victory")
            local userAt = assert(text:find(user.name .. " fainted!", 1, true))
            local targetAt = assert(text:find(target.name .. " fainted!", 1, true))
            assert(userAt < targetAt)
            eq(b.player.xp, xp)
            eq(b.faintAnnounced.player, true)
            eq(b.faintAnnounced.enemy, true)
            assert(userAt)
        end
    end)
    test("Self-KO double faint retains party replacement and reward identity owners", function()
        local p = Pokemon("snorlax", 100)
        local e = Pokemon("blastoise", 100)
        local reserve = Pokemon("venusaur", 100)
        local enemyReserve = Pokemon("charizard", 100)
        local party = Party()
        assert(party:add(p))
        assert(party:add(reserve))
        local enemyParty = Party()
        assert(enemyParty:add(e))
        assert(enemyParty:add(enemyReserve))
        local b = fresh("selfDestruct", "splash", nil, {party=party, enemyParty=enemyParty})
        e.hp = 1
        use(b)
        eq(b.outcome, nil)
        eq(p.hp, 0)
        eq(e.hp, 0)
        eq(b.party, party)
        eq(b.enemyParty, enemyParty)
        eq(b:needsForcedSwitch(), true)
        assert(b.awardedEnemies[e])
        eq(b.awardedEnemies[enemyReserve], nil)
        eq(b.player, p)
        eq(reserve.hp, reserve.maxHP)
    end)
    test("Self-KO without a living target still faints after PP without hit RNG", function()
        local p = Pokemon("snorlax", 100)
        local reserve = Pokemon("venusaur", 100)
        local party = Party()
        assert(party:add(p))
        assert(party:add(reserve))
        local b = fresh("selfDestruct", "explosion", "blastoise", {party=party})
        b.player.atk = 1
        b.enemy.def = 1000
        local text = use(b)
        assert(text:find("there was no target", 1, true))
        eq(b.player.hp, 0)
        eq(b.enemy.hp, 0)
        eq(b.enemy.pp.explosion, 4)
        eq(b.outcome, "victory")
        rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
    end)
    test("Substitute remains a reported unsupported move without self-KO activation", function()
        local b = fresh("substitute")
        use(b)
        eq(b.player.hp, b.player.maxHP)
        eq(b.enemy.hp, b.enemy.maxHP)
        eq(#b:getMoveGaps(), 1)
        eq(b:getMoveGaps()[1].move, "substitute")
    end)
    RulesRNG.restore(saved)
    return report
end
