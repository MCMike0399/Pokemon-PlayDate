-- Real Battle/Party/Session/DSL/Signal/LearningState contracts. Root executes
-- this through the actual SDK; no substitute SDK or alternate battle engine.
WhirlwindContracts={}
local function eq(actual,expected,label)
 assert(actual==expected,(label or "value")..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function sameRNG(before)
 local now=RulesRNG.snapshot();for _,k in ipairs({"algorithm","seed","state","rolls"})do eq(now[k],before[k],"RNG "..k)end
end
local function own(mon,keys,pp)
 mon.moves,mon.pp={},{};for i,key in ipairs(keys)do mon.moves[i]=key;mon.pp[key]=pp or moveData[key].maxPP end
end
local function roster(...)
 local party=Party();for _,mon in ipairs({...})do assert(party:add(mon))end;return party
end
local function learning(b)
 local receipt,mon=b:takeLearningRequest();assert(receipt,"actual learning receipt required")
 local machine=StateMachine();local game={machine=machine};local state=LearningState(game)
 machine:register("base",State("base"));machine:register("learning",state);machine:change("base")
 assert(LearningState.open(game,mon,function()assert(b:resumeLearning(receipt))end))
 for _=1,100 do
  if not machine:is("learning")then return mon end
  if state.phase=="message"then assert(state.dialog.onComplete)();state:handleInput()
  elseif state.phase=="ask"then state.menu.onSelect(2)
  elseif state.phase=="stop"then state.menu.onSelect(1)
  else error("unexpected actual learning phase "..state.phase)end
 end
 error("actual learning did not settle")
end
local function settle(b,pauseLearning)
 local lines={}
 for _=1,500 do
  if b:phase()~="script"then return table.concat(lines,"|")end
  lines[#lines+1]=b.message
  if b:getLearningSnapshot().pending then
   if pauseLearning then return table.concat(lines,"|")end
   learning(b)
  else b.machine:get("script"):advance()end
 end
 error("battle script did not settle: "..tostring(b.message))
end
local battles={}
local function fresh(p,e,deps,trainer)
 local b=Battle(p or Pokemon("pidgey",100),e or Pokemon("rattata",100),trainer,deps)
 battles[#battles+1]=b;settle(b);return b
end
local function one(b,side,key,finish)
 local actor=b[side];if not actor:hasMove(key)then own(actor,{key})end
 local turn={side=side,actor=actor,key=key,move=moveData[key],continuation=b.conditions:lockedKey(actor)==key}
 b:runScript(function()
  local outcome=b:resolveTurn(turn)
  if outcome and outcome~="replacement"then return outcome end
  if finish then return b:finishRound()end
  return outcome
 end)
 return settle(b)
end
local function trainerPair(extra)
 local p,a,z=Pokemon("pidgey",100),Pokemon("rattata",100),Pokemon("squirtle",100)
 own(p,{"whirlwind"});own(a,{"splash"});own(z,{"splash"})
 local enemies=extra and roster(a,z,extra)or roster(a,z)
 return fresh(p,a,{enemyParty=enemies},"TRAINER"),p,a,z,enemies
end
local function sessionWith(p)
 local session=GameSession.newSession({itemDefinitions=ItemData.definitions,validateWorld=WorldDeltas.validate,
  resolveLocation=WorldDeltas.resolveLocation},{location={zone_id="reds_house_2f",x=5,y=3,facing="up"},seed=42})
 assert(session:recruit(p));assert(session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=false}))
 return session
end
function WhirlwindContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)
  battles={};Autopilot.resetControls();local ok,problem=pcall(fn)
  for _,b in ipairs(battles)do pcall(b.clearVolatiles,b)end
  Autopilot.resetControls();RulesRNG.restore(saved)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil}
  if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("Root-generated Whirlwind retains all scalars and has one typed opposing effect",function()
  local move=moveData.whirlwind;eq(move.power,0);eq(move.accuracy,100);eq(move.maxPP,20);eq(move.priority,-6);eq(move.targetId,10)
  eq(move.protectable,true);eq(move.contact,false);eq(#move.effects,1);assert(move.effects[1]:is("ForceSwitchEffect"))
  local before=RulesRNG.snapshot()
  for _,bad in ipairs({false,1,"attacker",ATTACKER,{},Target("invalid")})do eq(pcall(ForceSwitchEffect,bad),false)end
  eq(pcall(ForceSwitchEffect,nil),false);assert(ForceSwitchEffect("defender"));assert(ForceSwitchEffect(Target("defender")));sameRNG(before)
 end)
 test("Pure eligible indices exclude active/fainted and reject malformed/foreign targets without owner mutation or RNG",function()
  local fainted=Pokemon("gastly",100);fainted.hp=0
  local b,_,a,z,enemies=trainerPair(fainted);local before=RulesRNG.snapshot()
  local count=0;for _ in pairs(b.conditions.members)do count=count+1 end
  local indices,side=b:eligibleForcedReplacements(a);eq(table.concat(indices,","),"2");eq(side,"enemy")
  eq(b:eligibleForcedReplacements({}),nil);eq(b:eligibleForcedReplacements(Pokemon("rattata",100)),nil)
  local after=0;for _ in pairs(b.conditions.members)do after=after+1 end;eq(after,count);eq(enemies:active(),a);eq(z.hp,z.maxHP);sameRNG(before)
 end)
 test("Typed force effect outside the owned script or after close changes nothing",function()
  local b,_,a=trainerPair();b:setDirection("player");local before=RulesRNG.snapshot();local round=b.effects.round
  eq(b:forceSwitch(a),nil);eq(b:getForceSwitchSnapshot().present,false);eq(b.effects.round,round);sameRNG(before)
  b:clearVolatiles();eq(b:forceSwitch(a),nil);eq(b:getForceSwitchSnapshot().present,false);sameRNG(before)
 end)
 test("Missing/forged queued actors are rejected before context direction status PP or RNG",function()
  local b=fresh();own(b.player,{"whirlwind"});local before=RulesRNG.snapshot();local attacker=b.attacker;local round=b.effects.round
  eq(pcall(b.resolveTurn,b,{side="player",key="whirlwind",move=moveData.whirlwind}),false)
  local foreign=Pokemon("pidgey",100);eq(b:resolveTurn({side="player",actor=foreign,key="whirlwind",move=moveData.whirlwind}),nil)
  eq(b.attacker,attacker);eq(b.effects.round,round);eq(b.player.pp.whirlwind,20);sameRNG(before)
 end)
 test("Equal/lower-level wild targets exit through run once without XP EV or prizes",function()
  for _,level in ipairs({16,17})do
   local p,e=Pokemon("pidgey",17),Pokemon("rattata",level);own(p,{"whirlwind"});local b=fresh(p,e)
   local xp=p.xp;local ev=json.encode(p.evs);local calls=0
   b:on("battleEnd",function(won,kind)calls=calls+1;eq(won,false);eq(kind,"run")end)
   RulesRNG.seed(14);local text=one(b,"player","whirlwind")
   eq(b.outcome,"run");eq(b:phase(),"ended");eq(calls,1);eq(b:emitEnd(),false)
   eq(p.xp,xp);eq(json.encode(p.evs),ev);eq(p.pp.whirlwind,19);eq(b:getRewardSnapshot().awards,0)
   eq(RulesRNG.snapshot().rolls,1);eq(RulesRNG.snapshot().state,235298);assert(text:find("blown away",1,true))
   local receipt=b:getForceSwitchSnapshot();eq(receipt.success,true);eq(receipt.reason,"wild-escape");eq(receipt.cause,"phaze")
  end
 end)
 test("Wild enemy Whirlwind ends encounter rather than selecting an owned reserve",function()
  local p,bench,e=Pokemon("charmander",17),Pokemon("pikachu",17),Pokemon("pidgey",17);local session=sessionWith(p);assert(session:recruit(bench))
  local b=fresh(p,e,{session=session});local money=session:inventory():money();local xp=p.xp;local eHP=e.hp;local pHP=p.hp
  RulesRNG.seed(14);one(b,"enemy","whirlwind")
  eq(b.outcome,"run");eq(session:party():active(),p);eq(b.player,p);eq(p.hp,pHP);eq(e.hp,eHP);eq(p.xp,xp)
  eq(session:inventory():money(),money);eq(session:party():count(),2);eq(session:flags().trainers and next(session:flags().trainers),nil)
  eq(e.pp.whirlwind,19);eq(RulesRNG.snapshot().rolls,1);eq(b:getForceSwitchSnapshot().targetSide,"player")
 end)
 test("Higher-level wild target fails after one accuracy roll and one PP without escape lottery",function()
  local p,e=Pokemon("pidgey",17),Pokemon("rattata",18);local b=fresh(p,e);local hp=e.hp;local xp=p.xp
  RulesRNG.seed(14);local text=one(b,"player","whirlwind")
  eq(b.outcome,nil);eq(b:phase(),"command");eq(e.hp,hp);eq(p.xp,xp);eq(p.pp.whirlwind,19)
  eq(RulesRNG.snapshot().rolls,1);eq(RulesRNG.snapshot().state,235298);eq(b:getForceSwitchSnapshot().reason,"higher-level");assert(text:find("failed",1,true))
 end)
 test("Trainer with no living reserve fails after PP and accuracy without a replacement draw",function()
  local p,a,z=Pokemon("pidgey",100),Pokemon("rattata",100),Pokemon("squirtle",100);z.hp=0;local enemies=roster(a,z)
  local b=fresh(p,a,{enemyParty=enemies},"TRAINER");RulesRNG.seed(14);one(b,"player","whirlwind")
  eq(enemies:active(),a);eq(b.enemy,a);eq(p.pp.whirlwind,19);eq(b.outcome,nil);eq(RulesRNG.snapshot().rolls,1)
  eq(b:getForceSwitchSnapshot().reason,"no-reserve")
 end)
 test("One trainer reserve samples once and uses dragged-out narration through opponent entry",function()
  local b,p,a,z,enemies=trainerPair();RulesRNG.seed(14);local text=one(b,"player","whirlwind")
  eq(b.enemy,z);eq(enemies:active(),z);eq(a.hp,a.maxHP);eq(p.pp.whirlwind,19);eq(RulesRNG.snapshot().rolls,2);eq(RulesRNG.snapshot().state,1807169839)
  assert(text:find("SQUIRTLE was dragged out!",1,true));assert(not text:find("TRAINER sent out SQUIRTLE",1,true))
  local view=b:getForceSwitchSnapshot();eq(view.index,2);eq(view.incoming,"squirtle");view.incoming="forged";eq(b:getForceSwitchSnapshot().incoming,"squirtle")
 end)
 test("Two usable trainer reserves follow stable actual party indices with literal RNG vectors",function()
  for _,case in ipairs({{seed=1,index=2,state=282475249},{seed=2,index=3,state=564950498}})do
   local third=Pokemon("gastly",100);local b,p,a,z,enemies=trainerPair(third);RulesRNG.seed(case.seed);one(b,"player","whirlwind")
   eq(enemies:activeIndex(),case.index);eq(b.enemy,enemies:get(case.index));eq(RulesRNG.snapshot().rolls,2);eq(RulesRNG.snapshot().state,case.state)
  end
 end)
 test("Miss samples accuracy only and does not select or mutate an opponent",function()
  local b,p,a=trainerPair();p.statStages.acc=-6;RulesRNG.seed(14);local text=one(b,"player","whirlwind")
  eq(b.enemy,a);eq(p.pp.whirlwind,19);eq(RulesRNG.snapshot().rolls,1);eq(RulesRNG.snapshot().state,235298)
  eq(b:getForceSwitchSnapshot().present,false);assert(text:find("missed",1,true))
 end)
 test("Normal-type Whirlwind is not stopped by a Ghost status target",function()
  local p,a,z=Pokemon("pidgey",100),Pokemon("gastly",100),Pokemon("squirtle",100)
  local enemies=roster(a,z);local b=fresh(p,a,{enemyParty=enemies},"TRAINER");RulesRNG.seed(14);one(b,"player","whirlwind")
  eq(b.enemy,z);eq(p.pp.whirlwind,19);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Actual Protect blocks before Whirlwind accuracy and choice while both attempts spend PP",function()
  local b,p,a,z,enemies=trainerPair();own(a,{"protect"});RulesRNG.seed(14)
  assert(b:selectMove(1));local text=settle(b)
  eq(b.enemy,a);eq(enemies:active(),a);eq(a.pp.protect,9);eq(p.pp.whirlwind,19);eq(b:getForceSwitchSnapshot().present,false)
  eq(RulesRNG.snapshot().rolls,1,"only enemy move selection; guaranteed first Protect and blocked Whirlwind do not roll")
  assert(text:find("protected",1,true))
 end)
 test("Priority minus6 allows a real opposing attack to faint the user before Whirlwind spends PP",function()
  local p,bench,a,z=Pokemon("pidgey",100),Pokemon("pikachu",100),Pokemon("rattata",100),Pokemon("squirtle",100)
  p.hp=1;p.spe=1000;a.spe=1;own(p,{"whirlwind"});own(a,{"tackle"});local enemies=roster(a,z)
  local b=fresh(p,a,{party=roster(p,bench),enemyParty=enemies},"TRAINER");RulesRNG.seed(1);assert(b:selectMove(1));settle(b)
  eq(p.hp,0);eq(p.pp.whirlwind,20);eq(a.pp.tackle,34);eq(b.enemy,a);eq(b:phase(),"forcedSwitch");eq(b:getForceSwitchSnapshot().present,false)
 end)
 test("A displaced queued actual actor never begins action or lends PP/status/action to incoming",function()
  local p,a,z=Pokemon("pidgey",100),Pokemon("pidgey",5),Pokemon("squirtle",100)
  own(p,{"whirlwind"});own(a,{"whirlwind"});own(z,{"tackle"});a.status,a.statusTurns,a.sleepDuration="sleep",1,3
  local b=fresh(p,a,{enemyParty=roster(a,z)},"TRAINER");local began={};local original=b.effects.beginAction
  b.effects.beginAction=function(owner,turn,mon)began[#began+1]=mon;return original(owner,turn,mon)end
  RulesRNG.seed(1);assert(b:selectMove(1));settle(b)
  eq(b.enemy,z);eq(#began,1);eq(began[1],p);eq(a.pp.whirlwind,20);eq(a.statusTurns,3,"switch reset, no displaced sleep attempt")
  eq(z.pp.tackle,35);eq(b.effects:pendingMove(z),nil);eq(b:phase(),"command")
 end)
 test("Public commands keep invalid index/phase rejection RNG and models unchanged",function()
  local b,p,a=trainerPair();local before=RulesRNG.snapshot();local pp=p.pp.whirlwind
  for _,index in ipairs({-1,0,2,1.5,"1"})do eq(b:selectMove(index),false);sameRNG(before)end
  eq(b.enemy,a);eq(p.pp.whirlwind,pp);assert(b:selectMove(1));local entered=RulesRNG.snapshot()
  eq(b:selectMove(1),false);sameRNG(entered);settle(b)
 end)
 test("Actual binding/Arena Trap do not prevent trainer forced displacement",function()
  local b,p,a,z=trainerPair();RulesRNG.seed(1);one(b,"player","wrap");assert(b.conditions:trapped(a))
  RulesRNG.seed(14);one(b,"player","whirlwind");eq(b.enemy,z);eq(b.conditions:trapped(a),false);eq(b.conditions:trapped(z),false)
  eq(RulesRNG.snapshot().rolls,2)
  local old,bench=Pokemon("charmander",100),Pokemon("pikachu",100)
  local trapper=Pokemon("diglett",100,{natureId=0,abilitySlot="second",heldItem="none"})
  local bound=fresh(old,trapper,{party=roster(old,bench)},"TRAINER");assert(bound.effects:withdrawBlocked(old))
  local before=RulesRNG.snapshot();eq(bound:chooseParty(2),false);sameRNG(before)
  RulesRNG.seed(14);one(bound,"enemy","whirlwind");eq(bound.player,bench);eq(bound.outcome,nil);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Actual entry marks only dragged opponent seen and preserves unseen bench identities",function()
  local p=Pokemon("charmander",100);local session=sessionWith(p);local a,z,last=Pokemon("pidgey",100),Pokemon("rattata",100),Pokemon("gastly",100)
  local enemies=roster(a,z,last);local b=fresh(p,a,{session=session,enemyParty=enemies},"TRAINER")
  eq(session:pokedex().seen.pidgey,true);eq(session:pokedex().seen.rattata,nil);eq(session:pokedex().seen.gastly,nil)
  RulesRNG.seed(1);one(b,"player","whirlwind");eq(b.enemy,z);eq(session:pokedex().seen.rattata,true);eq(session:pokedex().seen.gastly,nil)
  RulesRNG.seed(1);one(b,"player","whirlwind");eq(b.enemy,a);eq(session:pokedex().seen.gastly,nil);eq(b:getRewardSnapshot().awards,0)
 end)
 test("Forced owned replacement preserves major status/HP/PP and resets original sleep and stages",function()
  local p,bench,e=Pokemon("charmander",100),Pokemon("pikachu",100),Pokemon("pidgey",100)
  p.status,p.statusTurns,p.sleepDuration="sleep",1,3;p.statStages.atk=4;own(p,{"tackle"},7)
  bench.status,bench.statusTurns,bench.sleepDuration="burn",0,0;bench.hp=bench.hp-3
  local party=roster(p,bench);local b=fresh(p,e,{party=party},"TRAINER");local hp=p.hp;local benchHP=bench.hp
  RulesRNG.seed(14);one(b,"enemy","whirlwind")
  eq(b.player,bench);eq(party:active(),bench);eq(p.hp,hp);eq(p.pp.tackle,7);eq(p.status,"sleep");eq(p.statusTurns,3);eq(p.sleepDuration,3)
  eq(p.statStages.atk,0);eq(bench.statStages.atk,0);eq(bench.status,"burn");eq(bench.hp,benchHP);eq(b.outcome,nil);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Real Bide/charge/rampage locks clear on phaze without phantom continuation PP or fatigue",function()
  for _,key in ipairs({"bide","skullBash","petalDance"})do
   local p,bench,e=Pokemon("pidgey",100),Pokemon("pikachu",100),Pokemon("rattata",100)
   local b=fresh(p,e,{party=roster(p,bench)},"TRAINER");RulesRNG.seed(1);one(b,"player",key);assert(b.conditions:locked(p),key.." did not start")
   local pp=p.pp[key];RulesRNG.seed(14);one(b,"enemy","whirlwind")
   eq(b.player,bench);eq(b.conditions:locked(p),nil);eq(b.conditions:locked(bench),nil);eq(p.pp[key],pp);eq(p.confusion,nil);eq(p.statStages.def,0)
   local before=RulesRNG.snapshot();b:update();sameRNG(before)
  end
 end)
 test("Phaze clears real Roost/ability override while side timers and rain persist",function()
  local p,bench,e=Pokemon("pidgeot",100),Pokemon("pikachu",100),Pokemon("bulbasaur",100);p.hp=1
  local b=fresh(p,e,{party=roster(p,bench)},"TRAINER");one(b,"player","tailwind");one(b,"player","rainDance");one(b,"player","roost")
  assert(not b:hasType(p,"flying"));one(b,"enemy","worrySeed");eq(b.effects:effectiveAbility(p),15)
  RulesRNG.seed(14);one(b,"enemy","whirlwind")
  eq(b.player,bench);eq(b:hasType(p,"flying"),true);eq(b.effects:effectiveAbility(p),p:ability());eq(b.effects:weatherId(),"raindance")
  eq(b.conditions:sideTurns(bench,"tailwind"),4);eq(b.effects:snapshot().turns,5)
  RulesRNG.seed(14);one(b,"enemy","whirlwind");eq(b.player,p);eq(b.effects:effectiveAbility(p),p:ability())
  eq(b:hasType(p,"flying"),true);eq(b.conditions:sideTurns(p,"tailwind"),4);eq(e.pp.whirlwind,18)
 end)
 test("Repeated phaze reentry preserves per-opponent participants and actual once-only reward/learning",function()
  local p,bench,a,z=Pokemon("charmander",6),Pokemon("bulbasaur",6),Pokemon("bulbasaur",6),Pokemon("squirtle",6)
  own(p,{"whirlwind","dragonRage"});own(bench,{"whirlwind"});own(a,{"growl"});own(z,{"growl"})
  p.spe,bench.spe,a.spe,z.spe=1000,1000,1,1;local party,enemies=roster(p,bench),roster(a,z)
  local b=fresh(p,a,{party=party,enemyParty=enemies},"TRAINER");assert(b:chooseParty(2));settle(b)
  RulesRNG.seed(1);one(b,"player","whirlwind");eq(b.enemy,z);local setA=b.participantSets[a];assert(setA[p]and setA[bench])
  assert(b:chooseParty(1));settle(b);RulesRNG.seed(1);one(b,"player","whirlwind");eq(b.enemy,a);eq(b.participants,setA)
  a.hp=1;RulesRNG.seed(1);assert(b:selectMove(2));settle(b,true);eq(a.hp,0);eq(b.enemy,a);assert(b:getLearningSnapshot().pending)
  local before=RulesRNG.snapshot();local context=b.effects.round;for _=1,20 do b:update()end
  eq(b:selectMove(1),false);eq(b.enemy,a);eq(b.effects.round,context);sameRNG(before)
  local first=learning(b);eq(first,p);settle(b,true);assert(b:getLearningSnapshot().pending);eq(b.enemy,a)
  local second=learning(b);eq(second,bench);settle(b);eq(b.enemy,z);eq(p.xp,237);eq(bench.xp,237)
  eq(p:hasMove("ember"),true);eq(bench:hasMove("leechSeed"),true);eq(b:getRewardSnapshot().awards,1)
  assert(b.participants[p]and b.participants[bench],"returning opponent lost prior actual participants")
  z.hp=1;RulesRNG.seed(1);assert(b:selectMove(2));settle(b);eq(b.outcome,"victory");eq(p.xp,288);eq(bench.xp,288);eq(b:getRewardSnapshot().awards,2)
  eq(p.evs.spa,1);eq(p.evs.def,1);eq(bench.evs.spa,1);eq(bench.evs.def,1)
 end)
 test("Entry hazard faint uses actual incoming identity before XP/learning and normal replacement",function()
  local p,a,z=Pokemon("charmander",6),Pokemon("rattata",100),Pokemon("bulbasaur",6);z.hp=1
  own(p,{"spikes","whirlwind"});own(a,{"growl"});own(z,{"growl"})
  local session=sessionWith(p);local seen=0
  session.markSeen=function(owner,species)if species=="bulbasaur"then seen=seen+1 end;return GameSession.markSeen(owner,species)end
  local b=fresh(p,a,{session=session,enemyParty=roster(a,z)},"TRAINER");eq(session:pokedex().seen.bulbasaur,nil)
  one(b,"player","spikes");RulesRNG.seed(1)
  local turn={side="player",actor=p,key="whirlwind",move=moveData.whirlwind}
  b:runScript(function()local outcome=b:resolveTurn(turn);if outcome and outcome~="replacement"then return outcome end;return b:finishRound()end)
  settle(b,true);eq(z.hp,0);eq(b.enemy,z);assert(b:getLearningSnapshot().pending);eq(b:getRewardSnapshot().awards,1)
  eq(session:pokedex().seen.bulbasaur,true);eq(seen,1,"hazard-fainted opponent seen on actual entry exactly once")
  local before=RulesRNG.snapshot();for _=1,10 do b:update()end;eq(b.enemy,z);sameRNG(before)
  eq(learning(b),p);settle(b);eq(b.enemy,a);eq(b.outcome,nil);eq(p.xp,294);eq(p:hasMove("ember"),true);eq(b:getRewardSnapshot().latest.foe.species,"bulbasaur")
  eq(b.awardedEnemies[z],true);eq(b.awardedEnemies[a],nil);eq(z.pp.growl,40)
 end)
 test("Faint replacement after earlier phaze uses ordinary trainer announcement and retains reward markers",function()
  local b,p,a,z=trainerPair();RulesRNG.seed(1);one(b,"player","whirlwind");eq(b.enemy,z)
  z.hp=1;local text=one(b,"player","dragonRage",true);eq(b.enemy,a);eq(b.outcome,nil);eq(b.awardedEnemies[z],true)
  assert(text:find("TRAINER sent out RATTATA!",1,true));eq(b:getRewardSnapshot().awards,1)
  local before=RulesRNG.snapshot();eq(b:handleFaint(),nil);sameRNG(before);eq(b:getRewardSnapshot().awards,1)
 end)
 test("Forced exit invalidates stale phaze/queued callbacks and clears all member/side/weather owners",function()
  local b,p,a=trainerPair();local turn={side="player",actor=p,key="whirlwind",move=moveData.whirlwind}
  b:clearVolatiles();local before=RulesRNG.snapshot();eq(b:resolveTurn(turn),nil);eq(b:forceSwitch(a),nil)
  eq(next(b.conditions.members),nil);eq(next(b.conditions.sides.player),nil);eq(next(b.conditions.sides.enemy),nil);eq(b.effects:snapshot().weather,"none");sameRNG(before)
 end)
 test("Ordinary effect booleans are not terminal outcomes in the shared status pipeline",function()
  local p=Pokemon("pidgey",100);p.hp=1;local b=fresh(p,Pokemon("rattata",100));one(b,"player","roost")
  eq(b.outcome,nil);eq(b:phase(),"command");eq(p.pp.roost,9);assert(p.hp>1);eq(b:getForceSwitchSnapshot().present,false)
 end)
 test("Named Helping Hand singles attempt fails without an ally or move RNG and spends PP",function()
  local b=fresh(Pokemon("nidoranF",25),Pokemon("rattata",100));own(b.player,{"helpingHand"});RulesRNG.seed(14)
  local text=one(b,"player","helpingHand");eq(b.player.pp.helpingHand,19);eq(b.enemy.hp,b.enemy.maxHP);eq(b.player.statStages.atk,0)
  eq(RulesRNG.snapshot().rolls,0);eq(RulesRNG.snapshot().state,14);eq(b.outcome,nil);assert(text:find("no target",1,true))
 end)
 RulesRNG.restore(saved)
 return report
end
