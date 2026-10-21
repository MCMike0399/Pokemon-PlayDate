SideContracts={}
local function eq(a,b,s)assert(a==b,(s or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function own(p,keys)p.moves,p.pp={},{};for _,k in ipairs(keys)do p.moves[#p.moves+1]=k;p.pp[k]=moveData[k].pp end end
local function settle(b)local n,t=0,{};while b:phase()=="script"do n=n+1;assert(n<300,"stuck: "..tostring(b.message));assert(not b.pendingLearning,"unexpected learning");t[#t+1]=b.message;b.machine:get("script"):advance()end;return table.concat(t,"|")end
local function fresh(p,e)local b=Battle(p or Pokemon("squirtle",100),e or Pokemon("snorlax",100));settle(b);own(b.player,{"harden"});own(b.enemy,{"harden"});return b end
local function side(b,kind,who)b:runScript(function()b:setDirection(who or "player");assert(SideConditionEffect(kind):apply(b))end);settle(b)end
local function act(b,index)assert(b:selectMove(index or 1));return settle(b)end
local function same(before)local n=RulesRNG.snapshot();eq(n.state,before.state);eq(n.rolls,before.rolls)end
local function setStatus(b,target,status,origin)b:runScript(function()b:setDirection("player");ApplyStatus(target,status,origin):apply(b)end);return settle(b)end
function SideContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
 test("Exact three side producers preserve target4 GenVPP30 25 30 and priorities",function()
  for _,v in ipairs({{"lightScreen",30},{"safeguard",25},{"tailwind",30}})do local m=moveData[v[1]];eq(m.pp,v[2]);eq(m.targetId,4);eq(m.priority,0);eq(m.protectable,false);eq(#m.effects,1)end
  eq(#Pokemon("pikachu",45).moves,4);eq(Pokemon("pikachu",45).moves[4],"lightScreen");eq(Pokemon("butterfree",36).moves[4],"safeguard");eq(Pokemon("butterfree",30).moves[4],"tailwind")
  for _,v in ipairs({{"pidgey",41},{"pidgeotto",47},{"pidgeot",50}})do eq(Pokemon(v[1],v[2]).moves[4],"tailwind")end
 end)
 test("Actual side producers tick5 5 4 once perround and refuse timer refresh",function()
  for _,v in ipairs({{"lightScreen",5},{"safeguard",5},{"tailwind",4}})do
   local b=fresh();own(b.player,{v[1],"harden"});RulesRNG.seed(2);act(b);eq(b.conditions:sideTurns(b.player,v[1]),v[2]-1);eq(b.player.pp[v[1]],moveData[v[1]].pp-1);eq(RulesRNG.snapshot().rolls,1)
   local text=act(b);assert(text:find("But it failed!",1,true));eq(b.conditions:sideTurns(b.player,v[1]),v[2]-2)
   for expected=v[2]-3,0,-1 do act(b,2);eq(b.conditions:sideTurns(b.player,v[1]),expected)end
   eq(b.conditions.sides.player[v[1]],nil)
  end
 end)
 test("Unsupported family names and unowned source reject without side allocation or RNG",function()
  local b=fresh();local before=RulesRNG.snapshot();for _,kind in ipairs({"reflect","mist","auroraVeil",{},false})do eq(pcall(SideConditionEffect,kind),false);eq(b.conditions:setSideCondition(kind),false)end
  eq(b.conditions:setSideCondition("tailwind"),false);eq(next(b.conditions.sides.player),nil);same(before)
 end)
 test("Side snapshots foreignmon and pure speed/damage queries are inert",function()
  local b=fresh();local foreign=Pokemon("squirtle",100);side(b,"tailwind");local before=RulesRNG.snapshot();local members=b.conditions.members
  for _=1,30 do eq(b:effectiveSpeed(b.player),182);eq(b:effectiveSpeed(foreign),91);eq(b.conditions:sideTurns(foreign,"tailwind"),0);b:getConditionsSnapshot()end
  eq(b.conditions.members,members);eq(members[foreign],nil);eq(b.conditions:sideTurns(b.player,"reflect"),0);same(before)
 end)
 test("Actual shared effectiveSpeed doubles BEFORE GenVparalysisfloor with minimum1",function()
  local b=fresh();b.player.spe=7;eq(b:effectiveSpeed(b.player),7);b.player.status="paralyze";eq(b:effectiveSpeed(b.player),1);side(b,"tailwind");eq(b:effectiveSpeed(b.player),3)
  b.player.status=nil;eq(b:effectiveSpeed(b.player),14);b.player.spe=1;b.player.status="paralyze";eq(b:effectiveSpeed(b.player),1)
 end)
 test("GenV turn queue remains frozen and only next command uses new Tailwind speed",function()
  local b=fresh(Pokemon("pidgey",41),Pokemon("metapod",100));own(b.player,{"tailwind","wingAttack"});local original=b.effectiveSpeed;local calls=0
  b.effectiveSpeed=function(self,mon)calls=calls+1;return original(self,mon)end
  RulesRNG.seed(2);assert(b:selectMove(1));eq(calls,2);local text=settle(b);assert(text:find("METAPOD used HARDEN!",1,true)<text:find("PIDGEY used TAILWIND!",1,true));eq(b:effectiveSpeed(b.player),100)
  -- Residual callbacks may query updated speed; the next actual selected move
  -- must nevertheless order once atcommit, not a Gen8 midqueue resort.
  RulesRNG.seed(2);text=act(b,2);assert(text:find("PIDGEY used WING ATTACK!",1,true)<text:find("METAPOD used HARDEN!",1,true));eq(b.enemy.hp,192);eq(b.player.pp.tailwind,29)
 end)
 test("ElectroBall pure power immediately shares active side speed without mutation",function()
  local b=fresh(Pokemon("pikachu",50),Pokemon("snorlax",100));b.player.spe=65;b.enemy.spe=65;eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),60);side(b,"tailwind");local before=RulesRNG.snapshot();eq(b:effectiveMovePower(moveData.electroBall,b.player,b.enemy),80);same(before)
 end)
 test("Side timers use own suborders and exactly one pairedside tie perkind not activeSpeed",function()
  local b=fresh();for _,who in ipairs({"player","enemy"})do for _,kind in ipairs({"lightScreen","safeguard","tailwind"})do side(b,kind,who)end end
  assert(b:effectiveSpeed(b.player)~=b:effectiveSpeed(b.enemy));RulesRNG.seed(2);b:runScript(function()return b:finishRound()end);settle(b)
  eq(RulesRNG.snapshot().rolls,3);for _,who in ipairs({"player","enemy"})do eq(b.conditions.sides[who].lightScreen.turns,4);eq(b.conditions.sides[who].safeguard.turns,4);eq(b.conditions.sides[who].tailwind.turns,3)end
 end)
 test("Side expiry follows weather and status, and stale duplicate timer events cannot tick",function()
  local b=fresh();side(b,"lightScreen");local event;for _,e in ipairs(b.conditions:events())do if e.kind=="sideTimer"then event=e end end;assert(event);local before=RulesRNG.snapshot()
  b.conditions:residual(event);eq(b.conditions:sideTurns(b.player,"lightScreen"),4);b.conditions:residual(event);eq(b.conditions:sideTurns(b.player,"lightScreen"),4);same(before)
  b:clearVolatiles();b.conditions:residual(event);eq(next(b.conditions.sides.player),nil);same(before)
 end)
 test("LightScreen exact final modifier halves15 to7; physical fixed crit self bypass",function()
  local b=fresh(Pokemon("squirtle",50),Pokemon("snorlax",50));side(b,"lightScreen","enemy");local before=RulesRNG.snapshot()
  eq(b.conditions:screenDamage(b.player,b.enemy,moveData.waterGun,15,false),7);eq(b.conditions:screenDamage(b.player,b.enemy,moveData.tackle,18,false),18);eq(b.conditions:screenDamage(b.player,b.enemy,moveData.waterGun,30,true),30);eq(b.conditions:screenDamage(b.enemy,b.enemy,moveData.waterGun,15,false),15);same(before)
  RulesRNG.seed(2);eq(calcDamage(b.player,b.enemy,moveData.waterGun,40,b.effects).damage,6);eq(RulesRNG.snapshot().rolls,2)
  RulesRNG.seed(1407677000);local critical=calcDamage(b.player,b.enemy,moveData.waterGun,40,b.effects);eq(critical.isCrit,true);eq(critical.damage,27);eq(RulesRNG.snapshot().rolls,2)
  eq(b.conditions:screenDamage(b.player,b.enemy,moveData.dragonRage,40,false),40)
  local hp=b.enemy.hp;b:runScript(function()b:setDirection("player");b.currentMove=moveData.dragonRage;DirectDamage(DEFENDER,40):apply(b)end);settle(b);eq(hp-b.enemy.hp,40)
 end)
 test("Natural Pikachu100 screen vs Sandshrew11 Swift is actual successful0HP hit",function()
  local b=fresh(Pokemon("pikachu",100),Pokemon("sandshrew",11));own(b.player,{"lightScreen"});own(b.enemy,{"swift"});RulesRNG.seed(2);local text=act(b)
  eq(b.player.hp,180);eq(b.player.pp.lightScreen,29);eq(b.enemy.pp.swift,19);eq(b.lastDamage,0);eq(RulesRNG.snapshot().rolls,3);assert(text:find("took 0 damage",1,true));eq(b.isFlashing,true)
 end)
 test("ZeroHP contact hit starts real rampage and samples Static with no HP ledger",function()
  local b=fresh(Pokemon("bulbasaur",5),Pokemon("pikachu",100));own(b.player,{"petalDance"});own(b.enemy,{"lightScreen"});b.player.statStages.spa=-6;RulesRNG.seed(2);assert(b:selectMove(1))
  local n=0;while b:phase()=="script"and not(b.message and b.message:find("took 0 damage",1,true))do n=n+1;assert(n<30);b.machine:get("script"):advance()end
  eq(b.effects:damagedThisRound(b.enemy),false);settle(b);eq(b.enemy.hp,180);eq(b.player.status,nil);eq(b:getConditionsSnapshot().player.rampage_total,2);eq(b:getConditionsSnapshot().player.rampage_remaining,1);eq(b.player.pp.petalDance,9);eq(RulesRNG.snapshot().rolls,6)
 end)
 test("Successful zeroHP Swift builds living Rage receiver while HP ledgers stay unchanged",function()
  local b=fresh(Pokemon("sandshrew",11),Pokemon("onix",14));own(b.player,{"swift"});own(b.enemy,{"rage"});side(b,"lightScreen","enemy");b.player.statStages.spa=-6;b.enemy.statStages.spd=6
  RulesRNG.seed(2);local text=act(b);eq(b.enemy.hp,b.enemy.maxHP);eq(b.player.hp,29);eq(b.enemy.statStages.atk,1);eq(b.lastDamage,0);assert(text:find("rage is building",1,true));eq(RulesRNG.snapshot().rolls,6)
 end)
 test("Protect miss immunity and forged/dead receipts remain nonhits not0HP successes",function()
  local b=fresh(Pokemon("bulbasaur",5),Pokemon("pikachu",100));own(b.player,{"petalDance"});own(b.enemy,{"protect"});b.player.statStages.spa=-6;RulesRNG.seed(2);act(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.status,nil);eq(b.enemy.hp,180);eq(RulesRNG.snapshot().rolls,1)
  local before=RulesRNG.snapshot();eq(b.effects:afterHit({source=b.player,target=b.enemy,before=180,removed=0,contact=true}),false);same(before)
  b.enemy.hp=0;local receipt=b.effects:hit(b.player,b.enemy,moveData.petalDance,0);eq(b.effects:afterHit(receipt),false);same(before)
 end)
 test("Safeguard blocks opponent primary majors/confusion before duration but not flinch",function()
  for _,status in ipairs({"poison","badPoison","burn","paralyze","sleep","freeze","confuse"})do
   local b=fresh(nil,Pokemon("squirtle",100));side(b,"safeguard","enemy");RulesRNG.seed(2);setStatus(b,DEFENDER,status);eq(b.enemy.status,nil,status);eq(b.enemy.confusion,nil,status);eq(b.enemy.statusTurns,0,status);eq(RulesRNG.snapshot().rolls,0,status)
  end
  local b=fresh();side(b,"safeguard","enemy");RulesRNG.seed(2);setStatus(b,DEFENDER,"flinch");eq(b.enemy.flinched,true);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Ability immunity including WorrySeed Insomnia precedes Safeguard without duration RNG",function()
  local b=fresh(nil,Pokemon("slowpoke",100,{natureId=0,abilitySlot="second",heldItem="none"}));side(b,"safeguard","enemy");RulesRNG.seed(2);local text=setStatus(b,DEFENDER,"confuse");assert(text:find("Own Tempo",1,true));assert(not text:find("Safeguard",1,true));eq(b.enemy.confusion,nil);eq(RulesRNG.snapshot().rolls,0)
  b=fresh();side(b,"safeguard","enemy");b:runScript(function()b:setDirection("player");assert(b.effects:worrySeed(b.player,b.enemy))end);settle(b);eq(b.effects:effectiveAbility(b.enemy),15);RulesRNG.seed(2);text=setStatus(b,DEFENDER,"sleep");assert(text:find("Insomnia",1,true));assert(not text:find("Safeguard",1,true));eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Source-self sleep and late residual fatigue pass Safeguard with explicit provenance",function()
  local b=fresh();side(b,"safeguard");RulesRNG.seed(2);setStatus(b,ATTACKER,"sleep");eq(b.player.status,"sleep");eq(b.player.sleepDuration,2);eq(RulesRNG.snapshot().rolls,1)
  b=fresh(Pokemon("venusaur",100));own(b.player,{"petalDance"});side(b,"safeguard");RulesRNG.seed(2);act(b);eq(b:getConditionsSnapshot().player.rampage_remaining,1);b.player.flinched=true;RulesRNG.seed(2);b:update();settle(b)
  assert(b.player.confusion);eq(b.conditions:lockedKey(b.player),nil);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("New Safeguard never cures existing major/confusion or stops existing status damage",function()
  local b=fresh();b.player.status="poison";b.player.confusion=2;side(b,"safeguard");eq(b.player.status,"poison");eq(b.player.confusion,2)
  b:runScript(function()return b:finishRound()end);settle(b);eq(b.player.hp,174);eq(b.player.status,"poison");eq(b.player.confusion,2)
 end)
 test("Contact dealer is concrete opponent evenKO; Safeguard stops ability status not chance",function()
  local b=fresh(Pokemon("bulbasaur",100),Pokemon("pikachu",100));own(b.player,{"tackle"});b.enemy.hp=1;side(b,"safeguard");RulesRNG.seed(2);local text=act(b)
  eq(b.enemy.hp,0);eq(b.player.status,nil);eq(b.player.pp.tackle,34);eq(RulesRNG.snapshot().rolls,5);assert(text:find("Static",1,true));assert(text:find("Safeguard",1,true))
 end)
 test("Origin schema rejects malformed source cause before effect mutation",function()
  local b=fresh();local before=RulesRNG.snapshot();for _,origin in ipairs({false,{},{source=ATTACKER,cause="guess"},{source={},cause="move"},{source=ATTACKER,cause="move",extra=true},{source=ATTACKER,cause="fatigue"}})do
   eq(pcall(ApplyStatus,DEFENDER,"sleep",origin),false)
  end;eq(b.enemy.status,nil);same(before)
 end)
 test("RapidSpin removes only hazards and bindings while preserving all side timers",function()
  local b=fresh();for _,kind in ipairs({"lightScreen","safeguard","tailwind"})do side(b,kind)end
  b:runScript(function()b:setDirection("enemy");for _,kind in ipairs({"spikes","toxicSpikes","stealthRock"})do b.conditions:hazard(kind)end end);settle(b)
  own(b.player,{"rapidSpin"});RulesRNG.seed(2);act(b);local state=b.conditions.sides.player
  eq(state.spikes,nil);eq(state.toxicSpikes,nil);eq(state.stealthRock,nil);eq(state.order,nil);eq(state.hazardOrigins,nil);eq(state.lightScreen.turns,4);eq(state.safeguard.turns,4);eq(state.tailwind.turns,3);eq(b.player.statStages.spe,0);eq(RulesRNG.snapshot().rolls,4)
 end)
 test("Actual switch and forced faint preserve side owner lifetime until exit",function()
  local p,q=Pokemon("squirtle",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("snorlax",100);own(e,{"harden"});local b=Battle(p,e,nil,{party=party});settle(b);side(b,"tailwind");assert(b:chooseParty(2));settle(b)
  eq(b.player,q);eq(b.conditions:sideTurns(q,"tailwind"),3);eq(b:effectiveSpeed(q),234);eq(b.conditions.members[p],nil)
  q.hp=0;b:runScript(function()b:setDirection("enemy");eq(b:handleFaint("player"),"replacement");return b:finishRound()end);settle(b);eq(b:phase(),"forcedSwitch");eq(b.conditions.sides.player.tailwind.turns,2)
  assert(b:chooseParty(1));settle(b);eq(b:effectiveSpeed(p),182);eq(b.conditions:sideTurns(p,"tailwind"),2);b:clearVolatiles();eq(next(b.conditions.sides.player),nil)
 end)
 test("Actual ToxicSpikes setter origin persists after KO inactive replacement and guards entry",function()
  local p,q=Pokemon("butterfree",100),Pokemon("squirtle",100);local party=Party();assert(party:add(p));assert(party:add(q));local e,reserve=Pokemon("beedrill",100),Pokemon("snorlax",100);own(p,{"safeguard"});own(e,{"toxicSpikes"});own(reserve,{"harden"});local enemies=Party();assert(enemies:add(e));assert(enemies:add(reserve))
  local b=Battle(p,e,"ORIGIN",{party=party,enemyParty=enemies});settle(b);RulesRNG.seed(2);act(b);local origin=b.conditions.sides.player.hazardOrigins.toxicSpikes;eq(origin.source,e);eq(origin.side,"enemy");eq(origin.cause,"toxicSpikes")
  e.hp=0;b:runScript(function()b:setDirection("player");eq(b:handleFaint("enemy"),"replacement");return b:finishRound()end);settle(b);eq(b.enemy,reserve);eq(e.hp,0)
  assert(b:chooseParty(2));local text=settle(b);eq(b.player,q);eq(q.status,nil);assert(text:find("Safeguard",1,true));eq(b.conditions.sides.player.hazardOrigins.toxicSpikes,origin);eq(origin.source,e)
 end)
 test("Poison absorber removes ToxicSpikes origin even while Safeguard remains active",function()
  local b=fresh(Pokemon("bulbasaur",100));side(b,"safeguard");b:runScript(function()b:setDirection("enemy");b.conditions:hazard("toxicSpikes");b.conditions:entry(b.player,"player")end);settle(b)
  eq(b.conditions.sides.player.toxicSpikes,nil);eq(b.conditions.sides.player.hazardOrigins.toxicSpikes,nil);eq(b.player.status,nil);eq(b.conditions:sideTurns(b.player,"safeguard"),5)
 end)
 test("Native scene draws and codecpersistence never tick side or copy volatile records",function()
  local b=fresh();for _,kind in ipairs({"lightScreen","safeguard","tailwind"})do side(b,kind)end;local scene=BattleScene(b);scene:enter();local before=RulesRNG.snapshot()
  for _=1,30 do scene:draw();eq(b.conditions:sideTurns(b.player,"lightScreen"),5);eq(b.conditions:sideTurns(b.player,"safeguard"),5);eq(b.conditions:sideTurns(b.player,"tailwind"),4)end;same(before)
  local data=assert(PokemonCodec.encode(b.player));eq(data.lightScreen,nil);eq(data.safeguard,nil);eq(data.tailwind,nil);scene:exit();b:clearVolatiles();eq(next(b.conditions.sides.player),nil)
 end)
 RulesRNG.restore(saved);return report
end
