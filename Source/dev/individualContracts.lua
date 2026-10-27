-- Packet A: actual model/factory/codec/evolution, no combat EV reward producer.
IndividualContracts={}
local keys={"hp","atk","def","spa","spd","spe"}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function cp(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=cp(x)end;return out end
local function same(a,b)eq(type(a),type(b));if type(a)~="table"then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function six(values)local out={};for i,key in ipairs(keys)do out[key]=values[i]end;return out end
local function attrs(iv,ev,nature)return {natureId=nature or 0,abilitySlot="first",heldItem="none",ivs=iv,evs=ev}end
local gate={root="overworld",overworld="explore",settled=true}
function IndividualContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}}
 local function test(name,fn)
  local before,owner=RulesRNG.snapshot(),GameSession.activeRNGSession();local ok,why=pcall(fn)
  local active=GameSession.activeRNGSession();if active~=owner then if active then active:deactivateRNG()end;if owner then assert(owner:activateRNG())end end;RulesRNG.restore(before)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("all151 deterministic constructors have zero individuals and canonical no-RNG stats",function()
  local before=RulesRNG.snapshot();local count=0
  for species,data in pairs(pokemonData)do local p=Pokemon(species,50);same(p.ivs,IndividualStats.zero());same(p.evs,IndividualStats.zero());eq(p.maxHP,calcHP(data.baseHP,50));eq(p.atk,calcStat(data.baseAtk,50));assert(PokemonCodec.encode(p));count=count+1 end
  eq(count,151);same(before,RulesRNG.snapshot())
 end)
 test("every IV0/31 boundary accepted and malformed records rejected before construction",function()
  for _,key in ipairs(keys)do
   local iv=IndividualStats.zero();iv[key]=31;assert(Pokemon("bulbasaur",5,attrs(iv,IndividualStats.zero())))
   for _,bad in ipairs({-1,32,0.5,true,"31"})do iv[key]=bad;eq(pcall(Pokemon,"bulbasaur",5,attrs(iv,IndividualStats.zero())),false)end
   iv[key]=nil;eq(pcall(Pokemon,"bulbasaur",5,attrs(iv,IndividualStats.zero())),false)
  end
  local iv=IndividualStats.zero();iv.extra=0;eq(pcall(Pokemon,"bulbasaur",5,attrs(iv,IndividualStats.zero())),false)
 end)
 test("EV255 and total510 exact,511 fractional boolean missing and extra reject",function()
  for _,key in ipairs(keys)do local ev=IndividualStats.zero();ev[key]=255;assert(Pokemon("mew",100,attrs(IndividualStats.zero(),ev)))
   for _,bad in ipairs({-1,256,1.5,false,"255"})do ev[key]=bad;eq(pcall(Pokemon,"mew",100,attrs(IndividualStats.zero(),ev)),false)end
   ev[key]=nil;eq(pcall(Pokemon,"mew",100,attrs(IndividualStats.zero(),ev)),false)
  end
  local ev=six({255,255,0,0,0,0});assert(Pokemon("mew",100,attrs(IndividualStats.zero(),ev)));ev.spe=1;eq(pcall(Pokemon,"mew",100,attrs(IndividualStats.zero(),ev)),false)
 end)
 test("primary C literal stat vectors preserve EV quarter floors and nature order",function()
  local rows={
   {"bulbasaur",5,0,{0,0,0,0,0,0},{0,0,0,0,0,0},{19,9,9,11,11,9}},
   {"squirtle",16,5,{31,31,31,31,31,31},{252,6,252,0,0,0},{55,22,44,25,30,23}},
   {"charmander",16,15,{31,31,31,31,31,31},{0,0,0,0,0,0},{43,23,23,31,25,30}},
   {"bulbasaur",100,3,{31,31,31,31,31,31},{255,255,0,0,0,0},{294,216,134,149,166,126}},
   {"bulbasaur",100,0,{0,0,0,0,0,0},{0,3,0,0,0,0},{200,103,103,135,135,95}},
   {"bulbasaur",100,0,{0,0,0,0,0,0},{0,4,0,0,0,0},{200,104,103,135,135,95}},
   {"bulbasaur",5,0,{16,18,16,16,16,16},{0,0,0,0,0,0},{20,10,10,12,12,10}}}
  for _,v in ipairs(rows)do local p=Pokemon(v[1],v[2],attrs(six(v[4]),six(v[5]),v[3]));for i,key in ipairs({"maxHP","atk","def","spa","spd","spe"})do eq(p[key],v[6][i])end end
 end)
 test("recalc preserves missingHP growth, clamps shrink and never revives fainted",function()
  local p=Pokemon("squirtle",16,attrs(six({31,31,31,31,31,31}),six({252,6,252,0,0,0}),5))
  for _,v in ipairs({{40,30,45},{100,70,55},{40,0,0}})do p.maxHP,p.hp=v[1],v[2];p:recalcStats();eq(p.maxHP,55);eq(p.hp,v[3])end
 end)
 test("constructor attributes getters receipts and codec own defensive individual copies",function()
  local iv,ev=IndividualStats.zero(),IndividualStats.zero();iv.atk=31;local p=Pokemon("eevee",5,attrs(iv,ev));iv.atk=0;ev.hp=255;eq(p.ivs.atk,31);eq(p.evs.hp,0)
  local a=p:attributes();a.ivs.atk=0;eq(p.ivs.atk,31);local i=p:individuals();i.evs.hp=1;eq(p.evs.hp,0)
  local data=assert(PokemonCodec.encode(p));data.ivs.atk=0;eq(p.ivs.atk,31)
 end)
 test("creationv3 appends six exact sequential PM IV samples after old three",function()
  for _,v in ipairs({{1,"first",23,216,{9,1,7,23,29,2},1458777923},{42,"second",22,184,{22,9,24,16,7,25},1139130650},{12345,"first",23,191,{23,2,22,27,9,11},1963079340}})do
   local rng=RulesRNG.new(v[1]);local p,r=Specimen.create("eevee",5,"gift",rng);assert(p,r);eq(r.version,3);eq(r.draws,9);eq(r.rawRolls,9);eq(p.abilitySlot,v[2]);eq(p.natureId,v[3]);eq(p.sexProvenance.byte,v[4]);same(p.ivs,six(v[5]));same(p.evs,IndividualStats.zero());eq(rng:snapshot().state,v[6]);eq(r.individualPolicy,"random-normal-v1");r.ivs.hp=99;eq(p.ivs.hp,v[5][1])
  end
 end)
 test("Pikachu existing fourth held sample remains before six IV calls",function()
  local rng=RulesRNG.new(91);local expected=RulesRNG.new(91);expected:random(1,2);expected:random(0,24);expected:random(0,255);eq(expected:random(0,99),50)
  local iv={};for _,key in ipairs(keys)do iv[key]=expected:random(0,31)end
  local p,r=Specimen.create("pikachu",5,"wild",rng);assert(p,r);eq(r.draws,10);eq(p.heldItem,"lightBall");same(p.ivs,iv);same(rng:snapshot(),expected:snapshot())
 end)
 test("fixed Blue trainer policy keeps old three draws and exact hybrid DV contribution",function()
  local rng=RulesRNG.new(42);local p,r=Specimen.create("bulbasaur",5,"trainer",rng,nil,Specimen.blueTrainerPolicy("authored:oaks_lab:npc:2"));assert(p,r)
  same(p.ivs,six({16,18,16,16,16,16}));same(p.evs,IndividualStats.zero());eq(r.draws,3);eq(rng:snapshot().state,1579310009);eq(r.individualPolicy,"blue-scripted-v1")
 end)
 test("missing malformed or misplaced trainer policy rejects before any RNG draw",function()
  local rng=RulesRNG.new(42);local before=rng:snapshot()
  eq(Specimen.create("bulbasaur",5,"trainer",rng),nil)
  for _,policy in ipairs({{kind="perfect",sourceId="x"},{kind="blue-scripted-v1"},{kind="blue-scripted-v1",sourceId="x",ivs=IndividualStats.blueTrainer()}})do eq(Specimen.create("bulbasaur",5,"trainer",rng,nil,policy),nil)end
  eq(Specimen.create("bulbasaur",5,"gift",rng,nil,Specimen.blueTrainerPolicy("x")),nil);same(rng:snapshot(),before)
 end)
 test("exhaustion inside appended IVs leaves entire original RNG unchanged",function()
  for room=3,8 do local rng=RulesRNG.new(42);local data=rng:snapshot();data.rolls=2147483647-room;rng:restore(data);local p,why=Specimen.create("eevee",5,"gift",rng);eq(p,nil);assert(why:find("exhausted",1,true));same(rng:snapshot(),data)end
 end)
 test("Current codec strict required individual records roundtrip through real SDK JSON",function()
  local p=Pokemon("bulbasaur",100,attrs(six({31,30,29,28,27,26}),six({255,255,0,0,0,0}),3));p.hp=0
  local record=assert(PokemonCodec.encode(p))
  eq(record.version,PokemonCodec.VERSION)
  local before=RulesRNG.snapshot()
  local restored=assert(PokemonCodec.decode(json.decode(json.encode(record))))
  same(assert(PokemonCodec.encode(restored)),record)
  eq(restored.hp,0)
  same(before,RulesRNG.snapshot())
  for _,field in ipairs({"ivs","evs"})do local bad=cp(record);bad[field]=nil;eq(PokemonCodec.decode(bad),nil)end
  local bad=cp(record);bad.ivs.hp=32;eq(PokemonCodec.decode(bad),nil);bad=cp(record);bad.evs.spe=1;eq(PokemonCodec.decode(bad),nil)
 end)
 test("old3through6 migrate strict zero with no HP PP XP sleep or identity history reroll",function()
  local mon=Pokemon("charmander",15);mon.name="OLD";mon.hp=0;mon.pp.scratch=0;mon.status="sleep";mon.statusTurns=0;mon.sleepDuration=3
  for _,version in ipairs({3,4,5,6})do
   local old=assert(PokemonCodec.encode(mon))
   old.version=version
   old.acquisition=nil
   old.ivs,old.evs=nil,nil
   if version < 6 then
    old.sex,old.sexProvenance=nil,nil
   end
   if version < 5 then
    old.natureId,old.abilitySlot,old.heldItem=nil,nil,nil
   end
   local before=RulesRNG.snapshot()
   local restored=assert(PokemonCodec.decode(old))
   same(restored.ivs,IndividualStats.zero())
   same(restored.evs,IndividualStats.zero())
   eq(restored.hp,0)
   eq(restored.xp,mon.xp)
   eq(restored.pp.scratch,0)
   eq(restored.sleepDuration,3)
   eq(restored.name,"OLD")
   eq(assert(PokemonCodec.encode(restored)).version,PokemonCodec.VERSION)
   same(before,RulesRNG.snapshot())
   old.ivs=IndividualStats.zero();eq(PokemonCodec.decode(old),nil)
  end
 end)
 test("owned party storage and session JSON preserve exact individuals without either stream draw",function()
  local g=GameContext();local p=Pokemon("charmander",5,attrs(six({31,30,29,28,27,26}),six({255,0,0,0,0,255})));assert(g:recruit(p));assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
  local second=Pokemon("pikachu",20,attrs(six({1,2,3,4,5,6}),six({0,0,255,0,255,0})));assert(g:recruit(second));assert(g.session:storage():deposit(g.session:party(),2))
  local before,world=RulesRNG.snapshot(),g.session:worldRngData();local wire=assert(SessionCodec.encode(g.session,gate));local again=assert(SessionCodec.decode(json.decode(json.encode(wire)),g:getSessionDependencies()))
  same(again:party():get(1):individuals(),p:individuals());same(again:storage():get(1,1):individuals(),second:individuals());same(before,RulesRNG.snapshot());same(world,g.session:worldRngData())
 end)
 test("stone evolution retains exact individuals identity faint and no acquisition rolls",function()
  local g=GameContext();local p=Pokemon("eevee",20,attrs(six({31,1,2,3,4,5}),six({255,255,0,0,0,0})));assert(g:recruit(p));assert(g:recruit(Pokemon("charmander",5)));assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}));assert(g.session:inventory():add("waterStone",1));p.hp=0
  local iv,ev=cp(p.ivs),cp(p.evs);local before=RulesRNG.snapshot();assert(Evolution.complete(assert(Evolution.prepare(g.session,p,{kind="stone",item="waterStone"}))));eq(g.session:party():get(1),p);eq(p.species,"vaporeon");eq(p.hp,0);same(p.ivs,iv);same(p.evs,ev);same(before,RulesRNG.snapshot());eq(p.maxHP,p:calculatedStats().maxHP)
 end)
 test("level evolution and pending choices preserve trained identity and missingHP",function()
  local g=GameContext();assert(g:recruit(Pokemon("charmander",5)));local p=Pokemon("caterpie",6,attrs(six({31,2,3,4,5,6}),six({4,0,0,0,0,8})));assert(g:recruit(p));assert(g.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle"}))
  p.hp=p.maxHP-3;local iv,ev=cp(p.ivs),cp(p.evs);local before=RulesRNG.snapshot();assert(p:gainXP(p:xpForLevel(7)-p.xp));eq(p.maxHP-p.hp,3)
  assert(Evolution.complete(assert(Evolution.prepare(g.session,p,{kind="level"}))));eq(p.species,"metapod");eq(g.session:party():get(2),p);same(p.ivs,iv);same(p.evs,ev);eq(p.maxHP-p.hp,3)
  local restored=assert(PokemonCodec.decode(assert(PokemonCodec.encode(p))));same(restored:individuals(),p:individuals());same(restored:getPendingMoveChoices(),p:getPendingMoveChoices());same(before,RulesRNG.snapshot())
 end)
 test("all151 pinned yields exposed defensively without awarding any effort",function()
  for dex=1,151 do local row=IndividualStats.yieldFor(dex);local sum=0;for _,key in ipairs(keys)do assert(row[key]>=0 and row[key]<=3);sum=sum+row[key]end;assert(sum>=1 and sum<=3);row.hp=99;assert(IndividualStats.yieldFor(dex).hp<=3)end
  local p=Pokemon("bulbasaur",5);p:gainXP(10);same(p.evs,IndividualStats.zero()) -- PacketB intentionally absent.
 end)
 return report
end
