-- Real SDK/production classes. Controlled move ownership/stats isolate literal rules vectors.
EarlyCombatContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function own(mon,keys,pp)
    mon.moves,mon.pp={},{}
    for i,key in ipairs(keys) do mon.moves[i]=key;mon.pp[key]=pp or moveData[key].maxPP end
end
local function settle(b)
    local lines={}
    for _=1,400 do
        if b:phase()~="script" then return table.concat(lines,"|") end
        lines[#lines+1]=b.message;b.machine:get("script"):advance()
    end
    error("script exceeded400 messages")
end
local function fresh(p,e,party)
    p=p or Pokemon("onix",14);e=e or Pokemon("magikarp",100)
    own(e,{"splash"})
    local b=Battle(p,e,nil,party and {party=party} or nil);settle(b);return b
end
local function one(b,side,key,continuation)
    local mon=b[side]
    if not mon:hasMove(key) then own(mon,{key}) end
    b:runScript(function() return b:resolveTurn({side=side,key=key,move=moveData[key],continuation=continuation}) end)
    return settle(b)
end
local function round(b) b:runScript(function() return b:finishRound() end);return settle(b) end
local function partyBattle()
    local p=Pokemon("sandshrew",100);local reserve=Pokemon("charmander",12)
    local party=Party();assert(party:add(p));assert(party:add(reserve));own(p,{"rollout","splash"})
    return fresh(p,nil,party),reserve
end
function EarlyCombatContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Generated String Shot lowers exactly one stage and never damages",function()
        local b=fresh();local hp=b.enemy.hp;RulesRNG.seed(2);one(b,"player","stringShot")
        eq(b.enemy.statStages.spe,-1);eq(b.enemy.hp,hp);eq(b.player.pp.stringShot,39)
    end)
    test("Non-Ghost Curse is a self target with Speed-1 Attack+1 Defense+1",function()
        local b=fresh();local hp=b.player.hp;local rolls=RulesRNG.snapshot().rolls
        one(b,"player","curse");eq(b.player.statStages.spe,-1);eq(b.player.statStages.atk,1);eq(b.player.statStages.def,1)
        eq(b.player.hp,hp);eq(b.player.pp.curse,9);eq(b.enemy.statStages.atk,0);eq(RulesRNG.snapshot().rolls,rolls)
        b.enemy.hp=0;b:setDirection("player");eq(b:moveHasTarget(moveData.curse),true)
    end)
    test("Ghost Curse pays half max HP once, duplicate fails, residual quarter and switch clears",function()
        local b=fresh(Pokemon("gastly",20));local before=b.player.hp
        one(b,"player","curse");eq(b.player.hp,before-before//2);eq(b:getConditionsSnapshot().enemy.cursed,true)
        local after=b.player.hp;one(b,"player","curse");eq(b.player.hp,after,"duplicate curse cost")
        local hp=b.enemy.hp;round(b);eq(b.enemy.hp,hp-b.enemy.maxHP//4)
        b.conditions:clear(b.enemy);eq(b:getConditionsSnapshot().enemy.cursed,false)
    end)
    test("Ghost Curse may faint its user; no accidental victory or XP",function()
        local b=fresh(Pokemon("gastly",20));b.player.hp=1;local xp=b.player.xp
        one(b,"player","curse");eq(b.player.hp,0);eq(b.outcome,"defeat");eq(b.player.xp,xp)
    end)
    test("Mud Sport Q12 power and independent damage vector, both sides and withdrawal",function()
        local b=fresh(Pokemon("rattata",100),Pokemon("snorlax",100));b.player.spa=100;b.enemy.spd=100
        one(b,"player","mudSport");eq(b.conditions:basePower(b.player,moveData.thunderbolt),31)
        RulesRNG.seed(2);local result=calcDamage(b.player,b.enemy,moveData.thunderbolt,b.conditions:basePower(b.player,moveData.thunderbolt));eq(result.damage,24)
        local pp=b.player.pp.mudSport;one(b,"player","mudSport");eq(b.player.pp.mudSport,pp-1);eq(b:getConditionsSnapshot().player.mud_sport,true)
        one(b,"enemy","mudSport");eq(b.conditions:basePower(b.player,moveData.thunderbolt),10)
        b.conditions:clear(b.player);eq(b.conditions:basePower(b.player,moveData.thunderbolt),31)
        b.conditions:clear(b.enemy);eq(b.conditions:basePower(b.player,moveData.thunderbolt),95)
    end)
    test("Rage boosts per damaging hit, caps6 and ends before blocked next attempt",function()
        local b=fresh(Pokemon("onix",100));RulesRNG.seed(2);one(b,"player","rage");eq(b:getConditionsSnapshot().player.rage,true)
        RulesRNG.seed(2);one(b,"enemy","doubleSlap");eq(b.player.statStages.atk,2,"two-hit Rage boosts")
        b.player.statStages.atk=5;RulesRNG.seed(2);one(b,"enemy","doubleSlap");eq(b.player.statStages.atk,6)
        b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1
        one(b,"player","rage");eq(b:getConditionsSnapshot().player.rage,false);eq(b.player.statStages.atk,6)
    end)
    test("Rage ignores status/residual damage but fixed damaging moves trigger it",function()
        local b=fresh(Pokemon("onix",100));RulesRNG.seed(2);one(b,"player","rage")
        one(b,"enemy","growl");eq(b.player.statStages.atk,-1)
        b.player.status="poison";round(b);eq(b.player.statStages.atk,-1)
        RulesRNG.seed(2);one(b,"enemy","dragonRage");eq(b.player.statStages.atk,0)
    end)
    test("Rollout literal five-hit power/damage sequence consumes only initial PP",function()
        local b=fresh(Pokemon("sandshrew",100),Pokemon("snorlax",100));b.player.atk=100;b.enemy.def=100;own(b.player,{"rollout"},1)
        local expected={23,45,88,176,352}
        for i,n in ipairs(expected) do
            b.enemy:heal();RulesRNG.seed(2);one(b,"player","rollout",i>1)
            eq(b.lastDamage,n,"Rollout hit"..i);eq(b.player.pp.rollout,0,"locked PP")
            eq(b:getConditionsSnapshot().player.rollout_hits,i==5 and 0 or i)
        end
    end)
    test("Defense Curl doubles Rollout power and is removed on actual withdrawal",function()
        local b,reserve=partyBattle();one(b,"player","defenseCurl");eq(b.conditions:basePower(b.player,moveData.rollout),60)
        own(b.player,{"rollout","splash"});assert(b:chooseParty(2));settle(b)
        eq(b.player,reserve);eq(b:getConditionsSnapshot().player.defense_curl,false)
        assert(b:chooseParty(1));settle(b);eq(b.conditions:basePower(b.player,moveData.rollout),30)
    end)
    test("Rollout public lock rejects alternate move/run/bag/switch without RNG; update forces continuation",function()
        local b=partyBattle();own(b.player,{"rollout","splash"},1);RulesRNG.seed(2);one(b,"player","rollout")
        local before=RulesRNG.snapshot();eq(b:selectMove(2),false);eq(b:tryRun(),false);eq(b:beginSelection("party"),false);eq(b:chooseParty(2),false)
        eq(RulesRNG.snapshot().state,before.state);eq(RulesRNG.snapshot().rolls,before.rolls)
        b:update();eq(b:phase(),"script");settle(b);eq(b.player.pp.rollout,0)
        assert(b:getConditionsSnapshot().player.rollout_hits==2 or b:getConditionsSnapshot().player.rollout_hits==0,"continuation must hit or miss")
    end)
    test("Rollout miss and absent target release lock after PP timing",function()
        local b=fresh(Pokemon("sandshrew",100));own(b.player,{"rollout"});RulesRNG.seed(2);one(b,"player","rollout")
        local pp=b.player.pp.rollout;RulesRNG.seed(42);one(b,"player","rollout",true);eq(b.conditions:locked(b.player),nil);eq(b.player.pp.rollout,pp)
        RulesRNG.seed(2);one(b,"player","rollout");b.enemy.hp=0
        local rolls=RulesRNG.snapshot().rolls;one(b,"player","rollout",true);eq(b.conditions:locked(b.player),nil);eq(RulesRNG.snapshot().rolls,rolls)
    end)
    test("Sleep freeze flinch paralysis and confusion self-hit interrupt Rollout without extra PP",function()
        for _,gate in ipairs({"sleep","freeze","flinch","paralyze","confusion"}) do
            local b=fresh(Pokemon("sandshrew",100));own(b.player,{"rollout"});RulesRNG.seed(2);one(b,"player","rollout")
            local pp=b.player.pp.rollout
            if gate=="flinch" then b.player.flinched=true
            elseif gate=="confusion" then b.player.confusion=2
            else b.player.status=gate;if gate=="sleep" then b.player.statusTurns,b.player.sleepDuration=1,1 end end
            RulesRNG.seed(gate=="paralyze" and 3 or (gate=="confusion" and 1 or 2));one(b,"player","rollout",true)
            eq(b.conditions:locked(b.player),nil,gate);eq(b.player.pp.rollout,pp,gate.." PP")
        end
    end)
    test("Leech Seed producer drains actual HP to current source-side receiver and Grass immunity",function()
        local b=fresh(Pokemon("bulbasaur",20));b.player.hp=b.player.hp-10;RulesRNG.seed(2);one(b,"player","leechSeed")
        local p,e=b.player.hp,b.enemy.hp;round(b);local amount=b.enemy.maxHP//8
        eq(b.enemy.hp,e-amount);eq(b.player.hp,math.min(b.player.maxHP,p+amount))
        local c=fresh(Pokemon("bulbasaur",20),Pokemon("bulbasaur",20));RulesRNG.seed(2);one(c,"player","leechSeed");eq(c:getConditionsSnapshot().enemy.seeded,false)
    end)
    test("Real binding trap blocks withdrawal/run, lasts4-5 residuals, ends with source withdrawal",function()
        local b=partyBattle();RulesRNG.seed(2);one(b,"enemy","bind");eq(b:getConditionsSnapshot().player.trapped,true)
        eq(b:chooseParty(2),false);eq(b:tryRun(),false)
        local turns=b:getConditionsSnapshot().player.trap_turns;assert(turns==4 or turns==5)
        local hp=b.player.hp;round(b);eq(b.player.hp,hp-b.player.maxHP//16)
        b.conditions:clear(b.enemy);eq(b:getConditionsSnapshot().player.trapped,false)
    end)
    test("Rapid Spin removes real seed trap and all own hazards without Speed boost",function()
        local b=fresh(Pokemon("sandshrew",100));RulesRNG.seed(2);one(b,"enemy","leechSeed");RulesRNG.seed(2);one(b,"enemy","bind")
        for _,key in ipairs({"spikes","toxicSpikes","stealthRock"}) do one(b,"enemy",key) end
        eq(b:getConditionsSnapshot().player.seeded,true);eq(b:getConditionsSnapshot().player.trapped,true)
        eq(b:getConditionsSnapshot().sides.player.spikes,1)
        RulesRNG.seed(2);one(b,"player","rapidSpin");local s=b:getConditionsSnapshot()
        eq(s.player.seeded,false);eq(s.player.trapped,false);eq(s.sides.player.spikes,0);eq(s.sides.player.toxic_spikes,0);eq(s.sides.player.stealth_rock,0);eq(b.player.statStages.spe,0)
    end)
    test("Rapid Spin miss/immunity consumes PP but preserves obstacles",function()
        local b=fresh(Pokemon("sandshrew",100),Pokemon("gastly",100));one(b,"enemy","spikes")
        local pp;own(b.player,{"rapidSpin"});pp=b.player.pp.rapidSpin;RulesRNG.seed(2);one(b,"player","rapidSpin")
        eq(b.player.pp.rapidSpin,pp-1);eq(b:getConditionsSnapshot().sides.player.spikes,1)
        b.enemy.type,b.enemy.type2="normal",nil;b.player.statStages.acc=-6;RulesRNG.seed(42);one(b,"player","rapidSpin")
        eq(b:getConditionsSnapshot().sides.player.spikes,1)
    end)
    test("Spikes layers and Rock effectiveness apply on actual party entry; Flying avoids ground hazards",function()
        local b,reserve=partyBattle();for _=1,3 do one(b,"enemy","spikes") end;one(b,"enemy","stealthRock")
        local hp=reserve.hp;assert(b:chooseParty(2));settle(b)
        -- Charmander31HP loses floor31/4=7 Spikes + floor31*2/8=7 Rocks; enemy Splash harmless.
        eq(reserve.hp,hp-14);eq(b:getConditionsSnapshot().sides.player.spikes,3)
        local flying=Pokemon("pidgey",12);b:runScript(function() b.conditions:entry(flying,"player") end);settle(b)
        eq(flying.hp,flying.maxHP-math.floor(flying.maxHP*2/8))
    end)
    test("Two Toxic Spikes layers cause durable bad poison; Poison absorbs and Steel/Flying avoid",function()
        local b,reserve=partyBattle();one(b,"enemy","toxicSpikes");one(b,"enemy","toxicSpikes")
        assert(b:chooseParty(2));settle(b);eq(reserve.status,"badPoison");eq(reserve.statusTurns,0)
        for _,species in ipairs({"magnemite","pidgey"}) do local m=Pokemon(species,12);b:runScript(function() b.conditions:entry(m,"player") end);settle(b);eq(m.status,nil) end
        local poison=Pokemon("nidoranF",12);b:runScript(function() b.conditions:entry(poison,"player") end);settle(b);eq(b:getConditionsSnapshot().sides.player.toxic_spikes,0)
    end)
    test("Toxic residual independent31HP vector1/2/3, counter reset on switch and faint cleanup",function()
        local p=Pokemon("charmander",12);eq(p.maxHP,31);local reserve=Pokemon("squirtle",12);local party=Party();assert(party:add(p));assert(party:add(reserve))
        local b=fresh(p,nil,party);RulesRNG.seed(2);one(b,"enemy","toxic");eq(p.status,"badPoison")
        round(b);eq(p.hp,30);round(b);eq(p.hp,28);round(b);eq(p.hp,25)
        assert(b:chooseParty(2));settle(b);assert(b:chooseParty(1));settle(b);eq(p.hp,24);eq(b:getConditionsSnapshot().player.toxic_counter,1)
        p.hp=1;round(b);eq(p.hp,0);eq(b:phase(),"forcedSwitch");eq(b:getConditionsSnapshot().player.toxic_counter,0)
    end)
    test("Bad poison codec/JSON roundtrip and Antidote/Full Heal clear status/counters without changing schema",function()
        local mon=Pokemon("charmander",12);mon.status="badPoison"
        local data=assert(PokemonCodec.encode(mon));eq(data.version,5)
        local copy=assert(PokemonCodec.decode(json.decode(json.encode(data))));eq(copy.status,"badPoison");eq(copy.statusTurns,0);eq(copy.sleepDuration,0)
        for _,id in ipairs({"antidote","fullHeal"}) do
            copy.status="badPoison";local bag=Inventory(ItemData.definitions);assert(bag:add(id,1));assert(Items.use(bag,id,copy));eq(copy.status,nil);eq(copy.statusTurns,0);eq(copy.sleepDuration,0);eq(bag:quantity(id),0)
        end
    end)
    test("Actual battle Antidote cure clears visible toxic counter and reapplication starts at1",function()
        local b=fresh(Pokemon("charmander",12));RulesRNG.seed(2);one(b,"enemy","toxic");round(b);round(b)
        eq(b.player.hp,28);eq(b:getConditionsSnapshot().player.toxic_counter,2)
        local bag=Inventory(ItemData.definitions);assert(bag:add("antidote",1));assert(Items.use(bag,"antidote",b.player))
        eq(b:getConditionsSnapshot().player.toxic_counter,0);eq(b.player.status,nil)
        RulesRNG.seed(2);one(b,"enemy","toxic");round(b);eq(b.player.hp,27);eq(b:getConditionsSnapshot().player.toxic_counter,1)
        local bad=assert(Capture.parameters({pokemon=b.player,wild=true},"pokeBall",0))
        b.player.status="poison";local regular=assert(Capture.parameters({pokemon=b.player,wild=true},"pokeBall",0))
        eq(bad.modifiedRate4096,regular.modifiedRate4096,"same GenV1.5 capture bonus")
    end)
    test("Residual order Seed8 Poison9 Burn10 Curse12 Binding13 and terminal cleanup",function()
        local b=fresh(Pokemon("gastly",100),Pokemon("snorlax",100));b.enemy.status="poison"
        RulesRNG.seed(2);one(b,"player","leechSeed");one(b,"player","curse");RulesRNG.seed(2);one(b,"player","bind")
        local text=round(b);local seed=text:find("Leech Seed",1,true);local poison=text:find("hurt by poison",1,true);local curse=text:find("afflicted by the curse",1,true);local trap=text:find("binding",1,true)
        assert(seed and poison and curse and trap and seed<poison and poison<curse and curse<trap,text)
        b:clearVolatiles();eq(next(b.conditions.members),nil);eq(next(b.conditions.sides.player),nil)
        eq(b.enemy.status,"poison","exit keeps major status")
    end)
    test("Normal run emits once then clears all transient conditions; status persists",function()
        local b=fresh(Pokemon("rattata",100),Pokemon("magikarp",5));one(b,"player","mudSport");b.player.status="badPoison"
        local called=0;b:on("battleEnd",function() called=called+1 end);RulesRNG.seed(2);assert(b:tryRun());settle(b)
        eq(b.outcome,"run");eq(called,1);eq(next(b.conditions.members),nil);eq(b.player.status,"badPoison");eq(b:emitEnd(),false)
    end)
    RulesRNG.restore(saved);return report
end
