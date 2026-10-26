-- Run only in the real SDK. These witnesses use actual Battle coroutine phases,
-- public commands, Pokemon HP/PP/status, and the production rules stream.
EntryAbilityContracts = {}

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
    local battle = Battle(player or mon("squirtle"), enemy or mon("squirtle"), nil, dependencies)
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

function EntryAbilityContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local saved=RulesRNG.snapshot()
    local function test(name,body)
        local before=RulesRNG.snapshot()
        local ok,why=pcall(body)
        RulesRNG.restore(before)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1
        else report.failed=report.failed+1; report.ok=false end
    end

    test("Intimidate real initial entry lowers living Inner Focus opponent without RNG",function()
        RulesRNG.seed(1)
        local p,e=mon("zubat"),mon("ekans")
        local b=fresh(p,e)
        eq(p.statStages.atk,-1); eq(p.hp,p.maxHP); eq(e.hp,e.maxHP)
        eq(p.status,nil); eq(RulesRNG.snapshot().rolls,0)
        eq(b.effects:effectiveAbility(p),39)
    end)

    test("Simultaneous actual entry callbacks follow effective speed and only tied starts draw",function()
        RulesRNG.seed(1)
        local b=Battle(mon("ekans",11),mon("gyarados",20))
        local text=settle(b)
        assert(text:find("GYARADOS's Intimidate",1,true)<text:find("EKANS's Intimidate",1,true))
        eq(b.player.statStages.atk,-1); eq(b.enemy.statStages.atk,-1)
        eq(RulesRNG.snapshot().rolls,0)
        for _,row in ipairs({{1,"EKANS"},{2,"GYARADOS"}}) do
            RulesRNG.seed(row[1])
            b=Battle(mon("ekans",22),mon("gyarados",15))
            text=settle(b)
            eq(b:effectiveSpeed(b.player),b:effectiveSpeed(b.enemy))
            local first=text:find(row[2].."'s Intimidate",1,true)
            local other=text:find((row[2]=="EKANS" and "GYARADOS" or "EKANS").."'s Intimidate",1,true)
            assert(first<other); eq(RulesRNG.snapshot().rolls,1)
        end
    end)

    test("Intimidate clamps at minus six and rejects stale dead overridden and closed holders",function()
        local b=fresh(nil,mon("ekans"))
        b.player.statStages.atk=-6
        b:runScript(function() b.effects:entry(b.enemy) end)
        assert(settle(b):find("won't go any lower",1,true))
        eq(b.player.statStages.atk,-6)
        b.player.statStages.atk=0
        replaceAbility(b,b.enemy)
        b:runScript(function() b.effects:entry(b.enemy) end); settle(b)
        eq(b.player.statStages.atk,0)
        b.effects:clear(b.enemy)
        local old=b.enemy; b.enemy=mon("squirtle")
        eq(b.effects:entry(old),false)
        b.enemy=old; old.hp=0; eq(b.effects:entry(old),false)
        old.hp=old.maxHP; b.effects:close(); eq(b.effects:entry(old),false)
        eq(b.player.statStages.atk,0)
    end)

    test("Actual party switch activates Intimidate again and clears ability override",function()
        local p,reserve=mon("ekans"),mon("squirtle")
        local party=Party(); assert(party:add(p)); assert(party:add(reserve))
        local b=fresh(p,mon("zubat"),{party=party})
        own(b.enemy,{"harden"}); eq(b.enemy.statStages.atk,-1)
        replaceAbility(b,p)
        assert(b:chooseParty(2)); settle(b)
        assert(b:chooseParty(1)); settle(b)
        eq(b.player,p); eq(b.effects:effectiveAbility(p),22)
        eq(b.enemy.statStages.atk,-2); eq(p.hp,p.maxHP)
        eq(b.enemy.pp.harden,28)
    end)

    test("Forewarn real initial entry chooses declared strongest even with zero PP",function()
        local p=mon("charmander")
        own(p,{"scratch","dragonRage","growl"}); p.pp.dragonRage=0
        RulesRNG.seed(1)
        local b=Battle(p,mon("drowzee",17,"second"))
        local text=settle(b)
        assert(text:find("Forewarn",1,true)); assert(text:find("DRAGON RAGE",1,true))
        eq(RulesRNG.snapshot().rolls,1); eq(p.pp.dragonRage,0)
        eq(p.hp,p.maxHP); eq(p.status,nil)
    end)

    test("Forewarn tied strongest sample follows learned slot order and spends one trial",function()
        for _,row in ipairs({{1,"SCRATCH"},{2,"EMBER"}}) do
            local p=mon("charmander"); own(p,{"scratch","ember","growl"})
            RulesRNG.seed(row[1])
            local b=Battle(p,mon("drowzee",17,"second"))
            assert(settle(b):find(row[2],1,true)); eq(RulesRNG.snapshot().rolls,1)
            eq(p.pp.scratch,35); eq(p.pp.ember,25)
        end
    end)

    test("Forewarn reachable variable power Low Kick ranks eighty while status-only has no alert or RNG",function()
        for _,row in ipairs({{{"lowKick","scratch","leer"},true},{{"growl","leer"},false}}) do
            local p=mon("mankey"); own(p,row[1]); RulesRNG.seed(1)
            local b=Battle(p,mon("drowzee",17,"second"))
            local text=settle(b)
            eq(text:find("Forewarn",1,true)~=nil,row[2])
            if row[2] then assert(text:find("LOW KICK",1,true)) end
            eq(RulesRNG.snapshot().rolls,row[2] and 1 or 0)
        end
    end)

    test("Forewarn override and benched holder do not sample or reveal",function()
        local b=fresh(nil,mon("drowzee",17,"second"))
        replaceAbility(b,b.enemy); local before=RulesRNG.snapshot()
        b:runScript(function() b.effects:entry(b.enemy) end); settle(b)
        unchanged(before)
        local old=b.enemy; b.enemy=mon("squirtle")
        eq(b.effects:entry(old),false); unchanged(before)
    end)

    test("Forewarn actual party reentry samples anew and enemy retains its own attempted PP",function()
        local p,reserve=mon("squirtle",10),mon("drowzee",17,"second")
        local party=Party(); assert(party:add(p)); assert(party:add(reserve))
        local b=fresh(p,mon("charmander",10),{party=party})
        own(b.enemy,{"scratch"}); RulesRNG.seed(1)
        assert(b:chooseParty(2))
        assert(settle(b):find("Forewarn",1,true))
        eq(RulesRNG.snapshot().rolls,5); eq(b.enemy.pp.scratch,34)
        assert(b:chooseParty(1)); settle(b)
        eq(RulesRNG.snapshot().rolls,9); eq(b.enemy.pp.scratch,33)
        assert(b:chooseParty(2))
        assert(settle(b):find("Forewarn",1,true))
        eq(RulesRNG.snapshot().rolls,14); eq(b.enemy.pp.scratch,32)
        eq(b.player,reserve); eq(reserve.status,nil); assert(reserve:isAlive())
    end)

    test("Vital Spirit rejects actual Sleep Powder after accuracy without sleep duration RNG",function()
        local b=fresh(nil,mon("mankey"))
        local text=attempt(b,"player","sleepPowder",1)
        assert(text:find("Vital Spirit",1,true))
        eq(b.enemy.status,nil); eq(b.enemy.statusTurns,0); eq(b.enemy.sleepDuration,0)
        eq(b.player.pp.sleepPowder,14); eq(RulesRNG.snapshot().rolls,1)
        eq(b.enemy.hp,b.enemy.maxHP)
    end)

    test("Worry Seed replaces Vital Spirit with Insomnia and sleep remains prevented",function()
        local b=fresh(nil,mon("mankey"))
        replaceAbility(b,b.enemy)
        local text=attempt(b,"player","sleepPowder",1)
        assert(text:find("Insomnia",1,true)); eq(b.enemy.status,nil)
        eq(b.effects:effectiveAbility(b.enemy),15); eq(b.enemy:ability(),72)
        eq(RulesRNG.snapshot().rolls,1)
    end)

    test("Water Veil rejects Ember burn payload after chance draw and preserves damage and PP",function()
        local b=fresh(mon("squirtle"),mon("goldeen",25,"second"))
        local text=attempt(b,"player","ember",11)
        eq(text:find("Water Veil",1,true),nil,"secondary immunity stays silent")
        eq(b.enemy.hp,52); eq(b.enemy.status,nil)
        eq(b.player.pp.ember,24); eq(RulesRNG.snapshot().rolls,4)
        replaceAbility(b,b.enemy); b.enemy.hp=b.enemy.maxHP
        attempt(b,"player","ember",11)
        eq(b.enemy.hp,52); eq(b.enemy.status,"burn")
        eq(RulesRNG.snapshot().rolls,4)
    end)

    test("Water Veil announces a direct Will-O-Wisp immunity and override permits the burn",function()
        local b=fresh(nil,mon("goldeen",25,"second"))
        local text=attempt(b,"player","willOWisp",1)
        assert(text:find("Water Veil",1,true))
        eq(b.enemy.status,nil); eq(b.enemy.hp,b.enemy.maxHP)
        eq(b.player.pp.willOWisp,14); eq(RulesRNG.snapshot().rolls,1)
        replaceAbility(b,b.enemy)
        attempt(b,"player","willOWisp",1)
        eq(b.enemy.status,"burn"); eq(b.enemy.hp,b.enemy.maxHP)
        eq(RulesRNG.snapshot().rolls,1)
    end)

    test("Entry cures genuine persisted sleep and burn for Vital Spirit and Water Veil",function()
        for _,row in ipairs({{"mankey","first","sleep"},{"goldeen","second","burn"}}) do
            local e=mon(row[1],25,row[2])
            e.status=row[3]; e.statusTurns=row[3]=="sleep" and 2 or 0
            e.sleepDuration=e.statusTurns
            local b=fresh(nil,e)
            eq(e.status,nil); eq(e.statusTurns,0); eq(e.sleepDuration,0)
            eq(e.hp,e.maxHP); eq(b.effects:statusImmunity(e,row[3]),row[1]=="mankey" and "Vital Spirit" or "Water Veil")
        end
    end)

    test("No Guard on either living participant bypasses accuracy stages without accuracy RNG",function()
        for _,side in ipairs({"player","enemy"}) do
            local b=fresh(side=="player" and mon("machop",25,"second") or mon("squirtle"),
                side=="enemy" and mon("machop",25,"second") or mon("squirtle"))
            b.player.statStages.acc=-6; b.enemy.statStages.eva=6
            local before=b.enemy.hp
            eq(accuracyThreshold(moveData.tackle,b.player,b.enemy,b.effects),100)
            attempt(b,"player","tackle",1)
            assert(b.enemy.hp<before); eq(b.player.pp.tackle,34)
            eq(RulesRNG.snapshot().rolls,2); eq(b.enemy.status,nil)
        end
    end)

    test("No Guard cannot bypass Protect or Ghost immunity",function()
        local b=fresh(mon("machop",25,"second"),mon("squirtle"))
        -- Protect requires an opposing selected move still queued. An isolated
        -- resolveTurn intentionally fails that precondition; use a real round.
        own(b.player,{"tackle"}); own(b.enemy,{"protect"}); RulesRNG.seed(1)
        assert(b:selectMove(1)); local text=settle(b)
        assert(text:find("SQUIRTLE protected itself!",1,true))
        eq(b:phase(),"command"); eq(b.effects.round,nil)
        eq(b.enemy.hp,b.enemy.maxHP); eq(b.player.pp.tackle,34)
        eq(b.enemy.pp.protect,9)
        eq(RulesRNG.snapshot().rolls,1) -- Enemy selection only.
        b=fresh(mon("machop",25,"second"),mon("gastly"))
        attempt(b,"player","tackle",1)
        eq(b.enemy.hp,b.enemy.maxHP); eq(RulesRNG.snapshot().rolls,0)
    end)

    test("No Guard Worry Seed override restores ordinary accuracy trial and misses",function()
        local b=fresh(mon("machop",25,"second"))
        replaceAbility(b,b.player)
        b.player.statStages.acc=-6; b.enemy.statStages.eva=6
        attempt(b,"player","tackle",11)
        eq(b.enemy.hp,b.enemy.maxHP); eq(RulesRNG.snapshot().rolls,1)
        eq(b.player.pp.tackle,34)
    end)

    test("Shell Armor also rejects guaranteed criticals without inventing a critical trial",function()
        local b=fresh(mon("squirtle"),mon("shellder"))
        local text=attempt(b,"player","stormThrow",1)
        eq(text:find("A critical hit!",1,true),nil)
        eq(b.player.pp.stormThrow,9); eq(RulesRNG.snapshot().rolls,2)
        eq(b.enemy.hp,45)
    end)

    test("Shell Armor rejects sampled critical after its trial, without favorable stage bypass",function()
        local b=fresh(mon("squirtle"),mon("shellder"))
        eq(b.player.atk,29); eq(b.enemy.def,55); eq(b.enemy.maxHP,50)
        -- IV/EV0, neutral L25: A29/D55/HP50. Seed1 draws accuracy7,
        -- critical1/16, random93 (state1622650073). Shell Armor rejects that
        -- sampled crit before stage bypass: A14/D110 -> base3 -> damage2.
        -- Without armor: stages ignored -> base8 -> crit16 -> damage14.
        -- Independent pinned-source arithmetic: test_entry_ability_witness_math.py.
        b.player.statStages.atk=-2; b.enemy.statStages.def=2
        local text=attempt(b,"player","tackle",1)
        eq(text:find("A critical hit!",1,true),nil)
        eq(b.enemy.hp,48); eq(b.player.pp.tackle,34)
        eq(RulesRNG.snapshot().rolls,3)
        eq(RulesRNG.snapshot().state,1622650073)
        eq(b.player.statStages.atk,-2); eq(b.enemy.statStages.def,2)
        replaceAbility(b,b.enemy); b.enemy.hp=b.enemy.maxHP
        text=attempt(b,"player","tackle",1)
        assert(text:find("A critical hit!",1,true))
        eq(b.enemy.hp,36); eq(b.player.pp.tackle,34)
        eq(RulesRNG.snapshot().rolls,3); eq(RulesRNG.snapshot().state,1622650073)
        eq(b.player.statStages.atk,-2); eq(b.enemy.statStages.def,2)
    end)

    test("Skill Link actual Icicle Spear lands five independently rolled hits without count draw",function()
        local b=fresh(mon("shellder",16,"second"),mon("squirtle",40))
        local text=attempt(b,"player","icicleSpear",14)
        assert(text:find("Hit 5 times!",1,true))
        eq(b.player.pp.icicleSpear,29); eq(RulesRNG.snapshot().rolls,11)
        eq(b.enemy.hp,80); eq(b.enemy.status,nil)
        eq(moveData.icicleSpear.minHits,2); eq(moveData.icicleSpear.maxHits,5)
    end)

    test("Skill Link Worry Seed restores variable hit-count entropy and early KO stops remaining rolls",function()
        local b=fresh(mon("shellder",16,"second"),mon("squirtle",40))
        replaceAbility(b,b.player)
        local text=attempt(b,"player","icicleSpear",14)
        assert(text:find("Hit 3 times!",1,true))
        eq(RulesRNG.snapshot().rolls,8); eq(b.enemy.hp,82)
        b=fresh(mon("shellder",16,"second"),mon("squirtle",1))
        b.enemy.hp=1
        -- A low-level KO keeps the real reward owner below a learning boundary.
        attempt(b,"player","icicleSpear",14)
        eq(b.enemy.hp,0); eq(b.player.pp.icicleSpear,29)
        eq(RulesRNG.snapshot().rolls,3)
    end)

    test("Sniper real Water Gun critical applies final half-down modifier after resistance",function()
        local b=fresh(mon("horsea",16,"second"),mon("squirtle",21))
        local text=attempt(b,"player","waterGun",1)
        assert(text:find("A critical hit!",1,true))
        -- Base7 -> critical14 -> random13 -> STAB19 -> resist9 -> Sniper13.
        -- Multiplying the early critical by3 would incorrectly remove14 HP.
        eq(b.enemy.hp,36); eq(b.player.pp.waterGun,24)
        eq(RulesRNG.snapshot().rolls,3)
        replaceAbility(b,b.player); b.enemy.hp=b.enemy.maxHP
        attempt(b,"player","waterGun",1)
        eq(b.enemy.hp,40); eq(RulesRNG.snapshot().rolls,3)
    end)

    test("Sniper ordinary noncritical damage and RNG match its Worry Seed override",function()
        local b=fresh(mon("horsea",16,"second"),mon("squirtle",21))
        attempt(b,"player","waterGun",14)
        local hp=b.enemy.hp
        eq(hp,45); eq(RulesRNG.snapshot().rolls,3)
        replaceAbility(b,b.player); b.enemy.hp=b.enemy.maxHP
        attempt(b,"player","waterGun",14)
        eq(b.enemy.hp,hp); eq(b.player.pp.waterGun,24)
        eq(RulesRNG.snapshot().rolls,3)
    end)

    test("Soundproof general Supersonic Sing Growl Screech and damaging sound guard before accuracy",function()
        for _,key in ipairs({"supersonic","sing","growl","screech","hyperVoice","bugBuzz"}) do
            local b=fresh(nil,mon("voltorb"))
            local text=attempt(b,"player",key,1)
            assert(text:find("Soundproof",1,true),key)
            eq(b.enemy.hp,b.enemy.maxHP); eq(b.enemy.status,nil); eq(b.enemy.confusion,nil)
            eq(b.enemy.statStages.atk,0); eq(b.enemy.statStages.def,0)
            eq(b.player.pp[key],moveData[key].maxPP-1)
            eq(RulesRNG.snapshot().rolls,0); eq(next(b.effects.receipts),nil)
        end
    end)

    test("Soundproof does not block Sonic Boom and Worry Seed enables actual Supersonic confusion",function()
        local b=fresh(nil,mon("voltorb"))
        attempt(b,"player","sonicBoom",1)
        eq(b.enemy.hp,b.enemy.maxHP-20); eq(b.player.pp.sonicBoom,19)
        eq(RulesRNG.snapshot().rolls,1)
        replaceAbility(b,b.enemy)
        attempt(b,"player","supersonic",1)
        eq(b.enemy.confusion,1); eq(RulesRNG.snapshot().rolls,2)
        eq(b.player.pp.supersonic,19); eq(b.enemy.status,nil)
    end)

    test("Public complete round Soundproof spends both PP slots and only enemy choice RNG",function()
        local b=fresh(mon("charmander"),mon("voltorb"))
        own(b.player,{"growl"}); own(b.enemy,{"harden"}); RulesRNG.seed(1)
        assert(b:selectMove(1)); settle(b)
        eq(b:phase(),"command"); eq(b.player.pp.growl,39); eq(b.enemy.pp.harden,29)
        eq(b.enemy.statStages.atk,0); eq(b.enemy.statStages.def,1)
        eq(b.enemy.hp,b.enemy.maxHP); eq(RulesRNG.snapshot().rolls,1)
    end)

    test("New query hooks reject benched dead overridden closed identities without entropy",function()
        for _,row in ipairs({{"machop","second",99},{"shellder","first",75},
            {"shellder","second",92},{"horsea","second",97},{"mankey","first",72},{"goldeen","second",41}}) do
            local b=fresh(nil,mon(row[1],25,row[2])); local e=b.enemy
            eq(b.effects:livingAbility(e,row[3]),true)
            local before=RulesRNG.snapshot()
            b.enemy=mon("squirtle"); eq(b.effects:livingAbility(e,row[3]),false)
            b.enemy=e; e.hp=0; eq(b.effects:livingAbility(e,row[3]),false)
            e.hp=e.maxHP; replaceAbility(b,e); eq(b.effects:livingAbility(e,row[3]),false)
            b.effects:close(); eq(b.effects:livingAbility(e,row[3]),false)
            unchanged(before)
        end
    end)

    test("Stale queued actor cannot borrow replacement No Guard or spend PP or RNG",function()
        local p=mon("squirtle"); local reserve=mon("machop",25,"second")
        local party=Party(); assert(party:add(p)); assert(party:add(reserve))
        local b=fresh(p,nil,{party=party}); own(p,{"tackle"}); own(b.enemy,{"harden"})
        local turn={side="player",actor=p,key="tackle",move=moveData.tackle}
        assert(b:chooseParty(2)); settle(b)
        local hp=b.enemy.hp; local before=RulesRNG.snapshot()
        b:runScript(function() b:resolveTurn(turn) end); settle(b)
        eq(p.pp.tackle,35); eq(b.enemy.hp,hp); unchanged(before)
    end)

    RulesRNG.restore(saved)
    return report
end
