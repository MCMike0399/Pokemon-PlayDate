-- Real production Battle/Party/Pokemon/Growth/Codec. No new reward fixtures.
RewardContracts={}
local keys={"hp","atk","def","spa","spd","spe"}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function cp(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=cp(x)end;return out end
local function same(a,b)eq(type(a),type(b));if type(a)~="table"then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function zero()return IndividualStats.zero()end
local function stats(p)return {hp=p.hp,maxHP=p.maxHP,atk=p.atk,def=p.def,spa=p.spa,spd=p.spd,spe=p.spe}end
local function rec(p)return assert(PokemonCodec.encode(p))end
local function own(p,moves)p.moves,p.pp={},{};for i,key in ipairs(moves)do p.moves[i]=key;p.pp[key]=moveData[key].maxPP end end
local function settle(b, scene, stopMessage)
    for _ = 1, 10000 do
        if scene then
            scene:update()
        end
        if b:phase() ~= "script" or b:getLearningSnapshot().pending then
            return
        end
        if not b.presentationRequest and (not scene or not scene:isVitalsBlocking()) then
            if stopMessage and b.message:find(stopMessage, 1, true) then
                return
            end
            if b.shiftChoice then
                assert(b:declineShift())
            else
                assert(b.machine:get("script"):advance())
            end
        else
            assert(scene, "reward presentation requires its production scene")
        end
    end
    error("reward script did not settle after presentation")
end
local function fresh(p,foe,bench,enemies)
    local party=Party();assert(party:add(p));if bench then assert(party:add(bench))end
    local b=Battle(p,foe,enemies and "REWARD TEST"or nil,{party=party,enemyParty=enemies});settle(b);return b,party
end
local function award(b)
    b.enemy.hp=0;local plan,why=BattleRewards.prepare(b,b.enemy);assert(plan,why);local ok,r=BattleRewards.commit(b,plan);assert(ok,r);return r
end
local function readyGame(p)
    local g=GameContext();assert(g:recruit(p));local starter=({charmander=true,squirtle=true,bulbasaur=true})[p.species]and p.species or "charmander"
    if starter~=p.species then assert(g:recruit(Pokemon(starter,5)))end
    assert(g.session:setIntro({stage="done",starter=starter,rivalStarter=({charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"})[starter]}));return g
end
function RewardContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}}
 local function test(name,fn)
    local before,owner=RulesRNG.snapshot(),GameSession.activeRNGSession();local ok,why=pcall(fn)
    local active=GameSession.activeRNGSession();if active~=owner then if active then active:deactivateRNG()end;if owner then assert(owner:activateRNG())end end;RulesRNG.restore(before)
    report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("pure EV addition obeys255/510 source stat order and input ownership",function()
    local current=zero();current.hp=255;current.atk=254;local yield=zero();yield.spa=1;yield.spe=1
    local before=cp(current);local ev,delta,wasted=IndividualStats.addEffort(current,yield)
    eq(ev.spe,1);eq(ev.spa,0);eq(delta.spe,1);eq(wasted.spa,1);same(current,before)
    current=zero();current.def=254;yield=zero();yield.def=3;ev,delta,wasted=IndividualStats.addEffort(current,yield);eq(ev.def,255);eq(delta.def,1);eq(wasted.def,2)
    current.hp=255;current.def=255;ev,delta=IndividualStats.addEffort(current,yield);eq(delta.def,0);same(ev,current)
    current.spe=1;eq(pcall(IndividualStats.addEffort,current,yield),false)
 end)
 test("actual Caterpie Pidgey Pikachu Geodude and Onix yields are never fabricated",function()
    for _,v in ipairs({{"caterpie","hp",1},{"pidgey","spe",1},{"pikachu","spe",2},{"geodude","def",1},{"onix","def",1}})do
        local p=Pokemon("squirtle",50);local b=fresh(p,Pokemon(v[1],5));local before=RulesRNG.snapshot();local r=award(b)
        for _,key in ipairs(keys)do eq(p.evs[key],key==v[2]and v[3]or 0)end
        eq(r.rows[1].evDelta[v[2]],v[3]);same(before,RulesRNG.snapshot());b:clearVolatiles()
    end
 end)
 test("one through six actual conscious participants each receive full unsplit yield",function()
    local species={"squirtle","charmander","bulbasaur","pidgey","rattata","caterpie"}
    for count=1,6 do
        local party=Party();for index=1,count do assert(party:add(Pokemon(species[index],50)))end
        local b=Battle(party:get(1),Pokemon("pikachu",5),nil,{party=party});settle(b)
        for _,mon in ipairs(party:members())do b.participants[mon]=true end
        local before=RulesRNG.snapshot();local receipt=award(b);eq(receipt.eligible,count);eq(#receipt.rows,count)
        for _,mon in ipairs(party:members())do eq(mon.evs.spe,2)end;same(before,RulesRNG.snapshot());b:clearVolatiles()
    end
 end)
 test("actual Beedrill reward saturates255 and510 with explicit wasted yield",function()
    local ev=zero();ev.hp=255;ev.atk=254;local p=Pokemon("bulbasaur",50,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local b=fresh(p,Pokemon("beedrill",5));local r=award(b)
    eq(p.evs.hp,255);eq(p.evs.atk,255);eq(p.evs.spd,0);eq(r.rows[1].yield.atk,2);eq(r.rows[1].yield.spd,1);eq(r.rows[1].evDelta.atk,1);eq(r.rows[1].evDelta.spd,0);eq(r.rows[1].evWasted.atk,1);eq(r.rows[1].evWasted.spd,1);b:clearVolatiles()
 end)
 test("fainted and nonparticipating members get no XP or EV and never revive",function()
    local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local b,party=fresh(p,Pokemon("pidgey",5),q);b.participants[q]=true;q.hp=0
    local bench=Pokemon("bulbasaur",50);assert(party:add(bench));local a,c=rec(q),rec(bench);local receipt=award(b)
    eq(receipt.eligible,1);eq(#receipt.rows,1);eq(p.evs.spe,1);same(rec(q),a);same(rec(bench),c);assert(b:flushRewards());eq(q.hp,0);b:clearVolatiles()
 end)
 test("Lv100 receives full EV with zeroXP and remains in literal49 XP split denominator",function()
    local p,q=Pokemon("bulbasaur",5),Pokemon("charmander",100);local party=Party();assert(party:add(p));assert(party:add(q))
    local b=Battle(p,Pokemon("bulbasaur",5),"TRAINER",{party=party});settle(b);b.participants[q]=true
    local px,qx=p.xp,q.xp;local r=award(b)
    eq(p.xp-px,49);eq(q.xp,qx);eq(r.rows[1].xp,49);eq(r.rows[2].xp,0);eq(q.evs.spa,1);eq(p.evs.spa,1);eq(r.eligible,2);b:clearVolatiles()
 end)
 test("Lv100 HP EV crossing4 keeps battle snapshot then preserves missingHP on return",function()
    local ev=zero();ev.hp=3;local p=Pokemon("bulbasaur",100,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});p.hp=195
    local b=fresh(p,Pokemon("caterpie",5));local before=stats(p);local r=award(b)
    eq(p.evs.hp,4);eq(p.xp,p:xpForLevel(100));eq(p.maxHP,200);eq(p.hp,195);same(stats(p),before);eq(r.rows[1].deferred,true)
    assert(b:flushRewards());eq(p.maxHP,201);eq(p.hp,196);eq(p.maxHP-p.hp,5);assert(b:flushRewards());eq(p.hp,196);b:clearVolatiles()
 end)
 test("pure prepare and snapshot reads never mutate records streams or one-time marker",function()
    local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local b=fresh(p,Pokemon("pidgey",5),q);b.participants[q]=true;b.enemy.hp=0
    local a,c,rng=rec(p),rec(q),RulesRNG.snapshot();local plan=assert(BattleRewards.prepare(b,b.enemy));assert(plan)
    for _=1,5 do local s=b:getRewardSnapshot();eq(s.awards,0);eq(#s.deferred,0)end
    same(rec(p),a);same(rec(q),c);same(RulesRNG.snapshot(),rng);eq(b.awardedEnemies[b.enemy],nil);b:clearVolatiles()
 end)
 test("invalid second recipient choice exhaustion leaves first marker owners and both streams untouched",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",6);q.nextMoveChoiceId=2147483647
    local g=readyGame(p);assert(g:recruit(q));local b=Battle(p,Pokemon("chansey",100),nil,{session=g.session});settle(b);b.participants[q]=true;b.enemy.hp=0
    local a,c,rng,world=rec(p),rec(q),RulesRNG.snapshot(),g.session:worldRngData();local conditions,effects=b:getConditionsSnapshot(),b.effects:snapshot()
    local plan,why=BattleRewards.prepare(b,b.enemy);eq(plan,nil);assert(why:find("move%-choice%-id%-exhausted"),why)
    same(rec(p),a);same(rec(q),c);eq(b.awardedEnemies[b.enemy],nil);eq(b:getRewardSnapshot().awards,0);same(RulesRNG.snapshot(),rng);same(g.session:worldRngData(),world);same(b:getConditionsSnapshot(),conditions);same(b.effects:snapshot(),effects);b:clearVolatiles()
 end)
 test("malformed second recipient fails before first EV XP or choice queue commit",function()
    local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local b=fresh(p,Pokemon("pidgey",5),q);b.participants[q]=true;b.enemy.hp=0
    local a,rng=rec(p),RulesRNG.snapshot();q.evs.spe=256;local plan,why=BattleRewards.prepare(b,b.enemy);eq(plan,nil);assert(why);q.evs.spe=0
    same(rec(p),a);same(RulesRNG.snapshot(),rng);eq(b.awardedEnemies[b.enemy],nil);b:clearVolatiles()
 end)
 test("stale second record rejects whole commit and rejected opaque plan cannot replay",function()
    local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local b=fresh(p,Pokemon("pidgey",5),q);b.participants[q]=true;b.enemy.hp=0
    local plan=assert(BattleRewards.prepare(b,b.enemy));local a,rng=rec(p),RulesRNG.snapshot();q.evs.spe=1
    local ok,why=BattleRewards.commit(b,plan);eq(ok,false);assert(why:find("stale%-reward%-member%-record"),why);same(rec(p),a);eq(b.awardedEnemies[b.enemy],nil);same(RulesRNG.snapshot(),rng)
    q.evs.spe=0;eq(BattleRewards.commit(b,plan),false);local replacement=assert(BattleRewards.prepare(b,b.enemy));assert(BattleRewards.commit(b,replacement));eq(p.evs.spe,1);b:clearVolatiles()
 end)
 test("changed active participant owner or continuation rejects without overwriting new state",function()
    for _,kind in ipairs({"active","participants","rng"})do
        local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local b,party=fresh(p,Pokemon("pidgey",5),q);b.participants[q]=true;b.enemy.hp=0
        local plan=assert(BattleRewards.prepare(b,b.enemy));local a,c=rec(p),rec(q)
        if kind=="active"then assert(party:switch(2));b.player=q elseif kind=="participants"then b.participants[q]=nil else RulesRNG.random(0,99)end
        local before=RulesRNG.snapshot();eq(BattleRewards.commit(b,plan),false);same(rec(p),a);same(rec(q),c);same(RulesRNG.snapshot(),before);eq(b.awardedEnemies[b.enemy],nil);b:clearVolatiles()
    end
 end)
 test("duplicate foe and foreign plan commits never duplicate reward or consume foreign plan",function()
    local p=Pokemon("squirtle",50);local b=fresh(p,Pokemon("pidgey",5));b.enemy.hp=0;local plan=assert(BattleRewards.prepare(b,b.enemy))
    local other=fresh(Pokemon("charmander",50),Pokemon("rattata",5));eq(BattleRewards.commit(other,plan),false)
    assert(BattleRewards.commit(b,plan));local before=rec(p);eq(BattleRewards.commit(b,plan),false);eq(BattleRewards.prepare(b,b.enemy),nil);same(rec(p),before);eq(b:getRewardSnapshot().awards,1);b:clearVolatiles();other:clearVolatiles()
 end)
 test("real handleFaint two-opponent scripts award each identity once and reset actual participation",function()
    local p,q=Pokemon("squirtle",50),Pokemon("charmander",50);local e1,e2=Pokemon("pidgey",5),Pokemon("caterpie",5);own(e1,{"growl"});own(e2,{"stringShot"});local foes=Party();assert(foes:add(e1));assert(foes:add(e2))
    local b=fresh(p,e1,q,foes);b.participants[q]=true;e1.hp=0
    b:runScript(function()local result=b:handleFaint("enemy");if result=="replacement"then return b:finishRound()end;return result end);settle(b)
    eq(b.enemy,e2);eq(p.evs.spe,1);eq(q.evs.spe,1);eq(q.evs.hp,0);eq(b.participants[q],nil);eq(b.awardedEnemies[e1],true)
    e2.hp=0;b:runScript(function()return b:handleFaint("enemy")end);settle(b)
    eq(b.outcome,"victory");eq(p.evs.hp,1);eq(q.evs.hp,0);eq(b:getRewardSnapshot().awards,2);local before=rec(p);eq(b:handleFaint("enemy"),"victory");same(rec(p),before);b:clearVolatiles()
 end)
 test("no-level EV changes keep live HP defense speed through next actual foe",function()
    local ev=zero();ev.spe=7;local p=Pokemon("squirtle",50,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local e1,e2=Pokemon("pikachu",5),Pokemon("rattata",5);own(e1,{"growl"});own(e2,{"tailWhip"});local foes=Party();assert(foes:add(e1));assert(foes:add(e2))
    local b=fresh(p,e1,nil,foes);local before=stats(p);e1.hp=0;b:runScript(function()local result=b:handleFaint("enemy");if result=="replacement"then return b:finishRound()end;return result end);settle(b)
    eq(b.enemy,e2);eq(p.evs.spe,9);same(stats(p),before);assert(p:calculatedStats().spe>p.spe);eq(#b:getRewardSnapshot().deferred,1)
    assert(b:flushRewards());eq(p.spe,p:calculatedStats().spe);b:clearVolatiles()
 end)
 test("level-up recomputes from EV already allocated before next foe and typed learning",function()
    local iv,ev=zero(),zero();iv.spe=13;ev.spe=3;local p=Pokemon("squirtle",6,{natureId=0,abilitySlot="first",heldItem="none",ivs=iv,evs=ev});p.xp=p:xpForLevel(7)-1;local e1,e2=Pokemon("pidgey",5),Pokemon("geodude",5);own(e1,{"growl"});own(e2,{"defenseCurl"});local foes=Party();assert(foes:add(e1));assert(foes:add(e2))
    local b=fresh(p,e1,nil,foes);local beforeHP=p.maxHP-p.hp;e1.hp=0;b:runScript(function()local result=b:handleFaint("enemy");if result=="replacement"then return b:finishRound()end;return result end);settle(b)
    eq(p.level,7);eq(p.evs.spe,4);eq(p.spe,12);eq(p.spe,p:calculatedStats().spe);eq(p.maxHP-p.hp,beforeHP);eq(b.enemy,e1);eq(b:getLearningSnapshot().pending,true)
    local receipt,mon=b:takeLearningRequest();eq(mon,p);while #p:getPendingMoveChoices()>0 do assert(p:resolveMoveChoice(p:getPendingMoveChoices()[1].id,"learn"))end;assert(b:resumeLearning(receipt));settle(b);eq(b.enemy,e2);eq(b:getRewardSnapshot().awards,1);eq(p:hasMove("bubble"),true);b:clearVolatiles()
 end)
 test("emitEnd flushes before same-owned evolution callback and cannot flush twice",function()
    local ev=zero();ev.hp=3;local p=Pokemon("eevee",100,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local g=readyGame(p);assert(g.session:inventory():add("waterStone",1));p.hp=p.maxHP-7
    local b=Battle(p,Pokemon("caterpie",5),nil,{session=g.session});settle(b);award(b);local oldMax=p.maxHP;local calls=0
    b:on("battleEnd",function()calls=calls+1;eq(p.maxHP,oldMax+1);eq(p.maxHP-p.hp,7);assert(Evolution.complete(assert(Evolution.prepare(g.session,p,{kind="stone",item="waterStone"}))))end)
    b.outcome="victory";assert(b:emitEnd());eq(calls,1);eq(p.species,"vaporeon");eq(p.evs.hp,4);eq(p.maxHP-p.hp,7);eq(b:emitEnd(),false);eq(calls,1);eq(g.session:party():get(1),p)
 end)
 test("flush preflights every deferred member before changing either live snapshot",function()
    local ev=zero();ev.spe=7;local p=Pokemon("squirtle",50,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local q=Pokemon("charmander",50,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local b=fresh(p,Pokemon("pikachu",5),q);b.participants[q]=true;award(b)
    local a,c,rng=stats(p),stats(q),RulesRNG.snapshot();q.ivs.spe=32;eq(b:flushRewards(),false);same(stats(p),a);same(stats(q),c);same(RulesRNG.snapshot(),rng);eq(#b:getRewardSnapshot().deferred,2)
    q.ivs.spe=0;assert(b:flushRewards());eq(p.spe,p:calculatedStats().spe);eq(q.spe,q:calculatedStats().spe);b:clearVolatiles()
 end)
 test("capture run and living foe cannot mint a reward plan",function()
    local p=Pokemon("charmander",50);local b=fresh(p,Pokemon("rattata",5));local before=rec(p);eq(BattleRewards.prepare(b,b.enemy),nil)
    for _,outcome in ipairs({"caught","run"})do b.enemy.hp=0;b.outcome=outcome;eq(BattleRewards.prepare(b,b.enemy),nil);same(rec(p),before)end;b:clearVolatiles()
 end)
 test("actual poison residual faint awards the defeated source yield exactly once",function()
    local p,e=Pokemon("squirtle",50),Pokemon("rattata",5);own(p,{"growl"});own(e,{"growl"});local b=fresh(p,e);e.hp=1;e.status="poison"
    RulesRNG.seed(42);assert(b:selectMove(1));settle(b);eq(b.outcome,"victory");eq(e.hp,0);eq(p.evs.spe,1);eq(b:getRewardSnapshot().awards,1);b:clearVolatiles()
 end)
 test("actual recoil selfKO excludes fainted actor but rewards conscious earlier participant",function()
    local p,q,e=Pokemon("rattata",50),Pokemon("squirtle",50),Pokemon("pidgey",5);own(p,{"takeDown"});own(e,{"growl"});p.spe=1000;e.spe=1
    local b=fresh(p,e,q);assert(b:chooseParty(2));settle(b);assert(b:chooseParty(1));settle(b);p.hp=1;e.hp=1
    RulesRNG.seed(1);assert(b:selectMove(1));settle(b);eq(p.hp,0);eq(e.hp,0);eq(b.outcome,"victory");same(p.evs,zero());eq(q.evs.spe,1);eq(b:getRewardSnapshot().latest.eligible,1);b:clearVolatiles()
 end)
 test("real battle medicine uses deferred live maxHP until return flush",function()
    local ev=zero();ev.hp=3;local p=Pokemon("bulbasaur",100,{natureId=0,abilitySlot="first",heldItem="none",ivs=zero(),evs=ev});local g=readyGame(p);assert(g.session:inventory():add("potion",1));p.hp=195
    local e1,e2=Pokemon("caterpie",5),Pokemon("rattata",5);own(e1,{"stringShot"});own(e2,{"growl"});local foes=Party();assert(foes:add(e1));assert(foes:add(e2));local b=Battle(p,e1,"MEDICINE REWARD",{session=g.session,enemyParty=foes});settle(b)
    e1.hp=0;b:runScript(function()local result=b:handleFaint("enemy");if result=="replacement"then return b:finishRound()end;return result end);settle(b);eq(b.enemy,e2);eq(p.maxHP,200);eq(p:calculatedStats().maxHP,201)
    assert(g.session:activateRNG());assert(b:useItem("potion",1));settle(b);eq(p.hp,200);eq(p.maxHP,200);local _,shownHP,shownMax=b:presentationVitals(p);eq(shownHP,200);eq(shownMax,200);eq(g.session:inventory():quantity("potion"),0);assert(b:flushRewards());eq(p.hp,201);eq(p.maxHP,201);b:clearVolatiles()
 end)
 test("HUD holds before vitals through gained message then releases before grew message",function()
    local p=Pokemon("charmander",6);p.xp=p:xpForLevel(7)-1;p.hp=18;local b=fresh(p,Pokemon("rattata",5));b.enemy.hp=0
    b:runScript(function()return b:handleFaint("enemy")end)
    local n=0;while not b.message:find(" gained ",1,true)do n=n+1;assert(n<20);assert(b.machine:get("script"):advance())end
    eq(p.level,7);eq(p.hp,20);eq(p.maxHP,22);local before=RulesRNG.snapshot()
    for _=1,64 do local level,hp,maximum=b:presentationVitals(p);eq(level,6);eq(hp,18);eq(maximum,20)end;same(RulesRNG.snapshot(),before)
    local scene=BattleScene(b);local bars={};local draw=scene.drawHPBar
    scene.drawHPBar=function(self,x,y,w,h,hp,maximum)bars[#bars+1]={hp,maximum};return draw(self,x,y,w,h,hp,maximum)end
    local image=playdate.graphics.image.new(400,240,playdate.graphics.kColorWhite);playdate.graphics.pushContext(image);scene:drawBattleField();playdate.graphics.popContext();eq(bars[2][1],18);eq(bars[2][2],20)
    assert(b.machine:get("script"):advance())
    eq(b.presentationRequest.kind, "experience")
    local level, hp, maximum = b:presentationVitals(p)
    eq(level, 6)
    eq(hp, 18)
    eq(maximum, 20)
    settle(b, scene, " grew to Lv7!")
    assert(b.message:find(" grew to Lv7!", 1, true))
    level, hp, maximum = b:presentationVitals(p)
    eq(level, 7)
    eq(hp, 20)
    eq(maximum, 22)
    same(RulesRNG.snapshot(), before)
    bars={};playdate.graphics.pushContext(image);scene:drawBattleField();playdate.graphics.popContext();eq(bars[2][1],20);eq(bars[2][2],22);scene:exit();b:clearVolatiles()
 end)
 test("active second member stays held while first bench member narrates and learns",function()
    local p,q=Pokemon("squirtle",6),Pokemon("charmander",6);p.xp=p:xpForLevel(7)-1;q.xp=q:xpForLevel(7)-1
    local e=Pokemon("bulbasaur",6);own(e,{"growl"});local party=Party();assert(party:add(p));assert(party:add(q));local b=Battle(p,e,"HUD ORDER",{party=party});settle(b);assert(b:chooseParty(2));settle(b);e.hp=0
    b:runScript(function()return b:handleFaint("enemy")end);local n=0
    while not b.message:find("SQUIRTLE gained ",1,true)do n=n+1;assert(n<20);assert(b.machine:get("script"):advance())end
    eq(p.level,7);eq(q.level,7);local level,hp,maximum=b:presentationVitals(q);eq(level,6);eq(hp,20);eq(maximum,20)
    assert(b.machine:get("script"):advance());eq(select(1,b:presentationVitals(q)),6);assert(b.machine:get("script"):advance());eq(b:getLearningSnapshot().pending,true)
    local request,mon=b:takeLearningRequest();eq(mon,p);while #p:getPendingMoveChoices()>0 do assert(p:resolveMoveChoice(p:getPendingMoveChoices()[1].id,"learn"))end;assert(b:resumeLearning(request))
    assert(b.message:find("CHARMANDER gained ",1,true));eq(select(1,b:presentationVitals(q)),6);assert(b.machine:get("script"):advance());eq(select(1,b:presentationVitals(q)),7);eq(party:active(),q);b:clearVolatiles()
 end)
 test("closed or stale presentation receipt never leaks old vitals or consumes rules RNG",function()
    local p=Pokemon("charmander",6);p.xp=p:xpForLevel(7)-1;local b=fresh(p,Pokemon("rattata",5));local r=award(b);eq(select(1,b:presentationVitals(p)),6)
    local before=RulesRNG.snapshot();eq(BattleRewards.acknowledge(b,r.id+1,1),false);eq(select(1,b:presentationVitals(p)),6);b:clearVolatiles();eq(#b:getRewardSnapshot().holds,0)
    eq(BattleRewards.acknowledge(b,r.id,1),false);p:takeDamage(1);local level,hp,maximum=b:presentationVitals(p);eq(level,p.level);eq(hp,p.hp);eq(maximum,p.maxHP);same(RulesRNG.snapshot(),before)
 end)
 test("closed or aborted reward owner flushes durable EV without opening new grants",function()
    local p=Pokemon("squirtle",50);local b=fresh(p,Pokemon("pikachu",5));award(b);local before=cp(p.evs);b:clearVolatiles();eq(b:getRewardSnapshot().closed,true);eq(BattleRewards.prepare(b,b.enemy),nil);same(p.evs,before);eq(p.spe,p:calculatedStats().spe)
 end)
 return report
end
