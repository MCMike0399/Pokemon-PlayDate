-- Actual production objects; custom fixtures isolate BasePower, not acquisition.
PowerOrderContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function mon(id,slot,sex)return Pokemon(id,50,{natureId=0,abilitySlot=slot or "first",heldItem="none",sex=sex})end
local function fresh(p,e)
 local b=Battle(p or mon("nidoranM","second"),e or mon("charmander","first","male"))
 for _=1,120 do if not b.machine:is("script")then return b end;b.machine:get("script"):advance()end
 error("intro did not settle")
end
local function mud(b,n)
 if n>=1 then b.conditions:of(b.player).mudSport=true end
 if n>=2 then b.conditions:of(b.enemy).mudSport=true end
end
local function query(b,key)return b:effectiveMovePower(moveData[key],b.player,b.enemy)end
function PowerOrderContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)
  local before=RulesRNG.snapshot();local ok,why=pcall(fn);RulesRNG.restore(before)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
  if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("Actual PS Q12 same-sex Rivalry plus one/two Mud Sports gives17/5 not16/5",function()
  for n,expected in ipairs({17,5})do local b=fresh();eq(b.player:ability(),79);mud(b,n);eq(query(b,"thunderShock"),expected)end
 end)
 test("Actual PS opposite-sex Rivalry plus one/two Mud Sports gives10/3",function()
  for n,expected in ipairs({10,3})do local b=fresh(nil,mon("charmander","first","female"));mud(b,n);eq(query(b,"thunderShock"),expected)end
 end)
 test("Ordinary Static Pikachu Electro Ball40 with Mud Sport stays13",function()
  local b=fresh(mon("pikachu"));eq(b.player:ability(),9);b.player.spe=40;b.enemy.spe=100;mud(b,1)
  eq(query(b,"electroBall"),13);eq(query(b,"thunderShock"),13);mud(b,2);eq(query(b,"thunderShock"),4)
 end)
 test("Genderless target keeps Rivalry neutral and retains isolated Mud Sport31/10",function()
  local b=fresh(nil,mon("staryu"));eq(query(b,"thunderShock"),40);mud(b,1);eq(query(b,"thunderbolt"),31);mud(b,2);eq(query(b,"thunderbolt"),10)
 end)
 test("Solar policy chains after Rivalry and keeps Sun unweakened",function()
  local b=fresh();for _,id in ipairs({"none","sunnyday","raindance","sandstorm","hail"})do
   b.effects.weather=id~="none"and{id=id,turns=5}or nil
   eq(query(b,"solarBeam"),(id=="none"or id=="sunnyday")and 150 or 75,id)
  end
 end)
 test("Rollout and Defense Curl remain raw before the Rivalry modifier",function()
  local b=fresh();local state=b.conditions:of(b.player);state.rollout={hits=2};state.defenseCurl=true
  eq(b.conditions:rawPower(b.player,moveData.rollout,30),240);eq(query(b,"rollout"),300)
  state.defenseCurl=nil;eq(query(b,"rollout"),150);state.rollout=nil;eq(query(b,"rollout"),37)
  eq(b.conditions.basePower,nil,"no duplicate rounded facade")
 end)
 test("Power observation preserves identities, stages, HP, PP and RNG even opposite direction",function()
  local b=fresh();mud(b,1);b:setDirection("enemy");local a,d=b.attacker,b.defender
  local before=RulesRNG.snapshot();local hp,pp,atk,spa=b.player.hp,b.player.pp.thunderShock,b.player.atk,b.player.spa
  local members=b.conditions.members;local p,e=members[b.player],members[b.enemy]
  for _=1,20 do eq(query(b,"thunderShock"),17)end
  eq(b.attacker,a);eq(b.defender,d);eq(b.player.hp,hp);eq(b.player.pp.thunderShock,pp);eq(b.player.atk,atk);eq(b.player.spa,spa)
  eq(b.conditions.members,members);eq(members[b.player],p);eq(members[b.enemy],e);eq(RulesRNG.snapshot().state,before.state);eq(RulesRNG.snapshot().rolls,before.rolls)
 end)
 test("Withdrawn/fainted Mud Sport owners stop contributing; status/fixed early0 guard preserved",function()
  local b=fresh();mud(b,2);eq(b.conditions:mudSportCount(),2);b.enemy.hp=0;eq(b.conditions:mudSportCount(),1);eq(query(b,"thunderShock"),17)
  b.conditions:clear(b.player);eq(b.conditions:mudSportCount(),0);eq(query(b,"thunderShock"),50)
  local raw=b.conditions.rawPower;b.conditions.rawPower=function()error("early0 reached raw power")end
  eq(query(b,"mudSport"),0);eq(query(b,"nightShade"),0);b.conditions.rawPower=raw
 end)
 RulesRNG.restore(saved);return report
end
