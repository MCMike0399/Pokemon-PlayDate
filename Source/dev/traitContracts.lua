-- Actual production model/codec/owners/RNG; no fake SDK or fabricated mons.
TraitContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function cp(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=cp(x)end;return r end
local function same(a,b)eq(type(a),type(b));if type(a)~="table"then eq(a,b);return end;for k,v in pairs(a)do same(v,b[k])end;for k in pairs(b)do assert(a[k]~=nil)end end
local function attrs(sex)return {natureId=0,abilitySlot="first",heldItem="none",sex=sex}end
local function owned(mon)
    local game=GameContext();assert(game:recruit(Pokemon("charmander",5)));if mon then assert(game:recruit(mon))end
    assert(game.session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=true}));return game
end
local gate={root="overworld",overworld="explore",settled=true}
function TraitContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot();local previousOwner=GameSession.activeRNGSession()
 local function test(name,fn)
  local before=RulesRNG.snapshot();local owner=GameSession.activeRNGSession();local ok,why=pcall(fn)
  local active=GameSession.activeRNGSession();if active~=owner then if active then assert(active:deactivateRNG())end;if owner then assert(owner:activateRNG())end end;RulesRNG.restore(before)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("151 exact B2W2 ratio inventory and valid pure constructor defaults",function()
  local counts={};local n=0;local before=RulesRNG.snapshot()
  for species in pairs(pokemonData)do local ratio=assert(SpecimenTraits.ratios[species]);counts[ratio]=(counts[ratio]or 0)+1;n=n+1
   local p=Pokemon(species,5)
   eq(p:getSex(),Specimen.defaultSex(species))
   eq(p.sexProvenance.kind,"constructor-default")
   local old=assert(PokemonCodec.encode(p))
   old.version=5
   old.acquisition=nil
   old.ivs,old.evs=nil,nil
   old.sex,old.sexProvenance=nil,nil
   local again=assert(PokemonCodec.decode(old));eq(again:getSex(),Specimen.defaultSex(species));eq(again.sexProvenance.kind,"legacy-default")
  end
  eq(n,151);same(counts,{[0]=6,[31]=19,[63]=10,[127]=91,[191]=6,[254]=6,[255]=13});same(before,RulesRNG.snapshot())
 end)
 test("Literal PID low byte boundaries and fixed species categories",function()
  for _,v in ipairs({{"bulbasaur",30,"female"},{"bulbasaur",31,"male"},{"growlithe",62,"female"},{"growlithe",63,"male"},{"pikachu",126,"female"},{"pikachu",127,"male"},{"clefairy",190,"female"},{"clefairy",191,"male"},{"nidoranF",255,"female"},{"nidoranM",0,"male"},{"staryu",255,"genderless"}})do eq(Specimen.sex(v[1],v[2]),v[3])end
 end)
 test("Seed1 creation literal third sample records generated male Clefairy",function()
  local rng=RulesRNG.new(1);local p,r=Specimen.create("clefairy",5,"gift",rng);assert(p,r)
  eq(p.abilitySlot,"first");eq(p.natureId,23);eq(p:getSex(),"male");eq(p.sexProvenance.byte,216);eq(r.version,3);eq(r.draws,9);eq(r.rawRolls,9);eq(rng:snapshot().state,1458777923)
  eq(Pokemon("clefairy",5):getSex(),"female");local a=p:attributes();a.sexProvenance.byte=0;eq(p.sexProvenance.byte,216)
 end)
 test("Fixed sex and genderless creation still consume explicit independent third sample",function()
  for _,species in ipairs({"nidoranF","nidoranM","staryu"})do local rng=RulesRNG.new(1);local p,r=Specimen.create(species,5,"trainer",rng,nil,Specimen.blueTrainerPolicy("contract:fixed-sex"));assert(p,r);eq(r.draws,3);eq(rng:snapshot().state,1622650073);eq(p:getSex(),Specimen.defaultSex(species))end
 end)
 test("Species sex and bounded provenance mutations reject without RNG",function()
  local p=assert(Specimen.create("pikachu",5,"gift",RulesRNG.new(1)));local data=assert(PokemonCodec.encode(p));local before=RulesRNG.snapshot()
  for _,change in ipairs({{sex="genderless"},{sex="female"},{sexProvenance={version=1,kind="generated",protocol=2,origin="wild",byte=256}},{sexProvenance={version=1,kind="explicit",byte=0}},{sexProvenance={version=2,kind="explicit"}},{sexProvenance={version=1,kind="generated",protocol=2,origin="unknown",byte=216}}})do local bad=cp(data);for k,v in pairs(change)do bad[k]=v end;eq(PokemonCodec.decode(bad),nil)end
  for _,field in ipairs({"sex","sexProvenance"})do local bad=cp(data);bad[field]=nil;eq(PokemonCodec.decode(bad),nil)end
  eq(pcall(Pokemon,"staryu",5,attrs("female")),false);eq(pcall(Pokemon,"nidoranF",5,attrs("male")),false);same(before,RulesRNG.snapshot())
 end)
 test("Legacy3 4 5 preserve all prior fields with deterministic no-RNG assigned sex",function()
  for _,species in ipairs({"clefairy","pikachu","nidoranF","nidoranM","staryu"})do
   for _,version in ipairs({3,4,5})do
    local p=Pokemon(species,20)
    p.name="OLD"
    p.hp=1
    p.pp[p.moves[1]]=0
    local data=assert(PokemonCodec.encode(p))
    data.version=version
    data.acquisition=nil
    data.ivs,data.evs=nil,nil
    data.sex,data.sexProvenance=nil,nil
    if version<5 then data.natureId,data.abilitySlot,data.heldItem=nil,nil,nil end
    local before=RulesRNG.snapshot();local again=assert(PokemonCodec.decode(data));local encoded=assert(PokemonCodec.encode(again));eq(encoded.sex,Specimen.defaultSex(species));eq(encoded.sexProvenance.kind,"legacy-default")
    for key,value in pairs(data)do if key~="version"then same(encoded[key],value)end end;same(before,RulesRNG.snapshot())
    data.sex="male";eq(PokemonCodec.decode(data),nil)
   end
  end
 end)
 test("Third-sample and Pikachu fourth-sample exhaustion leave detached RNG unchanged",function()
  for _,v in ipairs({{"eevee",2147483645},{"pikachu",2147483644}})do local rng=RulesRNG.new(1);local snapshot=rng:snapshot();snapshot.rolls=v[2];rng:restore(snapshot);local p,why=Specimen.create(v[1],5,"wild",rng);eq(p,nil);assert(why:find("exhausted",1,true));same(snapshot,rng:snapshot())end
 end)
 test("Ordinary wild Pikachu exact five of100 outcomes with empty common slot",function()
  local found=0;for roll=0,99 do local id=Specimen.ordinaryPikachuItem(roll);if id=="lightBall"then found=found+1;assert(roll>=50 and roll<=54)else eq(id,"none")end end;eq(found,5)
  for _,v in ipairs({{48,49,"none"},{91,50,"lightBall"},{86,54,"lightBall"},{70,55,"none"}})do local p,r=Specimen.create("pikachu",5,"wild",RulesRNG.new(v[1]));assert(p,r);eq(r.draws,10);eq(r.heldRoll,v[2]);eq(p.heldItem,v[3]);eq(r.heldItem,v[3])end
 end)
 test("Nonwild Pikachu and other species never use this narrow held-acquisition sampler",function()
  for _,origin in ipairs({"starter","trainer","gift","debug"})do local p,r=Specimen.create("pikachu",5,origin,RulesRNG.new(91),nil,origin=="trainer"and Specimen.blueTrainerPolicy("contract:nonwild")or nil);assert(p,r);eq(p.heldItem,"none");eq(r.draws,origin=="trainer"and 3 or 9);eq(r.heldRoll,nil)end
  local p,r=Specimen.create("rattata",5,"wild",RulesRNG.new(91));assert(p,r);eq(p.heldItem,"none");eq(r.draws,9)
 end)
 test("Compound Eyes exact20percent boundaries and authoritative fainted physical slot1",function()
  local count=0;for roll=0,99 do if Specimen.ordinaryPikachuItem(roll,true)=="lightBall"then count=count+1;assert(roll>=60 and roll<=79)end end;eq(count,20)
  local lead=Pokemon("butterfree",10);local game=owned(lead);assert(game.session:party():swap(1,2));eq(game.session:party():active().species,"charmander");lead.hp=0;assert(game.session:activateRNG())
  local token=assert(Specimen.planEncounter(game.session))
  for _,v in ipairs({{28,59,"none"},{12,60,"lightBall"},{62,79,"lightBall"},{46,80,"none"}})do local p,r=Specimen.create("pikachu",5,"wild",RulesRNG.new(v[1]),token);assert(p,r);eq(r.heldRoll,v[2]);eq(p.heldItem,v[3]);eq(r.heldPolicy,"compound-eyes")end
 end)
 test("Production Zone passes real slot1 lead through whole encounter transaction",function()
  local lead=Pokemon("butterfree",10);local game=owned(lead);assert(game.session:party():swap(1,2));assert(game.session:activateRNG());lead.hp=0
  local zone=Zone({name="held contract",tileRows={"Fo"},encounters={{species="pikachu",minLevel=5,maxLevel=5,weight=1}}})
  RulesRNG.seed(1);local p=zone:rollEncounter(game.session);eq(p.heldItem,"lightBall");eq(RulesRNG.snapshot().rolls,12)
 end)
 test("Actual Blue Forest chance slots creation and held acquisition match independent literal stream",function()
  local zone=PewterWorld.isolated("ViridianForest");local gx,gy
  for y=0,zone.height-1 do for x=0,zone.width-1 do if zone:isTallGrass(x,y)then gx,gy=x,y;break end end;if gx then break end end;assert(gx)
  for _,v in ipairs({{19525,false,"lightBall",154,5,1285017372},{2583,false,"none",44,17,823536374},{2583,true,"lightBall",44,17,823536374}})do
   local game=owned(v[2]and Pokemon("butterfree",10)or nil);if v[2]then assert(game.session:party():swap(1,2))end;assert(game.session:activateRNG());RulesRNG.seed(v[1])
   assert(zone:checkEncounter(gx,gy));local p=zone:rollEncounter(game.session);eq(p.species,"pikachu");eq(p.level,3);eq(p.heldItem,v[3]);eq(p.sexProvenance.byte,v[4]);eq(p.natureId,v[5]);eq(RulesRNG.snapshot().rolls,13);eq(RulesRNG.snapshot().state,v[6])
  end
 end)
 test("Absent foreign inactive stale or nonwild encounter contexts reject before draws",function()
  local game=owned(Pokemon("butterfree",10));eq(Specimen.planEncounter(game.session),nil);assert(game.session:activateRNG());local token=assert(Specimen.planEncounter(game.session));local rng=RulesRNG.new(12);local before=rng:snapshot()
  eq(Specimen.create("pikachu",5,"wild",rng,{}),nil);eq(Specimen.create("pikachu",5,"gift",rng,token),nil);same(before,rng:snapshot())
  assert(game.session:party():swap(1,2));eq(Specimen.create("pikachu",5,"wild",rng,token),nil);same(before,rng:snapshot())
  local fresh=assert(Specimen.planEncounter(game.session));RulesRNG.random(0,99);local advanced=RulesRNG.snapshot();eq(Specimen.create("pikachu",5,"wild",rng,fresh),nil);same(advanced,RulesRNG.snapshot());same(before,rng:snapshot())
  local empty=GameContext();assert(empty.session:activateRNG());local global=RulesRNG.snapshot();eq(Specimen.planEncounter(empty.session),nil);eq(Specimen.createForSession(empty.session,"pikachu",5,"wild"),nil);same(global,RulesRNG.snapshot())
  eq(Specimen.create("pikachu",5,"wild",rng,token),nil);same(before,rng:snapshot())
 end)
 test("Missing enabled held registry rejects creation with no RNG commit",function()
  local original=ItemData.definitions.lightBall;ItemData.definitions.lightBall=nil;local rng=RulesRNG.new(91);local before=rng:snapshot();local p,why=Specimen.create("pikachu",5,"wild",rng);ItemData.definitions.lightBall=original
  eq(p,nil);assert(why:find("missing-Light-Ball",1,true));same(before,rng:snapshot())
 end)
 test("Light Ball crosswalk has no invented Blue price or commerce",function()
  local d=ItemData.definitions.lightBall;eq(d.gen5Id,236);eq(d.pokeApiId,213);eq(d.numericId,nil);eq(d.sellPrice,nil);eq(d.price,nil);eq(SpecimenData.holdable.lightBall,236)
  local bag=Inventory(ItemData.definitions);assert(bag:add("lightBall",1));eq(Items.sell(bag,"lightBall",1),false);eq(bag:quantity("lightBall"),1)
 end)
 test("Light Ball modifies Pikachu physical and special effective attack only with no RNG",function()
  local p=Pokemon("pikachu",50);local q=Pokemon("raichu",50);local b=Battle(p,q);local before=RulesRNG.snapshot();p.heldItem="lightBall"
  eq(b.effects:attackStat(p,moveData.tackle,91),182);eq(b.effects:attackStat(p,moveData.thunderShock,83),166);q.heldItem="lightBall";eq(b.effects:attackStat(q,moveData.tackle,91),91)
  eq(p.atk,60);eq(p.spa,55);p.heldItem="none";eq(b.effects:attackStat(p,moveData.tackle,91),91);same(before,RulesRNG.snapshot())
 end)
 test("Actual damage hook Light Ball Pikachu literal physical14to27 special16to30 burn13",function()
  local p=Pokemon("pikachu",50);local q=Pokemon("mew",50);local b=Battle(p,q)
  RulesRNG.seed(15);eq(calcDamage(p,q,moveData.tackle,nil,b.effects).damage,14)
  p.heldItem="lightBall";RulesRNG.seed(15);eq(calcDamage(p,q,moveData.tackle,nil,b.effects).damage,27)
  p.heldItem="none";RulesRNG.seed(15);eq(calcDamage(p,q,moveData.thunderShock,nil,b.effects).damage,16)
  p.heldItem="lightBall";RulesRNG.seed(15);eq(calcDamage(p,q,moveData.thunderShock,nil,b.effects).damage,30)
  p.status="burn";RulesRNG.seed(15);eq(calcDamage(p,q,moveData.tackle,nil,b.effects).damage,13)
 end)
 test("Captured same identity and Give Take keep sex history across aggregate JSON",function()
  local p=assert(Specimen.create("pikachu",5,"wild",RulesRNG.new(91)));local game=owned();assert(game.session:inventory():add("masterBall",1))
  local b=Battle(game:getPlayerPokemon(),p,nil,{party=game.session:party(),session=game.session});local n=0
  while b.machine:is("script")do n=n+1;assert(n<40);b.machine:get("script"):advance()end
  assert(b:throwBall("masterBall"));eq(b.caughtPokemon,p);eq(game.session:party():get(2),p);eq(p.heldItem,"lightBall")
  while b.machine:is("script")do n=n+1;assert(n<80);b.machine:get("script"):advance()end
  local original=cp(p.sexProvenance);local before=RulesRNG.snapshot()
  assert(game.session:takeHeldItem(p));eq(p.heldItem,"none");eq(game.session:inventory():quantity("lightBall"),1);assert(game.session:giveHeldItem(p,"lightBall"));eq(p.heldItem,"lightBall");same(original,p.sexProvenance)
  local data=assert(SessionCodec.encode(game.session,gate));local candidate=assert(SessionCodec.decode(json.decode(json.encode(data)),game:getSessionDependencies()));local restored=candidate:party():get(2)
  eq(restored.heldItem,"lightBall");eq(restored:getSex(),p:getSex());same(restored.sexProvenance,original);data.party.members[2].sexProvenance.byte=0;eq(restored.sexProvenance.byte,original.byte);eq(game.session:party():get(2),p);same(before,RulesRNG.snapshot())
 end)
 test("Malformed late aggregate candidate leaves live objects and both streams unchanged",function()
  local p=assert(Specimen.create("pikachu",5,"wild",RulesRNG.new(91)));local game=owned(p);local session=game.session;local before=assert(SessionCodec.encode(session,gate));local rules=RulesRNG.snapshot();local world=session:worldRngData();local bad=cp(before);bad.party.members[2].sex="genderless"
  eq(SessionCodec.decode(bad,game:getSessionDependencies()),nil);eq(game.session,session);eq(session:party():get(2),p);same(before,assert(SessionCodec.encode(session,gate)));same(rules,RulesRNG.snapshot());same(world,session:worldRngData())
 end)
 test("Actual stone evolution preserves generated sex history and same owned Light Ball",function()
  local p=assert(Specimen.create("pikachu",5,"wild",RulesRNG.new(91)));local game=owned(p);assert(game.session:inventory():add("thunderStone",1));local history=cp(p.sexProvenance);local sex=p:getSex();local before=RulesRNG.snapshot()
  assert(Evolution.complete(assert(Evolution.prepare(game.session,p,{kind="stone",item="thunderStone"}))));eq(p.species,"raichu");eq(p:getSex(),sex);same(history,p.sexProvenance);eq(p.heldItem,"lightBall");eq(game.session:party():get(2),p);assert(PokemonCodec.encode(p));same(before,RulesRNG.snapshot())
 end)
 eq(GameSession.activeRNGSession(),previousOwner);RulesRNG.restore(saved);return report
end
