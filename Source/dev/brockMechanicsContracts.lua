-- Pallet-Brock fixes through actual production domain/controller/SDK classes.
BrockMechanicsContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function sameRNG(before)local now=RulesRNG.snapshot();eq(now.state,before.state,"RNG state");eq(now.rolls,before.rolls,"RNG rolls")end
local function settle(b)
    local n=0;local text={}
    while b:phase()=="script" do n=n+1;assert(n<400,"script stuck: "..b.message);assert(not b.pendingLearning,"unexpected learning receipt");text[#text+1]=b.message;b.machine:get("script"):advance()end
    return table.concat(text,"|")
end
local function own(p,keys)p.moves={};p.pp={};for i,key in ipairs(keys)do p.moves[i]=key;p.pp[key]=moveData[key].pp end end
local function direct(b,key,side)
    local p=side=="enemy" and b.enemy or b.player;own(p,{key})
    b:runScript(function()return b:resolveTurn({side=side or "player",actor=b[side or "player"],key=key,move=moveData[key]})end);return settle(b)
end
local function fresh(p,e)local b=Battle(p or Pokemon("rattata",7),e or Pokemon("rattata",100));settle(b);return b end
local function seed(low,high,value)for i=1,100000 do if RulesRNG.new(i):random(low,high)==value then return i end end;error("no bounded seed")end
local function session()
    local s=GameSession.newSession(SessionContracts.dependencies(),{location={zone_id="reds_house_2f",x=5,y=3,facing="up"},seed=42,
        checkpoint={zone_id="reds_house",x=3,y=7,facing="up"}})
    local p=Pokemon("charmander",100);assert(s:recruit(p));assert(s:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}));return s,p
end
local function team()
    local t=Party();local all={Pokemon("pidgey",5),Pokemon("geodude",5),Pokemon("onix",5)}
    for _,p in ipairs(all)do assert(t:add(p))end;return t,all
