-- Compile-only preparation; Root owns real SDK execution and acceptance.
EarnedBMoveContracts = {}
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
        assert(count < 300, "earned B script stuck: " .. tostring(b.message))
        assert(not b.pendingLearning, "unexpected learning")
        lines[#lines + 1] = b.message
        if observe then
            observe(b)
        end
        b.machine:get("script"):advance()
    end
    return table.concat(lines, "|")
end
local function fresh(keys, enemyKey, player, enemy, party)
    local b = Battle(player or Pokemon("blastoise", 70), enemy or Pokemon("snorlax", 100),
        nil, party and {party=party} or nil)
    settle(b)
    own(b.player, keys)
    own(b.enemy, {enemyKey or "splash"})
    b.player.spe = 200
    b.enemy.spe = 100
    return b
end
local function use(b, slot, seed, observe)
    RulesRNG.seed(seed or 73)
    assert(b:selectMove(slot or 1))
    return settle(b, observe)
end
local function rng(seed, draws)
    local expected = RulesRNG.new(seed)
    for _, bounds in ipairs(draws) do
        expected:random(bounds[1], bounds[2])
    end
    local actual = RulesRNG.snapshot()
    local wanted = expected:snapshot()
    eq(actual.state, wanted.state)
    eq(actual.rolls, wanted.rolls)
end
local function asleep(mon, turns)
    mon.status = "sleep"
    mon.statusTurns = turns
    mon.sleepDuration = math.max(1, turns)
end
function EarnedBMoveContracts.run()
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
    test("Five earned B moves reject exhausted PP without starting a round or drawing RNG", function()
        for _, key in ipairs({"rest", "snore", "yawn", "foresight", "revenge"}) do
            local b = fresh({key})
            b.player.pp[key] = 0
            RulesRNG.seed(73)
            local ok, why = b:selectMove(1)
            eq(ok, false)
            eq(why, "no-pp")
            eq(b:phase(), "command")
            eq(b.effects.round, nil)
            eq(b.player.pp[key], 0)
            rng(73, {})
        end
    end)
    test("Rest cures status heals fully and retains unrelated condition stage and PP owners", function()
        local b = fresh({"rest"})
        b.player.hp = b.player.maxHP - 40
        b.player.status = "badPoison"
        b.player.statStages.atk = -2
        local state = b.conditions:of(b.player)
        state.toxic = 5
        state.focusEnergy = true
        state.foresight = true
        local pp = b.player.pp
        local text = use(b)
        eq(b.player.hp, b.player.maxHP)
        eq(b.player.status, "sleep")
        eq(b.player.statusTurns, 2)
        eq(b.player.sleepDuration, 2)
        eq(b.player.pp, pp)
        eq(pp.rest, 9)
        eq(state.toxic, nil)
        eq(state.focusEnergy, true)
        eq(state.foresight, true)
        eq(b.player.statStages.atk, -2)
        assert(text:find("regained health", 1, true))
        eq(#b:getMoveGaps(), 0)
        rng(73, {{1,1}, {1,3}})
    end)
    test("Rest full HP fails even with status spends PP and retains ordinary residual", function()
        local b = fresh({"rest"})
        b.player.status = "poison"
        local text = use(b)
        assert(text:find("But it failed!", 1, true))
        eq(b.player.status, "poison")
        eq(b.player.hp, b.player.maxHP - math.max(1, b.player.maxHP // 8))
        eq(b.player.pp.rest, 9)
        rng(73, {{1,1}})
    end)
    test("Rest Insomnia and Vital Spirit refuse healing and preserve prior status without sleep RNG", function()
        for _, id in ipairs({15, 72}) do
            local b = fresh({"rest"})
            b.player.ability = function()
                return id
            end
            b.player.hp = b.player.maxHP - 40
            b.player.status = "burn"
            local hp = b.player.hp
            local text = use(b)
            assert(text:find("protected by", 1, true))
            eq(b.player.status, "burn")
            eq(b.player.hp, hp - math.max(1, b.player.maxHP // 8))
            eq(b.player.pp.rest, 9)
            rng(73, {{1,1}})
        end
    end)
    test("Rest self sleep bypasses the actual user's Safeguard", function()
        local b = fresh({"safeguard", "rest"})
        b.player.hp = b.player.maxHP - 40
        use(b, 1)
        assert(b.conditions:sideTurns(b.player, "safeguard") > 0)
        use(b, 2)
        eq(b.player.status, "sleep")
        eq(b.player.hp, b.player.maxHP)
        eq(b.player.pp.rest, 9)
        rng(73, {{1,1}, {1,3}})
    end)
    test("Rest sleep flinch and zero PP gates retain real command rejection boundaries", function()
        for _, gate in ipairs({"sleep", "flinch", "pp"}) do
            local b = fresh({"rest"})
            b.player.hp = b.player.maxHP - 40
            if gate == "sleep" then
                asleep(b.player, 2)
            elseif gate == "flinch" then
                b.player.flinched = true
            else
                b.player.pp.rest = 0
            end
            RulesRNG.seed(73)
            if gate == "pp" then
                local ok, why = b:selectMove(1)
                eq(ok, false)
                eq(why, "no-pp")
                rng(73, {})
            else
                use(b)
                rng(73, {{1,1}})
            end
            eq(b.player.hp, b.player.maxHP - 40)
            eq(b.player.pp.rest, gate == "pp" and 0 or 10)
        end
    end)
    test("Rest permits two real asleep Snore actions then waking Snore fails with PP", function()
        local b = fresh({"rest", "snore"})
        b.player.hp = b.player.maxHP - 40
        use(b, 1)
        local hp = b.enemy.hp
        for remaining = 1, 0, -1 do
            local text = use(b, 2)
            assert(text:find("fast asleep", 1, true))
            eq(b.player.statusTurns, remaining)
            eq(b.player.status, "sleep")
            assert(b.enemy.hp < hp)
            hp = b.enemy.hp
        end
        local text = use(b, 2)
        assert(text:find("woke up", 1, true))
        assert(text:find("But it failed!", 1, true))
        eq(b.player.status, nil)
        eq(b.enemy.hp, hp)
        eq(b.player.pp.snore, 12)
        eq(b.player.pp.rest, 9)
        rng(73, {{1,1}})
    end)
    test("Rest sleep duration resets through actual party withdrawal", function()
        local player = Pokemon("snorlax", 70)
        local reserve = Pokemon("squirtle", 70)
        local party = Party()
        assert(party:add(player))
        assert(party:add(reserve))
        local b = fresh({"rest", "splash"}, nil, player, nil, party)
        own(reserve, {"splash"})
        player.hp = player.maxHP - 40
        use(b, 1)
        use(b, 2)
        eq(player.statusTurns, 1)
        assert(b:chooseParty(2))
        settle(b)
        eq(player.statusTurns, 2)
        eq(player.sleepDuration, 2)
        assert(b:chooseParty(1))
        settle(b)
        eq(player.statusTurns, 2)
        use(b, 2)
        eq(player.statusTurns, 1)
        eq(player.pp.rest, 9)
    end)
    test("Snore awake failure precedes Ghost immunity and does not sample hit RNG", function()
        local b = fresh({"snore"}, nil, nil, Pokemon("gastly", 100))
        local hp = b.enemy.hp
        local text = use(b)
        assert(text:find("But it failed!", 1, true))
        assert(not text:find("doesn't affect", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.snore, 14)
        rng(73, {{1,1}})
    end)
    test("Snore sleeping hit uses ordinary accuracy crit damage and flinch RNG", function()
        local b = fresh({"snore"})
        asleep(b.player, 2)
        local hp = b.enemy.hp
        use(b)
        assert(b.enemy.hp < hp)
        eq(b.player.pp.snore, 14)
        eq(b.player.statusTurns, 1)
        rng(73, {{1,1}, {1,100}, {1,16}, {85,100}, {1,100}})
    end)
    test("Snore miss spends PP and samples no damage or flinch RNG", function()
        local b = fresh({"snore"})
        asleep(b.player, 2)
        b.player.statStages.acc = -6
        b.enemy.statStages.eva = 6
        local hp = b.enemy.hp
        local text = use(b, 1, 2)
        assert(text:find("attack missed", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.snore, 14)
        rng(2, {{1,1}, {1,100}})
    end)
    test("Snore flinch blocks the real opposing queued action", function()
        local seed
        for candidate = 1, 1000 do
            local stream = RulesRNG.new(candidate)
            stream:random(1, 1)
            stream:random(1, 100)
            stream:random(1, 16)
            stream:random(85, 100)
            if stream:random(1, 100) <= 30 then
                seed = candidate
                break
            end
        end
        assert(seed)
        local b = fresh({"snore"}, "harden")
        asleep(b.player, 2)
        local text = use(b, 1, seed)
        assert(text:find("flinched", 1, true))
        eq(b.enemy.pp.harden, 30)
        eq(b.enemy.statStages.def, 0)
        eq(b.enemy.flinched, false)
        rng(seed, {{1,1}, {1,100}, {1,16}, {85,100}, {1,100}})
    end)
    test("Snore Ghost Soundproof Protect and Inner Focus retain existing hit gates", function()
        for _, gate in ipairs({"ghost", "soundproof", "protect", "innerFocus"}) do
            local enemy = Pokemon(gate == "ghost" and "gastly" or "snorlax", 100)
            local b = fresh({"snore"}, gate == "protect" and "protect" or "harden", nil, enemy)
            if gate == "soundproof" then
                enemy.ability = function()
                    return 43
                end
            end
            if gate == "innerFocus" then
                enemy.ability = function()
                    return 39
                end
            end
            asleep(b.player, 2)
            local hp = enemy.hp
            use(b)
            eq(b.player.pp.snore, 14)
            if gate == "innerFocus" then
                assert(enemy.hp < hp)
                eq(enemy.pp.harden, 29)
                rng(73, {{1,1}, {1,100}, {1,16}, {85,100}, {1,100}})
            else
                eq(enemy.hp, hp)
                rng(73, {{1,1}})
            end
        end
    end)
    test("Snore asleep still obeys flinch and Disable action gates", function()
        for _, gate in ipairs({"flinch", "disable"}) do
            local b = fresh({"snore"})
            asleep(b.player, 2)
            if gate == "flinch" then
                b.player.flinched = true
            else
                -- Real earlier use supplies Disable's actual last-move producer.
                use(b)
                own(b.enemy, {"disable"})
                b.enemy.spe = 300
            end
            local pp = b.player.pp.snore
            local hp = b.enemy.hp
            local text = use(b)
            eq(b.player.pp.snore, pp)
            eq(b.enemy.hp, hp)
            assert(text:find(gate == "flinch" and "flinched" or "disabled", 1, true))
        end
    end)
    test("Yawn sleeps only at the following round residual with one duration draw", function()
        local b = fresh({"yawn", "splash"})
        use(b, 1)
        eq(b.enemy.status, nil)
        eq(b.conditions:of(b.enemy).yawn.turns, 1)
        eq(b.player.pp.yawn, 9)
        rng(73, {{1,1}})
        use(b, 2)
        eq(b.enemy.status, "sleep")
        eq(b.conditions:of(b.enemy).yawn, nil)
        assert(b.enemy.statusTurns >= 1 and b.enemy.statusTurns <= 3)
        eq(b.enemy.statusTurns, b.enemy.sleepDuration)
        rng(73, {{1,1}, {1,3}})
        eq(#b:getMoveGaps(), 0)
    end)
    test("Yawn repeated placement fails without refreshing the original deadline", function()
        local b = fresh({"yawn"})
        use(b)
        local record = b.conditions:of(b.enemy).yawn
        local text = use(b)
        assert(text:find("But it failed!", 1, true))
        eq(record.turns, 0)
        eq(b.enemy.status, "sleep")
        eq(b.player.pp.yawn, 8)
        rng(73, {{1,1}, {1,3}})
    end)
    test("Yawn rejects current status sleep immunity Safeguard and Protect without duration RNG", function()
        for _, gate in ipairs({"status", "insomnia", "vitalSpirit", "safeguard", "protect"}) do
            local b = fresh({"yawn"}, gate == "protect" and "protect" or "splash")
            if gate == "status" then
                b.enemy.status = "paralyze"
            end
            if gate == "insomnia" then
                b.enemy.ability = function()
                    return 15
                end
            end
            if gate == "vitalSpirit" then
                b.enemy.ability = function()
                    return 72
                end
            end
            if gate == "safeguard" then
                own(b.enemy, {"safeguard"})
                b.enemy.spe = 300
            end
            use(b)
            eq(b.conditions:of(b.enemy).yawn, nil)
            eq(b.enemy.status, gate == "status" and "paralyze" or nil)
            eq(b.player.pp.yawn, 9)
            -- Existing paralysis gate legitimately adds its own trial.
            rng(73, gate == "status" and {{1,1}, {1,4}} or {{1,1}})
        end
    end)
    test("Yawn already placed ignores later Safeguard but rechecks actual status and ability", function()
        for _, gate in ipairs({"safeguard", "status", "ability"}) do
            local b = fresh({"yawn", "toxic", "worrySeed"}, nil, nil, Pokemon("chansey", 100))
            use(b, 1)
            if gate == "safeguard" then
                own(b.enemy, {"safeguard"})
                use(b, 1)
                eq(b.enemy.status, "sleep")
                rng(73, {{1,1}, {1,3}})
            elseif gate == "status" then
                use(b, 2)
                eq(b.enemy.status, "badPoison")
                eq(RulesRNG.snapshot().rolls, 2)
            else
                use(b, 3)
                eq(b.enemy.status, nil)
                eq(b.effects:effectiveAbility(b.enemy), 15)
                eq(RulesRNG.snapshot().rolls, 2)
            end
            eq(b.conditions:of(b.enemy).yawn, nil)
        end
    end)
    test("Enemy Yawn is cleared by real target withdrawal and cannot affect replacement", function()
        local player = Pokemon("snorlax", 70)
        local reserve = Pokemon("squirtle", 70)
        local party = Party()
        assert(party:add(player))
        assert(party:add(reserve))
        local b = fresh({"splash"}, "yawn", player, nil, party)
        own(reserve, {"splash"})
        use(b)
        assert(b.conditions:of(player).yawn)
        own(b.enemy, {"splash"})
        assert(b:chooseParty(2))
        settle(b)
        eq(b.conditions.members[player], nil)
        eq(reserve.status, nil)
        eq(player.status, nil)
        use(b)
        eq(reserve.status, nil)
        eq(player.status, nil)
    end)
    test("Yawn retains its source when that source actually withdraws", function()
        local player = Pokemon("snorlax", 70)
        local reserve = Pokemon("squirtle", 70)
        local party = Party()
        assert(party:add(player))
        assert(party:add(reserve))
        local b = fresh({"yawn"}, nil, player, nil, party)
        use(b)
        RulesRNG.seed(73)
        assert(b:chooseParty(2))
        settle(b)
        eq(b.enemy.status, "sleep")
        rng(73, {{1,1}, {1,3}})
    end)
    test("Yawn does not sleep a target fainted by the earlier Curse residual cohort", function()
        local b = fresh({"yawn", "curse"}, nil, Pokemon("gastly", 100))
        b.enemy.hp = math.max(1, b.enemy.maxHP // 4)
        use(b, 1)
        eq(b.enemy.status, nil)
        local text = use(b, 2)
        assert(text:find("fainted", 1, true))
        eq(b.enemy.hp, 0)
        eq(b.enemy.status, nil)
        eq(b.conditions.members[b.enemy], nil)
        rng(73, {{1,1}})
    end)
    test("Foresight target withdrawal removes identification and restores Ghost immunity", function()
        local player = Pokemon("gastly", 70)
        local reserve = Pokemon("squirtle", 70)
        local party = Party()
        assert(party:add(player))
        assert(party:add(reserve))
        local b = fresh({"splash"}, "foresight", player, nil, party)
        use(b)
        eq(b.conditions:identified(player), true)
        eq(b:typeMatchup("normal", player), 1)
        own(b.enemy, {"splash"})
        assert(b:chooseParty(2))
        settle(b)
        eq(b.conditions:identified(player), false)
        assert(b:chooseParty(1))
        settle(b)
        eq(b:typeMatchup("normal", player), 0)
    end)
    test("Foresight shares Odor Sleuth once-only target identity and ignores positive evasion", function()
        local b = fresh({"foresight", "odorSleuth", "tackle"}, nil, nil, Pokemon("gastly", 100))
        b.enemy.statStages.eva = 6
        use(b, 1)
        eq(b.conditions:identified(b.enemy), true)
        eq(b.enemy.statStages.eva, 6)
        eq(b.conditions:evasionStage(b.enemy), 0)
        eq(b:typeMatchup("normal", b.enemy), 1)
        eq(b:typeMatchup("fighting", b.enemy), 0.5)
        rng(73, {{1,1}})
        local text = use(b, 2)
        assert(text:find("But it failed!", 1, true))
        local hp = b.enemy.hp
        use(b, 3)
        assert(b.enemy.hp < hp)
        eq(b.player.pp.foresight, 39)
        eq(b.player.pp.odorSleuth, 39)
        rng(73, {{1,1}, {1,100}, {1,16}, {85,100}})
    end)
    test("Foresight also fails after Odor Sleuth and preserves negative evasion", function()
        local b = fresh({"odorSleuth", "foresight"})
        use(b, 1)
        b.enemy.statStages.eva = -2
        local text = use(b, 2)
        assert(text:find("But it failed!", 1, true))
        eq(b.conditions:evasionStage(b.enemy), -2)
        eq(b.player.pp.foresight, 39)
        rng(73, {{1,1}})
    end)
    test("Foresight Protect failure preserves Ghost immunity and spends PP without accuracy", function()
        local b = fresh({"foresight"}, "protect", nil, Pokemon("gastly", 100))
        use(b)
        eq(b.conditions:identified(b.enemy), false)
        eq(b:typeMatchup("normal", b.enemy), 0)
        eq(b.player.pp.foresight, 39)
        rng(73, {{1,1}})
    end)
    test("Revenge priority doubles only after actual opposing move damage in its logical round", function()
        local results = {}
        for _, enemyKey in ipairs({"tackle", "splash"}) do
            local b = fresh({"revenge"}, enemyKey)
            local hp = b.enemy.hp
            local observed = false
            local text = use(b, 1, 73, function(live)
                if live.currentMoveKey == "revenge" then
                    observed = true
                    eq(live:effectiveMovePower(moveData.revenge, live.player, live.enemy),
                        enemyKey == "tackle" and 120 or 60)
                end
            end)
            eq(observed, true)
            results[enemyKey] = hp - b.enemy.hp
            local first = assert(text:find(b.enemy.name .. " used", 1, true))
            local second = assert(text:find(b.player.name .. " used REVENGE", 1, true))
            assert(first < second)
            eq(b.player.pp.revenge, 9)
            eq(b.effects.round, nil)
            eq(#b:getMoveGaps(), 0)
        end
        assert(results.tackle > results.splash)
        eq(moveData.revenge.priority, -4)
    end)
    test("Revenge uses actual damage power and exact ordinary damage RNG", function()
        local b = fresh({"revenge"}, "sonicBoom")
        local hp = b.enemy.hp
        use(b)
        local damage = hp - b.enemy.hp
        rng(73, {{1,1}, {1,100}, {1,100}, {1,16}, {85,100}})
        -- A normal Fighting move with the same raw120 power is a separate
        -- production damage control, including its ordinary self stat drops.
        local control = fresh({"closeCombat"})
        local hp2 = control.enemy.hp
        -- Reproduce Revenge's stream position after AI plus Sonic Boom accuracy.
        RulesRNG.seed(73)
        RulesRNG.random(1, 1)
        RulesRNG.random(1, 100)
        control:runScript(function()
            return control:resolveTurn({side="player", actor=control.player,
                key="closeCombat", move=moveData.closeCombat})
        end)
        settle(control)
        eq(hp2 - control.enemy.hp, damage)
    end)
    test("Revenge preceding miss and residual HP loss do not boost next-round damage", function()
        local values = {}
        for _, mode in ipairs({"miss", "poison", "none"}) do
            local b = fresh({"revenge"}, mode == "miss" and "tackle" or "splash")
            if mode == "miss" then
                b.enemy.statStages.acc = -6
                b.player.statStages.eva = 6
            elseif mode == "poison" then
                b.player.status = "poison"
                use(b)
                eq(b.player.status, "poison")
                b.player.status = nil
                b.player.statusTurns = 0
                b.player.sleepDuration = 0
            end
            local hp = b.enemy.hp
            local observed = false
            local text = use(b, 1, 2, function(live)
                if live.currentMoveKey == "revenge" then
                    observed = true
                    eq(live:effectiveMovePower(moveData.revenge, live.player, live.enemy), 60)
                end
            end)
            eq(observed, true)
            if mode == "miss" then
                assert(text:find("attack missed", 1, true))
            end
            values[mode] = hp - b.enemy.hp
        end
        -- Miss consumes one accuracy trial, so compare damage with that exact
        -- stream alignment separately; poison and none have identical trials.
        eq(values.poison, values.none)
        assert(values.miss > 0)
    end)
    test("Enemy Revenge doubles from the actual player hit with symmetric PP and RNG", function()
        local b = fresh({"tackle"}, "revenge", Pokemon("snorlax", 100), Pokemon("snorlax", 70))
        local hp = b.player.hp
        local observed = false
        use(b, 1, 73, function(live)
            if live.currentMoveKey == "revenge" then
                eq(live.attackerSide, "enemy")
                eq(live:effectiveMovePower(moveData.revenge, live.enemy, live.player), 120)
                observed = true
            end
        end)
        eq(observed, true)
        assert(b.player.hp < hp)
        eq(b.enemy.pp.revenge, 9)
        rng(73, {{1,1}, {1,100}, {1,16}, {85,100}, {1,100}, {1,16}, {85,100}})
    end)
    test("Revenge can miss after taking damage without damage RNG or a PP refund", function()
        local b = fresh({"revenge"}, "sonicBoom")
        b.player.statStages.acc = -6
        b.enemy.statStages.eva = 6
        local hp = b.enemy.hp
        local observed = false
        local text = use(b, 1, 73, function(live)
            if live.currentMoveKey == "revenge" then
                eq(live:effectiveMovePower(moveData.revenge, live.player, live.enemy), 120)
                observed = true
            end
        end)
        eq(observed, true)
        assert(text:find("attack missed", 1, true))
        eq(b.enemy.hp, hp)
        eq(b.player.pp.revenge, 9)
        rng(73, {{1,1}, {1,100}, {1,100}})
    end)
    test("Revenge damage receipt expires before the next actual command round", function()
        local b = fresh({"revenge"}, "sonicBoom")
        local observed = false
        use(b, 1, 73, function(live)
            if live.currentMoveKey == "revenge" then
                eq(live:effectiveMovePower(moveData.revenge, live.player, live.enemy), 120)
                observed = true
            end
        end)
        eq(observed, true)
        eq(b.effects.round, nil)
        own(b.enemy, {"splash"})
        observed = false
        use(b, 1, 73, function(live)
            if live.currentMoveKey == "revenge" then
                eq(live:effectiveMovePower(moveData.revenge, live.player, live.enemy), 60)
                observed = true
            end
        end)
        eq(observed, true)
        eq(b.player.pp.revenge, 8)
    end)
    test("Revenge confusion self damage never creates an opposing attack receipt", function()
        local seed
        for candidate = 1, 1000 do
            local stream = RulesRNG.new(candidate)
            stream:random(1, 1)
            stream:random(1, 100)
            stream:random(1, 4)
            if stream:random(1, 2) == 1 then
                seed = candidate
                break
            end
        end
        assert(seed)
        local b = fresh({"revenge"}, "confuseRay")
        local observed = false
        local text = use(b, 1, seed, function(live)
            if live.message:find("hurt itself", 1, true) then
                observed = true
                eq(live.effects.round.attackedBy[live.player], nil)
                eq(live.effects:damagedThisRound(live.player), true)
            end
        end)
        eq(observed, true)
        assert(text:find("hurt itself", 1, true))
        eq(b.player.pp.revenge, 10)
        rng(seed, {{1,1}, {1,100}, {1,4}, {1,2}, {85,100}})
    end)
    test("Revenge Protect and Ghost immunity block damage with PP and no damage RNG", function()
        for _, gate in ipairs({"protect", "ghost"}) do
            local b = fresh({"revenge"}, gate == "protect" and "protect" or "splash",
                nil, Pokemon(gate == "ghost" and "gastly" or "snorlax", 100))
            local hp = b.enemy.hp
            use(b)
            eq(b.enemy.hp, hp)
            eq(b.player.pp.revenge, 9)
            rng(73, {{1,1}})
        end
    end)
    RulesRNG.restore(saved)
    return report
end
