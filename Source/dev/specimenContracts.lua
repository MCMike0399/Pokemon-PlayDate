-- Real SDK contracts for attributes/data/creation/persistence; no ability effects.
SpecimenContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function copy(x) if type(x)~="table" then return x end;local out={};for k,v in pairs(x) do out[k]=copy(v) end;return out end
local function same(a,b,path)
    path=path or "record";eq(type(a),type(b),path.." type")
    if type(a)~="table" then eq(a,b,path);return end
    for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,path.." extra "..tostring(k)) end
end
local function sameRNG(before,rng) same(before,rng and rng:snapshot() or RulesRNG.snapshot(),"RNG") end
local function attributes(nature,slot,item) return {natureId=nature or 0,abilitySlot=slot or "first",heldItem=item or "none"} end
local function owned(mon)
    local game=GameContext();assert(game:recruit(mon))
    local starter=({charmander=true,squirtle=true,bulbasaur=true})[mon.species] and mon.species or "charmander"
    if starter~=mon.species then assert(game:recruit(Pokemon(starter,5))) end
    assert(game.session:setIntro({stage="done",starter=starter,rivalStarter=({charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"})[starter],rivalOutcome=true}))
    assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
    return game
end
local function learn(game,mon)
    game.machine:register("base",State("base"));game.machine:register("learning",LearningState(game));game.machine:change("base")
    assert(LearningState.open(game,mon))
    local state=game.machine:get("learning");local n=0
    while game.machine:is("learning") do
        n=n+1;assert(n<100,"actual learning did not settle")
        if state.phase=="message" then assert(state.dialog.onComplete)();state:handleInput()
        elseif state.phase=="ask" then state.menu.onSelect(2)
        elseif state.phase=="stop" then state.menu.onSelect(1)
        else error("unexpected learning phase "..state.phase) end
    end
end
local function legacy(record,version)
    local out=copy(record);out.version=version;out.ivs,out.evs=nil,nil;out.sex,out.sexProvenance=nil,nil;out.natureId,out.abilitySlot,out.heldItem=nil,nil,nil
    if version==3 then out.pendingEvolution=nil end;return out
end
function SpecimenContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("151 species retain three slot preferences and111 GenV ability IDs",function()
        local count,abilities=0,{}
        for species,data in pairs(pokemonData) do
            count=count+1
            for _,slot in ipairs({"first","second","hidden"}) do
                local mon=Pokemon(species,5,attributes(0,slot))
                eq(mon:ability(),SpecimenData.slots[data.dex][slot]);assert(SpecimenData.abilityNames[mon:ability()]);abilities[mon:ability()]=true
            end
        end
        local n=0;for _ in pairs(abilities) do n=n+1 end;eq(count,151);eq(n,111)
        eq(Pokemon("gengar",5):ability(),26,"GenV Levitate, never later Cursed Body")
        eq(Pokemon("geodude",5,attributes(0,"second")):ability(),5)
    end)
    test("25 natures apply integer modifier after completed stat and never HP",function()
        local vectors={{0,54,54,70,70,50},{3,59,54,63,70,50},{5,48,59,70,70,50},{10,48,54,70,70,55},{15,48,54,77,70,50},{22,54,54,70,77,45}}
        for _,v in ipairs(vectors) do
            local p=Pokemon("bulbasaur",50,attributes(v[1]));eq(p.maxHP,105)
            for i,key in ipairs({"atk","def","spa","spd","spe"}) do eq(p[key],v[i+1],"nature "..v[1].." "..key) end
        end
        local p=Pokemon("mewtwo",100,attributes(15));eq(p.spa,344);eq(p.atk,202);eq(p.maxHP,322)
        local neutral=0;for id=0,24 do local row=SpecimenData.natures[id];assert(row);if row.atk==0 and row.def==0 and row.spa==0 and row.spd==0 and row.spe==0 then neutral=neutral+1 end end;eq(neutral,5)
    end)
    test("Pure two-argument construction and reconstruction consume no rules RNG",function()
        local before=RulesRNG.snapshot();local p=Pokemon("charmander",5)
        eq(p.natureId,0);eq(p.abilitySlot,"first");eq(p.heldItem,"none");eq(p:ability(),66)
        local record=assert(PokemonCodec.encode(p));local again=assert(PokemonCodec.decode(record));same(again:attributes(),p:attributes());sameRNG(before)
    end)
    test("Constructor attributes are detached normalized and reject malformed fields",function()
        local a=attributes(3,"hidden","potion");a.natureId=3.0;local p=Pokemon("pikachu",5,a);a.abilitySlot="first"
        eq(p.abilitySlot,"hidden");eq(math.type(p.natureId),"integer");local b=p:attributes();b.heldItem="none";eq(p.heldItem,"potion")
        for _,bad in ipairs({{},attributes(25),attributes(-1),attributes(1.5),attributes(0,"normal"),attributes(0,"first","missing"),{natureId=0,abilitySlot="first",heldItem="none",extra=true}}) do
            eq(pcall(Pokemon,"charmander",5,bad),false)
        end
    end)
    test("Canonical keys TM HM and EXP.ALL reject as held; medicines balls stones validate",function()
        for _,id in ipairs({"townMap","oaksParcel","tm01","hm01","expAll"}) do eq(pcall(Pokemon,"eevee",5,attributes(0,"first",id)),false,id) end
        for _,id in ipairs({"potion","pokeBall","moonStone"}) do eq(Pokemon("eevee",5,attributes(0,"first",id)).heldItem,id) end
    end)
    test("Factoryv3 literal nine-call vectors (old first-three retained) and continuation match independent PM oracle",function()
        for _,v in ipairs({{1,"first",23,1458777923},{42,"second",22,1139130650},{12345,"first",23,1963079340}}) do
            local rng=RulesRNG.new(v[1]);local mon,receipt=Specimen.create("eevee",5,"wild",rng);assert(mon,receipt)
            eq(mon.abilitySlot,v[2]);eq(mon.natureId,v[3]);eq(rng:snapshot().state,v[4]);eq(rng:snapshot().rolls,9)
            eq(receipt.version,3);eq(receipt.origin,"wild");eq(receipt.draws,9);eq(receipt.rawRolls,9);eq(mon.heldItem,"none")
        end
    end)
    test("Rejection sampling uses nine API calls but honest ten raw rolls",function()
        local rng=RulesRNG.new(671875339);local p,receipt=Specimen.create("eevee",5,"wild",rng);assert(p,receipt)
        eq(p.abilitySlot,"first");eq(p.natureId,14);eq(receipt.draws,9);eq(receipt.rawRolls,10);eq(rng:snapshot().state,689632769)
    end)
    test("All ordinary origins roll only normal preferences even duplicate ability species",function()
        for _,origin in ipairs({"wild","starter","trainer","gift","debug"}) do
            for _,seed in ipairs({1,42}) do
                local p=assert(Specimen.create("metapod",7,origin,RulesRNG.new(seed),nil,origin=="trainer" and Specimen.blueTrainerPolicy("contract:metapod")or nil))
                assert(p.abilitySlot=="first" or p.abilitySlot=="second");eq(p:ability(),61)
                eq(p.natureId,seed==1 and 23 or 22)
            end
        end
    end)
    test("Invalid factory origin species level RNG reject without live stream mutation",function()
        local rng=RulesRNG.new(42);local before=rng:snapshot()
        for _,v in ipairs({{"missing",5,"wild"},{"eevee",0,"wild"},{"eevee",101,"wild"},{"eevee",5.5,"wild"},{"eevee",5,"hidden"},{"eevee",5,{kind="wild",hidden=true}}}) do
            eq(Specimen.create(v[1],v[2],v[3],rng),nil);sameRNG(before,rng)
        end
        eq(Specimen.create("eevee",5,"wild",nil),nil);sameRNG(before,rng)
    end)
    test("Native MAX exhaustion after first draw rolls back entire creation",function()
        local rng=RulesRNG.new(42);local before=rng:snapshot();before.rolls=2147483646;rng:restore(before)
        local p,why=Specimen.create("eevee",5,"wild",rng);eq(p,nil);assert(why:find("exhausted",1,true),why);sameRNG(before,rng)
        before.rolls=2147483638;rng:restore(before);p=assert(Specimen.create("eevee",5,"wild",rng));eq(rng:snapshot().rolls,2147483647)
    end)
    test("All151 Codec7 reconstruct chosen attributes without reroll or PP change",function()
        local before=RulesRNG.snapshot()
        for species in pairs(pokemonData) do
            local p=Pokemon(species,50,attributes(15,"hidden","potion"));p.name="CUSTOM";p.hp=1;p.pp[p.moves[1]]=0
            local data=assert(PokemonCodec.encode(p));eq(data.version,7);local again=assert(PokemonCodec.decode(data))
            same(assert(PokemonCodec.encode(again)),data);eq(again.spa,p.spa);eq(again.atk,p.atk);eq(again:ability(),p:ability())
        end
        sameRNG(before)
    end)
    test("Legacy3 defaults are deliberate and preserve names HP0 sleep XP PP and choices",function()
        local p=Pokemon("charmander",6);p:gainXP(p:xpForLevel(7)-p.xp);p.name="OLD NAME";p.hp=0;p.status="sleep";p.statusTurns=0;p.sleepDuration=3;p.pp.scratch=2
        local old=legacy(assert(PokemonCodec.encode(p)),3);local before=RulesRNG.snapshot();local restored=assert(PokemonCodec.decode(old))
        eq(restored.natureId,0);eq(restored.abilitySlot,"first");eq(restored.heldItem,"none")
        local upgraded=assert(PokemonCodec.encode(restored));eq(upgraded.version,7)
        for _,key in ipairs({"species","name","hp","level","xp","status","statusTurns","sleepDuration","moves","pp","pendingMoveChoices","nextMoveChoiceId"}) do same(upgraded[key],old[key],key) end
        sameRNG(before)
    end)
    test("Legacy4 preserves pending evolution and current-level evolution move reasons",function()
        local p=Pokemon("charmander",15);local game=owned(p);p:gainXP(p:xpForLevel(16)-p.xp)
        local old=legacy(assert(PokemonCodec.encode(p)),4);local again=assert(PokemonCodec.decode(old));same(again.pendingEvolution,p.pendingEvolution);same(again.pendingMoveChoices,p.pendingMoveChoices)
        p=Pokemon("abra",15);game=owned(p);p:gainXP(p:xpForLevel(16)-p.xp)
        assert(Evolution.complete(assert(Evolution.prepare(game.session,p,{kind="level"}))))
        local current=assert(PokemonCodec.encode(p));eq(current.pendingMoveChoices[1].reason,"evolution");assert(PokemonCodec.decode(current))
        old=legacy(current,4);again=assert(PokemonCodec.decode(old));eq(again:getPendingMoveChoices()[1].reason,"evolution");eq(again.species,"kadabra")
    end)
    test("Malformed new mixed legacy and unknown codec schemas reject without reconstruction RNG",function()
        local data=assert(PokemonCodec.encode(Pokemon("charmander",5)));local before=RulesRNG.snapshot()
        for _,bad in ipairs({{version=2},{version=4},{version=3},{natureId=25},{abilitySlot="none"},{heldItem="townMap"},{heldItem="tm01"}}) do
            local record=copy(data);for k,v in pairs(bad) do record[k]=v end;eq(PokemonCodec.decode(record),nil)
        end
        local missing=copy(data);missing.natureId=nil;eq(PokemonCodec.decode(missing),nil);sameRNG(before)
    end)
    test("Session JSON roundtrip preserves owned hidden specimen nature item sleep and nickname",function()
        local p=Pokemon("pikachu",12,attributes(22,"hidden","potion"));p.name="SPARK";p.status="sleep";p.statusTurns=0;p.sleepDuration=3;p.hp=1
        local game=owned(p);local data=assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        local before=RulesRNG.snapshot();local again=assert(SessionCodec.decode(json.decode(json.encode(data)),game:getSessionDependencies())):party():get(1)
        eq(again.natureId,22);eq(again.abilitySlot,"hidden");eq(again.heldItem,"potion");eq(again:ability(),31);eq(again.name,"SPARK");eq(again.hp,1);eq(again.sleepDuration,3);sameRNG(before)
    end)
    test("HA provenance survives Caterpie Metapod Butterfree with nature held PP sleep preserved",function()
        local p=Pokemon("caterpie",6,attributes(10,"hidden","potion"));p.pp.tackle=2;p.status="sleep";p.statusTurns=0;p.sleepDuration=3
        local game=owned(p);local before=RulesRNG.snapshot();local identity=p
        for _,v in ipairs({{7,"metapod",61},{10,"butterfree",110}}) do
            p:gainXP(p:xpForLevel(v[1])-p.xp);if #p:getPendingMoveChoices()>0 then learn(game,p) end
            assert(Evolution.complete(assert(Evolution.prepare(game.session,p,{kind="level"}))))
            eq(p.species,v[2]);eq(p:ability(),v[3]);eq(p.abilitySlot,"hidden");eq(p.natureId,10);eq(p.heldItem,"potion");eq(p.pp.tackle,2);eq(p.status,"sleep");eq(p.statusTurns,0);eq(p.sleepDuration,3);eq(game.session:party():get(1),identity)
            if #p:getPendingMoveChoices()>0 then learn(game,p) end
        end
        sameRNG(before)
    end)
    test("Normal second preference survives stone evolution with duplicate target slot",function()
        local p=Pokemon("eevee",5,attributes(3,"second","moonStone"));local game=owned(p);assert(game.session:inventory():add("waterStone",1))
        local before=RulesRNG.snapshot();eq(p:ability(),91);assert(Evolution.complete(assert(Evolution.prepare(game.session,p,{kind="stone",item="waterStone"}))))
        eq(p.species,"vaporeon");eq(p.abilitySlot,"second");eq(p:ability(),11);eq(p.natureId,3);eq(p.heldItem,"moonStone");eq(game.session:inventory():quantity("waterStone"),0);sameRNG(before)
    end)
    test("Debug level reset keeps same owned identity attributes and custom name without RNG",function()
        local p=Pokemon("charmander",5,attributes(3,"hidden","potion"));p.name="CUSTOM";local game=owned(p);local before=RulesRNG.snapshot()
        eq(game:resetActiveLevelForDebug(20),p);eq(p.natureId,3);eq(p.abilitySlot,"hidden");eq(p.heldItem,"potion");eq(p.name,"CUSTOM");eq(p.level,20);sameRNG(before)
    end)
    test("Wild aggregate commits species level and attribute rolls only after success",function()
        local zone=Zone({name="Specimen contract",tileRows={"Fo"},encounters={{species="rattata",minLevel=3,maxLevel=3,weight=1}}})
        RulesRNG.seed(42);local mon=zone:rollEncounter();eq(mon.species,"rattata");eq(mon.level,3);eq(RulesRNG.snapshot().rolls,11)
        zone.encounters[1].species="missing";local before=RulesRNG.snapshot();eq(pcall(zone.rollEncounter,zone),false);sameRNG(before)
        zone.encounters[1].species="rattata";before.rolls=2147483644;RulesRNG.restore(before);eq(pcall(zone.rollEncounter,zone),false);sameRNG(before)
    end)
    test("Fixture specimen fields preflight late malformed values before reset mutation",function()
        local p=Pokemon("charmander",5);local game=owned(p);game.machine:register("base",State("base"));game.machine:change("base")
        local session,stack,before=game.session,game.machine:current(),RulesRNG.snapshot()
        local options={intro="skip",opening=false,party_pokemon={{species="charmander",level=5},{species="pikachu",level=5,nature_id=22,ability_slot="hidden",held_item="potion"}}}
        assert(HarnessFixtures.validate(options))
        for _,bad in ipairs({{nature_id=25},{nature_id=false},{ability_slot="unknown"},{held_item="tm01"},{held_item="townMap"},{held_item="expAll"},{extra=true}}) do
            local altered=copy(options);for k,v in pairs(bad) do altered.party_pokemon[2][k]=v end
            eq(pcall(HarnessFixtures.reset,game,altered),false);eq(game.session,session);eq(game.machine:current(),stack);sameRNG(before)
        end
    end)
    RulesRNG.restore(saved);return report
end
