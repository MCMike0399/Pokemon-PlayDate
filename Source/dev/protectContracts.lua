ProtectContracts={}
local function eq(a,b,s)assert(a==b,(s or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function own(p,keys)p.moves,p.pp={},{};for _,k in ipairs(keys)do p.moves[#p.moves+1]=k;p.pp[k]=moveData[k].pp end end
local function settle(b)local n,t=0,{};while b:phase()=="script"do n=n+1;assert(n<250,"stuck: "..tostring(b.message));assert(not b.pendingLearning,"unexpected learning");t[#t+1]=b.message;b.machine:get("script"):advance()end;return table.concat(t,"|")end
local function fresh(p,e)local b=Battle(p or Pokemon("squirtle",100),e or Pokemon("snorlax",100));settle(b);own(b.player,{"protect","harden"});own(b.enemy,{"tackle"});return b end
local function attempt(b,index)assert(b:selectMove(index or 1));return settle(b)end
local function same(before)local n=RulesRNG.snapshot();eq(n.state,before.state);eq(n.rolls,before.rolls)end
local function find(fn)for i=1,10000 do if fn(RulesRNG.new(i))then return i end end;error("bounded seed missing")end
local function missSeed()return find(function(r)r:random(1,1);return r:random(1,100)>33 end)end
function ProtectContracts.run()
 local saved=RulesRNG.snapshot();local report={ok=true,passed=0,failed=0,tests={}}
 local function test(name,fn)local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
 test("All425 protection flags are typed with332 protectable and Feint sole breaker",function()
  local count, protected, breaks = 0, 0, 0
  for key, move in pairs(PartyBattleContracts.generatedCatalog()) do
      count = count + 1
      eq(type(move.protectable), "boolean", key)
      eq(type(move.breaksProtect), "boolean", key)
      if move.protectable then protected = protected + 1 end
      if move.breaksProtect then
          breaks = breaks + 1
          eq(key, "feint")
      end
  end
  eq(count,425);eq(protected,332);eq(breaks,1);eq(moveData.protect.priority,4);eq(moveData.protect.pp,10);eq(moveData.protect.targetId,7);eq(#moveData.protect.effects,1)
  eq(moveData.feint.power,30);eq(moveData.feint.priority,2);eq(moveData.feint.targetId,10);eq(moveData.feint.contact,false);eq(moveData.feint.protectable,false)
 end)
 test("First Protect priority4 blocks actual faster attack before accuracy/critical/contact draws",function()
  local b=fresh(Pokemon("pikachu",100),Pokemon("snorlax",100));b.player.spe=1;RulesRNG.seed(2);local text=attempt(b)
  eq(b.player.hp,b.player.maxHP);eq(b.player.pp.protect,9);eq(b.enemy.pp.tackle,34);eq(b.enemy.status,nil);eq(RulesRNG.snapshot().rolls,1)
  assert(text:find("protected itself",1,true));eq(b:getConditionsSnapshot().player.protect,false);eq(b:getConditionsSnapshot().player.stall_counter,2);eq(b:getConditionsSnapshot().player.stall_remaining,1)
 end)
 test("Protect is installed during actual narration and cleared by normal turn boundary",function()
  local b=fresh();RulesRNG.seed(2);assert(b:selectMove(1));local n=0
  while b:phase()=="script"and b.message~="SQUIRTLE protected itself!"do n=n+1;assert(n<20);b.machine:get("script"):advance()end
  eq(b:getConditionsSnapshot().player.protect,true);local before=RulesRNG.snapshot();for _=1,20 do b:getConditionsSnapshot();b.effects:snapshot()end;same(before);settle(b);eq(b:getConditionsSnapshot().player.protect,false)
 end)
 test("Consecutive public Protect success doubles counter; failure then next attempt resets",function()
  local b=fresh();RulesRNG.seed(2);attempt(b);RulesRNG.seed(1);attempt(b);eq(b:getConditionsSnapshot().player.stall_counter,4);eq(b.player.pp.protect,8);eq(RulesRNG.snapshot().rolls,2)
  RulesRNG.seed(2);local text=attempt(b);assert(text:find("But it failed!",1,true));eq(b:getConditionsSnapshot().player.stall_counter,0);assert(b.player.hp<b.player.maxHP)
  RulesRNG.seed(2);attempt(b);eq(b:getConditionsSnapshot().player.stall_counter,2);eq(b.player.pp.protect,6);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Intervening real non-guard move expires stall rather than carrying streak forever",function()
  local b=fresh();own(b.enemy,{"harden"});attempt(b);attempt(b,2);eq(b:getConditionsSnapshot().player.stall_counter,0);RulesRNG.seed(2);attempt(b);eq(RulesRNG.snapshot().rolls,1);eq(b:getConditionsSnapshot().player.stall_counter,2)
 end)
 test("First guaranteed chance has zero draws; typed power-of-two boundaries use one draw",function()
  RulesRNG.seed(2);eq(BattleConditions.protectSucceeds(1),true);eq(RulesRNG.snapshot().rolls,0)
  for _,v in ipairs({{2,667870353},{4,2075547353},{8,595934059},{16,1931674765},{32,308188883},{64,1356184413},{128,1304691826}})do
   RulesRNG.seed(1407677000);eq(BattleConditions.protectSucceeds(v[1]),true);eq(RulesRNG.snapshot().rolls,1)
   RulesRNG.seed(v[2]);eq(BattleConditions.protectSucceeds(v[1]),false);eq(RulesRNG.snapshot().rolls,1)
  end
  local before=RulesRNG.snapshot();for _,bad in ipairs({0,3,255,257,"2",{},false})do eq(pcall(BattleConditions.protectSucceeds,bad),false)end;same(before)
 end)
 test("Saturated counter256 samples BOTH16bit draws and has real reproducible success",function()
  RulesRNG.seed(1917364174);eq(BattleConditions.protectSucceeds(256),true);local after=RulesRNG.snapshot();eq(after.state,1101463552);eq(after.rolls,2)
  RulesRNG.seed(2);eq(BattleConditions.protectSucceeds(256),false);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Public Protect reaches saturated counter and actually succeeds using reproducible rare pair",function()
  local b=fresh();RulesRNG.seed(2);attempt(b);eq(b:getConditionsSnapshot().player.stall_counter,2)
  for _,counter in ipairs({2,4,8,16,32,64,128})do
   eq(b:getConditionsSnapshot().player.stall_counter,counter);RulesRNG.seed(1475608308);attempt(b)
   eq(b:getConditionsSnapshot().player.stall_counter,math.min(256,counter*2));eq(RulesRNG.snapshot().state,1);eq(RulesRNG.snapshot().rolls,2)
  end
  eq(b.player.pp.protect,2);eq(b.player.hp,b.player.maxHP)
  -- Enemy choice advances2129965031 to1917364174; rare draws then reach
  --65536/1101463552, yielding maximal16bit values65535/65535.
  RulesRNG.seed(2129965031);attempt(b);eq(b.player.pp.protect,1);eq(b.player.hp,b.player.maxHP);eq(b:getConditionsSnapshot().player.stall_counter,256)
  eq(RulesRNG.snapshot().rolls,3);eq(RulesRNG.snapshot().state,1101463552)
 end)
 test("Rare branch preserves canonical decimal persistence and replay continuation",function()
  RulesRNG.seed(1917364174);local data=RulesRNG.toData();eq(data.seed,"1917364174");RulesRNG.seed(2);RulesRNG.restoreData(data)
  eq(BattleConditions.protectSucceeds(256),true);local state=RulesRNG.toData();eq(state.state,"1101463552");eq(state.rolls,"2");local nextValue=RulesRNG.random(1,100)
  RulesRNG.restoreData(state);eq(RulesRNG.random(1,100),nextValue)
 end)
 test("Two-draw saturation counter exhaustion rejects transactionally without partial RNG commit",function()
  RulesRNG.seed(1917364174);local before=RulesRNG.snapshot();before.rolls=2147483646;RulesRNG.restore(before);eq(pcall(BattleConditions.protectSucceeds,256),false);same(before);RulesRNG.seed(2)
 end)
 test("Last queued actor Protect fails without stall RNG or installing guard",function()
  local b=fresh();own(b.enemy,{"protect"});b.player.spe=999;RulesRNG.seed(2);local text=attempt(b)
  eq(b:getConditionsSnapshot().player.stall_counter,2);eq(b:getConditionsSnapshot().enemy.stall_counter,0);eq(b.enemy.pp.protect,9);eq(b.player.pp.protect,9);eq(RulesRNG.snapshot().rolls,1);assert(text:find("But it failed!",1,true))
  -- Reverse actual speed next turn: the existing player stall would normally
  -- sample1/2, but last-queued eligibility fails BEFORE that random gate.
  b.player.spe=1;RulesRNG.seed(2);attempt(b);eq(b:getConditionsSnapshot().player.stall_counter,0);eq(b:getConditionsSnapshot().enemy.stall_counter,2);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Real item-style enemy-only response cannot Protect after actor already finished",function()
  local b=fresh();own(b.enemy,{"protect"});RulesRNG.seed(2);b.effects:beginRound();b:runScript(function()b:resolveTurn(b:enemyTurn());return b:finishRound()end);settle(b)
  eq(b:getConditionsSnapshot().enemy.stall_counter,0);eq(b.enemy.pp.protect,9);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Status and PP gates precede Protect; blocked sleep cannot refresh previous stall",function()
  local b=fresh();attempt(b);b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1;RulesRNG.seed(2);attempt(b)
  eq(b.player.pp.protect,9);eq(b:getConditionsSnapshot().player.stall_counter,0);eq(b:getConditionsSnapshot().player.protect,false);assert(b.player.hp<b.player.maxHP)
 end)
 test("Public invalid phase/index/PP commands preserve protection/RNG/PP",function()
  local b=fresh();local before=RulesRNG.snapshot();for _,i in ipairs({0,3,-1,"protect",{key="protect"}})do eq(b:selectMove(i),false)end;same(before);eq(b.player.pp.protect,10);eq(b:getConditionsSnapshot().player.stall_counter,0)
  b.player.pp.protect=0;eq(b:selectMove(1),false);same(before);b.player.pp.protect=1;assert(b:selectMove(1));local now=RulesRNG.snapshot();eq(b:selectMove(1),false);same(now);settle(b);eq(b.player.pp.protect,0)
 end)
 test("Protection blocks primary status/stat changes, multi-hit sampling and secondaries",function()
  for _,key in ipairs({"thunderWave","tailWhip","doubleSlap","thunder","hurricane","closeCombat","rollout","toxic"})do
   local b=fresh();own(b.enemy,{key});RulesRNG.seed(2);attempt(b)
   eq(b.player.hp,b.player.maxHP,key);eq(b.player.status,nil,key);eq(b.player.confusion,nil,key);eq(b.player.statStages.def,0,key);eq(b.enemy.statStages.def,0,key);eq(b.enemy.statStages.spd,0,key)
   eq(b.enemy.pp[key],moveData[key].pp-1,key);eq(RulesRNG.snapshot().rolls,1,key);eq(b.conditions:lockedKey(b.enemy),nil,key)
  end
 end)
 test("Exhausted enemy Struggle is blocked with no HP/recoil/PP or rules draw",function()
  local b=fresh();b.enemy.pp.tackle=0;RulesRNG.seed(2);attempt(b);eq(b.player.hp,b.player.maxHP);eq(b.enemy.hp,b.enemy.maxHP);eq(b.enemy.pp.tackle,0);eq(b.player.pp.protect,9);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Explicit unprotectable Ghost Curse bypasses guard with actual HP cost/residual",function()
  local b=fresh(nil,Pokemon("gastly",100));own(b.enemy,{"curse"});RulesRNG.seed(2);attempt(b);eq(b:getConditionsSnapshot().player.cursed,true);eq(b.player.hp,149);eq(b.enemy.hp,85);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Rain always-hit Hurricane still stops at Protect before weather accuracy/secondary paths",function()
  local b=fresh();own(b.enemy,{"hurricane"});b:runScript(function()b.effects:setWeather("raindance")end);settle(b);RulesRNG.seed(2);attempt(b)
  eq(b.player.hp,b.player.maxHP);eq(b.player.confusion,nil);eq(b.enemy.pp.hurricane,9);eq(b.player.pp.protect,9);eq(b.effects:weatherId(),"raindance");eq(b.effects:snapshot().turns,4);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Protect stops OHKO before level/Sturdy/chance and avoids all damage RNG",function()
  local b=fresh();own(b.enemy,{"fissure"});RulesRNG.seed(2);attempt(b);eq(b.player.hp,b.player.maxHP);eq(b.enemy.pp.fissure,4);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Type immunity precedes guard, including Feint and explicit ThunderWave",function()
  local b=fresh(Pokemon("gastly",100));own(b.enemy,{"tackle"});RulesRNG.seed(2);local text=attempt(b);assert(text:find("doesn't affect",1,true));eq(RulesRNG.snapshot().rolls,1)
  b=fresh(Pokemon("sandshrew",100));own(b.enemy,{"thunderWave"});RulesRNG.seed(2);text=attempt(b);assert(text:find("doesn't affect",1,true));eq(b.player.status,nil);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Guard excludes source-self and field effects from actual metadata",function()
  for _,key in ipairs({"harden","rainDance","sandstorm","focusEnergy"})do
   local b=fresh();own(b.enemy,{key});RulesRNG.seed(2);attempt(b);eq(RulesRNG.snapshot().rolls,1,key)
   if key=="harden"then eq(b.enemy.statStages.def,1)elseif key=="focusEnergy"then eq(b:getConditionsSnapshot().enemy.focus_energy,true)else eq(b.effects:weatherId(),key=="rainDance"and"raindance"or"sandstorm")end
  end
 end)
 test("Poison/burn/seed/weather residuals are not stopped by target Protect",function()
  local b=fresh();b.player.status="poison";RulesRNG.seed(2);attempt(b);eq(b.player.hp,174);eq(b:getConditionsSnapshot().player.protect,false)
  b=fresh();b:runScript(function()b.effects:setWeather("sandstorm")end);settle(b);RulesRNG.seed(2);attempt(b);eq(b.player.hp,186)
 end)
 test("Blocked hits create no Assurance HP ledger/Rage boost or contact receipts",function()
  local b=fresh(Pokemon("pikachu",100));b.conditions:of(b.player).rage=true;RulesRNG.seed(2);assert(b:selectMove(1));local n=0
  while b:phase()=="script"and b.message~="PIKACHU protected itself!"do n=n+1;assert(n<20);b.machine:get("script"):advance()end
  b.machine:get("script"):advance();eq(b.message,"SNORLAX used TACKLE!");b.machine:get("script"):advance();eq(b.effects:damagedThisRound(b.player),false);eq(b.player.statStages.atk,0);eq(b.enemy.status,nil);eq(RulesRNG.snapshot().rolls,1);settle(b)
 end)
 test("Feint breaks real protection after accuracy, no contact reaction, preserving stall",function()
  local b=fresh(Pokemon("pikachu",100),Pokemon("squirtle",100));own(b.player,{"feint"});own(b.enemy,{"protect"});RulesRNG.seed(2);local text=attempt(b)
  assert(text:find("protection was broken",1,true));assert(b.enemy.hp<b.enemy.maxHP);eq(b.player.pp.feint,9);eq(b.enemy.pp.protect,9);eq(b:getConditionsSnapshot().enemy.stall_counter,2);eq(RulesRNG.snapshot().rolls,4)
  RulesRNG.seed(1);attempt(b);eq(b:getConditionsSnapshot().enemy.stall_counter,4);eq(b.player.pp.feint,8);eq(RulesRNG.snapshot().rolls,5)
  -- Defending Static would roll (and this seed would proc) on a real contact
  -- hit. GenV Feint is explicitly non-contact, including its breaking hit.
  b=fresh(Pokemon("snorlax",100),Pokemon("pikachu",100));own(b.player,{"feint"});own(b.enemy,{"protect"});RulesRNG.seed(2);attempt(b)
  eq(b.player.status,nil);eq(RulesRNG.snapshot().rolls,4);eq(b:getConditionsSnapshot().enemy.stall_counter,2)
 end)
 test("Feint damages unprotected targets in GenV instead of GenIV conditional failure",function()
  local b=fresh();own(b.player,{"feint"});own(b.enemy,{"harden"});RulesRNG.seed(2);attempt(b);assert(b.enemy.hp<b.enemy.maxHP);eq(b.player.pp.feint,9);eq(RulesRNG.snapshot().rolls,4)
 end)
 test("Missed Feint spends accuracy only and never breaks real protection",function()
  local b=fresh();own(b.player,{"feint"});own(b.enemy,{"protect"});b.player.statStages.acc=-6;b.enemy.statStages.eva=6;RulesRNG.seed(missSeed());assert(b:selectMove(1))
  local n=0;while b:phase()=="script"and not (b.message and b.message:find("attack missed",1,true))do n=n+1;assert(n<30);b.machine:get("script"):advance()end
  eq(b:getConditionsSnapshot().enemy.protect,true);eq(b:getConditionsSnapshot().enemy.stall_counter,2);eq(b.enemy.hp,b.enemy.maxHP);eq(b.player.pp.feint,9);eq(RulesRNG.snapshot().rolls,2);settle(b)
 end)
 test("Ghost-immune Feint never breaks protection or rolls accuracy",function()
  local b=fresh(nil,Pokemon("gastly",100));own(b.player,{"feint"});own(b.enemy,{"protect"});RulesRNG.seed(2);assert(b:selectMove(1));local n=0
  while b:phase()=="script"and not (b.message and b.message:find("doesn't affect",1,true))do n=n+1;assert(n<30);b.machine:get("script"):advance()end
  eq(b:getConditionsSnapshot().enemy.protect,true);eq(b.enemy.hp,b.enemy.maxHP);eq(RulesRNG.snapshot().rolls,1);settle(b)
 end)
 test("Native-C source-resolved Bide release blocked; retained actual PS bypass discrepancy explicit",function()
  local b=fresh(nil,Pokemon("snorlax",5));own(b.player,{"bide"});own(b.enemy,{"nightShade"});RulesRNG.seed(2);attempt(b);b:update();settle(b);eq(b:getConditionsSnapshot().player.bide_damage,10)
  own(b.enemy,{"protect"});b:update();settle(b);eq(b.enemy.hp,b.enemy.maxHP);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.bide,9);eq(b.enemy.pp.protect,9);eq(RulesRNG.snapshot().rolls,5)
 end)
 test("Charge preparation bypasses Protect, while actual second-turn release is blocked",function()
  for _,key in ipairs({"solarBeam","skullBash"})do
   local b=fresh();own(b.player,{key});own(b.enemy,{"protect"});RulesRNG.seed(2);attempt(b);eq(b.conditions:lockedKey(b.player),key);eq(b.enemy.hp,b.enemy.maxHP)
   if key=="skullBash"then eq(b.player.statStages.def,1)end;RulesRNG.seed(1);b:update();settle(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.enemy.hp,b.enemy.maxHP);eq(b.player.pp[key],moveData[key].pp-1);eq(RulesRNG.snapshot().rolls,2)
  end
 end)
 test("Protect cancels early rampage quietly and final rampage with real fatigue",function()
  for _,total in ipairs({2,3})do local b=fresh(Pokemon("venusaur",100));own(b.player,{"petalDance"});own(b.enemy,{"harden"});RulesRNG.seed(total==2 and 2 or 1);attempt(b)
   eq(b:getConditionsSnapshot().player.rampage_remaining,total-1);local hp=b.enemy.hp;own(b.enemy,{"protect"});RulesRNG.seed(2);b:update();settle(b);eq(b.enemy.hp,hp);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.petalDance,9)
   if total==2 then assert(b.player.confusion);eq(RulesRNG.snapshot().rolls,2)else eq(b.player.confusion,nil);eq(RulesRNG.snapshot().rolls,1)end
  end
 end)
 test("Actual switch clears stall/protection, preserves other field owner",function()
  local p,q=Pokemon("squirtle",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("snorlax",100);own(e,{"harden"});local b=Battle(p,e,nil,{party=party});settle(b);own(p,{"protect"});attempt(b)
  eq(b:getConditionsSnapshot().player.stall_counter,2);assert(b:chooseParty(2));settle(b);eq(b.conditions.members[p],nil);eq(b.player,q);eq(b:getConditionsSnapshot().player.stall_counter,0)
 end)
 test("Faint replacement clears guard/stall and ordinary exit discards all counters",function()
  local p,q=Pokemon("squirtle",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("snorlax",100);own(e,{"harden"});local b=Battle(p,e,nil,{party=party});settle(b);own(p,{"protect"});attempt(b);p.hp=0
  b:runScript(function()
   b:setDirection("enemy");local outcome=b:handleFaint("player");eq(outcome,"replacement")
   eq(b.conditions.members[p],nil,"faint cleanup before residual collection")
   return b:finishRound()
  end)
  settle(b);eq(b:phase(),"forcedSwitch")
  -- Residual enumeration installs an empty bookkeeping table even for the
  -- fainted active identity. Its presence is not a surviving volatile.
  local cleared=b.conditions.members[p];eq(type(cleared),"table")
  eq(next(cleared),nil,"no transient survives residual collection")
  eq(b.conditions:locked(p),nil);eq(b.conditions:lockedKey(p),nil)
  assert(b:chooseParty(2));settle(b);eq(b.player,q)
  eq(b.conditions.members[p],nil,"withdraw removes old identity")
  eq(b:getConditionsSnapshot().player.protect,false)
  eq(b:getConditionsSnapshot().player.stall_counter,0)
  eq(b.conditions:locked(q),nil);eq(b.conditions:lockedKey(q),nil)
  b:clearVolatiles();eq(next(b.conditions.members),nil)
  eq(next(b.conditions.sides.player),nil);eq(next(b.conditions.sides.enemy),nil)
 end)
 test("Repeated native scene draws/persistence do not advance guard or stall",function()
  local b=fresh();RulesRNG.seed(2);assert(b:selectMove(1));while b.message~="SQUIRTLE protected itself!"do b.machine:get("script"):advance()end
  local scene=BattleScene(b);scene:enter();local before=RulesRNG.snapshot();for _=1,30 do scene:draw();eq(b:getConditionsSnapshot().player.protect,true);eq(b:getConditionsSnapshot().player.stall_remaining,2)end;same(before)
  local data=assert(PokemonCodec.encode(b.player));eq(data.protect,nil);eq(data.stall,nil);scene:exit();b:clearVolatiles();eq(next(b.conditions.members),nil)
 end)
 RulesRNG.restore(saved);return report
end
