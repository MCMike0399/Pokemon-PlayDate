RainContracts={}
local function eq(a,b,s)assert(a==b,(s or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function own(p,keys)p.moves,p.pp={},{};for _,k in ipairs(keys)do p.moves[#p.moves+1]=k;p.pp[k]=moveData[k].pp end end
local function settle(b)local n,lines=0,{};while b:phase()=="script"do n=n+1;assert(n<250,"stuck: "..tostring(b.message));assert(not b.pendingLearning,"unexpected XP learning");lines[#lines+1]=b.message;b.machine:get("script"):advance()end;return table.concat(lines,"|")end
local function fresh(p,e)local b=Battle(p or Pokemon("squirtle",100),e or Pokemon("snorlax",100));settle(b);own(b.player,{"rainDance","waterGun","ember","synthesis"});own(b.enemy,{"harden"});return b end
local function weather(b,id)b:runScript(function()assert(b.effects:setWeather(id))end);settle(b)end
local function rngSame(before)local n=RulesRNG.snapshot();eq(n.state,before.state,"RNG state");eq(n.rolls,before.rolls,"RNG rolls")end
function RainContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
 test("Exact rain producer and two weather accuracy rows preserve GenV scalar data",function()
  eq(moveData.rainDance.pp,5);eq(moveData.rainDance.accuracy,0);eq(moveData.rainDance.targetId,12);eq(#moveData.rainDance.effects,1)
  for _,k in ipairs({"thunder","hurricane"})do eq(moveData[k].weatherAccuracy,true);eq(moveData[k].power,120);eq(moveData[k].accuracy,70);eq(moveData[k].pp,10)end
  eq(moveData.thunderbolt.weatherAccuracy,false);eq(moveData.solarBeam.weatherAccuracy,false)
 end)
 test("Real RainDance PP4 no accuracy/duration draw and first residual leaves4",function()
  local b=fresh();RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(b.effects:snapshot().weather,"raindance");eq(b.effects:snapshot().turns,4);eq(b.player.pp.rainDance,4);eq(RulesRNG.snapshot().rolls,1);eq(b.player.hp,b.player.maxHP);eq(b.enemy.hp,b.enemy.maxHP)
 end)
 test("Same rain fails consumes real attempted PP but never refreshes timer",function()
  local b=fresh();RulesRNG.seed(2);assert(b:selectMove(1));settle(b);assert(b:selectMove(1));local text=settle(b)
  assert(text:find("But it failed!",1,true));eq(b.effects:snapshot().turns,3);eq(b.player.pp.rainDance,3);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Five-turn weather expires after exactly five actual round boundaries",function()
  local b=fresh();own(b.player,{"rainDance","harden"});RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
  for _,n in ipairs({3,2,1})do assert(b:selectMove(2));settle(b);eq(b.effects:snapshot().turns,n)end
  assert(b:selectMove(2));local text=settle(b);eq(b.effects:weatherId(),"none");eq(b.effects:snapshot().turns,0);assert(text:find("The rain stopped.",1,true));eq(RulesRNG.snapshot().rolls,5)
 end)
 test("Rain replaces Sand and Sand replaces Rain with new5; same Sand fails",function()
  local b=fresh();RulesRNG.seed(2);weather(b,"sandstorm");eq(b.effects:snapshot().turns,5);weather(b,"raindance");eq(b.effects:weatherId(),"raindance");eq(b.effects:snapshot().turns,5)
  weather(b,"sandstorm");eq(b.effects:weatherId(),"sandstorm");eq(b.effects:snapshot().turns,5);local ok,why;b:runScript(function()ok,why=b.effects:setWeather("sandstorm")end);settle(b);eq(ok,false);eq(why,"same-weather");eq(b.effects:snapshot().turns,5);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Unsupported weather/closed owner reject without narration, state allocation or RNG",function()
  local b=fresh();local before=RulesRNG.snapshot();for _,id in ipairs({"sunnyday","hail","snowscape",false,0,{}})do eq(b.effects:setWeather(id),false);eq(b.effects.weather,nil)end;rngSame(before)
  b.effects:close();eq(b.effects:setWeather("raindance"),false);eq(b.effects.weather,nil);rngSame(before)
 end)
 test("Rejected public commands cannot start rain or spend PP/RNG",function()
  local b=fresh();local before=RulesRNG.snapshot();for _,i in ipairs({0,-1,99,"rainDance",{key="rainDance"}})do eq(b:selectMove(i),false)end;eq(b.player.pp.rainDance,5);eq(b.effects.weather,nil);rngSame(before)
 end)
 test("Sleep gate blocks RainDance before PP/producer but enemy choice remains real",function()
  local b=fresh();b.player.status,b.player.statusTurns,b.player.sleepDuration="sleep",1,1;RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
  eq(b.effects.weather,nil);eq(b.player.pp.rainDance,5);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Rain has no Sand residual damage events or Sand cohort tie draws",function()
  local b=fresh();weather(b,"raindance");local events=b.effects:events();eq(#events,1);eq(events[1].kind,"weatherTick");b.player.spe=b.enemy.spe;local before=RulesRNG.snapshot()
  b:runScript(function()b:finishRound()end);settle(b);eq(b.player.hp,b.player.maxHP);eq(b.enemy.hp,b.enemy.maxHP);rngSame(before)
 end)
 test("Rain cannot activate SandVeil or Rock special-defense bonus",function()
  local b=fresh(nil,Pokemon("sandshrew",100));weather(b,"raindance");eq(b.effects:accuracy(b.player,b.enemy,moveData.tackle),100)
  weather(b,"sandstorm");eq(b.effects:accuracy(b.player,b.enemy,moveData.tackle),80);weather(b,"raindance");eq(b.effects:accuracy(b.player,b.enemy,moveData.tackle),100)
  local rock=Pokemon("geodude",100);eq(b.effects:defenseStat(rock,moveData.waterGun,65),65);weather(b,"sandstorm");eq(b.effects:defenseStat(rock,moveData.waterGun,65),97)
 end)
 test("Literal odd BASE damage weather vectors match actual pinned PS half-down",function()
  local b=fresh();weather(b,"raindance");local before=RulesRNG.snapshot()
  for _,v in ipairs({{1,1,0},{3,4,1},{5,7,2},{7,10,3},{9,13,4},{11,16,5},{13,19,6},{15,22,7}})do
   eq(b.effects:weatherDamage(moveData.waterGun,v[1]),v[2]);eq(b.effects:weatherDamage(moveData.ember,v[1]),v[3]);eq(b.effects:weatherDamage(moveData.tackle,v[1]),v[1])
  end;rngSame(before)
 end)
 test("Weather damage precedes crit/random/STAB and does not mutate raw power",function()
  local b=fresh(Pokemon("squirtle",50),Pokemon("snorlax",50));weather(b,"raindance");eq(b:effectiveMovePower(moveData.waterGun,b.player,b.enemy),40)
  RulesRNG.seed(2);local hit=calcDamage(b.player,b.enemy,moveData.waterGun,40,b.effects);eq(hit.damage,18);eq(hit.isCrit,false);eq(RulesRNG.snapshot().rolls,2)
  RulesRNG.seed(2);local fire=calcDamage(b.player,b.enemy,moveData.ember,40,b.effects);eq(fire.damage,4);eq(RulesRNG.snapshot().rolls,2)
 end)
 test("Critical odd base weather rounding occurs BEFORE doubling",function()
  local b=fresh();weather(b,"raindance");local p,d=b.player,b.enemy;p.spa=5;d.spd=100
  local move={power=40,category="special",type="fire",willCrit=true,critStage=0};RulesRNG.seed(2);local hit=calcDamage(p,d,move,40,b.effects)
  -- Base3 -> rain1 -> crit2 -> seeded85..100 factor98 ->1; if weather
  -- were wrongly delayed until after crit, 3*2/2=3 -> random2.
  eq(hit.damage,1);eq(hit.isCrit,true);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Direct fixed damage unaffected by rain and consumes no weather RNG",function()
  local b=fresh();weather(b,"raindance");RulesRNG.seed(2);local hp=b.enemy.hp
  b:runScript(function()b:setDirection("player");b.currentMove=moveData.dragonRage;DirectDamage(DEFENDER,40):apply(b)end);settle(b);eq(hp-b.enemy.hp,40);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Rain Thunder/Hurricane ignore extreme stages without accuracy RNG; ordinary100 still rolls",function()
  local b=fresh();weather(b,"raindance");b.player.statStages.acc=-6;b.enemy.statStages.eva=6;local before=RulesRNG.snapshot()
  for _,key in ipairs({"thunder","hurricane"})do eq(accuracyThreshold(moveData[key],b.player,b.enemy,b.effects),100);eq(checkAccuracy(moveData[key],b.player,b.enemy,b.effects),true)end;rngSame(before)
  checkAccuracy(moveData.tackle,b.player,b.enemy,b.effects);eq(RulesRNG.snapshot().rolls,before.rolls+1)
 end)
 test("Clear/Sand restore70 base weather-move accuracy and normal stage RNG",function()
  local b=fresh();eq(accuracyThreshold(moveData.thunder,b.player,b.enemy,b.effects),70);weather(b,"sandstorm");eq(accuracyThreshold(moveData.hurricane,b.player,b.enemy,b.effects),70)
  local before=RulesRNG.snapshot();checkAccuracy(moveData.thunder,b.player,b.enemy,b.effects);eq(RulesRNG.snapshot().rolls,before.rolls+1)
 end)
 test("Rain immunity still precedes accuracy/crit/secondary, spending PP once",function()
  local b=fresh(nil,Pokemon("sandshrew",100));own(b.player,{"thunder"});weather(b,"raindance");RulesRNG.seed(2);assert(b:selectMove(1));local hp=b.enemy.hp;settle(b)
  eq(b.enemy.hp,hp);eq(b.enemy.status,nil);eq(b.player.pp.thunder,9);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Actual rain attacks hit with their real secondary/PP order; no accuracy draw",function()
  for _,key in ipairs({"thunder","hurricane"})do
   local b=fresh();own(b.player,{key});b.player.statStages.acc=-6;b.enemy.statStages.eva=6;weather(b,"raindance");RulesRNG.seed(2);assert(b:selectMove(1))
   -- Seed2: AI1, crit2, variance3, chance4=16. Pause at the actual
   -- secondary narration BEFORE slower Snorlax attempts Harden, proving no
   -- accuracy draw. The enemy's real status gate then has its own RNG.
   local message=key=="hurricane" and "SNORLAX became confused!" or "SNORLAX is paralyzed!";local n=0
   while b:phase()=="script"and b.message~=message do n=n+1;assert(n<30,"missing secondary boundary: "..tostring(b.message));b.machine:get("script"):advance()end
   eq(b.message,message);eq(b.enemy.pp.harden,30);eq(RulesRNG.snapshot().rolls,key=="hurricane"and 5 or 4);eq(RulesRNG.snapshot().state,key=="hurricane"and 140734213 or 1969887316)
   settle(b);assert(b.enemy.hp<b.enemy.maxHP);eq(b.player.pp[key],9)
   if key=="hurricane"then
    -- Duration5=1, confusion gate6=2 permits Harden; no self-hit variance.
    eq(b.enemy.confusion,0);eq(b.enemy.pp.harden,29);eq(b.enemy.statStages.def,1);eq(RulesRNG.snapshot().rolls,6);eq(RulesRNG.snapshot().state,940422544)
   else
    -- Paralysis gate5=1 blocks Harden before its PP commit.
    eq(b.enemy.status,"paralyze");eq(b.enemy.pp.harden,30);eq(b.enemy.statStages.def,0);eq(RulesRNG.snapshot().rolls,5);eq(RulesRNG.snapshot().state,140734213)
   end
  end
 end)
 test("ShieldDust still prevents chance/duration after always-hit Hurricane",function()
  local b=fresh(nil,Pokemon("caterpie",100));own(b.player,{"hurricane"});weather(b,"raindance");b.player.spa=5;RulesRNG.seed(2);assert(b:selectMove(1));settle(b)
  eq(b.enemy.confusion,nil);eq(b.player.pp.hurricane,9);eq(RulesRNG.snapshot().rolls,3)
 end)
 test("Explicit unproduced Sun query uses50 regular accuracy, never rain bypass",function()
  local b=fresh();b.effects.weatherId=function()return "sunnyday"end;eq(accuracyThreshold(moveData.thunder,b.player,b.enemy,b.effects),50);eq(b.effects:accuracyBypassesCheck(moveData.hurricane),false)
  local before=RulesRNG.snapshot();checkAccuracy(moveData.hurricane,b.player,b.enemy,b.effects);eq(RulesRNG.snapshot().rolls,before.rolls+1);eq(b.effects.weather,nil)
 end)
 test("Synthesis quarter recovery under Rain, half clear, rounded odd maximum145",function()
  local b=fresh(Pokemon("venusaur",52));eq(b.player.maxHP,145);eq(b.effects:weatherHeal(b.player),72);weather(b,"raindance");eq(b.effects:weatherHeal(b.player),36)
  b.player.hp=1;own(b.player,{"synthesis"});RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(b.player.hp,37);eq(b.player.pp.synthesis,4);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("FullHP Synthesis fails honestly while consuming attempted PP, no heal RNG",function()
  local b=fresh();own(b.player,{"synthesis"});weather(b,"raindance");RulesRNG.seed(2);assert(b:selectMove(1));local text=settle(b);assert(text:find("But it failed!",1,true));eq(b.player.hp,b.player.maxHP);eq(b.player.pp.synthesis,4);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Rain halves Solar at release, still requires actual charge, no PowerHerb invented",function()
  local b=fresh(Pokemon("venusaur",100));own(b.player,{"solarBeam"});weather(b,"raindance");RulesRNG.seed(2);assert(b:selectMove(1));settle(b);eq(b.conditions:lockedKey(b.player),"solarBeam");eq(b:effectiveMovePower(moveData.solarBeam,b.player,b.enemy),60)
  b:update();settle(b);eq(b.conditions:lockedKey(b.player),nil);eq(b.player.pp.solarBeam,9);eq(b.enemy.hp,369);eq(RulesRNG.snapshot().rolls,5)
 end)
 test("Rain does not disturb combined Rivalry/MudSport power or LightBall attack hooks",function()
  local b=fresh(Pokemon("pikachu",100));b.player.heldItem="lightBall";weather(b,"raindance");eq(b.effects:attackStat(b.player,moveData.thunder,105),210)
  b.conditions:of(b.player).mudSport=true;eq(b:effectiveMovePower(moveData.thunder,b.player,b.enemy),40);eq(b:effectiveMovePower(moveData.waterGun,b.player,b.enemy),40)
 end)
 test("Weather survives actual voluntary switching without inheriting volatile stages",function()
  local p,q=Pokemon("squirtle",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local e=Pokemon("snorlax",100);own(e,{"harden"})
  local b=Battle(p,e,nil,{party=party});settle(b);weather(b,"raindance");p.statStages.def=2;RulesRNG.seed(2);assert(b:chooseParty(2));settle(b)
  eq(b.player,q);eq(b.effects:weatherId(),"raindance");eq(b.effects:snapshot().turns,4);eq(p.statStages.def,0);eq(q.hp,q.maxHP);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Forced faint replacement preserves field rain and doesn't advance its timer again",function()
  local p,q=Pokemon("squirtle",100),Pokemon("pidgey",100);local party=Party();assert(party:add(p));assert(party:add(q));local b=Battle(p,Pokemon("snorlax",100),nil,{party=party});settle(b);weather(b,"raindance");p.hp=0
  local before=RulesRNG.snapshot()
  b:runScript(function()b:setDirection("enemy");local outcome=b:handleFaint("player");eq(outcome,"replacement");return b:finishRound()end);settle(b);eq(b:phase(),"forcedSwitch")
  eq(b.effects:snapshot().turns,4);rngSame(before) -- One actual round ends before replacement.
  assert(b:chooseParty(2));settle(b);eq(b.player,q);eq(b.effects:weatherId(),"raindance");eq(b.effects:snapshot().turns,4);rngSame(before)
 end)
 test("Draw/snapshot calls leave rain timer/PP/RNG inert; actual exit clears weather",function()
  local b=fresh();weather(b,"raindance");local scene=BattleScene(b);scene:enter();local before=RulesRNG.snapshot()
  for _=1,30 do scene:draw();eq(b.effects:snapshot().weather,"raindance");eq(b.effects:snapshot().turns,5)end;rngSame(before);scene:exit();b:clearVolatiles();eq(b.effects:snapshot().weather,"none");eq(b.effects:snapshot().turns,0)
 end)
 RulesRNG.restore(saved);return report
end
