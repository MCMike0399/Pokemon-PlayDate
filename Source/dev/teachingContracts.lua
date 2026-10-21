TeachingContracts={}
local function eq(a,b)assert(a==b,tostring(a).." ~= "..tostring(b))end
local function same(a,b)
    eq(type(a),type(b));if type(a)~="table"then eq(a,b);return end
    for k,v in pairs(a)do same(v,b[k])end
    for k in pairs(b)do assert(a[k]~=nil,"extra field "..tostring(k))end
end
local function setup(species,level)
    local g=GameContext();local p=Pokemon(species or "bulbasaur",level or 5);assert(g:recruit(p))
    assert(g.session:setIntro({stage="done",starter="bulbasaur",rivalStarter="charmander"}))
    return g,p,g.session:inventory()
end
local function snapshot(g,p)return {mon=assert(PokemonCodec.encode(p)),bag=g.session:inventory():toData(),rng=RulesRNG.toData()}end
local function ui(g)
    g.machine:register("base",State("base"));g.machine:register("party",PartyState(g));g.machine:register("bag",BagState(g));g.machine:register("learning",LearningState(g));g.machine:change("base");g.machine:push("bag")
    return g.machine:get("bag"),g.machine:get("learning")
end
function TeachingContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local rng=RulesRNG.snapshot();local prior=GameSession.activeRNGSession()
    local function test(name,fn)
        local ok,why=pcall(fn);Autopilot.resetControls();report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Blue55 machine identities and151 species retain3037 permissions including original Bide",function()
        local count,allowed,species=0,0,0
        for _ in pairs(MachineData.definitions)do count=count+1 end;eq(count,55)
        for key,row in pairs(MachineData.compatibility)do assert(pokemonData[key]);species=species+1;for id in pairs(row)do assert(MachineData.definitions[id]);allowed=allowed+1 end end
        eq(species,151);eq(allowed,3037);eq(MachineData.definitions.tm34.move,"bide");eq(MachineData.definitions.tm34.consume,true)
        eq(MachineData.compatibility.bulbasaur.tm34,true);eq(MachineData.compatibility.caterpie.tm34,nil);eq(MachineData.compatibility.charizard.hm02,nil)
        for _,id in ipairs({"hm01","hm02","hm03","hm04","hm05"})do eq(MachineData.definitions[id].consume,false)end
    end)
    test("Prepare is pure and preview tampering cannot change private authority",function()
        local g,p,bag=setup();assert(bag:add("tm21",2));local before=snapshot(g,p)
        local request=assert(Teaching.prepare(g.session,p,"tm21"));local preview=request:getSnapshot();preview.move="tackle";request.item="potion"
        same(snapshot(g,p),before);eq(request:getSnapshot().move,"megaDrain");eq(request:getSnapshot().item,"tm21")
    end)
    test("Free slot consumes exactly one TM, preserves all specimen fields and retained owners",function()
        local g,p,bag=setup();assert(bag:add("tm21",2));p.status="poison";p.pp.tackle=2;p.hp=3;p.name="CUSTOM";local before=assert(PokemonCodec.encode(p));local rng=RulesRNG.snapshot()
        local ok,result=Teaching.complete(assert(Teaching.prepare(g.session,p,"tm21")),"learn");assert(ok,result)
        eq(result.kind,"learned");eq(result.consumed,true);eq(result.forgotten,nil);eq(p.moves[3],"megaDrain");eq(p.pp.megaDrain,15)
        before.moves[3]="megaDrain";before.pp.megaDrain=15;same(assert(PokemonCodec.encode(p)),before)
        eq(g.session:party():get(1),p);eq(g.session:inventory(),bag);eq(bag:quantity("tm21"),1);same(RulesRNG.snapshot(),rng)
    end)
    test("Four-slot replacement preserves min oldPP and newMax, including zeroPP",function()
        for _,pp in ipairs({0,20})do
            local g,p,bag=setup("bulbasaur",25);assert(bag:add("tm06",1));eq(#p.moves,4);local old=p.moves[1];p.pp[old]=math.min(pp,moveData[old].maxPP);local expected=math.min(p.pp[old],10)
            local r=assert(Teaching.prepare(g.session,p,"tm06"));local before=snapshot(g,p);eq(Teaching.complete(r,"learn"),false);same(snapshot(g,p),before)
            local ok,result=Teaching.complete(r,"learn",1);assert(ok,result);eq(result.forgotten,old);eq(p.moves[1],"toxic");eq(p.pp.toxic,expected);eq(p.pp[old],nil);eq(#p.moves,4);eq(#p:getPendingMoveChoices(),0);eq(bag:quantity("tm06"),0)
        end
    end)
    test("Decline and forced cancellation close once with no bag mon or RNG changes",function()
        for _,decision in ipairs({"decline","cancel"})do
            local g,p,bag=setup();assert(bag:add("tm21",1));local r=assert(Teaching.prepare(g.session,p,"tm21"));local before=snapshot(g,p)
            if decision=="cancel"then assert(Teaching.cancel(r))else assert(Teaching.complete(r,decision))end
            same(snapshot(g,p),before);eq(Teaching.complete(r,"learn"),false);eq(Teaching.cancel(r),false);same(snapshot(g,p),before)
        end
    end)
    test("Already-known incompatible missing stock unknown machine and foreign copy are pure failures",function()
        local g,p,bag=setup();local other=Pokemon("bulbasaur",5);assert(bag:add("tm21",1));local before=snapshot(g,p)
        eq(Teaching.prepare(g.session,other,"tm21"),nil);eq(Teaching.prepare(g.session,p,"potion"),nil);eq(Teaching.prepare(g.session,p,"tm06"),nil);same(snapshot(g,p),before)
        assert(Teaching.complete(assert(Teaching.prepare(g.session,p,"tm21")),"learn"));before=snapshot(g,p);eq(Teaching.prepare(g.session,p,"tm21"),nil);same(snapshot(g,p),before)
        local h,q,b=setup("caterpie",5);assert(b:add("tm21",1));local untouched=snapshot(h,q);eq(Teaching.prepare(h.session,q,"tm21"),nil);same(snapshot(h,q),untouched)
    end)
    test("Changed PP HP name and held item stale the exact prepared record without consumption",function()
        for _,mutate in ipairs({function(p)p.pp.tackle=p.pp.tackle-1 end,function(p)p.hp=p.hp-1 end,function(p)p.name="OTHER"end,function(p)p.heldItem="potion"end})do
            local g,p,bag=setup();assert(bag:add("tm21",2));local r=assert(Teaching.prepare(g.session,p,"tm21"));mutate(p);local before=snapshot(g,p)
            eq(Teaching.complete(r,"learn"),false);same(snapshot(g,p),before)
        end
    end)
    test("Quantity changes and foreign session cannot redeem an older one-shot intent",function()
        local g,p,bag=setup();assert(bag:add("tm21",2));local r=assert(Teaching.prepare(g.session,p,"tm21"));assert(bag:add("tm21",1));local before=snapshot(g,p)
        eq(Teaching.complete(r,"learn"),false);same(snapshot(g,p),before)
        local h,q=setup();eq(h.session:resolveTeaching(r,"learn"),false);same(snapshot(g,p),before)
    end)
    test("Party reorder binds actual member, while deposit invalidates ownership",function()
        local g,p,bag=setup();assert(g:recruit(Pokemon("pidgey",5)));assert(bag:add("tm21",2));local r=assert(Teaching.prepare(g.session,p,"tm21"))
        assert(g.session:party():swap(1,2));assert(Teaching.complete(r,"learn"));eq(g.session:party():get(2),p)
        local h,q,b=setup();assert(h:recruit(Pokemon("pidgey",5)));assert(b:add("tm21",1));r=assert(Teaching.prepare(h.session,q,"tm21"));assert(h.session:storage():deposit(h.session:party(),1));local before=snapshot(h,q)
        eq(Teaching.complete(r,"learn"),false);same(snapshot(h,q),before)
    end)
    test("Invalid decisions and noninteger/out-of-range replacement slots do not spend stock",function()
        local g,p,bag=setup("bulbasaur",25);assert(bag:add("tm06",1));local r=assert(Teaching.prepare(g.session,p,"tm06"));local before=snapshot(g,p)
        for _,slot in ipairs({0,5,1.5,"1",true})do eq(Teaching.complete(r,"learn",slot),false);same(snapshot(g,p),before)end
        eq(Teaching.complete(r,"delete"),false);eq(Teaching.complete(r,"decline",1),false);same(snapshot(g,p),before)
    end)
    test("Pending real learning/evolution blocks teaching without forging durable choice provenance",function()
        local g,p,bag=setup("bulbasaur",6);assert(bag:add("tm21",1));p:gainXP(xpForLevel(7,"bulbasaur")-p.xp);assert(#p:getPendingMoveChoices()>0);local before=snapshot(g,p)
        eq(Teaching.prepare(g.session,p,"tm21"),nil);same(snapshot(g,p),before)
        local h,q,b=setup("bulbasaur",16);q.pendingEvolution={species="bulbasaur",level=16};assert(b:add("tm21",1));before=snapshot(h,q);eq(Teaching.prepare(h.session,q,"tm21"),nil);same(snapshot(h,q),before)
    end)
    test("Aggregate real JSON reload preserves taught moves and remaining TM without ephemeral intent",function()
        local g,p,bag=setup();assert(bag:add("tm21",2));assert(Teaching.complete(assert(Teaching.prepare(g.session,p,"tm21")),"learn"))
        local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}));local restored=assert(SessionCodec.decode(json.decode(json.encode(wire)),g:getSessionDependencies()))
        eq(restored:party():get(1).moves[3],"megaDrain");eq(restored:inventory():quantity("tm21"),1);eq(#restored:party():get(1):getPendingMoveChoices(),0)
    end)
    test("Field Bag opens typed learning and forced exit cancels with no free four-slot teaching",function()
        local g,p,bag=setup("bulbasaur",25);assert(bag:add("tm21",1));local b,l=ui(g);local before=snapshot(g,p)
        assert(b:useMachine("tm21",1));eq(g.machine:getCurrent(),"learning");eq(l:getSnapshot().mode,"machine");eq(l.phase,"ask");eq(#p:getPendingMoveChoices(),0)
        local stale=l.menu.onSelect;g.machine:pop();stale(1);eq(l.active,false);same(snapshot(g,p),before)
    end)
    test("Machine replacement UI commits through session only after explicit confirmation",function()
        local g,p,bag=setup("bulbasaur",25);assert(bag:add("tm21",1));local b,l=ui(g);local before=snapshot(g,p)
        assert(b:useMachine("tm21",1));l.menu.onSelect(1);eq(l.phase,"replace");l.menu.onSelect(1);eq(l.phase,"confirm");same(snapshot(g,p),before)
        l.menu.onSelect(2);eq(l.phase,"replace");same(snapshot(g,p),before);l.menu.onSelect(1);l.menu.onSelect(1);eq(l.phase,"message");eq(p.moves[1],"megaDrain");eq(bag:quantity("tm21"),0)
    end)
    test("Session swap makes queued UI confirmation inert against both inventories",function()
        local g,p,bag=setup("bulbasaur",25);assert(bag:add("tm21",1));local b,l=ui(g);assert(b:useMachine("tm21",1));l.menu.onSelect(1);l.menu.onSelect(1)
        local h,q,other=setup();g.session=h.session;local beforeBag=bag:toData();local before=assert(PokemonCodec.encode(p));l.menu.onSelect(1)
        same(bag:toData(),beforeBag);same(assert(PokemonCodec.encode(p)),before);eq(other:quantity("tm21"),0);eq(l.messageKind,"failed")
    end)
    test("Forged learning request and stale displayed party identity cannot redirect teaching",function()
        local g,p,bag=setup();assert(bag:add("tm21",1));assert(g:recruit(Pokemon("bulbasaur",5)));local b,l=ui(g);local before=snapshot(g,p)
        eq(LearningState.openTeaching(g,{}),false);eq(LearningState.openTeaching(g,TeachingRequest()),false);same(snapshot(g,p),before)
        b:chooseTarget("tm21");local callback=g.machine:get("party").options.onSelect;g.machine:pop();assert(g.session:party():swap(1,2));callback(1)
        eq(b.phase,"message");eq(bag:quantity("tm21"),1);eq(p:hasMove("megaDrain"),false);eq(g.session:party():get(1):hasMove("megaDrain"),false)
    end)
    local active=GameSession.activeRNGSession();if active then active:deactivateRNG()end
    if prior then prior:activateRNG()end;RulesRNG.restore(rng)
    return report
end
