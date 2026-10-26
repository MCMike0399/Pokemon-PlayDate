-- Actual Battle/Pokemon/DSL and identity ownership. Explicit illegal ability
-- fixtures are used only for generic GenV Truant/Multitype rejection timing.
WorrySeedContracts={}
local function eq(a,b,label)assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b)
 eq(type(a),type(b))
 if type(a)~="table"then return eq(a,b)end
 for key,value in pairs(a)do same(value,b[key])end
 for key in pairs(b)do assert(a[key]~=nil,"missing durable field "..tostring(key))end
end
local function mon(id,slot,sex)return Pokemon(id or "bulbasaur",50,{natureId=0,abilitySlot=slot or "first",heldItem="none",sex=sex})end
local function own(p,key)p.moves={key};p.pp={[key]=moveData[key].maxPP}end
local function settle(b)
 local lines={}
 for _=1,160 do if not b.machine:is("script")then return table.concat(lines,"|")end;lines[#lines+1]=b.message;b.machine:get("script"):advance()end
 error("script did not settle")
end
local function fresh(p,e,opts)local b=Battle(p or mon("bulbasaur"),e or mon("pikachu"),nil,opts);settle(b);return b end
local function act(b,key,seed,side)
 side=side or "player";if not b[side]:hasMove(key)then own(b[side],key)end;RulesRNG.seed(seed or 14)
 b:runScript(function()return b:resolveTurn({side=side,actor=b[side],key=key,move=moveData[key]})end);return settle(b)
end
local function replace(b,target)
 local source=target==b.player and b.enemy or b.player;local result,reason
 b:runScript(function()result,reason=b.effects:worrySeed(source,target)end);settle(b);return result,reason
end
local function status(b,key)
 b:setDirection("player");b:runScript(function()ApplyStatus(DEFENDER,key):apply(b)end);return settle(b)
end
local function unchanged(s)local r=RulesRNG.snapshot();eq(r.state,s.state);eq(r.rolls,s.rolls)end
local function noEvent(events,kind)for _,e in ipairs(events)do assert(e.kind~=kind,"unexpected "..kind)end end
function WorrySeedContracts.run()
 local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
 local function test(name,fn)
  local before=RulesRNG.snapshot();local ok,why=pcall(fn);RulesRNG.restore(before)
  report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
  if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
 end
 test("Producer388 keeps PP10 accuracy100 and declares exactly WorrySeedEffect",function()
  local move=moveData.worrySeed;eq(move.attemptRule,"worrySeed");eq(move.maxPP,10);eq(move.accuracy,100);eq(move.targetId,10);eq(move.category,"status")
  eq(#move.effects,1);assert(move.effects[1]:is("WorrySeedEffect"))
 end)
 test("Actual WorrySeed attempt spends1PP/1accuracy and overrides Static without specimen mutation",function()
  local b=fresh();local before=assert(PokemonCodec.encode(b.enemy));local slot=b.enemy.abilitySlot
  act(b,"worrySeed");eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,1);eq(b.effects:effectiveAbility(b.enemy),15)
  eq(b.enemy:ability(),9);eq(b.enemy.abilitySlot,slot);same(assert(PokemonCodec.encode(b.enemy)),before)
  act(b,"worrySeed");eq(b.player.pp.worrySeed,8);eq(RulesRNG.snapshot().rolls,0)
 end)
 test("Existing Insomnia15 and Truant54 reject BEFORE accuracy but spend attempted PP",function()
  local b=fresh(nil,mon("drowzee"));eq(b.enemy:ability(),15);act(b,"worrySeed");eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,0);eq(b.effects.abilityOverrides[b.enemy],nil)
  -- Actual Pokemon object, explicitly illegal ability fixture matching PS probe.
  b=fresh();b.enemy.ability=function()return 54 end;act(b,"worrySeed");eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,0);eq(b.effects.abilityOverrides[b.enemy],nil)
 end)
 test("Multitype121 rejects AFTER accuracy at hit with unchanged target and1PP",function()
  local b=fresh();b.enemy.ability=function()return 121 end;local before=RulesRNG.snapshot();act(b,"worrySeed")
  eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,1);eq(b.effects:effectiveAbility(b.enemy),121);eq(b.effects.abilityOverrides[b.enemy],nil)
 end)
 test("Missed WorrySeed never changes ability or sleeping status",function()
  local b=fresh();b.player.statStages.acc=-6;b.enemy.status,b.enemy.statusTurns,b.enemy.sleepDuration="sleep",2,3
  act(b,"worrySeed",42);eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,1);eq(b.effects:effectiveAbility(b.enemy),9);eq(b.enemy.status,"sleep");eq(b.enemy.statusTurns,2);eq(b.enemy.sleepDuration,3)
 end)
 test("Successful WorrySeed cures sleep immediately including remaining0 without duration RNG",function()
  for _,remaining in ipairs({0,1,3})do
   local b=fresh();b.enemy.status,b.enemy.statusTurns,b.enemy.sleepDuration="sleep",remaining,3
   local text=act(b,"worrySeed");eq(b.enemy.status,nil);eq(b.enemy.statusTurns,0);eq(b.enemy.sleepDuration,0);eq(RulesRNG.snapshot().rolls,1)
   assert(text:find("Insomnia",1,true));eq(b.effects:effectiveAbility(b.enemy),15)
  end
 end)
 test("Sleep cure and override commit before first presentation yield; exit cannot lose cure",function()
  local b=fresh();b.enemy.status,b.enemy.statusTurns,b.enemy.sleepDuration="sleep",2,3
  b:runScript(function()assert(b.effects:worrySeed(b.player,b.enemy))end)
  assert(b.message:find("acquired Insomnia",1,true));eq(b.enemy.status,nil);eq(b.enemy.statusTurns,0);eq(b.enemy.sleepDuration,0);eq(b.effects:effectiveAbility(b.enemy),15)
  b:clearVolatiles();eq(b.enemy.status,nil);eq(b.effects:effectiveAbility(b.enemy),9);eq(b.enemy:ability(),9)
 end)
 test("New Insomnia blocks actual SleepPowder before duration RNG, repeat WorrySeed skips accuracy",function()
  local b=fresh();act(b,"worrySeed");act(b,"sleepPowder");eq(b.enemy.status,nil);eq(RulesRNG.snapshot().rolls,1);eq(b.player.pp.sleepPowder,14)
  act(b,"worrySeed");eq(b.player.pp.worrySeed,9);eq(RulesRNG.snapshot().rolls,0);eq(b.effects:effectiveAbility(b.enemy),15)
 end)
 test("Natural Insomnia entry cures existing sleep; prevention leaves counters/RNG untouched",function()
  local p=mon("drowzee");p.status,p.statusTurns,p.sleepDuration="sleep",2,3;local b=fresh(p)
  eq(p.status,nil);eq(p.statusTurns,0);eq(p.sleepDuration,0);eq(b.effects:supported(15),true)
  local before=RulesRNG.snapshot();eq(b.effects:statusImmunity(p,"sleep"),"Insomnia");eq(b.effects:statusImmunity(p,"yawn"),"Insomnia");unchanged(before)
 end)
 test("WorrySeed changes no non-sleep status or confusion and samples no RNG at commit",function()
  for _,value in ipairs({"poison","badPoison","paralyze","burn","freeze"})do
   local b=fresh();b.enemy.status,b.enemy.statusTurns,b.enemy.sleepDuration=value,0,0;b.enemy.confusion=2
   local before=RulesRNG.snapshot();assert(replace(b,b.enemy));eq(b.enemy.status,value);eq(b.enemy.confusion,2);unchanged(before)
  end
 end)
 test("Battle ability override never disables an independent LightBall item modifier",function()
  local p=mon("pikachu");p.heldItem="lightBall";local b=fresh(p);eq(b.effects:attackStat(p,moveData.thunderShock,100),200)
  assert(replace(b,p));eq(b.effects:effectiveAbility(p),15);eq(p:ability(),9);eq(p.heldItem,"lightBall");eq(b.effects:attackStat(p,moveData.thunderShock,100),200)
 end)
 test("Foreign inactive self fainted closed and unsupported replacement requests fail atomically",function()
  local b=fresh();local outsider=mon("pikachu");local before=RulesRNG.snapshot()
  for _,pair in ipairs({{outsider,b.enemy},{b.player,outsider},{b.player,b.player}})do eq(b.effects:worrySeed(pair[1],pair[2]),false)end
  b.enemy.hp=0;eq(b.effects:worrySeed(b.player,b.enemy),false);b.enemy.hp=b.enemy.maxHP
  local native=b.enemy.ability;b.enemy.ability=function()return 999 end;eq(b.effects:worrySeed(b.player,b.enemy),false);b.enemy.ability=native
  eq(b.effects.abilityOverrides[b.enemy],nil);unchanged(before);b.effects:close();eq(b.effects:worrySeed(b.player,b.enemy),false);unchanged(before)
 end)
 test("All previously enabled ability IDs resolve overridden values while native slots remain exact",function()
  for _,id in ipairs({5,8,9,12,14,17,19,20,38,50,51,61,62,65,66,67,68,69,71,77,79})do
   local found
   for key,data in pairs(pokemonData)do
    for _,slot in ipairs({"first","second","hidden"})do
     if SpecimenData.slots[data.dex][slot]==id then found=mon(key,slot);break end
    end
    if found then break end
   end
   assert(found,"missing original151 controlled fixture ability"..id);local b=fresh(nil,found);eq(found:ability(),id);assert(replace(b,found));eq(b.effects:effectiveAbility(found),15);eq(found:ability(),id)
  end
 end)
 test("Overwritten CompoundEyes/TangledFeet/SandVeil stop affecting actual accuracy",function()
  for _,v in ipairs({{"butterfree","first",moveData.sleepPowder,98},{"pidgey","second",moveData.tackle,50},{"sandshrew","first",moveData.tackle,80}})do
   local p=mon(v[1],v[2]);local b
   if v[1]=="butterfree"then b=fresh(p);eq(b.effects:accuracy(p,b.enemy,v[3]),v[4]);assert(replace(b,p));eq(b.effects:accuracy(p,b.enemy,v[3]),75)
   else b=fresh(nil,p);p.confusion=2;b.effects.weather={id="sandstorm",turns=5};eq(b.effects:accuracy(b.player,p,v[3]),v[4]);assert(replace(b,p));eq(b.effects:accuracy(b.player,p,v[3]),100)end
  end
 end)
 test("Overwritten Overgrow/Guts/Rivalry no longer modify attack power/burn handling",function()
  local p=mon("bulbasaur");local b=fresh(p);p.hp=1;eq(b.effects:attackStat(p,moveData.vineWhip,100),150);assert(replace(b,p));eq(b.effects:attackStat(p,moveData.vineWhip,100),100)
  p=mon("rattata","second");b=fresh(p);p.status="burn";eq(b.effects:attackStat(p,moveData.tackle,100),150);eq(b.effects:ignoresBurn(p),true);assert(replace(b,p));eq(b.effects:attackStat(p,moveData.tackle,100),100);eq(b.effects:ignoresBurn(p),false)
  p=mon("nidoranM","second");b=fresh(p,mon("charmander","first","male"));eq(b:effectiveMovePower(moveData.thunderShock,p,b.enemy),50);assert(replace(b,p));eq(b:effectiveMovePower(moveData.thunderShock,p,b.enemy),40)
 end)
 test("Overwritten ShieldDust/KeenEye/RockHead/RunAway/ArenaTrap hooks lose old effects",function()
  local b=fresh(nil,mon("caterpie"));eq(b.effects:allowsSecondary(b.player,b.enemy),false);assert(replace(b,b.enemy));eq(b.effects:allowsSecondary(b.player,b.enemy),true)
  b=fresh(nil,mon("pidgey"));eq(b.effects:canDropStat(b.player,b.enemy,"acc",-1),false);assert(replace(b,b.enemy));eq(b.effects:canDropStat(b.player,b.enemy,"acc",-1),true)
  b=fresh(mon("onix"));eq(b.effects:recoilBlocked(b.player,moveData.takeDown),true);assert(replace(b,b.player));eq(b.effects:recoilBlocked(b.player,moveData.takeDown),false)
  b=fresh(mon("rattata"));eq(b.effects:sureEscape(b.player),true);assert(replace(b,b.player));eq(b.effects:sureEscape(b.player),false)
  b=fresh(nil,mon("diglett","second"));eq(b.effects:withdrawBlocked(b.player),true);assert(replace(b,b.enemy));eq(b.effects:withdrawBlocked(b.player),false)
 end)
 test("Overwritten Oblivious/Immunity/OwnTempo stop blocking real Captivate/status producers",function()
  local b=fresh(nil,mon("slowpoke","first","female"));eq(b.effects:canAttempt(moveData.captivate,b.player,b.enemy),false);assert(replace(b,b.enemy));act(b,"captivate");eq(b.enemy.statStages.spa,-2);eq(RulesRNG.snapshot().rolls,1)
  b=fresh(nil,mon("snorlax"));status(b,"poison");eq(b.enemy.status,nil);assert(replace(b,b.enemy));status(b,"poison");eq(b.enemy.status,"poison")
  b=fresh(nil,mon("slowpoke","second"));local before=RulesRNG.snapshot();status(b,"confuse");eq(b.enemy.confusion,nil);unchanged(before);assert(replace(b,b.enemy));RulesRNG.seed(14);status(b,"confuse");assert(b.enemy.confusion);eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Overwritten ShedSkin emits no stale status-curing residual or RNG",function()
  local b=fresh(nil,mon("metapod"));b.enemy.status="poison";assert(replace(b,b.enemy));noEvent(b.effects:events(),"shedSkin")
  local before=RulesRNG.snapshot();b:runScript(function()b.effects:residual({kind="shedSkin",pokemon=b.enemy})end);settle(b);eq(b.enemy.status,"poison");unchanged(before)
 end)
 test("Overwritten Sturdy loses full-HP endure and OHKO immunity without damage RNG on observer",function()
  local b=fresh(nil,mon("onix","second"));eq(b.enemy:ability(),5);local n=b.enemy.hp
  eq(b.effects:limitDirectHit(b.player,b.enemy,moveData.tackle,n),n-1);assert(replace(b,b.enemy));eq(b.effects:limitDirectHit(b.player,b.enemy,moveData.tackle,n),n)
  RulesRNG.seed(14);local _,reason=b.effects:ohko(b.player,b.enemy,moveData.fissure);eq(reason,"accuracy");eq(RulesRNG.snapshot().rolls,1)
 end)
 test("Overwritten Static/PoisonPoint never reactivate on contact KO; clear follows receipt",function()
  for _,v in ipairs({{"pikachu",9},{"nidoranF",38}})do
   local b=fresh(nil,mon(v[1]));eq(b.enemy:ability(),v[2]);assert(replace(b,b.enemy));b.enemy.hp=1;act(b,"tackle")
   eq(b.enemy.hp,0);eq(b.player.status,nil);eq(RulesRNG.snapshot().rolls,3);eq(b.effects.abilityOverrides[b.enemy],nil)
   b=fresh(nil,mon(v[1]));b.enemy.hp=1;act(b,"tackle");eq(RulesRNG.snapshot().rolls,4,"unreplaced KO reaction preserved")
  end
 end)
 test("Real party switch restores native ability; new occupant never inherits override",function()
  local p,e,reserve=mon("pikachu"),mon("bulbasaur"),mon("charmander");local party=Party();assert(party:add(p));assert(party:add(reserve));own(e,"splash")
  local b=fresh(p,e,{party=party});assert(replace(b,p));eq(b.effects:effectiveAbility(p),15);assert(b:chooseParty(2));settle(b)
  eq(b.player,reserve);eq(b.effects.abilityOverrides[p],nil);eq(b.effects:effectiveAbility(reserve),66);eq(b.effects:worrySeed(e,p),false)
  assert(b:chooseParty(1));settle(b);eq(b.player,p);eq(b.effects:effectiveAbility(p),9);eq(p:ability(),9)
 end)
 test("Battle exit clears overrides and codec preserves exact native provenance",function()
  local b=fresh();local mon=b.enemy;local wire=PokemonCodec.encode(mon);assert(replace(b,mon));local decoded=PokemonCodec.decode(PokemonCodec.encode(mon))
  eq(decoded:ability(),9);eq(decoded.abilitySlot,wire.abilitySlot);eq(decoded:getSex(),mon:getSex());eq(decoded.heldItem,mon.heldItem)
  b:clearVolatiles();eq(next(b.effects.abilityOverrides),nil);eq(b.effects:effectiveAbility(mon),9);eq(b.effects:worrySeed(b.player,mon),false)
 end)
 RulesRNG.restore(saved);return report
end
