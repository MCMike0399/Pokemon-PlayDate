-- Optional shared status dependency for sourced charge/rampage fatigue.
OwnTempoContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function settle(b)local n=0;while b.machine:is("script")do n=n+1;assert(n<80);b.machine:get("script"):advance()end end
local function mon(slot)return Pokemon("slowpoke",30,{natureId=0,abilitySlot=slot,heldItem="none"})end
local function battle(slot)local p=Pokemon("pikachu",30);local e=mon(slot);local b=Battle(p,e);settle(b);return b end
function OwnTempoContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)local before=RulesRNG.snapshot();local ok,why=pcall(fn);RulesRNG.restore(before);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
 test("OwnTempo20 direct confusion prevention samples no duration RNG",function()
  local b=battle("second");eq(b.enemy:ability(),20);RulesRNG.seed(1);b:setDirection("player");eq(b.attacker,b.player);eq(b.defender,b.enemy);b:runScript(function()ApplyStatus(DEFENDER,"confuse"):apply(b)end);settle(b);eq(b.enemy.confusion,nil);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Real ConfuseRay spends accuracy and PP but OwnTempo prevents duration sample",function()
  local b=battle("second");b.player.moves={"confuseRay"};b.player.pp={confuseRay=moveData.confuseRay.maxPP};RulesRNG.seed(1)
  b:runScript(function()return b:resolveTurn({side="player",key="confuseRay",move=moveData.confuseRay})end);settle(b);eq(b.enemy.confusion,nil);eq(b.player.pp.confuseRay,moveData.confuseRay.maxPP-1);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Oblivious counterpart remains confusion eligible with original duration sample",function()
  local b=battle("first");eq(b.enemy:ability(),12);RulesRNG.seed(1);b:setDirection("player");eq(b.attacker,b.player);eq(b.defender,b.enemy);b:runScript(function()ApplyStatus(DEFENDER,"confuse"):apply(b)end);settle(b);eq(b.enemy.confusion,3);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("OwnTempo entry cure clears only active confusion and consumes no RNG",function()
  local b=battle("second");b.enemy.confusion=3;b.enemy.status="burn";RulesRNG.seed(1)
  b:runScript(function()assert(b.effects:entry(b.enemy))end);settle(b);eq(b.enemy.confusion,nil);eq(b.enemy.status,"burn");eq(RulesRNG.snapshot().rolls,0)
 end)
 test("OwnTempo GenV does not block Attack drops or unrelated status",function()
  local b=battle("second");RulesRNG.seed(1);b:setDirection("player");eq(b.attacker,b.player);eq(b.defender,b.enemy);b:runScript(function()ModifyStat(DEFENDER,"atk",-1):apply(b);ApplyStatus(DEFENDER,"poison"):apply(b)end);settle(b);eq(b.enemy.statStages.atk,-1);eq(b.enemy.status,"poison");eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Foreign entry owner cannot cure unrelated Pokemon",function()
  local b=battle("second");local foreign=mon("second");foreign.confusion=3;RulesRNG.seed(1);eq(b.effects:entry(foreign),false);eq(foreign.confusion,3);eq(RulesRNG.snapshot().rolls,0)
 end)
 RulesRNG.restore(saved);return report
end
