-- Actual Pokemon/Battle/DSL/PP/contact receipts, with explicit controlled fixtures.
SexAbilityContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function snapshot()return RulesRNG.snapshot()end
local function unchanged(s)local now=snapshot();eq(now.state,s.state);eq(now.rolls,s.rolls)end
local function mon(species,slot,sex)
 return Pokemon(species or "pikachu",50,{natureId=0,abilitySlot=slot or "first",heldItem="none",sex=sex})
end
local function own(p,key)p.moves={key};p.pp={[key]=moveData[key].maxPP}end
local function settle(b)
 local text={};local n=0
 while b.machine:is("script")do n=n+1;assert(n<120,"script did not settle");assert(not b.pendingLearning,"unexpected learning fixture");text[#text+1]=b.message;b.machine:get("script"):advance()end
 return table.concat(text,"|")
end
local function battle(p,e,opts)local b=Battle(p,e,nil,opts);settle(b);return b end
local function act(b,key,seed)
 own(b.player,key);RulesRNG.seed(seed or 14);b:runScript(function()return b:resolveTurn({side="player",key=key,move=moveData[key]})end);return settle(b)
end
local function cap(attackerSex,defenderSpecies,defenderSex,slot)
 return battle(mon("pikachu","first",attackerSex),mon(defenderSpecies or "charmander",slot or "first",defenderSex))
end
function SexAbilityContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=snapshot()
 local function test(name,fn)
  local before=snapshot();local ok,why=pcall(fn);RulesRNG.restore(before)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("Captivate uses exact declared oppositeSex metadata with original SpA-2 payload",function()
  eq(moveData.captivate.attemptRule,"oppositeSex");eq(moveData.captivate.maxPP,20);eq(moveData.captivate.accuracy,100);eq(moveData.captivate.targetId,11)
  local b=cap("male",nil,"female");local before=b.defender and b.defender.spa or b.enemy.spa;act(b,"captivate",14)
  eq(b.enemy.statStages.spa,-2);eq(b.enemy.spa,before);eq(b.player.pp.captivate,19);eq(snapshot().rolls,1)
 end)
 test("Captivate opposite-sex female user also succeeds with one accuracy sample",function()
  local b=cap("female",nil,"male");act(b,"captivate",14);eq(b.enemy.statStages.spa,-2);eq(snapshot().rolls,1);eq(b.player.pp.captivate,19)
 end)
 test("Same sex and genderless either side fail before accuracy but spend attempted PP",function()
  for _,v in ipairs({{"male","charmander","male"},{"female","charmander","female"},{"male","staryu","genderless"}})do local b=cap(v[1],v[2],v[3]);local text=act(b,"captivate",14);eq(b.enemy.statStages.spa,0);eq(b.player.pp.captivate,19);eq(snapshot().rolls,0);assert(text:find("failed",1,true))end
  local p=mon("staryu");local b=battle(p,mon("charmander","first","female"));act(b,"captivate",14);eq(b.enemy.statStages.spa,0);eq(snapshot().rolls,0);eq(p.pp.captivate,19)
 end)
 test("Captivate can miss after sex eligibility and never changes stage on miss",function()
  local b=cap("male",nil,"female");b.player.statStages.acc=-6;local text=act(b,"captivate",42);eq(b.enemy.statStages.spa,0);eq(b.player.pp.captivate,19);eq(snapshot().rolls,1);assert(text:find("missed",1,true))
 end)
 test("Oblivious12 blocks Captivate before accuracy including same-sex priority",function()
  for _,sex in ipairs({"male","female"})do local b=cap("male","slowpoke",sex);eq(b.enemy:ability(),12);local text=act(b,"captivate",14);eq(b.enemy.statStages.spa,0);eq(b.player.pp.captivate,19);eq(snapshot().rolls,0);assert(text:find("Oblivious",1,true))end
 end)
 test("NonOblivious Slowpoke slot does not accidentally inherit Captivate immunity",function()
  local b=cap("male","slowpoke","female","second");eq(b.enemy:ability(),20);act(b,"captivate",14);eq(b.enemy.statStages.spa,-2);eq(snapshot().rolls,1)
 end)
 test("Rivalry79 actual sex basepower40 becomes50 30 or40 without permanent stat changes",function()
  local p=mon("nidoranM","second");eq(p:ability(),79);local male,female,neutral=mon("charmander","first","male"),mon("charmander","first","female"),mon("staryu")
  local b=battle(p,male);local atk,spa=p.atk,p.spa;local before=snapshot()
  eq(b.effects:basePower(moveData.tackle,40,p,male),50);eq(b.effects:basePower(moveData.tackle,40,p,female),30);eq(b.effects:basePower(moveData.tackle,40,p,neutral),40);eq(b.effects:basePower(moveData.nightShade,0,p,male),0)
  eq(p.atk,atk);eq(p.spa,spa);eq(b.effects:attackStat(p,moveData.tackle,101),101);unchanged(before)
 end)
 test("Rivalry pure effectiveMovePower uses explicit identities in opposite current direction",function()
  local p=mon("nidoranM","second");local e=mon("charmander","first","male");local b=battle(p,e);b:setDirection("enemy");local a,d=b.attacker,b.defender;local before=snapshot()
  eq(b:effectiveMovePower(moveData.tackle,p,e),62);eq(b.attacker,a);eq(b.defender,d);unchanged(before)
 end)
 test("Rivalry actual command damage34 same versus21 opposite with exactly3 rolls and1 PP",function()
  for _,v in ipairs({{"male",34},{"female",21}})do local p=mon("nidoranM","second");local e=mon("charmander","first",v[1]);local b=battle(p,e);local hp=e.hp;act(b,"tackle",14);eq(hp-e.hp,v[2]);eq(snapshot().rolls,3);eq(p.pp.tackle,moveData.tackle.maxPP-1);eq(p.atk,62)end
 end)
 test("Rivalry female Nidoran reverses male target preference and keeps neutral type queries",function()
  local p=mon("nidoranF","second");local e=mon("charmander","first","male");local b=battle(p,e);eq(b.effects:basePower(moveData.tackle,40,p,e),30);eq(b.effects:basePower(moveData.tackle,40,p,mon("charmander","first","female")),50)
  eq(b.effects:basePower(moveData.tackle,40,mon("nidoranM","first"),e),40)
 end)
 test("Rivalry chains weather factor in Q12 once while original weather behavior remains",function()
  local p=mon("nidoranM","second");local e=mon("charmander","first","male");local b=battle(p,e);b.effects.weather={turns=5}
  eq(b.effects:basePower(moveData.solarBeam,29,p,e),18);eq(b.effects:basePower(moveData.solarBeam,120,p,e),75)
  eq(b.effects:basePower(moveData.solarBeam,120,mon("pikachu"),e),60)
 end)
 test("PoisonPoint38 contact30percent boundary rolls29 succeeds and30 fails after damage",function()
  for _,v in ipairs({{14,"poison"},{94,nil}})do local p,e=mon("pikachu"),mon("nidoranF");eq(e:ability(),38);local b=battle(p,e);local hp=e.hp;local text=act(b,"tackle",v[1]);assert(e.hp<hp);eq(p.status,v[2]);eq(snapshot().rolls,4);eq(p.pp.tackle,moveData.tackle.maxPP-1);if v[2]then assert(text:find("Poison Point",1,true))end end
 end)
 test("PoisonPoint actual two-hit contact rolls per landed hit even after poison applied",function()
  local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);act(b,"doubleKick",14);eq(p.status,"poison");eq(snapshot().rolls,7);eq(p.pp.doubleKick,moveData.doubleKick.maxPP-1)
 end)
 test("PoisonPoint actual missed contact spends PP but never samples a reaction",function()
  local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);p.statStages.acc=-6;local hp=e.hp;act(b,"tackle",14);eq(e.hp,hp);eq(p.status,nil);eq(snapshot().rolls,1);eq(p.pp.tackle,moveData.tackle.maxPP-1)
 end)
 test("PoisonPoint preserves chance-before-status type and Immunity eligibility",function()
  for _,species in ipairs({"nidoranM","magnemite","snorlax"})do local p,e=mon(species),mon("nidoranF");local b=battle(p,e);act(b,"tackle",14);eq(p.status,nil);eq(snapshot().rolls,4)end
  local p,e=mon("pikachu"),mon("nidoranF");p.status="burn";local b=battle(p,e);act(b,"tackle",14);eq(p.status,"burn");eq(snapshot().rolls,4)
 end)
 test("PoisonPoint is not filtered as a secondary and activates existing Guts without stat mutation",function()
  local p=mon("caterpie");local b=battle(p,mon("nidoranF"));eq(p:ability(),19);act(b,"tackle",14);eq(p.status,"poison");eq(snapshot().rolls,4)
  p=mon("rattata","second");b=battle(p,mon("nidoranF"));local atk=p.atk;eq(p:ability(),62);act(b,"tackle",14);eq(p.status,"poison");eq(p.atk,atk);eq(b.effects:attackStat(p,moveData.tackle,101),151)
 end)
 test("PoisonPoint on actual lethal contact receipt still poisons before terminal handling",function()
  local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);e.hp=1;RulesRNG.seed(1)
  b:runScript(function()local receipt=b.effects:hit(p,e,moveData.tackle,1);eq(e.hp,0);assert(b.effects:afterHit(receipt))end);settle(b);eq(p.status,"poison");eq(snapshot().rolls,1)
 end)
 test("PoisonPoint one-shot receipt rejects replay and fabricated receipts without further draws",function()
  local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);RulesRNG.seed(1);local receipt
  b:runScript(function()receipt=b.effects:hit(p,e,moveData.tackle,1);assert(b.effects:afterHit(receipt))end);settle(b);local before=snapshot()
  eq(b.effects:afterHit(receipt),false);eq(b.effects:afterHit({source=p,target=e,contact=true,removed=1}),false);unchanged(before)
 end)
 test("PoisonPoint zero damage noncontact and status receipts never roll or poison",function()
  for _,v in ipairs({{moveData.tackle,0},{moveData.poisonSting,1},{moveData.growl,0}})do local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);RulesRNG.seed(1);local before=snapshot();local receipt=b.effects:hit(p,e,v[1],v[2]);assert(b.effects:afterHit(receipt));eq(p.status,nil);unchanged(before)end
 end)
 test("PoisonPoint fainted attacker remains ineligible after the native chance sample",function()
  local p,e=mon("pikachu"),mon("nidoranF");local b=battle(p,e);p.hp=0;RulesRNG.seed(1);local r=b.effects:hit(p,e,moveData.tackle,1);assert(b.effects:afterHit(r));eq(p.status,nil);eq(snapshot().rolls,1)
 end)
 test("Immunity17 shared DSL prevents poison toxic but leaves sleep and burn paths intact",function()
  local p=mon("pikachu");local e=mon("snorlax");local b=battle(p,e);eq(e:ability(),17);b:setDirection("player");eq(b.attacker,p);eq(b.defender,e)
  for _,status in ipairs({"poison","badPoison"})do RulesRNG.seed(1);b:runScript(function()ApplyStatus(DEFENDER,status):apply(b)end);settle(b);eq(e.status,nil);eq(snapshot().rolls,0)end
  b:runScript(function()ApplyStatus(DEFENDER,"burn"):apply(b)end);settle(b);eq(e.status,"burn");e.status=nil;RulesRNG.seed(1)
  b:runScript(function()ApplyStatus(DEFENDER,"sleep"):apply(b)end);settle(b);eq(e.status,"sleep");eq(e.statusTurns,1);eq(snapshot().rolls,1)
 end)
 test("Immunity actual Toxic command spends one PP accuracy sample without poisoning",function()
  local b=battle(mon("pikachu"),mon("snorlax"));local text=act(b,"toxic",43);eq(b.enemy.status,nil);eq(b.player.pp.toxic,moveData.toxic.maxPP-1);eq(snapshot().rolls,1);assert(text:find("Immunity",1,true))
 end)
 test("Immunity entry cures preexisting ordinary and bad poison with zero RNG",function()
  for _,status in ipairs({"poison","badPoison"})do local p=mon("snorlax");p.status=status;local before=snapshot();local b=battle(p,mon("pikachu"));eq(p.status,nil);eq(p.statusTurns,0);eq(p.sleepDuration,0);eq(b.conditions:of(p).toxic,nil);unchanged(before)end
 end)
 test("Immunity actual voluntary party entry cures selected reserve poison once",function()
  local p,e=mon("pikachu"),mon("charmander");local q=mon("snorlax");q.status="badPoison";own(e,"splash");local party=Party();assert(party:add(p));assert(party:add(q));local b=battle(p,e,{party=party});RulesRNG.seed(1);local before=snapshot()
  assert(b:chooseParty(2));settle(b);eq(b.player,q);eq(q.status,nil);eq(q.statusTurns,0);eq(q.sleepDuration,0)
  -- Voluntary switching also resolves one real enemy response; no silent turn skip.
  assert(party:active()==q);eq(e.pp.splash,moveData.splash.maxPP-1);eq(snapshot().rolls-before.rolls,1)
 end)
 test("Immunity actual forced party entry cures poison without enemy action or RNG",function()
  local p=mon("pikachu");p.hp=0;local q=mon("snorlax");q.status="poison";local e=mon("charmander");own(e,"splash");local party=Party();assert(party:add(p));assert(party:add(q));local b=battle(p,e,{party=party});assert(b.machine:is("forcedSwitch"));local before=snapshot()
  assert(b:chooseParty(2));settle(b);eq(b.player,q);eq(q.status,nil);eq(e.pp.splash,moveData.splash.maxPP);unchanged(before)
 end)
 test("Immunity real enemy replacement cures stored poison before next command",function()
  local p=Pokemon("pikachu",100);own(p,"sonicBoom");local e=Pokemon("rattata",5);e.hp=1;local q=Pokemon("snorlax",5);q.status="badPoison";local team=Party();assert(team:add(e));assert(team:add(q))
  local b=Battle(p,e,"CONTRACT",{enemyParty=team});settle(b);eq(q.status,"badPoison");RulesRNG.seed(43)
  b:runScript(function()local outcome=b:resolveTurn({side="player",key="sonicBoom",move=moveData.sonicBoom});if outcome=="replacement"then return b:finishRound()end;return outcome end);local text=settle(b)
  eq(b.enemy,q);eq(q.status,nil);eq(q.statusTurns,0);assert(text:find("Immunity",1,true))
 end)
 test("Snorlax without Immunity keeps its preexisting poison on entry",function()
  local p=mon("snorlax","second");eq(p:ability(),47);p.status="poison";battle(p,mon("pikachu"));eq(p.status,"poison")
 end)
 test("Immunity ToxicSpikes query prevents both layers without false poisoned state",function()
  for _,layers in ipairs({1,2})do local p,e=mon("pikachu"),mon("snorlax");local b=battle(p,e);local h=b.conditions.sides.enemy;h.toxicSpikes=layers;h.order={"toxicSpikes"};local before=snapshot()
   b:runScript(function()b.conditions:entry(e,"enemy");b.effects:entry(e)end);settle(b);eq(e.status,nil);unchanged(before)
  end
 end)
 test("Original Poison Steel immunity and ordinary Dark type eligibility remain distinct",function()
  for _,species in ipairs({"nidoranM","magnemite"})do local b=battle(mon("pikachu"),mon(species));b:setDirection("player");eq(b.attacker,b.player);eq(b.defender,b.enemy);b:runScript(function()ApplyStatus(DEFENDER,"poison"):apply(b)end);settle(b);eq(b.enemy.status,nil)end
  local p,e=mon("pikachu"),mon("rattata");e.type,e.type2="dark",nil -- Explicit type fixture on actual Pokemon, no new species/world exposure.
  local b=battle(p,e);b:setDirection("player");eq(b.attacker,p);eq(b.defender,e);b:runScript(function()ApplyStatus(DEFENDER,"poison"):apply(b)end);settle(b);eq(e.status,"poison")
 end)
 RulesRNG.restore(saved);return report
end
