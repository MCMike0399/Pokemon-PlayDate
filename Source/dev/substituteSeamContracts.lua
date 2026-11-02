-- Retained owner-level seam regressions; full action coverage is in substituteContracts.
SubstituteSeamContracts = {}
local function eq(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function fresh()
    local b = Battle(Pokemon("snorlax", 100), Pokemon("snorlax", 100))
    local count = 0
    while b:phase() == "script" do
        count = count + 1
        assert(count < 100, "substitute seam setup stuck")
        b.machine:get("script"):advance()
    end
    b.say = function() end
    b.player.ability = function() return 0 end
    b.enemy.ability = function() return 0 end
    b.effects:beginRound()
    return b
end
local function unchangedRNG(before)
    local after = RulesRNG.snapshot()
    eq(after.state, before.state)
    eq(after.rolls, before.rolls)
end
function SubstituteSeamContracts.run()
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
    test("Substitute seam pays floor quarter once and rejects exact boundary without RNG", function()
        for _, maximum in ipairs({100, 101, 103}) do
            local b = fresh()
            local p = b.player
            p.maxHP = maximum
            p.hp = maximum // 4
            local before = RulesRNG.snapshot()
            local ok, why = b.conditions:createSubstitute(p)
            eq(ok, false)
            eq(why, "insufficient-substitute-hp")
            eq(p.hp, maximum // 4)
            eq(b.conditions:substituteHP(p), 0)
            p.hp = maximum // 4 + 1
            assert(b.conditions:createSubstitute(p))
            eq(p.hp, 1)
            eq(b.conditions:substituteHP(p), maximum // 4)
            eq(b.effects:damagedThisRound(p), false)
            ok, why = b.conditions:createSubstitute(p)
            eq(ok, false)
            eq(why, "existing-substitute")
            eq(p.hp, 1)
            unchangedRNG(before)
        end
        local b = fresh()
        b.player.maxHP = 1
        b.player.hp = 1
        eq(b.conditions:createSubstitute(b.player), false)
        eq(b.conditions:substituteHP(b.player), 0)
    end)
    test("Substitute seam commits cost and trap removal before narration preserving other owners", function()
        local b = fresh()
        local p = b.player
        local state = b.conditions:of(p)
        state.trap = {source=b.enemy, remaining=4}
        state.seed = b.enemy
        state.foresight = true
        p.status = "paralyze"
        p.statStages.atk = 3
        p.ability = function() return 98 end
        local hp = p.hp
        local pp = p.pp
        b.say = function()
            eq(p.hp, hp - p.maxHP // 4)
            eq(state.substituteHP, p.maxHP // 4)
            eq(state.trap, nil)
        end
        assert(b.conditions:createSubstitute(p))
        eq(state.seed, b.enemy)
        eq(state.foresight, true)
        eq(p.status, "paralyze")
        eq(p.statStages.atk, 3)
        eq(p.pp, pp)
        eq(p.substituteHP, nil)
    end)
    test("Substitute seam caps each hit without spill and keeps body damage ledgers empty", function()
        local b = fresh()
        local e = b.enemy
        e.maxHP = 100
        e.hp = 100
        assert(b.conditions:createSubstitute(e))
        local first = b.effects:hitSubstitute(b.player, e, moveData.doubleKick, 10, 1)
        eq(first.removed, 10)
        eq(first.substituteBefore, 25)
        eq(first.substituteBroken, false)
        eq(b.conditions:substituteHP(e), 15)
        local second = b.effects:hitSubstitute(b.player, e, moveData.doubleKick, 90, 2)
        eq(second.removed, 15)
        eq(second.substituteBroken, true)
        eq(b.conditions:substituteHP(e), 0)
        eq(e.hp, 75)
        eq(b.effects:damagedThisRound(e), false)
        eq(b.effects.round.attackedBy[e], nil)
        local third = b.effects:hit(b.player, e, moveData.doubleKick, 10, 3)
        eq(third.removed, 10)
        eq(e.hp, 65)
        eq(b.effects:damagedThisRound(e), true)
        eq(b.effects.round.attackedBy[e][b.player], true)
    end)
    test("Substitute receipt suppresses Sturdy Anger Point and contact ability RNG even on break", function()
        for _, ability in ipairs({5, 9, 27, 38, 56, 83}) do
            local b = fresh()
            b.enemy.ability = function() return ability end
            assert(b.conditions:createSubstitute(b.enemy))
            local hp = b.enemy.hp
            local before = RulesRNG.snapshot()
            local hit = b.effects:hitSubstitute(b.player, b.enemy, moveData.bodySlam, 1000)
            eq(hit.endured, false)
            eq(hit.contact, false)
            eq(ContactAbilities.onHit(b.effects, hit, true), false)
            assert(b.effects:resolveSubstituteHit(hit))
            assert(b.effects:afterHit(hit))
            eq(b.effects:afterHit(hit), false)
            eq(b.enemy.hp, hp)
            eq(b.enemy.statStages.atk, 0)
            eq(b.player.status, nil)
            eq(b.conditions:of(b.player).infatuation, nil)
            unchangedRNG(before)
        end
    end)
    test("Substitute drain uses capped loss ceil rounding and existing Liquid Ooze owner once", function()
        for _, ooze in ipairs({false, true}) do
            local b = fresh()
            b.enemy.ability = function() return ooze and 64 or 0 end
            assert(b.conditions:createSubstitute(b.enemy))
            b.player.hp = 100
            local before = RulesRNG.snapshot()
            local hit = b.effects:hitSubstitute(b.player, b.enemy, moveData.absorb, 3)
            assert(b.effects:resolveSubstituteHit(hit))
            eq(b.player.hp, ooze and 98 or 102)
            eq(b.effects:drainHit(hit), false)
            eq(b.effects:resolveSubstituteHit(hit), false)
            unchangedRNG(before)
        end
    end)
    test("Substitute recoil uses intercepted loss and existing Rock Head Magic Guard gates once", function()
        for _, ability in ipairs({0, 69, 98}) do
          for _, dollHP in ipairs({25, 153}) do
            local b = fresh()
            b.player.ability = function() return ability end
            b.enemy.maxHP = dollHP * 4
            b.enemy.hp = b.enemy.maxHP
            assert(b.conditions:createSubstitute(b.enemy))
            b.player.hp = 100
            local hit = b.effects:hitSubstitute(b.player, b.enemy, moveData.doubleEdge, 1000)
            assert(b.effects:resolveSubstituteHit(hit))
            eq(hit.removed, dollHP)
            local loss = dollHP == 153 and 50 or 8
            eq(b.player.hp, ability == 0 and 100 - loss or 100)
            eq(b.effects:resolveSubstituteHit(hit), false)
            eq(b.enemy.hp, dollHP * 3)
          end
        end
    end)
    test("Substitute seam rejects implicit body routing unsupported producers and malformed damage", function()
        local b = fresh()
        assert(b.conditions:createSubstitute(b.enemy))
        local hp = b.enemy.hp
        local doll = b.conditions:substituteHP(b.enemy)
        local before = RulesRNG.snapshot()
        eq(pcall(function() b.effects:hit(b.player, b.enemy, moveData.tackle, 10) end), false)
        for _, move in ipairs({moveData.substitute, moveData.trick, moveData.recycle}) do
            eq(pcall(function() b.effects:hitSubstitute(b.player, b.enemy, move, 10) end), false)
        end
        for _, amount in ipairs({-1, 1.5, "10"}) do
            eq(pcall(function() b.effects:hitSubstitute(b.player, b.enemy, moveData.tackle, amount) end), false)
        end
        eq(b.enemy.hp, hp)
        eq(b.conditions:substituteHP(b.enemy), doll)
        eq(MoveSupport.gaps.substitute, nil)
        eq(MoveSupport.handlers.substitute, "engine-dsl")
        unchangedRNG(before)
    end)
    test("Substitute lifetime follows existing member cleanup and invalidates retired receipts", function()
        local b = fresh()
        assert(b.conditions:createSubstitute(b.enemy))
        local hit = b.effects:hitSubstitute(b.player, b.enemy, moveData.tackle, 1)
        b.conditions:clear(b.enemy)
        b.effects:clear(b.enemy)
        eq(b.conditions:substituteHP(b.enemy), 0)
        eq(b.effects:resolveSubstituteHit(hit), false)
        eq(b.effects:afterHit(hit), false)
        assert(b.conditions:createSubstitute(b.enemy))
        b.conditions:clearAll()
        b.effects:close()
        eq(b.conditions:substituteHP(b.enemy), 0)
        eq(b.conditions:createSubstitute(b.enemy), false)
    end)
    RulesRNG.restore(saved)
    return report
end
