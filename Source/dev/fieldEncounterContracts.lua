-- Actual production Zone/Party/Specimen/RulesRNG and Explore owner contracts.
FieldEncounterContracts={}
local function eq(a,b)assert(a==b,"expected "..tostring(b)..", got "..tostring(a))end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function game(species,level)
    local g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});local lead=Pokemon(species,level)
    assert(g:recruit(lead));local reserve=Pokemon(species=="squirtle"and "pidgey"or "squirtle",5);assert(g:recruit(reserve))
    assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}));assert(g.session:activateRNG())
    return g,lead,reserve
end
local ordinary={{species="rattata",minLevel=5,maxLevel=5,weight=240},{species="pikachu",minLevel=3,maxLevel=3,weight=11},
    {species="pikachu",minLevel=5,maxLevel=5,weight=3},{species="voltorb",minLevel=4,maxLevel=4,weight=2}}
local function zone(slots,rate)return Zone({name="field encounter contracts",tileRows={"TG Fo"},encounterRate=rate or 1,encounters=slots or ordinary})end
local function attempt(g,z,seed)
    if seed then RulesRNG.seed(seed)end
    local plan,why=FieldEncounters.prepare({session=g.session,party=g.session:party(),zone=z,x=0,y=0});assert(plan,why)
    local ok,result=FieldEncounters.resolve(plan);assert(ok,result);return result
end
local function explore(species,level,seed,door,fn)
    local gfx=playdate.graphics;local sprites={};local count=gfx.sprite.spriteCount();local ox,oy=gfx.getDrawOffset();local noEncounters=DEBUG_FLAGS.noEncounters
    for _,sprite in ipairs(gfx.sprite.getAllSprites())do sprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()}end
    gfx.sprite.removeAll();local g,lead=game(species,level)
    local z=zone({{species="rattata",minLevel=5,maxLevel=5,weight=1}});if door then z.doors={{x=0,y=0,to="reds_house"}}end;currentZone=z
    g.player=Player(0,0,z.collision,g.npcManager);g.player.stepJustFinished=true;Story.bind(g)
    local owner={game=g,machine=g.machine,_presentedWorld=function()end};local sub=StateMachine();owner.sub=sub
    local state=ExploreSubstate(owner);sub:register("explore",state);sub:register("irisOut",{});sub:register("doorWarp",{})
    sub:change("explore");g.machine:register("overworld",{sub=sub});g.machine:change("overworld")
    RulesRNG.seed(seed);DEBUG_FLAGS.noEncounters=false
    local ok,why=pcall(function()state:update();fn(g,sub,lead)end)
    DEBUG_FLAGS.noEncounters=noEncounters
    for _,sprite in ipairs(gfx.sprite.getAllSprites())do sprite:remove()end
    for sprite,value in pairs(sprites)do sprite:add();sprite:setVisible(value.visible);sprite:setUpdatesEnabled(value.enabled)end
    gfx.setDrawOffset(ox,oy);eq(gfx.sprite.spriteCount(),count);assert(ok,why)
