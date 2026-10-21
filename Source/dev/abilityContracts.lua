-- Actual production classes and coroutine; no fake SDK or alternate rules engine.
AbilityContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function own(mon,keys) mon.moves={};mon.pp={};for i,key in ipairs(keys) do mon.moves[i]=key;mon.pp[key]=moveData[key].pp end end
local function mon(species,slot) return Pokemon(species,100,{natureId=0,abilitySlot=slot or "first",heldItem="none"}) end
local function settle(b)
    local text={};local n=0
    while b:phase()=="script" do
        n=n+1;assert(n<400,"script failed to settle; "..b.message)
        assert(not b.pendingLearning,"unexpected learning receipt; contract must settle actual learning overlay")
        text[#text+1]=b.message;b.machine:get("script"):advance()
    end
    return table.concat(text,"|")
end
local function battle(p,e,trainer,deps) local b=Battle(p,e,trainer,deps);settle(b);return b end
local function act(b,side,key)
    local p=side=="player" and b.player or b.enemy;own(p,{key})
    b:runScript(function() return b:resolveTurn({side=side,key=key,move=moveData[key]}) end)
    return settle(b)
end
local function script(b,fn) b:runScript(fn);return settle(b) end
local function seed(low,high,want)
    for s=1,100000 do if RulesRNG.new(s):random(low,high)==want then return s end end
    error("no bounded seed for literal RNG fixture")
end
local function unchanged(before) local a=RulesRNG.snapshot();eq(a.state,before.state,"rng state");eq(a.rolls,before.rolls,"rng rolls") end
local function critVarianceSeed()
    for s=1,10000 do local r=RulesRNG.new(s);if r:random(1,16)~=1 and r:random(85,100)==100 then return s end end
    error("no damage seed")
end
function AbilityContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
    local function test(name,fn)
        Autopilot.resetControls();local ok,why=pcall(fn);Autopilot.resetControls();report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("All sixteen normal IDs are registered and secondary metadata remains explicit for424 moves",function()
        local b=battle(mon("rattata"),mon("pidgey"));local ids={5,8,9,14,19,50,51,61,62,65,66,67,68,69,71,77}
        for _,id in ipairs(ids) do assert(b.effects:supported(id),"missing ability "..id) end
        local n=0;for key,m in pairs(moveData) do n=n+1;eq(type(m.contact),"boolean",key.." contact");eq(type(m.hasSecondary),"boolean",key.." secondary");eq(type(m.ohko),"boolean",key.." OHKO") end;eq(n,424)
        eq(moveData.poisonSting.hasSecondary,true);eq(moveData.thunderWave.hasSecondary,false);eq(moveData.tackle.contact,true);eq(moveData.earthquake.contact,false);eq(moveData.fissure.ohko,true)
    end)
    test("Q12 factor chain half-up and application half-down remain distinct",function()
        eq(BattleEffects.chain(5325,3277),4260);eq(BattleEffects.chain(4260,2048),2130)
        eq(BattleEffects.fixedRound(75,2130),39);eq(BattleEffects.fixedRound(27,6144),40)
        eq(BattleEffects.chain(1,2048),1);eq(BattleEffects.fixedRound(1,2048),0)
    end)
    for _,row in ipairs({{"bulbasaur","grass",65},{"charmander","fire",66},{"squirtle","water",67},{"beedrill","bug",68}}) do
        test("Low-HP typed attack-stat boundary "..row[1],function()
            local p=mon(row[1]);local b=battle(p,mon("pidgey"));eq(p:ability(),row[3]);p.maxHP,p.hp=19,6
            local m={type=row[2],category="special"};eq(b.effects:attackStat(p,m,27),40)
            p.hp=7;eq(b.effects:attackStat(p,m,27),27);p.hp=6;m.type="normal";eq(b.effects:attackStat(p,m,27),27)
        end)
    end
    test("Guts physical stat and burn exemption produce literal damage24 versus burned8",function()
        local p,e=mon("rattata","second"),mon("pidgey");local b=battle(p,e)
        p.level,p.atk,p.status=20,27,"burn";e.def=21
        local s=critVarianceSeed();RulesRNG.seed(s);local boosted=calcDamage(p,e,moveData.bite,nil,b.effects);eq(boosted.damage,24)
        RulesRNG.seed(s);local plain=calcDamage(p,e,moveData.bite);eq(plain.damage,8)
        eq(b.effects:attackStat(p,{category="special"},27),27)
    end)
    test("Guts does not alter raw staged confusion self-damage",function()
        local p,e=mon("rattata","second"),mon("pidgey");local b=battle(p,e)
        p.level,p.atk,p.def,p.status,p.confusion=20,27,21,"burn",2;own(p,{"tackle"})
        local selected
        for s=1,10000 do local r=RulesRNG.new(s);if r:random(1,2)==1 and r:random(85,100)==100 then selected=s;break end end
        assert(selected);RulesRNG.seed(selected);local hp=p.hp;act(b,"player","tackle");eq(hp-p.hp,12);eq(p.pp.tackle,moveData.tackle.pp)
    end)
    test("Compound Eyes literal75 becomes98 before stages",function()
        local p,e=mon("butterfree"),mon("rattata");local b=battle(p,e)
        eq(b.effects:accuracy(p,e,moveData.sleepPowder),98)
        p.statStages.acc=-1;RulesRNG.seed(seed(1,100,74));eq(checkAccuracy(moveData.sleepPowder,p,e,b.effects),false)
        RulesRNG.seed(seed(1,100,73));eq(checkAccuracy(moveData.sleepPowder,p,e,b.effects),true)
    end)
    test("Tangled Feet uses confusion ratio without changing evasion stages",function()
        local p,e=mon("butterfree"),mon("pidgey","second");local b=battle(p,e);e.confusion=2
        eq(b.effects:accuracy(mon("rattata"),e,moveData.sleepPowder),37);eq(e.statStages.eva,0)
        eq(b.effects:accuracy(mon("rattata"),e,moveData.tackle),50);e.confusion=nil;eq(b.effects:accuracy(mon("rattata"),e,moveData.tackle),100)
    end)
    test("Sand Veil weather query and combined Compound Eyes ratio are exact",function()
        local p,e=mon("butterfree"),mon("sandshrew");local b=battle(p,e)
        script(b,function() b.effects:setSandstorm() end)
        eq(b.effects:accuracy(p,e,moveData.sleepPowder),78);eq(b.effects:accuracy(mon("rattata"),e,moveData.tackle),80)
        b.effects.weather=nil;eq(b.effects:accuracy(mon("rattata"),e,moveData.tackle),100)
    end)
    test("Shield Dust prevents secondary before chance but primary paralysis still works",function()
        local p,e=mon("rattata"),mon("caterpie");local b=battle(p,e);b:setDirection("player")
        local before=RulesRNG.snapshot();script(b,function() b:applyMoveSecondaries(moveData.poisonSting) end);unchanged(before);eq(e.status,nil)
        script(b,function() ApplyStatus(DEFENDER,"paralyze"):apply(b) end);eq(e.status,"paralyze")
        e.status=nil;script(b,function() ModifyStat(DEFENDER,"atk",-1):apply(b);ApplyStatus(DEFENDER,"confuse"):apply(b) end)
        eq(e.statStages.atk,-1);assert(e.confusion)
    end)
    test("Shield Dust does not stop self secondary or Rapid Spin primary cleanup",function()
        local p,e=mon("rattata"),mon("caterpie");local b=battle(p,e);b:setDirection("player")
        script(b,function() SecondaryEffect(ATTACKER,ModifyStat(ATTACKER,"atk",1)):apply(b) end);eq(p.statStages.atk,1)
        b.conditions:of(p).seed="enemy";act(b,"player","rapidSpin");eq(b.conditions:of(p).seed,nil)
    end)
    test("Keen Eye blocks opponent accuracy drop without mutating stages or RNG",function()
        local p,e=mon("rattata"),mon("pidgey");local b=battle(p,e);b:setDirection("player");local before=RulesRNG.snapshot()
        script(b,function() ModifyStat(DEFENDER,"acc",-1):apply(b) end);eq(e.statStages.acc,0);unchanged(before)
        b:setDirection("enemy");script(b,function() ModifyStat(ATTACKER,"acc",-1):apply(b) end);eq(e.statStages.acc,-1)
        p.statStages.eva=2;eq(p.statStages.eva,2);RulesRNG.seed(seed(1,100,60));eq(checkAccuracy(moveData.tackle,e,p,b.effects),false)
    end)
    test("Sturdy fixed Dragon Rage40 leaves full28HP at1 without altering actual damage receipt",function()
        local p,e=mon("charmander"),mon("geodude","second");e.maxHP,e.hp=28,28
        local b=battle(p,e);act(b,"player","dragonRage");eq(e.hp,1);eq(b.lastDamage,27)
    end)
    test("Sturdy partial HP fixed damage faints and fullHP OHKO immunity consumes no accuracy RNG",function()
        local p,e=mon("charmander"),mon("geodude","second");e.maxHP,e.hp=28,27
        local b=battle(p,e);act(b,"player","dragonRage");eq(e.hp,0)
        b=battle(mon("dugtrio"),mon("geodude","second"));b.enemy.hp=3
        local before=RulesRNG.snapshot();local text=act(b,"player","fissure");unchanged(before);assert(text:find("Sturdy",1,true));eq(b.enemy.hp,3)
    end)
    test("Sturdy cannot endure second direct hit or residual damage",function()
        local p,e=mon("rattata"),mon("geodude","second");local b=battle(p,e);e.maxHP,e.hp=28,28
        script(b,function()
            local first=b.effects:hit(p,e,moveData.tackle,40);eq(first.removed,27);b.effects:afterHit(first)
            local second=b.effects:hit(p,e,moveData.tackle,40);eq(second.removed,1);b.effects:afterHit(second)
        end);eq(e.hp,0)
        e.hp,e.status=28,"poison";e.maxHP=224;script(b,function() b:applyStatusDamage(e) end);eq(e.hp,0)
    end)
    test("OHKO lower-level/type gates reject before RNG, level-equal boundary29 hits30 misses",function()
        local p,e=mon("dugtrio"),mon("rattata");local b=battle(p,e)
        p.level=99;local before=RulesRNG.snapshot();eq(b.effects:ohko(p,e,moveData.fissure),false);unchanged(before)
        p.level=100;e.type="flying";eq(b.effects:ohko(p,e,moveData.fissure),false);unchanged(before);e.type="normal"
        RulesRNG.seed(seed(0,99,29));eq(b.effects:ohko(p,e,moveData.fissure),true)
        RulesRNG.seed(seed(0,99,30));eq(b.effects:ohko(p,e,moveData.fissure),false)
    end)
    test("Actual OHKO move bypasses ordinary accuracy and removes current HP",function()
        local b=battle(mon("dugtrio"),mon("rattata"));RulesRNG.seed(seed(0,99,0));local before=RulesRNG.snapshot().rolls
        act(b,"player","fissure");eq(b.enemy.hp,0);eq(RulesRNG.snapshot().rolls-before,1)
    end)
    test("Static lethal contact and already-statused attacker still take eligible reaction roll once",function()
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e);p.status,p.statusTurns,p.sleepDuration="burn",0,0;e.hp=1
        local receipt=b.effects:hit(p,e,moveData.tackle,999);RulesRNG.seed(seed(0,99,29));local before=RulesRNG.snapshot().rolls
        script(b,function() assert(b.effects:afterHit(receipt)) end);eq(p.status,"burn");eq(RulesRNG.snapshot().rolls-before,1);eq(e.hp,0)
        local saved=RulesRNG.snapshot();eq(b.effects:afterHit(receipt),false);unchanged(saved)
    end)
    test("Static boundary29 paralyzes Ground and Electric in Gen5;30 does not",function()
        for _,species in ipairs({"sandshrew","pikachu"}) do
            local p,e=mon(species),mon("pikachu");local b=battle(p,e);RulesRNG.seed(seed(0,99,29))
            script(b,function() b.effects:afterHit(b.effects:hit(p,e,moveData.tackle,1)) end);eq(p.status,"paralyze",species)
        end
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e);RulesRNG.seed(seed(0,99,30))
        script(b,function() b.effects:afterHit(b.effects:hit(p,e,moveData.tackle,1)) end);eq(p.status,nil)
    end)
    test("Noncontact physical does not trigger Static; eligible special contact uses metadata",function()
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e);local before=RulesRNG.snapshot()
        script(b,function() b.effects:afterHit(b.effects:hit(p,e,moveData.earthquake,1)) end);unchanged(before)
        eq(moveData.petalDance.contact,true);eq(moveData.petalDance.category,"special")
        RulesRNG.seed(seed(0,99,0));script(b,function() b.effects:afterHit(b.effects:hit(p,e,moveData.petalDance,1)) end);eq(p.status,"paralyze")
    end)
    test("Rock Head blocks Double Edge but never Struggle recoil",function()
        local p,e=mon("geodude"),mon("rattata");local b=battle(p,e);local hp=p.hp
        act(b,"player","doubleEdge");eq(p.hp,hp)
        b=battle(mon("geodude"),mon("rattata"));hp=b.player.hp;act(b,"player","struggle");eq(hp-b.player.hp,math.floor(b.player.maxHP/4+0.5))
    end)
    test("Shed Skin33percent clears sleep/toxic before status residual with exact boundary",function()
        for _,status in ipairs({"sleep","badPoison","burn"}) do
            local p,e=mon("metapod"),mon("rattata");local b=battle(p,e);p.status=status;p.statusTurns=status=="sleep" and 1 or 0;p.sleepDuration=status=="sleep" and 3 or 0;b.conditions:of(p).toxic=5
            RulesRNG.seed(seed(0,99,32));local hp=p.hp;script(b,function() b:endOfRoundStatus() end)
            eq(p.status,nil);eq(p.statusTurns,0);eq(p.sleepDuration,0);eq(b.conditions:of(p).toxic,nil);eq(p.hp,hp)
        end
        local p,e=mon("kakuna"),mon("rattata");local b=battle(p,e);p.status="poison";RulesRNG.seed(seed(0,99,33));local hp=p.hp
        script(b,function() b:endOfRoundStatus() end);eq(p.status,"poison");eq(hp-p.hp,p.maxHP//8)
    end)
    test("Healthy Shed Skin consumes no residual RNG; confusion is not cured",function()
        local p,e=mon("metapod"),mon("rattata");local b=battle(p,e);p.confusion=2;local before=RulesRNG.snapshot()
        script(b,function() b:endOfRoundStatus() end);unchanged(before);eq(p.confusion,2)
    end)
    test("Real Sandstorm producer lasts five ticks, damage before Shed Skin and no damage on expiry",function()
        local p,e=mon("sandshrew"),mon("rattata");local b=battle(p,e);act(b,"player","sandstorm");eq(b.effects:snapshot().turns,5)
        local hp=e.hp;for i=1,5 do script(b,function() b:endOfRoundStatus() end);eq(b.effects:snapshot().turns,5-i) end
        eq(hp-e.hp,4*math.max(1,e.maxHP//16));eq(p.hp,p.maxHP);eq(b.effects:snapshot().weather,"none")
    end)
    test("Sandstorm Rock SpD modifier is stat phase and cannot affect fixed damage",function()
        local p,e=mon("squirtle"),mon("geodude");local b=battle(p,e);script(b,function() b.effects:setSandstorm() end)
        eq(b.effects:defenseStat(e,moveData.waterGun,27),40);eq(b.effects:defenseStat(e,moveData.tackle,27),27)
        e.hp,e.maxHP=100,100;act(b,"player","dragonRage");eq(e.hp,60)
    end)
    test("Arena Trap switch rejection is transactional, forced switch and Flying remain legal",function()
        local p,e=mon("squirtle"),mon("diglett","second");local party=Party();assert(party:add(p));assert(party:add(mon("pidgey")))
        local b=battle(p,e,"TRAINER",{party=party});local before=RulesRNG.snapshot();eq(b:chooseParty(2),false);eq(party:active(),p);unchanged(before)
        p.hp=0;b.machine:change("forcedSwitch");assert(b:chooseParty(2));settle(b);eq(party:active().species,"pidgey")
        eq(b.effects:withdrawBlocked(b.player),false);e.hp=0;eq(b.effects:withdrawBlocked(mon("squirtle")),false)
    end)
    test("Gen5 Ghost groundedness and living-owner policy are explicit",function()
        local p,e=mon("gengar"),mon("diglett","second");local b=battle(p,e)
        -- Levitate is outside this first16 implementation; pure type check must
        -- never grant the later universal Ghost escape exemption.
        eq(b.effects:grounded({type="ghost",type2=nil}),true)
        e.hp=0;eq(b.effects:withdrawBlocked(p),false)
    end)
    test("Run Away bypasses wild Arena Trap and binding without RNG but not trainer refusal",function()
        local p,e=mon("rattata"),mon("diglett","second");local b=battle(p,e);b.conditions:of(p).trap={source=e,remaining=3};local before=RulesRNG.snapshot()
        assert(b:tryRun());settle(b);eq(b.outcome,"run");unchanged(before)
        b=battle(mon("rattata"),mon("pidgey"),"TRAINER");before=RulesRNG.snapshot();assert(b:tryRun());settle(b);eq(b:phase(),"command");eq(b.outcome,nil);unchanged(before)
    end)
    test("Flee failedattempt0/equal speed literal128 boundary and faster guaranteed no RNG",function()
        local function trial(speed,other,roll,attempts)
            local b=battle(mon("pidgey"),mon("rattata"));b.player.spe,b.enemy.spe=speed,other;b.runAttempts=attempts or 0
            RulesRNG.seed(seed(0,255,roll));local before=RulesRNG.snapshot().rolls;assert(b:tryRun());local message=b.message
            return b,message,RulesRNG.snapshot().rolls-before
        end
        local b,msg,n=trial(20,20,127);assert(msg:find("Got away",1,true));eq(n,1);eq(b.runAttempts,0)
        b,msg,n=trial(20,20,128);assert(msg:find("Can't escape",1,true));eq(b.runAttempts,1);eq(n,1)
        b,msg,n=trial(21,20,255);assert(msg:find("Got away",1,true));eq(n,0)
        b,msg,n=trial(20,20,255,20);assert(msg:find("Got away",1,true));eq(n,1) -- no modulo wrap
    end)
    test("Weather and hit receipts are canceled on clearVolatiles without changing durable status",function()
        local p,e=mon("pikachu"),mon("rattata");local b=battle(p,e);p.status,p.statusTurns,p.sleepDuration="sleep",0,3
        local receipt=b.effects:hit(p,e,moveData.tackle,1);script(b,function() b.effects:setSandstorm() end)
        b:clearVolatiles();local before=RulesRNG.snapshot();eq(b.effects:afterHit(receipt),false);unchanged(before)
        eq(b.effects:snapshot().weather,"none");eq(p.status,"sleep");eq(p.sleepDuration,3)
        local nextBattle=battle(p,mon("rattata"));eq(nextBattle.effects:snapshot().weather,"none")
    end)
    test("Invalid phase/index/PP commands preserve ability weather HP and RNG",function()
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e);own(p,{"tackle"});p.pp.tackle=0
        local before=RulesRNG.snapshot();eq(b:selectMove(1),false);eq(b:selectMove(99),false);eq(b.player.hp,p.maxHP);eq(b.enemy.hp,e.maxHP);unchanged(before)
    end)
    test("Gen5 multihit literal35/35/15/15 boundaries drive the production picker",function()
        local b=battle(mon("rattata"),mon("pidgey"))
        for _,row in ipairs({{0,2},{34,2},{35,3},{69,3},{70,4},{84,4},{85,5},{99,5}}) do
            RulesRNG.seed(seed(0,99,row[1]));eq(b:hitCount(moveData.furyAttack),row[2],"multihit roll"..row[1])
        end
        local before=RulesRNG.snapshot();eq(b:hitCount(moveData.doubleKick),2);unchanged(before)
    end)
    test("Actual Double Kick Sturdy endures first then second hit KOs with one PP",function()
        local p,e=mon("rattata"),mon("geodude","second");p.atk=999;e.def=1;e.maxHP,e.hp=28,28
        local b=battle(p,e);act(b,"player","doubleKick");eq(e.hp,0);eq(p.pp.doubleKick,moveData.doubleKick.pp-1);eq(b.lastDamage,28)
    end)
    test("Actual double contact rolls Static each hit after first paralysis without a second status gate",function()
        local p,e=mon("rattata"),mon("pikachu");p.atk=1;e.maxHP,e.hp=1000,1000
        local b=battle(p,e);local chosen
        for v=1,10000 do
            local r=RulesRNG.new(v);r:random(1,100);r:random(1,16);r:random(85,100)
            if r:random(0,99)<30 then chosen=v;break end
        end
        assert(chosen);RulesRNG.seed(chosen);local before=RulesRNG.snapshot().rolls
        act(b,"player","doubleKick");eq(p.status,"paralyze");eq(RulesRNG.snapshot().rolls-before,7);eq(p.pp.doubleKick,moveData.doubleKick.pp-1)
    end)
    test("Move immunity and miss do not create contact reaction or damage rolls",function()
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e)
        -- Actual typed immunity, retaining Pikachu's actual Static identity.
        e.type="ghost";RulesRNG.seed(seed(1,100,1));local before=RulesRNG.snapshot().rolls
        act(b,"player","tackle");eq(RulesRNG.snapshot().rolls-before,0);eq(p.status,nil);eq(e.hp,e.maxHP)
        e.type="electric";RulesRNG.seed(seed(1,100,100));before=RulesRNG.snapshot().rolls
        act(b,"player","slam");eq(RulesRNG.snapshot().rolls-before,1);eq(p.status,nil);eq(e.hp,e.maxHP)
    end)
    test("Lethal contact status precedes recoil and terminal faint verdict in actual script",function()
        local p,e=mon("rattata"),mon("pikachu");local b=battle(p,e);e.hp=1;p.hp=1
        local chosen
        for v=1,10000 do local r=RulesRNG.new(v);r:random(1,100);r:random(1,16);r:random(85,100);if r:random(0,99)<30 then chosen=v;break end end
        assert(chosen);RulesRNG.seed(chosen);local text=act(b,"player","doubleEdge")
        eq(p.hp,0);eq(e.hp,0);eq(p.status,"paralyze");eq(b.outcome,"victory")
        local status=assert(text:find("is paralyzed",1,true));local recoil=assert(text:find("damaged by recoil",1,true));local faint=assert(text:find("fainted",1,true))
        assert(status<recoil and recoil<faint,"status/recoil/faint order: "..text)
    end)
    test("Tri Attack real secondary has all three sourced outcomes and immunity after both draws",function()
        local function choice(index)
            for v=1,100000 do local r=RulesRNG.new(v);if r:random(1,100)<=20 and r:random(1,3)==index then return v end end
            error("no Tri Attack fixture seed")
        end
        for i,status in ipairs({"burn","paralyze","freeze"}) do
            local p,e=mon("dugtrio"),mon("rattata");local b=battle(p,e);b:setDirection("player");RulesRNG.seed(choice(i));local before=RulesRNG.snapshot().rolls
            script(b,function() b:applyMoveSecondaries(moveData.triAttack) end);eq(e.status,status);eq(RulesRNG.snapshot().rolls-before,2)
        end
        local p,e=mon("dugtrio"),mon("charmander");local b=battle(p,e);b:setDirection("player");RulesRNG.seed(choice(1));local before=RulesRNG.snapshot().rolls
        script(b,function() b:applyMoveSecondaries(moveData.triAttack) end);eq(e.status,nil);eq(RulesRNG.snapshot().rolls-before,2)
        e.status="poison";RulesRNG.seed(choice(1));before=RulesRNG.snapshot().rolls
        script(b,function() b:applyMoveSecondaries(moveData.triAttack) end);eq(e.status,"poison");eq(RulesRNG.snapshot().rolls-before,2)
    end)
    test("Tri Attack Shield Dust suppresses chance and random-status draws",function()
        local p,e=mon("dugtrio"),mon("caterpie");local b=battle(p,e);b:setDirection("player");local before=RulesRNG.snapshot()
        script(b,function() b:applyMoveSecondaries(moveData.triAttack) end);eq(e.status,nil);unchanged(before)
    end)
    test("Sandstorm heal producer uses exact Q12 quarter versus half and SolarBeam sand power60",function()
        local p,e=mon("bulbasaur"),mon("caterpie");local b=battle(p,e);p.maxHP,p.hp=19,1
        act(b,"player","synthesis");eq(p.hp,10)
        p.hp=1;act(b,"player","sandstorm");act(b,"player","synthesis");eq(p.hp,6)
        eq(b.effects:basePower(moveData.solarBeam,120),60);eq(b.effects:basePower(moveData.razorLeaf,55),55)
    end)
    test("Actual BattleScene repeated draws never advance weather abilities HP or RNG",function()
        local p,e=mon("metapod"),mon("pikachu");local b=battle(p,e);p.status="poison";script(b,function() b.effects:setSandstorm() end)
        local scene=BattleScene(b);scene:enter();for _=1,21 do scene:update() end
        local before=RulesRNG.snapshot();local hp,ehp,timer=p.hp,e.hp,b.effects:snapshot().turns
        for _=1,20 do scene:draw() end
        unchanged(before);eq(p.hp,hp);eq(e.hp,ehp);eq(b.effects:snapshot().turns,timer);eq(p.status,"poison");scene:exit()
    end)
    test("Real controller learning suspension freezes weather before enemy replacement then resumes same script",function()
        local game=GameContext();local p=Pokemon("squirtle",6);assert(game:recruit(p));assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur",rivalOutcome=true}))
        p.xp=p:xpForLevel(7)-1
        local e=Pokemon("rattata",5);local reserve=Pokemon("rattata",5);local team=Party();assert(team:add(e));assert(team:add(reserve))
        game.machine:register("overworld",State("overworld"));game.machine:register("learning",LearningState(game));local owner=BattleState(game);game.machine:register("battle",owner)
        game.machine:change("battle",p,e,{name="ABILITY LEARNING",markInteracted=function() end},team)
        local b=owner.battle;settle(b);script(b,function() b.effects:setSandstorm() end);e.hp=0
        b:runScript(function() local result=b:handleFaint("enemy");if result=="replacement" then return b:finishRound() end;return result end)
        local n=0;while b:phase()=="script" and not b:getLearningSnapshot().pending do n=n+1;assert(n<100);b.machine:get("script"):advance() end
        assert(b:getLearningSnapshot().pending);local co=b.machine:get("script").co;local hp=p.hp;local before=RulesRNG.snapshot()
        assert(owner:openPendingLearning());local learning=game.machine:get("learning");eq(learning.phase,"message")
        for _=1,20 do game.machine:update();game.machine:draw() end
        unchanged(before);eq(b.enemy,e);eq(p.hp,hp);eq(b.effects:snapshot().turns,5);eq(b.machine:get("script").co,co)
        learning:handleInput();assert(learning.dialog.onComplete)();learning:handleInput();settle(b)
        eq(b.enemy,reserve);eq(b:phase(),"command");eq(b.effects:snapshot().turns,4);eq(p:hasMove("bubble"),true)
        game.machine:change("overworld")
    end)
    test("Sand damage immunities use types plus Sand Veil, not immunity to every residual",function()
        for _,species in ipairs({"geodude","onix","magneton","sandshrew"}) do
            local p,e=mon(species),mon("rattata");local b=battle(p,e);local hp=p.hp
            if species=="sandshrew" then p.type,p.type2="water",nil end -- separate ability immunity from Ground immunity
            script(b,function() b.effects:setSandstorm();b:endOfRoundStatus() end);eq(p.hp,hp,species)
        end
    end)
    test("Weather residual precedes Shed Skin and status, and cured poison cannot damage again",function()
        local p,e=mon("metapod"),mon("rattata");local b=battle(p,e);p.status="poison";RulesRNG.seed(seed(0,99,32))
        local hp=p.hp;local text=script(b,function() b.effects:setSandstorm();b:endOfRoundStatus() end)
        eq(hp-p.hp,p.maxHP//16);eq(p.status,nil)
        assert(assert(text:find("buffeted",1,true))<assert(text:find("Shed Skin",1,true)),text)
        assert(not text:find("hurt by poison",1,true),text)
    end)
    test("Sandstorm resolves both faints as one cohort, last-fainted side wins and fainted gets no XP",function()
        for _,row in ipairs({{10,20,"victory"},{20,10,"defeat"}}) do
            local p,e=mon("pidgey"),mon("rattata");local b=battle(p,e);p.hp,e.hp=1,1;p.spe,e.spe=row[1],row[2];local xp=p.xp
            script(b,function() b.effects:setSandstorm() end)
            script(b,function() return b:endOfRoundStatus() end)
            eq(p.hp,0);eq(e.hp,0);eq(b.outcome,row[3]);eq(p.xp,xp)
        end
    end)
    RulesRNG.restore(saved);return report
end
