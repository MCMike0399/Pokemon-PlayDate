-- Source condition checkpoint regressions; raw diagnostic expectations retained.
ConditionCheckpointContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function cp(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=cp(x)end;return out end
local function same(a,b)eq(type(a),type(b));if type(a)~="table"then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function own(p,moves)p.moves,p.pp={},{};for i,key in ipairs(moves)do p.moves[i]=key;p.pp[key]=moveData[key].maxPP end end
local function settle(b,learning)
    local n=0
    while b:phase()=="script"do
        n=n+1;assert(n<300,"condition checkpoint script timeout")
        if b:getLearningSnapshot().pending then
            if not learning then return end
            local request,mon=b:takeLearningRequest();assert(request)
            while #mon:getPendingMoveChoices()>0 do assert(mon:resolveMoveChoice(mon:getPendingMoveChoices()[1].id,"decline"))end
            assert(b:resumeLearning(request))
        else assert(b.machine:get("script"):advance())end
    end
end
local function setup(p,e,q,z)
    local party,foes=Party(),Party();assert(party:add(p));assert(foes:add(e));if q then assert(party:add(q))end;if z then assert(foes:add(z))end
    own(e,{"growl"});if z then own(z,{"growl"})end
    for _,mon in ipairs(party:members())do assert(PokemonCodec.encode(mon))end
    for _,mon in ipairs(foes:members())do assert(PokemonCodec.encode(mon))end
    local b=Battle(p,e,"CONDITION CHECKPOINT",{party=party,enemyParty=foes});settle(b);return b,party,foes
end
local function round(b,learning)
    for _,mon in ipairs(b.party:members())do assert(PokemonCodec.encode(mon))end
    for _,mon in ipairs(b.enemyParty:members())do assert(PokemonCodec.encode(mon))end
    b:runScript(function()return b:finishRound()end);settle(b,learning)
end
local function learn(b)
    local request,mon=b:takeLearningRequest();assert(request)
    while #mon:getPendingMoveChoices()>0 do assert(mon:resolveMoveChoice(mon:getPendingMoveChoices()[1].id,"learn"))end
    assert(b:resumeLearning(request));return mon
end
function ConditionCheckpointContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}}
 local function test(name,fn)
    local before=RulesRNG.snapshot();local ok,why=pcall(fn);RulesRNG.restore(before)
    report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("enemy poison waits through later player burn when both teams retain reserves",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",5);p.xp=p:xpForLevel(7)-1
    local e,z=Pokemon("pidgey",6),Pokemon("rattata",5);local b=setup(p,e,q,z);p.hp,e.hp,p.status,e.status=1,1,"burn","poison"
    local xp=p.xp;round(b,true);eq(p.hp,0);eq(p.level,6);eq(p.xp,xp);same(p.evs,IndividualStats.zero());eq(b:phase(),"forcedSwitch");eq(b.enemy,z);eq(b:getRewardSnapshot().latest.eligible,0);b:clearVolatiles()
 end)
 test("terminal matchup breaks BETWEEN cohorts before later burn without blanket deferral",function()
    local p,e=Pokemon("squirtle",6),Pokemon("pidgey",6);p.xp=p:xpForLevel(7)-1;local b=setup(p,e);p.hp,e.hp,p.status,e.status=1,1,"burn","poison"
    round(b,true);eq(e.hp,0);eq(p.hp,5);eq(p.level,8);eq(p.xp,326);eq(p.evs.spe,1);eq(b.outcome,"victory");b:clearVolatiles()
    p,e=Pokemon("squirtle",6),Pokemon("pidgey",6);b=setup(p,e);p.hp,e.hp,p.status,e.status=1,1,"poison","burn"
    round(b,true);eq(p.hp,0);eq(e.hp,1);eq(b.outcome,"defeat");eq(b:getRewardSnapshot().awards,0);same(p.evs,IndividualStats.zero());b:clearVolatiles()
 end)
 test("same-cohort last newly-fainted side retains existing winner and blackout policy",function()
    for _,reverse in ipairs({false,true})do
        local p=Pokemon(reverse and "pidgey"or "squirtle",6);local e=Pokemon(reverse and "squirtle"or "pidgey",6)
        local b=setup(p,e);p.hp,e.hp,p.status,e.status=1,1,"poison","poison";local xp=p.xp
        round(b,true);eq(p.hp,0);eq(e.hp,0);eq(p.xp,xp);same(p.evs,IndividualStats.zero());eq(b.outcome,reverse and "defeat"or "victory");b:clearVolatiles()
    end
 end)
 test("conscious earlier reserve alone learns and earns full yield after poisoned active faints",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",6);p.xp=p:xpForLevel(7)-1;q.xp=q:xpForLevel(7)-1
    local e,z=Pokemon("pidgey",6),Pokemon("rattata",5);local b=setup(p,e,q,z)
    assert(b:chooseParty(2));settle(b);assert(b:chooseParty(1));settle(b);p.hp,e.hp,p.status,e.status=1,1,"poison","poison"
    local xp=p.xp;round(b);eq(p.hp,0);eq(p.xp,xp);same(p.evs,IndividualStats.zero());eq(q.evs.spe,1);eq(q.xp,326);eq(q.level,8);eq(b:getLearningSnapshot().species,"charmander");eq(b.enemy,e)
    eq(learn(b),q);settle(b);eq(b.enemy,z);eq(b:phase(),"forcedSwitch");eq(q:hasMove("ember"),true);eq(b:getRewardSnapshot().latest.eligible,1);eq(b:getRewardSnapshot().latest.rows[1].index,2);b:clearVolatiles()
 end)
 test("two healthy participants resolve separate typed learning only after all member conditions",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",6);p.xp=p:xpForLevel(7)-1;q.xp=q:xpForLevel(7)-1
    local e,z=Pokemon("pidgey",6),Pokemon("rattata",5);local b=setup(p,e,q,z)
    assert(b:chooseParty(2));settle(b);assert(b:chooseParty(1));settle(b);p.status="burn";e.hp,e.status=1,"poison"
    round(b);eq(b:getLearningSnapshot().species,"squirtle");eq(p.xp,281);eq(q.xp,281);eq(p.evs.spe,1);eq(q.evs.spe,1);eq(b:getRewardSnapshot().latest.rows[1].before.hp,19);eq(b.enemy,e)
    eq(learn(b),p);settle(b);eq(b:getLearningSnapshot().species,"charmander");eq(b.enemy,e);eq(learn(b),q);settle(b);eq(b.enemy,z);eq(b:phase(),"command");eq(p:hasMove("bubble"),true);eq(q:hasMove("ember"),true);eq(b:getRewardSnapshot().awards,1);b:clearVolatiles()
 end)
 test("seed burn curse trap cleanup and Roost precede checkpoint; sides and late rampage follow",function()
    local p,q=Pokemon("pidgeot",50),Pokemon("charmander",5);local e,z=Pokemon("pidgey",50),Pokemon("rattata",5);local b=setup(p,e,q,z)
    p.hp=p.maxHP-1;b:setDirection("player");b:runScript(function()assert(b.conditions:roost())end);settle(b);assert(not b:hasType(p,"flying"))
    p.status="burn";local state=b.conditions:of(p);state.curse=true;state.trap={source=e,remaining=3};state.rampage={key="outrage",remaining=2,total=3,interrupted=true}
    e.hp=1;b.conditions:of(e).seed="player";b.conditions.sides.player.lightScreen={turns=1}
    local xp=p.xp;local seen={};local original=b.conditions.residual
    b.conditions.residual=function(owner,event)
        if event.order>=8 and event.order<=25 then eq(p.xp,xp);eq(p.evs.spe,0);seen[event.kind]=true end
        if event.kind=="sideTimer"then assert(seen.roostEnd);assert(p.xp>xp);eq(p.evs.spe,1);seen.sideTimer=true end
        if event.kind=="rampageEnd"then assert(seen.sideTimer);assert(p.xp>xp);seen.rampageEnd=true end
        local result=original(owner,event)
        if event.kind=="roostEnd"then eq(b:hasType(p,"flying"),true);eq(p.evs.spe,0)end
        return result
    end
    round(b,true);assert(seen.seed and seen.status and seen.curse and seen.trap and seen.roostEnd and seen.sideTimer and seen.rampageEnd)
    eq(p.hp,91);eq(p.level,50);eq(p.evs.spe,1);eq(b.conditions:of(p).trap,nil);eq(b.conditions:of(p).rampage,nil);eq(b.conditions.sides.player.lightScreen,nil);eq(b:hasType(p,"flying"),true);eq(b.enemy,z);b:clearVolatiles()
 end)
 test("direct move reward and learning retain immediate checkpoint before later poison",function()
    local p,q=Pokemon("charmander",6),Pokemon("squirtle",5);p.xp=p:xpForLevel(7)-1
    local e,z=Pokemon("pidgey",6),Pokemon("rattata",5);local b=setup(p,e,q,z);p.hp=1;p.status="poison";e.hp=1
    RulesRNG.seed(42);assert(b:selectMove(1));settle(b);eq(b:getLearningSnapshot().species,"charmander");eq(p.level,8);eq(p.hp,5);eq(p.xp,326);eq(p.evs.spe,1);eq(b.enemy,e)
    eq(learn(b),p);settle(b);eq(p.hp,2);eq(b.enemy,z);eq(b:phase(),"command");b:clearVolatiles()
 end)
 test("complete weather cohort remains immediate and excludes both sand-fainted actives",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",5);p.xp=p:xpForLevel(7)-1
    local e,z=Pokemon("pidgey",6),Pokemon("rattata",5);local b=setup(p,e,q,z);p.hp,e.hp=1,1
    b:runScript(function()assert(b.effects:setSandstorm())end);settle(b);local xp=p.xp;round(b,true)
    eq(p.hp,0);eq(p.xp,xp);eq(p.level,6);same(p.evs,IndividualStats.zero());eq(b:phase(),"forcedSwitch");eq(b:getRewardSnapshot().latest.eligible,0);b:clearVolatiles()
 end)
 return report
end