end
function FieldEncounterContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local before,owner=RulesRNG.snapshot(),GameSession.activeRNGSession();local oldStory=Story.currentContext();local oldZone=currentZone
        local ok,why=pcall(fn)
        local active=GameSession.activeRNGSession();if active~=owner then if active then active:deactivateRNG()end;if owner then assert(owner:activateRNG())end end
        RulesRNG.restore(before);Story.bind(oldStory);currentZone=oldZone
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("source50 gate49 inactive and50 active, with Blue table physical duplicate indices",function()
        local g=game("pikachu",10);local z=zone();local saved=Party._primitive(z.encounters)
        local off=attempt(g,z,50);eq(off.receipt.gate_roll,49);eq(off.receipt.gate_active,false)
        local on=attempt(g,z,93);eq(on.receipt.gate_roll,50);eq(on.receipt.gate_active,true)
        assert(same(on.receipt.preferred_slots,{2,3,4}));assert(on.receipt.slot>=2 and on.receipt.slot<=4);eq(on.kind,"encounter")
        assert(same(z.encounters,saved));eq(z.encounterRate,1)
    end)
    test("Static uniformly chooses matching slot indices, preserving duplicate Pikachu levels",function()
        local g=game("pikachu",10);local z=zone();local seen={}
        for seed=1,100 do
            local r=attempt(g,z,seed)
            if r.receipt.gate_active then
                local expected=RulesRNG.new(seed);expected:random(0,99);expected:random();local pick=expected:random(1,3)
                eq(r.receipt.preferred_roll,pick);eq(r.receipt.slot,({2,3,4})[pick]);seen[r.receipt.slot]=true
                eq(r.pokemon.level,z.encounters[r.receipt.slot].minLevel)
            end
        end
        assert(seen[2]and seen[3]and seen[4])
    end)
    test("Static without any Electric slot falls back to the unchanged weighted table",function()
        local g=game("pikachu",10);local z=zone({{species="rattata",minLevel=3,maxLevel=3,weight=7},{species="pidgey",minLevel=4,maxLevel=4,weight=3}})
        local r=attempt(g,z,93);eq(r.receipt.gate_active,true);eq(#r.receipt.preferred_slots,0);assert(r.receipt.slot_roll);eq(r.kind,"encounter")
        eq(r.pokemon.species,z.encounters[r.receipt.slot].species);eq(RulesRNG.snapshot().rolls,7)
    end)
    test("KeenEye and Intimidate suppress at exactly5below before any creation",function()
        for _,species in ipairs({"pidgey","arbok"})do
            local g=game(species,10);local z=zone({{species="rattata",minLevel=5,maxLevel=5,weight=1}})
            local original=Specimen.create;local calls=0;Specimen.create=function(...)calls=calls+1;return original(...)end
            local ok,r=pcall(attempt,g,z,93);Specimen.create=original;assert(ok,r)
            eq(r.kind,"none");eq(r.reason,"ability-suppressed");eq(calls,0);eq(RulesRNG.snapshot().rolls,4)
        end
    end)
    test("fourbelow and inactive gate both permit original specimen creation calls",function()
        local g=game("pidgey",9);local z=zone({{species="rattata",minLevel=5,maxLevel=5,weight=1}})
        local r=attempt(g,z,93);eq(r.kind,"encounter");eq(r.receipt.gate_active,true);eq(r.receipt.creation.draws,3);eq(RulesRNG.snapshot().rolls,7)
        local g=game("pidgey",10);r=attempt(g,z,50);eq(r.receipt.gate_active,false);eq(r.kind,"encounter")
    end)
    test("fainted physical lead supplies ability but conscious member supplies suppression level",function()
        local g,lead,reserve=game("pidgey",20);lead.hp=0;local z=zone({{species="rattata",minLevel=5,maxLevel=5,weight=1}})
        local r=attempt(g,z,93);eq(r.kind,"encounter");eq(r.receipt.ability,51);eq(r.receipt.physical_lead.fainted,true);eq(r.receipt.usable_lead.index,2);eq(r.receipt.usable_lead.level,5)
        local g,lead,reserve=game("pidgey",5);lead.hp=0 -- install a valid native level10 reserve record below.
        local replacement=Pokemon("squirtle",10);local data=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
        data.party.members[2]=assert(SessionCodec.encodePokemon(replacement));local restored=assert(SessionCodec.decode(data,g:getSessionDependencies()));assert(restored:activateRNG());g.session=restored
        r=attempt(g,z,93);eq(r.kind,"none");eq(r.reason,"ability-suppressed");eq(r.receipt.usable_lead.level,10)
    end)
    test("physical lead Static survives fainting and ignores separately selected battle active",function()
        local g,lead,reserve=game("pikachu",10);lead.hp=0;assert(g.session:party():switch(2));local r=attempt(g,zone(),93)
        eq(r.receipt.ability,9);eq(r.receipt.physical_lead.fainted,true);eq(r.receipt.gate_active,true);eq(g.session:party():active(),reserve);assert(r.receipt.slot>=2)
    end)
    test("volatile WorrySeed overrides cannot replace durable field ability",function()
        local g,lead=game("pikachu",10);local b=Battle(lead,Pokemon("exeggcute",10),nil,{party=g.session:party(),session=g.session})
        b:runScript(function()assert(b.effects:worrySeed(b.enemy,lead))end);eq(b.effects:effectiveAbility(lead),15);eq(lead:ability(),9)
        local r=attempt(g,zone(),93);eq(r.receipt.ability,9);eq(r.receipt.gate_active,true);b:clearVolatiles()
    end)
    test("ordinary unrelated and CompoundEyes attempts retain old sampler exact continuation",function()
        for _,species in ipairs({"squirtle","butterfree"})do
            local g=game(species,10);local z=zone()
            for _,seed in ipairs({1,42,93})do
                RulesRNG.seed(seed);assert(z:checkEncounter(0,0));local old=assert(z:rollEncounter(g.session));local after=RulesRNG.toData();local mon=assert(PokemonCodec.encode(old))
                local r=attempt(g,z,seed);eq(r.receipt.gate,"none");assert(same(after,RulesRNG.toData()));assert(same(mon,PokemonCodec.encode(r.pokemon)))
            end
        end
    end)
    test("accepted Electric creation retains existing slot nature sex held sequence exactly",function()
        local g=game("pikachu",10);local z=zone({{species="pikachu",minLevel=3,maxLevel=3,weight=1}})
        local expected=RulesRNG.new(93);expected:random(0,99);expected:random();expected:random(1,1);expected:random(3,3)
        local token=assert(Specimen.planEncounter(g.session));local mon,created=Specimen.create("pikachu",3,"wild",expected,token);assert(mon,created)
        local r=attempt(g,z,93);eq(r.receipt.creation.draws,4);assert(same(PokemonCodec.encode(mon),PokemonCodec.encode(r.pokemon)));assert(same(expected:toData(),RulesRNG.toData()));eq(RulesRNG.snapshot().rolls,8)
    end)
    test("invalid indoor coordinates no usable party foreign owner and malformed table are pure",function()
        local g,lead,reserve=game("pikachu",10);local z=zone();local before=RulesRNG.toData();local world=g.session:worldRngData()
        local function reject(c)eq(FieldEncounters.prepare(c),nil);assert(same(before,RulesRNG.toData()));assert(same(world,g.session:worldRngData()))end
        reject({session=g.session,party=g.session:party(),zone=z,x=0,y=0,forced=true});reject({session=g.session,party=g.session:party(),zone=z,x=0,y=0,repelActive=true})
        reject({session=g.session,party=g.session:party(),zone=z,x=1,y=0});reject({session=g.session,party=g.session:party(),zone=z,x=-1,y=0})
        z.encounters[1].species="missing";reject({session=g.session,party=g.session:party(),zone=z,x=0,y=0});z.encounters[1].species="rattata"
        z.encounters[1].weight=0;reject({session=g.session,party=g.session:party(),zone=z,x=0,y=0});z.encounters[1].weight=240
        lead.hp=0;reserve.hp=0;reject({session=g.session,party=g.session:party(),zone=z,x=0,y=0})
        local foreign=GameContext();reject({session=foreign.session,party=foreign.session:party(),zone=z,x=0,y=0})
    end)
    test("stale plan rejects roster slot HP table terrain and RNG changes with no additional rolls",function()
        for _,change in ipairs({function(g,z)g.session:party():get(1).hp=1 end,function(g,z)assert(g.session:party():swap(1,2))end,
            function(g,z)z.encounters[1].weight=1 end,function(g,z)z:setTile(0,0,1)end,function(g,z)RulesRNG.random()end})do
            local g=game("pikachu",10);local z=zone();local plan=assert(FieldEncounters.prepare({session=g.session,party=g.session:party(),zone=z,x=0,y=0}));change(g,z)
            local before=RulesRNG.toData();eq(FieldEncounters.resolve(plan),false);assert(same(before,RulesRNG.toData()));eq(FieldEncounters.resolve(plan),false)
        end
    end)
    test("actual pinned BlueForest byte rate and both Electric source rows match independent literal vectors",function()
        local g=game("pikachu",10);local z=PewterWorld.isolated("ViridianForest");local x,y
        for gy=0,z.height-1 do for gx=0,z.width-1 do if z:isTallGrass(gx,gy)and z.collision[gy+1][gx+1]==0 then x,y=gx,gy;break end end;if x then break end end;assert(x)
        local descriptor=assert(z:encounterPolicyAt(x,y));eq(descriptor.rate.kind,"byte");eq(descriptor.rate.value,8);eq(#descriptor.slots,10)
        local before=Party._primitive(z.encounters)
        -- Independently calculated Park-Miller literal vectors; no RNG searching
        -- or outcome prediction in the production policy/native input journey.
        for _,v in ipairs({{327,88,1,10,5,6,246,18,"none","2123351119"},{413,90,2,9,3,5,138,53,"lightBall","796991454"}})do
            RulesRNG.seed(v[1]);local plan=assert(FieldEncounters.prepare({session=g.session,party=g.session:party(),zone=z,x=x,y=y}));local ok,r=FieldEncounters.resolve(plan);assert(ok,r)
            eq(r.kind,"encounter");eq(r.receipt.gate_roll,v[2]);eq(r.receipt.rate_roll,v[3]);eq(r.receipt.slot,v[4]);eq(r.pokemon.species,"pikachu");eq(r.pokemon.level,v[5]);eq(r.pokemon.abilitySlot,"second")
            eq(r.pokemon.natureId,v[6]);eq(r.pokemon.sexProvenance.byte,v[7]);eq(r.receipt.creation.heldRoll,v[8]);eq(r.pokemon.heldItem,v[9]);eq(RulesRNG.toData().state,v[10]);eq(RulesRNG.snapshot().rolls,8)
            assert(same(r.receipt.preferred_slots,{9,10}));assert(same(before,z.encounters))
        end
    end)
    test("specimen constructor and exhausted continuation failures commit no actual rules or world draws",function()
        local g=game("pikachu",10);local z=zone();RulesRNG.seed(93);local plan=assert(FieldEncounters.prepare({session=g.session,party=g.session:party(),zone=z,x=0,y=0}));local before=RulesRNG.toData();local world=g.session:worldRngData()
        local original=Specimen.create;Specimen.create=function()return nil,"controlled-field-constructor-failure"end
        local ok,error=FieldEncounters.resolve(plan);Specimen.create=original;eq(ok,false);assert(tostring(error):find("controlled-field-constructor-failure",1,true));assert(same(before,RulesRNG.toData()));assert(same(world,g.session:worldRngData()))
        local value=RulesRNG.snapshot();value.rolls=2147483647;RulesRNG.restore(value);before=RulesRNG.toData();plan=assert(FieldEncounters.prepare({session=g.session,party=g.session:party(),zone=z,x=0,y=0}));eq(FieldEncounters.resolve(plan),false);assert(same(before,RulesRNG.toData()))
    end)
    test("accepted suppressed and failed-rate attempts never consume actor world stream",function()
        local g=game("pidgey",10);local world=g.session:worldRngData();local z=zone({{species="rattata",minLevel=5,maxLevel=5,weight=1}})
        eq(attempt(g,z,93).kind,"none");eq(attempt(g,z,50).kind,"encounter");z.encounterRate=0.0000001;eq(attempt(g,z,93).reason,"rate");eq(RulesRNG.snapshot().rolls,2);assert(same(world,g.session:worldRngData()))
    end)
    test("schema save decode replay preserves both explicit streams and durable lead",function()
        local g=game("pikachu",10);local z=zone();RulesRNG.seed(93)
        local data=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}));local first=attempt(g,z);local after=RulesRNG.toData();local world=g.session:worldRngData()
        local restored=assert(SessionCodec.decode(data,g:getSessionDependencies()));assert(restored:activateRNG());g.session=restored;local replay=attempt(g,z)
        assert(same(first.receipt,replay.receipt));assert(same(PokemonCodec.encode(first.pokemon),PokemonCodec.encode(replay.pokemon)));assert(same(after,RulesRNG.toData()));assert(same(world,restored:worldRngData()))
    end)
    test("actual Explore suppresses without iris or specimen, accepted gate enters original iris",function()
        explore("pidgey",10,93,false,function(g,sub)
            eq(sub:getCurrent(),"explore");eq(g.lastEncounterAttempt.reason,"ability-suppressed");eq(RulesRNG.snapshot().rolls,4)
        end)
        explore("pidgey",10,50,false,function(g,sub)
            eq(sub:getCurrent(),"irisOut");eq(g.lastEncounterAttempt.reason,"accepted");eq(g.lastEncounterAttempt.creation.draws,3)
        end)
    end)
    test("actual Explore source door preempts field gate without consuming any rules draw",function()
        explore("pidgey",10,93,true,function(g,sub)
            eq(sub:getCurrent(),"doorWarp");eq(g.lastEncounterAttempt,nil);eq(RulesRNG.snapshot().rolls,0)
        end)
    end)
    return report
end
