-- Prepared real-SDK cases. Never run with stock Lua or replace production RNG.
ContactAbilityContracts = {}

local function eq(actual, expected, label)
    assert(actual == expected, (label or "value") .. ": expected " .. tostring(expected)
        .. ", got " .. tostring(actual))
end

local function mon(species, slot, sex, level)
    return Pokemon(species, level or 25, {
        natureId=0, abilitySlot=slot or "first", heldItem="none", sex=sex,
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
    for _=1,250 do
        if battle:phase() ~= "script" then return table.concat(lines, "|") end
        assert(not battle.pendingLearning, "unexpected learning interruption")
        lines[#lines+1] = battle.message
        battle.machine:get("script"):advance()
    end
    error("contact ability script did not settle")
end

local function fresh(player, enemy, dependencies, trainer)
    local battle = Battle(player or mon("squirtle"), enemy or mon("paras"), trainer, dependencies)
    settle(battle)
    return battle
end

-- A completed script leaves BattleScriptPhase, whose exit clears the round.
-- Observe HP provenance before that exit, using the real coroutine/HP owners.
local function observeRound(battle, action, observer)
    local round
    if observer then
        battle.effects:beginRound()
        round = battle.effects.round
    end
    local outcome = action()
    if observer then
        eq(battle.effects.round, round, "producer retains the observed round")
        assert(round, "live round required for damage-ledger witness")
        observer()
    end
    return outcome
end

local function attempt(battle, side, key, seed, observer)
    local actor = battle[side]
    own(actor, {key})
    RulesRNG.seed(seed or 14)
    battle:runScript(function()
        return observeRound(battle, function()
            return battle:resolveTurn({side=side, actor=actor, key=key, move=moveData[key]})
        end, observer)
    end)
    return settle(battle)
end

local function residual(battle, observer)
    battle:runScript(function()
        return observeRound(battle, function() return battle:endOfRoundStatus() end, observer)
    end)
    return settle(battle)
end

local function unchanged(before)
    eq(RulesRNG.snapshot().state, before.state, "RNG state")
    eq(RulesRNG.snapshot().rolls, before.rolls, "RNG advances")
end

local function attraction(dependencies, trainer)
    local b = fresh(mon("squirtle", "first", "male"),
        mon("jigglypuff", "first", "female"), dependencies, trainer)
    attempt(b, "player", "scratch", 10)
    assert(b.conditions.members[b.player].infatuation)
    return b
end

function ContactAbilityContracts.run()
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

    test("Effect Spore real Scratch has one 11/10/9 draw and real sleep duration", function()
        for _, row in ipairs({{11,"sleep",9,5,3},{2,"paralyze",8,4,0},{3,"poison",9,4,0},{4,false,9,4,0}}) do
            local b = fresh()
            attempt(b,"player","scratch",row[1])
            eq(b.enemy.hp,52-row[3]); eq(b.player.hp,57)
            eq(b.player.status,row[2] or nil); eq(b.player.statusTurns,row[5])
            eq(b.player.pp.scratch,34); eq(RulesRNG.snapshot().rolls,row[4])
            eq(next(b.effects.receipts),nil)
        end
    end)

    test("Effect Spore samples each actual Double Kick hit without interrupting the move", function()
        local b=fresh()
        attempt(b,"player","doubleKick",2)
        eq(b.enemy.hp,45); eq(b.lastDamage,7); eq(b.player.status,"paralyze")
        eq(b.player.pp.doubleKick,29); eq(RulesRNG.snapshot().rolls,7)
    end)

    test("Effect Spore Grass has no later-generation powder immunity", function()
        local b=fresh(mon("bulbasaur"))
        attempt(b,"player","scratch",11)
        eq(b.player.status,"sleep"); eq(b.player.statusTurns,3)
        eq(RulesRNG.snapshot().rolls,5)
    end)

    test("Effect Spore status and poison immunity reject payload after the contact draw", function()
        local b=fresh(mon("bulbasaur"))
        attempt(b,"player","scratch",3)
        eq(b.player.status,nil); eq(RulesRNG.snapshot().rolls,4)
        attempt(b,"enemy","stunSpore",2)
        eq(b.player.status,"paralyze")
        -- The prior paralysis gate may draw on the attacker; test the ability
        -- against an already-statused holder using poison with no action gate.
        local c=fresh()
        attempt(c,"enemy","poisonPowder",2); eq(c.player.status,"poison")
        attempt(c,"player","scratch",11)
        eq(c.player.status,"poison"); eq(RulesRNG.snapshot().rolls,4)
    end)

    test("Noncontact, misses and Protect create no Effect Spore callback", function()
        local b=fresh()
        attempt(b,"player","waterGun",11)
        eq(b.player.status,nil); eq(RulesRNG.snapshot().rolls,3)
        -- Sand Attack is a real accuracy producer, not an injected miss outcome.
        for _=1,6 do attempt(b,"enemy","sandAttack",14) end
        attempt(b,"player","scratch",11)
        eq(b.player.status,nil); eq(RulesRNG.snapshot().rolls,1)
        local c=fresh()
        own(c.player,{"scratch"})
        local turn={side="player",actor=c.player,key="scratch",move=moveData.scratch}
        c.effects:beginRound({turn})
        attempt(c,"enemy","protect",2)
        local hp=c.enemy.hp
        attempt(c,"player","scratch",11)
        eq(c.enemy.hp,hp); eq(c.player.status,nil); eq(RulesRNG.snapshot().rolls,0)
    end)

    test("Cute Charm binds identities, stops before PP, and permits the other half of its coin", function()
        local b=attraction()
        eq(RulesRNG.snapshot().rolls,4)
        local text=attempt(b,"player","harden",1)
        eq(b.player.pp.harden,30); eq(b.player.statStages.def,0)
        eq(RulesRNG.snapshot().rolls,1); assert(text:find("immobilized",1,true))
        attempt(b,"player","harden",2)
        eq(b.player.pp.harden,29); eq(b.player.statStages.def,1)
        eq(RulesRNG.snapshot().rolls,1)
        eq(b.player.infatuation,nil,"no durable field")
    end)

    test("Cute Charm still draws for same sex, genderless and Oblivious recipients", function()
        for _, player in ipairs({mon("squirtle","first","female"),mon("staryu"),mon("slowpoke")}) do
            local b=fresh(player,mon("jigglypuff","first","female"))
            attempt(b,"player","scratch",10)
            eq((b.conditions.members[player] or {}).infatuation,nil)
            eq(RulesRNG.snapshot().rolls,4)
        end
    end)

    test("Real target withdrawal clears attraction and stale queued actor spends nothing", function()
        local p=mon("squirtle","first","male")
        local reserve=mon("squirtle")
        local party=Party(); assert(party:add(p)); assert(party:add(reserve))
        local b=fresh(p,mon("jigglypuff","first","female"),{party=party})
        attempt(b,"player","scratch",10); own(b.enemy,{"harden"}); own(p,{"harden"})
        local turn={side="player",actor=p,key="harden",move=moveData.harden}
        assert(b:chooseParty(2)); settle(b)
        eq(b.conditions.members[p],nil)
        local before=RulesRNG.snapshot()
        b:runScript(function() return b:resolveTurn(turn) end); settle(b)
        eq(p.pp.harden,30); unchanged(before)
        assert(b:chooseParty(1)); settle(b)
        eq((b.conditions.members[p] or {}).infatuation,nil)
    end)

    test("Real source phazing and source faint cleanup clear attraction", function()
        local source=mon("jigglypuff","first","female")
        local enemies=Party(); assert(enemies:add(source)); assert(enemies:add(mon("paras")))
        local b=fresh(mon("squirtle","first","male"),source,{enemyParty=enemies},"TRAINER")
        attempt(b,"player","scratch",10)
        attempt(b,"player","whirlwind",2)
        assert(b.enemy~=source); eq((b.conditions.members[b.player] or {}).infatuation,nil)
        local c=attraction()
        -- The production faint checkpoint owns lifecycle cleanup.
        attempt(c,"player","dragonRage",2)
        if c.enemy:isAlive() then attempt(c,"player","dragonRage",2) end
        assert(not c.enemy:isAlive()); eq((c.conditions.members[c.player] or {}).infatuation,nil)
    end)

    test("Synchronize reflects real Toxic as bad poison without extra chance draws", function()
        local b=fresh(nil,mon("abra"))
        attempt(b,"player","toxic",2)
        eq(b.player.status,"badPoison"); eq(b.enemy.status,"badPoison")
        eq(b.player.statusTurns,0); eq(b.enemy.statusTurns,0)
        eq(b.player.pp.toxic,9); eq(RulesRNG.snapshot().rolls,1)
    end)

    test("Synchronize respects real Safeguard and reflected type immunity", function()
        local b=fresh(nil,mon("abra"))
        attempt(b,"player","safeguard",14)
        attempt(b,"player","toxic",2)
        eq(b.enemy.status,"badPoison"); eq(b.player.status,nil)
        local c=fresh(mon("bulbasaur"),mon("abra"))
        attempt(c,"player","toxic",2)
        eq(c.enemy.status,"badPoison"); eq(c.player.status,nil)
        eq(RulesRNG.snapshot().rolls,1)
    end)

    test("Synchronize reflects paralysis but neither sleep nor a Worry Seed override", function()
        local b=fresh(nil,mon("abra"))
        attempt(b,"player","stunSpore",2)
        eq(b.player.status,"paralyze"); eq(b.enemy.status,"paralyze")
        local c=fresh(nil,mon("abra"))
        attempt(c,"player","sleepPowder",2)
        eq(c.enemy.status,"sleep"); eq(c.player.status,nil)
        local d=fresh(nil,mon("abra"))
        attempt(d,"player","worrySeed",14)
        attempt(d,"player","toxic",2)
        eq(d.enemy.status,"badPoison"); eq(d.player.status,nil)
    end)

    test("Stench real full turn flinches before target PP without mutating the move", function()
        local b=fresh(mon("grimer", "first",nil,50),mon("squirtle"))
        own(b.player,{"mudSlap"}); own(b.enemy,{"harden"})
        -- Search the production stream only for a deterministic input seed.
        -- AI selects its sole move first, then accuracy/crit/variance/flinch.
        local seed
        for candidate=1,1000 do
            local r=RulesRNG.new(candidate)
            r:random(1,1); r:random(1,100); r:random(1,16); r:random(85,100); r:random(1,100)
            if r:random(1,100)<=10 then seed=candidate; break end
        end
        assert(seed); RulesRNG.seed(seed)
        assert(b:selectMove(1)); local text=settle(b)
        eq(b.player.pp.mudSlap,9); eq(b.enemy.pp.harden,30)
        eq(b.enemy.statStages.acc,-1); eq(b.enemy.statStages.def,0)
        assert(text:find("flinched",1,true)); eq(RulesRNG.snapshot().rolls,6)
        eq(#moveData.mudSlap.secondaries,1)
    end)

    test("Stench uses Shield Dust and does not duplicate an existing flinch secondary", function()
        local b=fresh(mon("grimer"),mon("weedle"))
        attempt(b,"player","waterGun",2)
        eq(RulesRNG.snapshot().rolls,3); eq(b.enemy.flinched,false)
        local c=fresh(mon("grimer"),mon("squirtle"))
        attempt(c,"player","bite",2)
        eq(RulesRNG.snapshot().rolls,4); eq(c.enemy.flinched,true)
        eq(#moveData.bite.secondaries,1)
    end)

    test("Stench also appends its secondary to a real fixed-damage hit", function()
        local b=fresh(mon("grimer"),mon("squirtle"))
        attempt(b,"player","dragonRage",65)
        eq(b.enemy.hp,17); eq(b.lastDamage,40); eq(b.enemy.flinched,true)
        eq(b.player.pp.dragonRage,9); eq(RulesRNG.snapshot().rolls,2)
    end)

    test("Anger Point uses actual critical calculation and only surviving recipients", function()
        local b=fresh(mon("squirtle",nil,nil,10),mon("mankey","second",nil,50))
        attempt(b,"player","slash",1)
        eq(b.enemy.statStages.atk,6); assert(b.enemy:isAlive())
        eq(b.player.pp.slash,19); eq(RulesRNG.snapshot().rolls,3)
        local c=fresh(mon("squirtle",nil,nil,10),mon("mankey","second",nil,50))
        attempt(c,"player","scratch",2)
        eq(c.enemy.statStages.atk,0); eq(RulesRNG.snapshot().rolls,3)
        local d=fresh(mon("squirtle",nil,nil,100),mon("mankey","second",nil,1))
        attempt(d,"player","slash",1)
        eq(d.enemy.hp,0); eq(d.enemy.statStages.atk,0)
    end)

    test("Natural Cure real voluntary withdrawal cures major status and toxic state", function()
        local p=mon("staryu","second")
        local party=Party(); assert(party:add(p)); assert(party:add(mon("squirtle")))
        local b=fresh(p,mon("paras"),{party=party})
        attempt(b,"enemy","toxic",2); residual(b)
        eq(p.status,"badPoison"); eq(b.conditions.members[p].toxic,1)
        own(b.enemy,{"harden"}); local hp=p.hp
        assert(b:chooseParty(2)); settle(b)
        eq(p.status,nil); eq(p.statusTurns,0); eq(p.sleepDuration,0); eq(p.hp,hp)
        eq(b.conditions.members[p],nil)
    end)

    test("Natural Cure checks effective ability before clearing Worry Seed on forced withdrawal", function()
        for _, overridden in ipairs({false,true}) do
            local e=mon("staryu","second")
            local enemies=Party(); assert(enemies:add(e)); assert(enemies:add(mon("squirtle")))
            local b=fresh(nil,e,{enemyParty=enemies},"TRAINER")
            attempt(b,"player","toxic",2)
            if overridden then attempt(b,"player","worrySeed",14) end
            attempt(b,"player","whirlwind",14)
            eq(e.status,overridden and "badPoison" or nil)
            eq(b.effects.abilityOverrides[e],nil)
        end
    end)

    test("Magic Guard real Toxic ticks without HP loss or hurt-this-round ledger", function()
        local b=fresh(nil,mon("clefairy","second"))
        attempt(b,"player","toxic",2)
        local hp=b.enemy.hp
        for tick=1,2 do
            residual(b,function()
                eq(b.enemy.hp,hp,"Magic Guard Toxic HP")
                eq(b.enemy.status,"badPoison","Magic Guard retains Toxic")
                eq(b.conditions.members[b.enemy].toxic,tick,"protected Toxic counter")
                eq(b.effects:damagedThisRound(b.enemy),false,"protected Toxic live ledger")
            end)
        end
        attempt(b,"player","worrySeed",14)
        eq(b.effects:effectiveAbility(b.enemy),15,"Worry Seed replaces Magic Guard")
        residual(b,function()
            assert(b.enemy.hp<hp,"Toxic damages after Worry Seed")
            eq(b.conditions.members[b.enemy].toxic,3,"unprotected Toxic counter")
            eq(b.effects:damagedThisRound(b.enemy),true,"unprotected Toxic live ledger")
        end)
        eq(b.effects.round,nil,"script exit clears Toxic round")
    end)

    test("Magic Guard actual burn poison and sand producers preserve status and HP ledger", function()
        for _, key in ipairs({"willOWisp","poisonPowder"}) do
            local b=fresh(nil,mon("clefairy","second"))
            attempt(b,"player",key,2)
            assert(b.enemy.status); local hp=b.enemy.hp
            local text=residual(b,function()
                eq(b.enemy.hp,hp,key.." protected HP")
                eq(b.effects:damagedThisRound(b.enemy),false,key.." live ledger")
            end)
            assert(not text:find("is hurt",1,true))
        end
        local b=fresh(nil,mon("clefairy","second"))
        attempt(b,"player","sandstorm",14)
        local hp=b.enemy.hp
        residual(b,function()
            eq(b.enemy.hp,hp,"protected sand HP")
            eq(b.effects:damagedThisRound(b.enemy),false,"protected sand live ledger")
        end)
    end)

    test("Magic Guard real seed and binding producers retain conditions without draining HP", function()
        local b=fresh(nil,mon("clefairy","second"))
        attempt(b,"enemy","scratch",14)
        attempt(b,"player","leechSeed",2)
        local hp,receiver=b.enemy.hp,b.player.hp
        residual(b,function()
            eq(b.enemy.hp,hp,"protected seed HP"); eq(b.player.hp,receiver,"seed heals no HP")
            eq(b.effects:damagedThisRound(b.enemy),false,"protected seed live ledger")
            assert(b.conditions.members[b.enemy].seed)
        end)
        local c=fresh(nil,mon("clefairy","second"))
        attempt(c,"player","bind",2)
        local duration=c.conditions.members[c.enemy].trap.remaining
        local health=c.enemy.hp
        residual(c,function()
            eq(c.enemy.hp,health,"protected binding HP")
            eq(c.conditions.members[c.enemy].trap.remaining,duration-1,"binding counter")
            eq(c.effects:damagedThisRound(c.enemy),false,"protected binding live ledger")
        end)
    end)

    test("Magic Guard recoil is prevented, direct hits and Struggle recoil still count correctly", function()
        local b=fresh(mon("clefairy","second"),mon("chansey",nil,nil,50))
        local hp=b.player.hp
        attempt(b,"player","doubleEdge",14,function()
            eq(b.player.hp,hp,"Magic Guard prevents ordinary recoil")
            assert(b.enemy.hp<b.enemy.maxHP,"Double Edge deals real HP damage")
            eq(b.effects:damagedThisRound(b.player),false,"protected recoil live ledger")
            eq(b.effects:damagedThisRound(b.enemy),true,"Double Edge target live ledger")
        end)
        attempt(b,"player","struggle",14,function()
            eq(b.player.hp,hp-math.max(1,math.floor(b.player.maxHP/4+0.5)),"Struggle recoil HP")
            eq(b.effects:damagedThisRound(b.player),false,"Struggle recoil excluded from live ledger")
            eq(b.effects:damagedThisRound(b.enemy),true,"Struggle target live ledger")
        end)
        local afterRecoil=b.player.hp
        attempt(b,"enemy","scratch",14,function()
            assert(b.player.hp<afterRecoil,"Scratch deals real HP damage to Magic Guard")
            eq(b.effects:damagedThisRound(b.player),true,"Scratch target live ledger")
        end)
        eq(b.effects.round,nil,"script exit clears hit round")
    end)

    test("Magic Guard confusion self-hit remains real Move HP loss before attempted PP", function()
        local b=fresh(mon("clefairy","second"),mon("squirtle"))
        attempt(b,"enemy","confuseRay",14)
        local hp=b.player.hp
        attempt(b,"player","harden",1,function()
            assert(b.player.hp<hp,"Magic Guard permits confusion HP loss")
            eq(b.player.pp.harden,30,"confusion precedes attempted PP")
            eq(b.effects:damagedThisRound(b.player),true,"confusion self-hit live ledger")
            eq(RulesRNG.snapshot().rolls,2,"confusion coin and damage variance")
        end)
        eq(b.effects.round,nil,"script exit clears confusion round")
    end)

    test("Consumed hit token and cancelled actual hit cannot later roll contact or set Anger Point", function()
        local b=fresh()
        own(b.player,{"scratch"}); RulesRNG.seed(11)
        b:runScript(function()
            return b:resolveTurn({side="player",actor=b.player,key="scratch",move=moveData.scratch})
        end)
        local script=b.machine:get("script")
        script:advance() -- actual HP commit, paused at damage narration
        local token=next(b.effects.receipts); assert(token)
        b:clearVolatiles()
        local before=RulesRNG.snapshot()
        eq(b.effects:afterHit(token),false)
        eq(ContactAbilities.onHit(b.effects,token,true),false)
        eq(script:advance(),false); eq(b.player.status,nil); unchanged(before)
    end)

    test("Actual consumed contact receipt cannot replay after the move finishes", function()
        local b=fresh()
        own(b.player,{"scratch"}); RulesRNG.seed(2)
        b:runScript(function()
            return b:resolveTurn({side="player",actor=b.player,key="scratch",move=moveData.scratch})
        end)
        b.machine:get("script"):advance()
        local token=next(b.effects.receipts); assert(token)
        settle(b)
        eq(b.player.status,"paralyze")
        local before=RulesRNG.snapshot()
        eq(b.effects:afterHit(token),false); unchanged(before)
    end)

    RulesRNG.restore(saved)
    return report
end
