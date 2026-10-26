-- Run only in the real SDK. These witnesses use actual Battle coroutine phases,
-- public commands, Pokemon HP/PP/status, and the production rules stream.
CommonAbilityContracts = {}

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end

local function mon(species, level, slot)
    return Pokemon(species, level or 25, {
        natureId=0, abilitySlot=slot or "first", heldItem="none",
    })
end

local function own(pokemon, keys)
    pokemon.moves, pokemon.pp = {}, {}
    for _, key in ipairs(keys) do
        pokemon.moves[#pokemon.moves+1] = key
        pokemon.pp[key] = moveData[key].maxPP
    end
end

local function settle(battle)
    local lines = {}
    for _=1,200 do
        if battle:phase() ~= "script" then return table.concat(lines, "|") end
        assert(not battle.pendingLearning, "unexpected learning interruption")
        lines[#lines+1] = battle.message
        battle.machine:get("script"):advance()
    end
    error("common ability script did not settle")
end

local function fresh(player, enemy, dependencies)
    local battle = Battle(player or mon("squirtle"), enemy or mon("paras",25,"second"), nil, dependencies)
    settle(battle)
    return battle
end

local function attempt(battle, side, key, seed)
    local pokemon = battle[side]
    own(pokemon, {key})
    RulesRNG.seed(seed or 14)
    battle:runScript(function()
        return battle:resolveTurn({side=side, actor=pokemon, key=key, move=moveData[key]})
    end)
    return settle(battle)
end

local function replaceAbility(battle, target)
    local source = target == battle.player and battle.enemy or battle.player
    battle:runScript(function() assert(battle.effects:worrySeed(source,target)) end)
    settle(battle)
end

local function unchanged(before)
    local after = RulesRNG.snapshot()
    eq(after.state,before.state,"RNG state")
    eq(after.rolls,before.rolls,"RNG rolls")
end

function CommonAbilityContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local saved = RulesRNG.snapshot()
    local function test(name, body)
        local before = RulesRNG.snapshot()
        local ok, why = pcall(body)
        RulesRNG.restore(before)
        report.tests[#report.tests+1] = {name=name, ok=ok, error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1
        else report.failed=report.failed+1; report.ok=false end
    end

    test("Inner Focus real Bite round preserves chance draw and allows target action/PP", function()
        local b = fresh(mon("charmander"),mon("zubat"))
        own(b.player,{"bite"}); own(b.enemy,{"harden"})
        RulesRNG.seed(2)
        assert(b:selectMove(1))
        settle(b)
        eq(b:phase(),"command"); eq(b.enemy.hp,36)
        eq(b.player.pp.bite,24); eq(b.enemy.pp.harden,29)
        eq(b.enemy.statStages.def,1); eq(b.enemy.flinched,false)
        eq(RulesRNG.snapshot().rolls,5)
        eq(b.effects.round,nil,"completed round")
    end)

    test("Worry Seed removes Inner Focus: identical Bite draws now flinch before target PP", function()
        local b = fresh(mon("charmander"),mon("zubat"))
        replaceAbility(b,b.enemy)
        own(b.player,{"bite"}); own(b.enemy,{"harden"})
        RulesRNG.seed(2)
        assert(b:selectMove(1))
        local text = settle(b)
        eq(b.enemy.hp,36); eq(b.enemy.pp.harden,30); eq(b.enemy.statStages.def,0)
        eq(b.player.pp.bite,24); eq(RulesRNG.snapshot().rolls,5)
        assert(text:find("flinched",1,true))
        eq(b.enemy:ability(),39); eq(b.effects:effectiveAbility(b.enemy),15)
    end)

    test("Inner Focus payload gate leaves non-flinch condition and stat secondaries enabled", function()
        local b = fresh(nil,mon("zubat"))
        b:setDirection("player")
        RulesRNG.seed(14)
        b:runScript(function()
            ApplyStatus(DEFENDER,"flinch"):apply(b)
            ApplyStatus(DEFENDER,"confuse"):apply(b)
        end)
        settle(b)
        eq(b.enemy.flinched,false); assert(b.enemy.confusion)
        eq(RulesRNG.snapshot().rolls,1)
        eq(b.effects:allowsSecondary(b.player,b.enemy,"condition"),true)
        eq(b.effects:allowsSecondary(b.player,b.enemy,"stat"),true)
    end)

    test("Dry Skin Water Gun heals floor quarter and consumes only attempted PP, no accuracy/damage RNG", function()
        local b = fresh()
        eq(b.enemy.maxHP,52); b.enemy.hp=10
        attempt(b,"player","waterGun")
        eq(b.enemy.hp,23); eq(b.lastDamage,0); eq(b.player.pp.waterGun,24)
        eq(RulesRNG.snapshot().rolls,0); eq(next(b.effects.receipts),nil)
        eq(b.enemy.status,nil)
    end)

    test("Dry Skin caps healing, remains immune at full HP, and precedes even a forced miss", function()
        local b = fresh()
        b.enemy.hp=b.enemy.maxHP-1; b.player.statStages.acc=-6; b.enemy.statStages.eva=6
        attempt(b,"player","waterGun",42)
        eq(b.enemy.hp,b.enemy.maxHP); eq(RulesRNG.snapshot().rolls,0)
        attempt(b,"player","waterGun",42)
        eq(b.enemy.hp,b.enemy.maxHP); eq(b.player.pp.waterGun,24)
        eq(RulesRNG.snapshot().rolls,0)
    end)

    test("Protect blocks Water before Dry Skin healing with no accuracy/damage draws", function()
        local b = fresh()
        own(b.player,{"waterGun"})
        own(b.enemy,{"protect"})
        b.enemy.hp=10
        RulesRNG.seed(2)
        assert(b:selectMove(1))
        settle(b)
        eq(b.enemy.hp,10); eq(b.player.pp.waterGun,24)
        eq(b.enemy.pp.protect,9)
        eq(RulesRNG.snapshot().rolls,1) -- Enemy selection only.
    end)

    test("Worry Seed removes water absorption without changing native Paras slot", function()
        local b = fresh()
        replaceAbility(b,b.enemy)
        local hp=b.enemy.hp
        attempt(b,"player","waterGun")
        assert(b.enemy.hp<hp); eq(b.player.pp.waterGun,24)
        eq(RulesRNG.snapshot().rolls,3); eq(b.enemy:ability(),87)
        eq(b.effects:effectiveAbility(b.enemy),15)
    end)

    test("Dry Skin Fire is base power 50, not final damage times 1.25; real Ember HP/status/RNG", function()
        local b = fresh(mon("squirtle",15),mon("paras",30,"second"))
        eq(b:effectiveMovePower(moveData.ember,b.player,b.enemy),50)
        eq(b.enemy.maxHP,61)
        attempt(b,"player","ember",14)
        -- Base6 -> random92%=5 -> Bug/Grass Fire4x=20. A final damage
        -- multiplier on unmodified power instead produces16 here.
        eq(b.enemy.hp,41); eq(b.enemy.status,nil)
        eq(b.player.pp.ember,24); eq(RulesRNG.snapshot().rolls,4)
        eq(moveData.ember.power,40)
    end)

    test("Dry Skin Q12 base power half ties round down, observer consumes no RNG", function()
        local b = fresh()
        local before=RulesRNG.snapshot()
        for _, row in ipairs({{1,1},{2,2},{3,4},{6,7},{10,12},{40,50}}) do
            eq(b.effects:basePower(moveData.ember,row[1],b.player,b.enemy),row[2])
        end
        eq(b:effectiveMovePower(moveData.waterGun,b.player,b.enemy),40)
        unchanged(before)
        replaceAbility(b,b.enemy)
        eq(b:effectiveMovePower(moveData.ember,b.player,b.enemy),40)
    end)

    test("Actual Rain Dance and complete round heal Dry Skin one eighth with no ability RNG", function()
        local b=fresh()
        own(b.player,{"rainDance","harden"}); own(b.enemy,{"harden"})
        b.enemy.hp=10; RulesRNG.seed(2)
        assert(b:selectMove(1)); settle(b)
        eq(b.enemy.hp,16); eq(b.player.pp.rainDance,4)
        eq(b.effects:snapshot().turns,4); eq(RulesRNG.snapshot().rolls,1)
        assert(b:selectMove(2)); settle(b)
        eq(b.enemy.hp,22); eq(b.effects:snapshot().turns,3)
        eq(RulesRNG.snapshot().rolls,2); eq(b.effects.round,nil)
    end)

    test("Rain Dry Skin caps HP and stops at existing weather expiry boundary", function()
        local b=fresh()
        own(b.player,{"rainDance","harden"}); own(b.enemy,{"harden"})
        b.enemy.hp=b.enemy.maxHP-1; RulesRNG.seed(2)
        assert(b:selectMove(1)); settle(b); eq(b.enemy.hp,b.enemy.maxHP)
        for _=1,3 do assert(b:selectMove(2)); settle(b) end
        eq(b.effects:snapshot().turns,1)
        b.enemy.hp=10
        assert(b:selectMove(2)); settle(b)
        eq(b.enemy.hp,10); eq(b.effects:weatherId(),"none")
        eq(RulesRNG.snapshot().rolls,5)
    end)

    test("Stale rain events cannot heal overridden, benched, fainted or closed recipients", function()
        local b=fresh()
        b:runScript(function() assert(b.effects:setWeather("raindance")) end); settle(b)
        local event
        for _, row in ipairs(b.effects:events()) do if row.kind=="drySkin" then event=row end end
        assert(event); local target=b.enemy; target.hp=10
        replaceAbility(b,target)
        local before=RulesRNG.snapshot()
        b:runScript(function() b.effects:residual(event) end); settle(b)
        eq(target.hp,10); unchanged(before)
        b.effects:clear(target); b.enemy=mon("paras",25,"second")
        b:runScript(function() b.effects:residual(event) end); settle(b)
        eq(target.hp,10); unchanged(before)
        b.enemy=target; target.hp=0
        b:runScript(function() b.effects:residual(event) end); settle(b)
        eq(target.hp,0); unchanged(before)
        target.hp=10; b.effects:close()
        b:runScript(function() b.effects:residual(event) end); settle(b)
        eq(target.hp,10); unchanged(before)
    end)

    test("Stale queued actor and dead recipient spend no PP/RNG and cannot absorb or revive", function()
        local b=fresh()
        own(b.player,{"waterGun"})
        local old=b.player
        local turn={side="player",actor=old,key="waterGun",move=moveData.waterGun}
        b.player=mon("squirtle")
        local before=RulesRNG.snapshot(); b.enemy.hp=10
        b:runScript(function() b:resolveTurn(turn) end); settle(b)
        eq(old.pp.waterGun,25); eq(b.enemy.hp,10); unchanged(before)
        b.enemy.hp=0
        eq(b.effects:absorbsWater(b.player,b.enemy,moveData.waterGun),false)
        eq(b.enemy.hp,0); unchanged(before)
        b.effects:close()
        eq(b.effects:absorbsWater(b.player,b.enemy,moveData.waterGun),false)
        unchanged(before)
    end)

    test("Real party switching clears Worry Seed and restores native Dry Skin on return", function()
        local p=mon("paras",25,"second")
        local reserve=mon("squirtle")
        local party=Party(); assert(party:add(p)); assert(party:add(reserve))
        local b=fresh(p,mon("charmander"),{party=party})
        own(b.enemy,{"harden"})
        replaceAbility(b,p)
        assert(b:chooseParty(2)); settle(b)
        eq(b.effects.abilityOverrides[p],nil)
        assert(b:chooseParty(1)); settle(b)
        eq(b.player,p); eq(b.effects:effectiveAbility(p),87)
        p.hp=10; attempt(b,"enemy","waterGun")
        eq(p.hp,23); eq(b.enemy.pp.waterGun,24); eq(RulesRNG.snapshot().rolls,0)
    end)

    test("Cancelled Water script cannot later heal; already committed absorption survives exit", function()
        for _, commit in ipairs({false,true}) do
            local b=fresh()
            b.enemy.hp=10; own(b.player,{"waterGun"}); RulesRNG.seed(14)
            b:runScript(function()
                return b:resolveTurn({side="player",actor=b.player,key="waterGun",move=moveData.waterGun})
            end)
            local script=b.machine:get("script")
            assert(b.message:find("used",1,true))
            eq(b.player.pp.waterGun,24)
            if commit then
                script:advance()
                assert(b.message:find("Dry Skin",1,true))
            end
            eq(b.enemy.hp,commit and 23 or 10)
            b:clearVolatiles()
            local before=RulesRNG.snapshot()
            local ok,why=script:advance()
            eq(ok,false); eq(why,"script-cancelled")
            eq(b.enemy.hp,commit and 23 or 10); unchanged(before)
        end
    end)

    test("Inner Focus query rejects benched dead and closed identities without entropy", function()
        local b=fresh(nil,mon("zubat"))
        local target=b.enemy
        local before=RulesRNG.snapshot()
        eq(b.effects:statusImmunity(target,"flinch"),"Inner Focus")
        b.enemy=mon("zubat")
        eq(b.effects:statusImmunity(target,"flinch"),nil)
        b.enemy=target; target.hp=0
        eq(b.effects:statusImmunity(target,"flinch"),nil)
        target.hp=target.maxHP; b.effects:close()
        eq(b.effects:statusImmunity(target,"flinch"),nil)
        unchanged(before)
    end)

    RulesRNG.restore(saved)
    return report
end