end
local function selected(p,key)for i,k in ipairs(p.moves)do if k==key then return i end end;error("required real move missing "..key)end
function BrockMechanicsContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot();local priorOwner=GameSession.activeRNGSession();local contexts={}
    local function test(name,fn)
        Autopilot.resetControls();local ok,why=pcall(fn);Autopilot.resetControls();report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Trainer initial and replacement discovery occurs on entry, never bench creation",function()
        local s,p=session();local t,all=team();local calls={};local mark=s.markSeen
        s.markSeen=function(owner,species)local before=RulesRNG.snapshot();local result=mark(owner,species);sameRNG(before);calls[#calls+1]=species;return result end
        local b=Battle(p,all[1],"DEX TEST",{session=s,party=s:party(),enemyParty=t})
        eq(b.message,"DEX TEST wants to battle!");eq(s:pokedex().seen.pidgey,nil);eq(s:pokedex().seen.geodude,nil);eq(s:pokedex().seen.onix,nil);eq(#calls,0)
        b.machine:get("script"):advance();eq(s:pokedex().seen.pidgey,true);eq(#calls,1);settle(b)
        assert(b:selectMove(selected(p,"flamethrower")));settle(b);eq(b.enemy,all[2]);eq(s:pokedex().seen.geodude,true);eq(s:pokedex().seen.onix,nil);eq(#calls,2)
        for _=1,20 do b:update()end;eq(#calls,2)
        assert(b:selectMove(selected(p,"flamethrower")));settle(b);eq(b.enemy,all[3]);eq(s:pokedex().seen.onix,true);eq(#calls,3)
        eq(s:pokedex().owned.pidgey,nil);eq(s:pokedex().owned.geodude,nil);eq(s:pokedex().owned.onix,nil)
    end)
    test("BattleState controller does not duplicate initial discovery and forced exit leaves bench unknown",function()
        local g=GameContext();contexts[#contexts+1]=g;local p=Pokemon("charmander",100);assert(g:recruit(p));assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
        local t,all=team();local count=0;local original=g.session.markSeen
        g.session.markSeen=function(s,species)count=count+1;return original(s,species)end
        g.machine:register("overworld",State("overworld"));local owner=BattleState(g);g.machine:register("battle",owner)
        g.machine:change("battle",p,all[1],{name="DEX TEST",markInteracted=function()end},t)
        eq(count,0);settle(owner.battle);eq(count,1);eq(g.session:pokedex().seen.pidgey,true);eq(g.session:pokedex().seen.geodude,nil)
        g.machine:change("overworld");eq(g.session:pokedex().seen.geodude,nil);eq(g.session:pokedex().seen.onix,nil);eq(count,1)
    end)
    test("Wild entry marks seen once and optional session-free Battle remains compatible",function()
        local s,p=session();local before=RulesRNG.snapshot();local b=Battle(p,Pokemon("pikachu",5),nil,{session=s,party=s:party()})
        eq(s:pokedex().seen.pikachu,true);sameRNG(before);settle(b)
        local plain=Battle(Pokemon("charmander",5),Pokemon("pidgey",5));settle(plain);eq(plain:phase(),"command")
    end)
    test("Entered replacements survive actual SessionCodec JSON roundtrip without owning benches",function()
        local s,p=session();local t,all=team();local b=Battle(p,all[1],"DEX TEST",{session=s,party=s:party(),enemyParty=t});settle(b)
        assert(b:selectMove(selected(p,"flamethrower")));settle(b);b:clearVolatiles()
        local record=assert(SessionCodec.encode(s,{root="overworld",overworld="explore",settled=true}));local text=json.encode(record);local parsed=json.decode(text)
        local restored,why=SessionCodec.decode(parsed,SessionContracts.dependencies());assert(restored,why)
        eq(restored:pokedex().seen.pidgey,true);eq(restored:pokedex().seen.geodude,true);eq(restored:pokedex().seen.onix,nil);eq(restored:pokedex().owned.geodude,nil)
        eq(restored:party():count(),1);eq(restored:party():active().species,"charmander")
    end)
    test("Rattata level7 natural initializer exposes real FocusEnergy producer",function()
        local p=Pokemon("rattata",7);eq(p.moves[4],"focusEnergy");eq(moveData.focusEnergy.pp,30);eq(moveData.focusEnergy.accuracy,0)
        local b=fresh(p);local before=RulesRNG.snapshot();direct(b,"focusEnergy");eq(p.pp.focusEnergy,29);eq(b:getConditionsSnapshot().player.focus_energy,true);eq(b.effects:criticalStage(p,moveData.tackle),2);sameRNG(before)
    end)
    test("FocusEnergy repeat fails without stacking, spends attempt PP and consumes no RNG",function()
        local b=fresh();local p=b.player;own(p,{"focusEnergy"});local before=RulesRNG.snapshot()
        b:runScript(function()return b:resolveTurn({side="player",actor=b.player,key="focusEnergy",move=moveData.focusEnergy})end);settle(b)
        b:runScript(function()return b:resolveTurn({side="player",actor=b.player,key="focusEnergy",move=moveData.focusEnergy})end);local text=settle(b)
        eq(p.pp.focusEnergy,28);eq(b.effects:criticalStage(p,moveData.tackle),2);assert(text:find("But it failed!",1,true));sameRNG(before)
    end)
    test("Gen5 critical family has literal denominators16,8,4,3,2 and clamps higher stages",function()
        local expected={16,8,4,3,2}
        for stage=0,4 do eq(BattleEffects.criticalDenominator(stage),expected[stage+1],"stage"..stage)end
        eq(BattleEffects.criticalDenominator(9),2);eq(BattleEffects.criticalDenominator(-1),16)
    end)
    test("All16 generated high-critical moves add one; forcedcrit is never a stage6 clamp",function()
        local expected={karateChop=true,razorWind=true,razorLeaf=true,skyAttack=true,crabhammer=true,slash=true,crossChop=true,blazeKick=true,airCutter=true,leafBlade=true,nightSlash=true,shadowClaw=true,psychoCut=true,crossPoison=true,stoneEdge=true,drillRun=true};local count=0
        for key,m in pairs(moveData)do eq(m.critStage,expected[key] and 1 or 0,key);if m.critStage>0 then count=count+1 end end
        eq(count,16);eq(moveData.stormThrow.willCrit,true);eq(moveData.stormThrow.critStage,0)
    end)
    test("Focus plus highcrit is stage3 one-third, not modern guaranteed or half critical",function()
        local b=fresh(Pokemon("rattata",100));local p,e=b.player,b.enemy;direct(b,"focusEnergy");eq(b.effects:criticalStage(p,moveData.slash),3)
        RulesRNG.seed(1);eq(calcDamage(p,e,moveData.slash,nil,b.effects).isCrit,true)
        RulesRNG.seed(1);eq(calcDamage(p,e,moveData.tackle,nil,b.effects).isCrit,false)
        b.conditions:clear(p);RulesRNG.seed(1);eq(calcDamage(p,e,moveData.slash,nil,b.effects).isCrit,false)
    end)
    test("Each critical stage passes and fails literal roll endpoints through actual damage",function()
        local p,e=Pokemon("rattata",100),Pokemon("pidgey",100)
        for stage,denom in ipairs({16,8,4,3,2})do
            local move=Move{name="CRIT VECTOR",type="normal",category="physical",power=40,accuracy=100,pp=10,critStage=stage-1}
            RulesRNG.seed(seed(1,denom,1));eq(calcDamage(p,e,move).isCrit,true,"stage"..(stage-1).." success")
            RulesRNG.seed(seed(1,denom,denom));eq(calcDamage(p,e,move).isCrit,false,"stage"..(stage-1).." failure")
        end
    end)
    test("Forced critical bypasses critical RNG and fixed damage cannot crit with Focus",function()
        local b=fresh(Pokemon("rattata",100));direct(b,"focusEnergy");RulesRNG.seed(1);local before=RulesRNG.snapshot().rolls
        local result=calcDamage(b.player,b.enemy,moveData.stormThrow,nil,b.effects);eq(result.isCrit,true);eq(RulesRNG.snapshot().rolls-before,1)
        RulesRNG.seed(1);before=RulesRNG.snapshot().rolls;direct(b,"dragonRage");eq(RulesRNG.snapshot().rolls-before,1);eq(b.lastDamage,40)
    end)
    test("Critical query and repeated BattleScene draws cannot allocate state or advance RNG",function()
        local b=fresh();local p=b.player;eq(b.conditions.members[p],nil);local before=RulesRNG.snapshot()
        for _=1,30 do eq(b.effects:criticalStage(p,moveData.slash),1)end;eq(b.conditions.members[p],nil);sameRNG(before)
        direct(b,"focusEnergy");local scene=BattleScene(b);scene:enter();for _=1,21 do scene:update()end
        before=RulesRNG.snapshot();local pp=p.pp.focusEnergy;for _=1,20 do scene:draw()end
        eq(b.effects:criticalStage(p,moveData.tackle),2);eq(p.pp.focusEnergy,pp);sameRNG(before);scene:exit()
    end)
    test("Sleep/flinch interruptions preserve Focus but consume no move PP",function()
        local b=fresh();direct(b,"focusEnergy");local p=b.player;own(p,{"tackle"});p.status,p.statusTurns,p.sleepDuration="sleep",1,1;local before=RulesRNG.snapshot()
        b:runScript(function()return b:resolveTurn({side="player",actor=b.player,key="tackle",move=moveData.tackle})end);settle(b)
        eq(p.pp.tackle,moveData.tackle.pp);eq(b.effects:criticalStage(p,moveData.tackle),2);sameRNG(before)
        p.status,p.statusTurns,p.sleepDuration=nil,0,0;p.flinched=true
        b:runScript(function()return b:resolveTurn({side="player",actor=b.player,key="tackle",move=moveData.tackle})end);settle(b);eq(p.pp.tackle,moveData.tackle.pp);eq(b.effects:criticalStage(p,moveData.tackle),2);sameRNG(before)
    end)
    test("Voluntary switch clears only outgoing Focus and no switching-back restoration",function()
        local p,q=Pokemon("rattata",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("metapod",5)
        local b=Battle(p,e,nil,{party=party});settle(b);direct(b,"focusEnergy");assert(b:chooseParty(2));settle(b);eq(b.effects:criticalStage(p,moveData.tackle),0)
        assert(b:chooseParty(1));settle(b);eq(b.player,p);eq(b.effects:criticalStage(p,moveData.tackle),0)
    end)
    test("Faint, forced exit, new battle and codec cannot carry Focus volatile",function()
        local p=Pokemon("rattata",100);local b=fresh(p);direct(b,"focusEnergy");local record=assert(PokemonCodec.encode(p));eq(record.focusEnergy,nil)
        p.hp=0;b:runScript(function()b:setDirection("enemy");return b:handleFaint("player")end);settle(b);eq(b.effects:criticalStage(p,moveData.tackle),0)
        p:fullRestore();b=fresh(p);direct(b,"focusEnergy");b:clearVolatiles();eq(b.effects:criticalStage(p,moveData.tackle),0)
        b=fresh(p);eq(b:getConditionsSnapshot().player.focus_energy,false)
    end)
    test("Pure ordinary accuracy observer shares stages ability rounding and clamps without RNG",function()
        local p,e=Pokemon("butterfree",100),Pokemon("sandshrew",100);local b=fresh(p,e);local before=RulesRNG.snapshot()
        eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),98);p.statStages.acc=-1;eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),73)
        b:runScript(function()b.effects:setSandstorm()end);settle(b);eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),58)
        p.statStages.acc,e.statStages.eva=6,-6;eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),100)
        p.statStages.acc,e.statStages.eva=-6,6;eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),26)
        eq(accuracyThreshold(moveData.swift,p,e,b.effects),100);local threshold,kind=accuracyThreshold(moveData.fissure,p,e,b.effects);eq(threshold,nil);eq(kind,"ohko")
        sameRNG(before)
    end)
    test("Always-hit accuracy observer100 never rolls but ordinary100 still samples",function()
        local b=fresh();local p,e=b.player,b.enemy;local before=RulesRNG.snapshot()
        eq(accuracyThreshold(moveData.swift,p,e,b.effects),100);eq(checkAccuracy(moveData.swift,p,e,b.effects),true);sameRNG(before)
        eq(accuracyThreshold(moveData.tackle,p,e,b.effects),100);eq(checkAccuracy(moveData.tackle,p,e,b.effects),true);eq(RulesRNG.snapshot().rolls-before.rolls,1)
    end)
    test("Actual accuracy roll boundaries use the shared73 threshold rather than duplicate math",function()
        local p,e=Pokemon("butterfree",100),Pokemon("rattata",100);local b=fresh(p,e);p.statStages.acc=-1
        eq(accuracyThreshold(moveData.sleepPowder,p,e,b.effects),73)
        RulesRNG.seed(seed(1,100,73));eq(checkAccuracy(moveData.sleepPowder,p,e,b.effects),true)
        RulesRNG.seed(seed(1,100,74));eq(checkAccuracy(moveData.sleepPowder,p,e,b.effects),false)
    end)
    test("Actual enemy KO clears Focus before forced party replacement",function()
        local p,q=Pokemon("rattata",7),Pokemon("pidgey",7);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("rattata",100)
        local b=Battle(p,e,nil,{party=party});settle(b);direct(b,"focusEnergy");own(e,{"tackle"})
        b:runScript(function()local result=b:resolveTurn({side="enemy",actor=b.enemy,key="tackle",move=moveData.tackle});if result=="replacement"then return b:finishRound()end;return result end);settle(b)
        eq(p.hp,0);eq(b:phase(),"forcedSwitch");eq(b.effects:criticalStage(p,moveData.tackle),0)
        local before=RulesRNG.snapshot();eq(b:chooseParty(99),false);sameRNG(before);assert(b:chooseParty(2));settle(b);eq(b.player,q);eq(b.effects:criticalStage(q,moveData.tackle),0)
    end)
    for _,g in ipairs(contexts)do pcall(function()g.machine:change("overworld")end)end
    local currentOwner=GameSession.activeRNGSession();if currentOwner and currentOwner~=priorOwner then assert(currentOwner:deactivateRNG())end
    if priorOwner then assert(priorOwner:activateRNG())end
    RulesRNG.restore(saved);return report
end
