-- Prepared real-SDK witnesses. Root must import/register and execute this suite.
-- Fixtures select existing production moves/traits; they never claim acquisition.
VermilionAbilityContracts = {}

local floor <const> = math.floor
local max <const> = math.max

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function mon(species, level, slot)
    return Pokemon(species, level or 25, {
        natureId = 0,
        abilitySlot = slot or "first",
        heldItem = "none",
    })
end

local function own(pokemon, keys)
    pokemon.moves, pokemon.pp = {}, {}
    for _, key in ipairs(keys) do
        pokemon.moves[#pokemon.moves + 1] = key
        pokemon.pp[key] = moveData[key].maxPP
    end
end

local function settle(battle)
    local lines = {}
    for _ = 1, 200 do
        if battle:phase() ~= "script" then
            return table.concat(lines, "|")
        end
        assert(not battle.pendingLearning, "unexpected learning interruption")
        lines[#lines + 1] = battle.message
        battle.machine:get("script"):advance()
    end
    error("Vermilion ability script did not settle")
end

local function fresh(player, enemy, dependencies, trainer)
    local battle = Battle(player, enemy, trainer, dependencies)
    settle(battle)
    return battle
end

local function attempt(battle, side, key, seed)
    local actor = battle[side]
    own(actor, { key })
    RulesRNG.seed(seed or 2)
    battle:runScript(function()
        return battle:resolveTurn({ side=side, actor=actor, key=key, move=moveData[key] })
    end)
    return settle(battle)
end

local function residual(battle)
    battle:runScript(function()
        return battle:endOfRoundStatus()
    end)
    return settle(battle)
end

local function override(battle, side)
    return attempt(battle, side == "player" and "enemy" or "player", "worrySeed")
end

local function unchanged(before)
    local after = RulesRNG.snapshot()
    eq(after.state, before.state, "RNG state")
    eq(after.rolls, before.rolls, "RNG trials")
end

local function fireBattle(dependencies, trainer)
    return fresh(mon("charmander"), mon("growlithe", 25, "second"), dependencies, trainer)
end

local function activateFire(battle)
    attempt(battle, "player", "ember")
    eq(battle.effects.ordinaryAbilities.flashFire[battle.enemy], true)
end

local function seedBattle(receiver, dependencies)
    local battle = fresh(receiver or mon("bulbasaur"), mon("tentacool", 25, "second"), dependencies)
    attempt(battle, "player", "leechSeed")
    eq(battle.conditions.members[battle.enemy].seed, "player")
    return battle
end

function VermilionAbilityContracts.run()
    local report = { ok=true, passed=0, failed=0, tests={} }
    local saved = RulesRNG.snapshot()
    local function test(name, body)
        local before = RulesRNG.snapshot()
        local ok, why = pcall(body)
        RulesRNG.restore(before)
        report.tests[#report.tests + 1] = { name=name, ok=ok, error=not ok and tostring(why) or nil }
        if ok then
            report.passed = report.passed + 1
        else
            report.ok = false
            report.failed = report.failed + 1
        end
    end

    test("Technician actual Scratch boosts damage without changing PP or RNG trials", function()
        local boosted = fresh(mon("meowth", 10, "second"), mon("nidorina"))
        local plain = fresh(mon("meowth", 10, "second"), mon("nidorina"))
        override(plain, "player")
        local before = boosted.enemy.hp
        attempt(boosted, "player", "scratch", 2)
        local draws = RulesRNG.snapshot().rolls
        local damage = before - boosted.enemy.hp
        before = plain.enemy.hp
        attempt(plain, "player", "scratch", 2)
        assert(damage > before - plain.enemy.hp)
        eq(RulesRNG.snapshot().rolls, draws)
        eq(boosted.player.pp.scratch, moveData.scratch.maxPP - 1)
        eq(boosted.effects:basePower(moveData.scratch, 40), 60)
        eq(plain.effects:basePower(moveData.scratch, 40, plain.player, plain.enemy), 40)
        eq(plain.player:ability(), 101, "specimen unchanged")
    end)

    test("Technician 60 boundary, greater power and actual fixed damage", function()
        local b = fresh(mon("meowth", 25, "second"), mon("nidorina", 35))
        eq(b:effectiveMovePower(moveData.bite, b.player, b.enemy), 90)
        eq(b:effectiveMovePower(moveData.slash, b.player, b.enemy), 70)
        local hp = b.enemy.hp
        attempt(b, "player", "seismicToss")
        eq(hp - b.enemy.hp, 25)
        eq(b.player.pp.seismicToss, moveData.seismicToss.maxPP - 1)
    end)

    test("Technician actual Fury Swipes preserves hit-count trials and boosts each hit", function()
        local boosted = fresh(mon("meowth", 14, "second"), mon("nidorina", 40))
        local plain = fresh(mon("meowth", 14, "second"), mon("nidorina", 40))
        override(plain, "player")
        local hp = boosted.enemy.hp
        local boostedText = attempt(boosted, "player", "furySwipes", 2)
        local damage = hp - boosted.enemy.hp
        local draws = RulesRNG.snapshot().rolls
        hp = plain.enemy.hp
        local plainText = attempt(plain, "player", "furySwipes", 2)
        assert(damage > hp - plain.enemy.hp)
        eq(boostedText:match("Hit (%d) times"), plainText:match("Hit (%d) times"))
        eq(RulesRNG.snapshot().rolls, draws)
    end)

    test("Technician Protect stops the hit before new damage or receipts", function()
        local b = fresh(mon("meowth", 14, "second"), mon("shellder"))
        attempt(b, "enemy", "protect")
        local hp = b.enemy.hp
        attempt(b, "player", "furySwipes")
        eq(b.enemy.hp, hp)
        eq(next(b.effects.receipts), nil)
        eq(RulesRNG.snapshot().rolls, 0)
    end)

    test("Flash Fire actual Ember absorbs repeatedly with PP only, no RNG or receipt", function()
        local b = fireBattle()
        local hp = b.enemy.hp
        for _ = 1, 2 do
            activateFire(b)
            eq(b.enemy.hp, hp)
            eq(b.player.pp.ember, moveData.ember.maxPP - 1)
            eq(RulesRNG.snapshot().rolls, 0)
            eq(next(b.effects.receipts), nil)
            eq(b.effects:attackStat(b.enemy, moveData.ember, 101), 151)
        end
    end)

    test("Flash Fire boosts actual physical and special Fire damage, not another type", function()
        for _, key in ipairs({ "flameWheel", "ember" }) do
            local boosted = fireBattle()
            local plain = fireBattle()
            activateFire(boosted)
            local hp = boosted.player.hp
            attempt(boosted, "enemy", key, 2)
            local damage = hp - boosted.player.hp
            local draws = RulesRNG.snapshot().rolls
            hp = plain.player.hp
            attempt(plain, "enemy", key, 2)
            assert(damage > hp - plain.player.hp)
            eq(RulesRNG.snapshot().rolls, draws)
            eq(boosted.effects:attackStat(boosted.enemy, moveData.bite, 100), 100)
        end
    end)

    test("Flash Fire Protect precedes activation; absent ability takes actual damage", function()
        local b = fireBattle()
        attempt(b, "enemy", "protect")
        attempt(b, "player", "ember")
        eq(b.effects.ordinaryAbilities.flashFire[b.enemy], nil)
        eq(RulesRNG.snapshot().rolls, 0)
        local plain = fresh(mon("charmander"), mon("ponyta", 25, "first"))
        local hp = plain.enemy.hp
        attempt(plain, "player", "ember")
        assert(plain.enemy.hp < hp)
        eq(plain.effects.ordinaryAbilities.flashFire[plain.enemy], nil)
    end)

    test("Worry Seed ends Flash Fire before its narration and disables reactivation", function()
        local b = fireBattle()
        activateFire(b)
        override(b, "enemy")
        eq(b.effects.ordinaryAbilities.flashFire[b.enemy], nil)
        eq(b.effects:effectiveAbility(b.enemy), 15)
        eq(b.enemy:ability(), 18)
        eq(b.effects:attackStat(b.enemy, moveData.ember, 100), 100)
        local hp = b.enemy.hp
        attempt(b, "player", "ember")
        assert(b.enemy.hp < hp)
    end)

    test("Actual forced withdrawal clears Flash Fire and its returning identity starts clean", function()
        local holder = mon("growlithe", 25, "second")
        local enemies = Party()
        assert(enemies:add(holder))
        assert(enemies:add(mon("rattata")))
        local b = fresh(mon("pidgey"), holder, { enemyParty=enemies }, "TRAINER")
        activateFire(b)
        attempt(b, "player", "whirlwind")
        eq(b.effects.ordinaryAbilities.flashFire[holder], nil)
        attempt(b, "player", "whirlwind")
        eq(b.enemy, holder)
        eq(b.effects:attackStat(holder, moveData.ember, 100), 100)
    end)

    test("Flash Fire cancellation discards the volatile and cannot resume the suspended hit", function()
        local b = fireBattle()
        own(b.player, { "ember" })
        b:runScript(function()
            return b:resolveTurn({ side="player", actor=b.player, key="ember", move=moveData.ember })
        end)
        local script = b.machine:get("script")
        script:advance()
        eq(b.effects.ordinaryAbilities.flashFire[b.enemy], true)
        local hp = b.enemy.hp
        b:clearVolatiles()
        local before = RulesRNG.snapshot()
        eq(script:advance(), false)
        eq(b.effects.ordinaryAbilities.flashFire[b.enemy], nil)
        eq(b.enemy.hp, hp)
        unchanged(before)
    end)

    test("Clear Body actual direct stat moves share the DSL guard", function()
        local b = fresh(mon("squirtle"), mon("tentacool", 17, "first"))
        for _, key in ipairs({ "growl", "tailWhip", "sandAttack", "screech" }) do
            local text = attempt(b, "player", key)
            assert(text:find("Clear Body", 1, true))
            eq(b.enemy.statStages.atk, 0)
            eq(b.enemy.statStages.def, 0)
            eq(b.enemy.statStages.acc, 0)
            eq(b.player.pp[key], moveData[key].maxPP - 1)
        end
    end)

    test("Clear Body blocks initial and actual replacement Intimidate", function()
        local b = fresh(mon("tentacool", 25, "first"), mon("growlithe", 18, "first"))
        eq(b.player.statStages.atk, 0)
        local starter = mon("rattata")
        local enemies = Party()
        assert(enemies:add(starter))
        assert(enemies:add(mon("growlithe", 18, "first")))
        b = fresh(mon("tentacool", 25, "first"), starter, { enemyParty=enemies }, "TRAINER")
        local text = attempt(b, "player", "whirlwind")
        eq(b.player.statStages.atk, 0)
        assert(text:find("Clear Body", 1, true))
    end)

    test("Clear Body allows self drops and Worry Seed restores opponent stat drops", function()
        local b = fresh(mon("tentacool", 25, "first"), mon("squirtle"))
        b:setDirection("player")
        b:runScript(function()
            ModifyStat(ATTACKER, "def", -1):apply(b)
        end)
        settle(b)
        eq(b.player.statStages.def, -1)
        override(b, "player")
        attempt(b, "enemy", "growl")
        eq(b.player.statStages.atk, -1)
    end)

    test("Clear Body secondary trial is preserved when the actual Acid payload is blocked", function()
        local witnessed = false
        for seed = 1, 60 do
            local guarded = fresh(mon("tentacool", 25, "first"), mon("tentacool"))
            local plain = fresh(mon("tentacool", 25, "first"), mon("tentacool"))
            override(plain, "player")
            attempt(plain, "enemy", "acid", seed)
            local draws = RulesRNG.snapshot().rolls
            local text = attempt(guarded, "enemy", "acid", seed)
            assert(not text:find("Clear Body", 1, true), "secondary prevention stays silent")
            eq(RulesRNG.snapshot().rolls, draws)
            eq(guarded.player.statStages.spd, 0)
            if plain.player.statStages.spd == -1 then
                witnessed = true
                break
            end
        end
        assert(witnessed, "no real Acid secondary trial witnessed")
    end)

    test("Liquid Ooze actual Absorb reverses drain even at full recipient HP", function()
        for _, missing in ipairs({ 0, 10 }) do
            local b = fresh(mon("oddish"), mon("tentacool", 17, "second"))
            b.player.hp = b.player.maxHP - missing
            local hp = b.player.hp
            attempt(b, "player", "absorb")
            eq(b.player.hp, hp - max(1, floor(b.lastDamage / 2 + 0.5)))
            eq(b.player.pp.absorb, moveData.absorb.maxPP - 1)
            eq(next(b.effects.receipts), nil)
        end
    end)

    test("Liquid Ooze actual lethal donor hit still hurts and rewards exactly once", function()
        local b = fresh(mon("oddish"), mon("tentacool", 5, "second"))
        b.enemy.hp = 1
        local hp = b.player.hp
        attempt(b, "player", "absorb")
        eq(b.lastDamage, 1)
        eq(b.player.hp, hp - 1)
        eq(b.outcome, "victory")
        eq(b.awardedEnemies[b.enemy], true)
        eq(b:getRewardSnapshot().awards, 1)
    end)

    test("Direct drain without Liquid Ooze and after Worry Seed heals normally", function()
        for _, slot in ipairs({ "first", "second" }) do
            local b = fresh(mon("oddish"), mon("tentacool", 17, slot))
            if slot == "second" then
                override(b, "enemy")
            end
            b.player.hp = b.player.maxHP - 10
            local hp = b.player.hp
            attempt(b, "player", "absorb")
            eq(b.player.hp, hp + max(1, floor(b.lastDamage / 2 + 0.5)))
        end
    end)

    test("Liquid Ooze actual Leech Seed uses captured side, not current attacker orientation", function()
        local b = seedBattle()
        local playerHP, enemyHP = b.player.hp, b.enemy.hp
        b:setDirection("enemy")
        residual(b)
        local lost = enemyHP - b.enemy.hp
        assert(lost > 0)
        eq(b.player.hp, playerHP - lost)
    end)

    test("Leech Seed reflects onto the real switched recipient and Magic Guard prevents that loss", function()
        local original = mon("bulbasaur")
        local recipient = mon("clefairy", 25, "second")
        local party = Party()
        assert(party:add(original))
        assert(party:add(recipient))
        local b = seedBattle(original, { party=party })
        own(b.enemy, { "harden" })
        local hp = recipient.hp
        local originalHP = original.hp
        assert(b:chooseParty(2))
        settle(b)
        eq(b.player, recipient)
        eq(recipient.hp, hp)
        eq(original.hp, originalHP)
        assert(b.enemy.hp < b.enemy.maxHP)
    end)

    test("Leech Seed recipient KO enters the existing faint checkpoint", function()
        local b = seedBattle()
        b.player.hp = 1
        residual(b)
        eq(b.player.hp, 0)
        eq(b.outcome, "defeat")
        eq(b.faintAnnounced.player, true)
        eq(b.awardedEnemies[b.enemy], nil)
    end)

    test("Leech Seed double KO retains the existing last-fainted-side verdict and reward owner", function()
        local b = seedBattle()
        b.player.hp, b.enemy.hp = 1, 1
        residual(b)
        eq(b.player.hp, 0)
        eq(b.enemy.hp, 0)
        eq(b.outcome, "victory")
        eq(b:getRewardSnapshot().awards, 1)
    end)

    test("Direct drain receipt is single use before contact and cannot replay after consumption", function()
        local b = fresh(mon("oddish"), mon("tentacool", 17, "second"))
        own(b.player, { "absorb" })
        b:runScript(function()
            return b:resolveTurn({ side="player", actor=b.player, key="absorb", move=moveData.absorb })
        end)
        local script = b.machine:get("script")
        script:advance() -- actual donor HP commit and damage narration
        local receipt = next(b.effects.receipts)
        assert(receipt)
        script:advance() -- Liquid Ooze commits and yields narration
        eq(receipt.drainResolved, true)
        local hp = b.player.hp
        eq(b.effects:drainHit(receipt), false)
        eq(b.player.hp, hp)
        settle(b)
        eq(b.effects:drainHit(receipt), false)
    end)

    test("Cancellation after the hit commit prevents its pending drain", function()
        local b = fresh(mon("oddish"), mon("tentacool", 17, "second"))
        own(b.player, { "absorb" })
        b:runScript(function()
            return b:resolveTurn({ side="player", actor=b.player, key="absorb", move=moveData.absorb })
        end)
        local script = b.machine:get("script")
        script:advance()
        local receipt = next(b.effects.receipts)
        assert(receipt)
        local hp = b.player.hp
        b:clearVolatiles()
        local before = RulesRNG.snapshot()
        eq(b.effects:drainHit(receipt), false)
        eq(script:advance(), false)
        eq(b.player.hp, hp)
        unchanged(before)
    end)

    test("Water Absorb actual Water Gun heals a quarter, caps and remains immune at full HP", function()
        local b = fresh(mon("squirtle"), mon("poliwag", 18, "first"))
        for _, hp in ipairs({ 1, b.enemy.maxHP - 1, b.enemy.maxHP }) do
            b.enemy.hp = hp
            attempt(b, "player", "waterGun")
            eq(b.enemy.hp, math.min(b.enemy.maxHP, hp + max(1, b.enemy.maxHP // 4)))
            eq(b.player.pp.waterGun, moveData.waterGun.maxPP - 1)
            eq(RulesRNG.snapshot().rolls, 0)
            eq(next(b.effects.receipts), nil)
        end
    end)

    test("Water Absorb respects Protect, absence and actual Worry Seed override", function()
        local b = fresh(mon("squirtle"), mon("poliwag", 18, "first"))
        b.enemy.hp = 10
        attempt(b, "enemy", "protect")
        attempt(b, "player", "waterGun")
        eq(b.enemy.hp, 10)
        local absent = fresh(mon("squirtle", 10), mon("poliwag", 25, "second"))
        local hp = absent.enemy.hp
        attempt(absent, "player", "waterGun")
        assert(absent.enemy.hp < hp)
        local changed = fresh(mon("squirtle", 10), mon("poliwag", 25, "first"))
        override(changed, "enemy")
        hp = changed.enemy.hp
        attempt(changed, "player", "waterGun")
        assert(changed.enemy.hp < hp)
    end)

    test("Swift Swim actual Rain Dance changes real round order without a speed-tie trial", function()
        local b = fresh(mon("magikarp", 18), mon("poliwag", 18, "second"))
        assert(b:effectiveSpeed(b.player) < b:effectiveSpeed(b.enemy))
        attempt(b, "enemy", "rainDance")
        assert(b:effectiveSpeed(b.player) > b:effectiveSpeed(b.enemy))
        own(b.player, { "tackle" })
        own(b.enemy, { "growl" })
        RulesRNG.seed(14)
        assert(b:selectMove(1))
        local text = settle(b)
        local first = assert(text:find(b.player.name .. " used", 1, true))
        local second = assert(text:find(b.enemy.name .. " used", 1, true))
        assert(first < second)
        eq(b.player.pp.tackle, moveData.tackle.maxPP - 1)
        eq(b.enemy.pp.growl, moveData.growl.maxPP - 1)
        eq(RulesRNG.snapshot().rolls, 5, "AI, two accuracies, critical and damage variance; no tie")
    end)

    test("Swift Swim speed query composes stages Tailwind and paralysis, and Worry Seed removes it", function()
        local b = fresh(mon("magikarp"), mon("poliwag", 18, "second"))
        local speed = b:effectiveSpeed(b.player)
        attempt(b, "enemy", "rainDance")
        eq(b:effectiveSpeed(b.player), speed * 2)
        attempt(b, "player", "tailwind")
        eq(b:effectiveSpeed(b.player), speed * 4)
        b.player.status = "paralyze"
        eq(b:effectiveSpeed(b.player), speed)
        b.player.status = nil
        b.player.statStages.spe = 1
        eq(b:effectiveSpeed(b.player), applyStageMod(b.player.spe, 1) * 4)
        override(b, "player")
        eq(b:effectiveSpeed(b.player), applyStageMod(b.player.spe, 1) * 2)
    end)

    test("Swift Swim expires with actual rain and feeds Electro Ball's real power consumer", function()
        local b = fresh(mon("magikarp"), mon("voltorb"))
        local ordinary = b.effects:movePower(moveData.electroBall, moveData.electroBall.power, b.enemy, b.player)
        attempt(b, "player", "rainDance")
        local rain = b.effects:movePower(moveData.electroBall, moveData.electroBall.power, b.enemy, b.player)
        assert(rain < ordinary)
        for _ = 1, 5 do
            residual(b)
        end
        eq(b.effects:weatherId(), "none")
        eq(b:effectiveSpeed(b.player), b.player.spe)
    end)

    test("Swift Swim participates in actual residual status ordering", function()
        local b = fresh(mon("magikarp", 18), mon("poliwag", 18, "second"))
        attempt(b, "enemy", "rainDance")
        b.player.status, b.enemy.status = "poison", "poison"
        local text = residual(b)
        assert(assert(text:find(b.player.name .. " is hurt", 1, true)) < assert(text:find(b.enemy.name .. " is hurt", 1, true)))
    end)

    test("Levitate actual Mud-Slap and Bulldoze stop before accuracy secondary and hit receipts", function()
        local b = fresh(mon("diglett", 18), mon("koffing", 12))
        for _, key in ipairs({ "mudSlap", "bulldoze" }) do
            local hp = b.enemy.hp
            attempt(b, "player", key)
            eq(b.enemy.hp, hp)
            eq(b.enemy.statStages.acc, 0)
            eq(b.enemy.statStages.spe, 0)
            eq(b.player.pp[key], moveData[key].maxPP - 1)
            eq(RulesRNG.snapshot().rolls, 0)
            eq(next(b.effects.receipts), nil)
        end
        attempt(b, "player", "sandAttack")
        eq(b.enemy.statStages.acc, -1, "Ground status move is not Ground damage immunity")
    end)

    test("Levitate Worry Seed enables the same actual Ground hit and clears grounded immunity", function()
        local b = fresh(mon("diglett", 18), mon("koffing", 25))
        eq(b.effects:grounded(b.enemy), false)
        override(b, "enemy")
        eq(b.effects:grounded(b.enemy), true)
        local hp = b.enemy.hp
        attempt(b, "player", "mudSlap")
        assert(b.enemy.hp < hp)
        eq(b.enemy.statStages.acc, -1)
    end)

    test("Levitate real forced entry avoids Toxic Spikes without absorbing them", function()
        local original = mon("rattata")
        local airborne = mon("koffing", 12)
        local enemies = Party()
        assert(enemies:add(original))
        assert(enemies:add(airborne))
        local b = fresh(mon("tentacool"), original, { enemyParty=enemies }, "TRAINER")
        attempt(b, "player", "toxicSpikes")
        attempt(b, "player", "whirlwind")
        eq(b.enemy, airborne)
        eq(airborne.status, nil)
        eq(b.conditions.sides.enemy.toxicSpikes, 1, "airborne Poison holder does not absorb hazards")
        eq(airborne.hp, airborne.maxHP)
    end)

    test("Levitate real Arena Trap switch legality observes effective ability", function()
        for _, changed in ipairs({ false, true }) do
            local p = mon("koffing")
            local party = Party()
            assert(party:add(p))
            assert(party:add(mon("squirtle")))
            local b = fresh(p, mon("diglett", 18, "second"), { party=party })
            if changed then
                override(b, "player")
            end
            own(b.enemy, { "harden" })
            local accepted, reason = b:chooseParty(2)
            eq(accepted, not changed)
            if changed then
                eq(reason, "trapped")
            else
                settle(b)
                eq(b.player, party:get(2))
            end
        end
    end)

    test("Liquid Ooze Protect produces no drain and a lethal reflected hit does not revive its user", function()
        local b = fresh(mon("oddish"), mon("tentacool", 17, "second"))
        attempt(b, "enemy", "protect")
        local hp = b.player.hp
        local enemyHP = b.enemy.hp
        attempt(b, "player", "absorb")
        eq(b.player.hp, hp)
        eq(b.enemy.hp, enemyHP)
        eq(RulesRNG.snapshot().rolls, 0)
        b = fresh(mon("oddish"), mon("tentacool", 17, "second"))
        b.player.hp = 1
        attempt(b, "player", "absorb")
        eq(b.player.hp, 0)
        eq(b.outcome, "defeat")
        eq(b.awardedEnemies[b.enemy], nil)
    end)

    test("Worry Seed changes the actual Leech Seed donor's heal callback", function()
        local b = seedBattle()
        override(b, "enemy")
        b.player.hp = b.player.maxHP - 20
        local hp, enemyHP = b.player.hp, b.enemy.hp
        residual(b)
        eq(b.player.hp, hp + enemyHP - b.enemy.hp)
        eq(b.enemy:ability(), 64)
    end)

    test("Voluntary withdrawal clears Flash Fire before the actual holder returns", function()
        local holder = mon("growlithe", 25, "second")
        local party = Party()
        assert(party:add(holder))
        assert(party:add(mon("squirtle")))
        local b = fresh(holder, mon("charmander"), { party=party })
        attempt(b, "enemy", "ember")
        eq(b.effects.ordinaryAbilities.flashFire[holder], true)
        own(b.enemy, { "harden" })
        assert(b:chooseParty(2))
        settle(b)
        eq(b.effects.ordinaryAbilities.flashFire[holder], nil)
        assert(b:chooseParty(1))
        settle(b)
        eq(b.effects:attackStat(holder, moveData.ember, 100), 100)
    end)

    test("Swift Swim follows active identity during actual switching and battle cleanup", function()
        local swimmer = mon("magikarp")
        local replacement = mon("squirtle")
        local party = Party()
        assert(party:add(swimmer))
        assert(party:add(replacement))
        local b = fresh(swimmer, mon("poliwag", 18, "second"), { party=party })
        attempt(b, "enemy", "rainDance")
        eq(b:effectiveSpeed(swimmer), swimmer.spe * 2)
        own(b.enemy, { "harden" })
        assert(b:chooseParty(2))
        settle(b)
        eq(b:effectiveSpeed(swimmer), swimmer.spe)
        eq(b:effectiveSpeed(replacement), replacement.spe)
        eq(b.effects:weatherId(), "raindance", "weather is field-owned")
        b:clearVolatiles()
        eq(b.effects:weatherId(), "none")
    end)

    test("Closed battle rejects seed drain and absorption without HP RNG or state changes", function()
        local b = fireBattle()
        b:clearVolatiles()
        local hp = b.enemy.hp
        local before = RulesRNG.snapshot()
        eq(b.effects:absorbsMove(b.player, b.enemy, moveData.ember), false)
        eq(b.effects:drainSeed(b.enemy, b.player, 10), false)
        eq(b.enemy.hp, hp)
        eq(next(b.effects.ordinaryAbilities.flashFire), nil)
        unchanged(before)
    end)

    test("A withdrawn queued Technician actor spends no PP RNG or replacement damage", function()
        local p = mon("meowth", 14, "second")
        local party = Party()
        assert(party:add(p))
        assert(party:add(mon("squirtle")))
        local b = fresh(p, mon("nidorina"), { party=party })
        own(p, { "scratch" })
        own(b.enemy, { "harden" })
        local queued = { side="player", actor=p, key="scratch", move=moveData.scratch }
        assert(b:chooseParty(2))
        settle(b)
        local hp = b.enemy.hp
        local before = RulesRNG.snapshot()
        b:runScript(function()
            return b:resolveTurn(queued)
        end)
        settle(b)
        eq(p.pp.scratch, moveData.scratch.maxPP)
        eq(b.enemy.hp, hp)
        unchanged(before)
    end)

    RulesRNG.restore(saved)
    return report
end
