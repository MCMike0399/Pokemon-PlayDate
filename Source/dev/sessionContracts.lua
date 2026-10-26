-- SDK contracts against real domain models, RNG and staged world preflight.
SessionContracts={}
local invocation=0
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function copy(value) return Party._primitive(value) end
local gate={root="overworld",overworld="explore",settled=true}
local function start() return {zone_id="reds_house_2f",x=5,y=3,facing="up"} end
function SessionContracts.dependencies()
    assert(WorldDeltas and WorldDeltas.validate and WorldDeltas.resolveLocation,"pure world seams required")
    return {itemDefinitions={potion={keyItem=false},pokeBall={keyItem=false},oaksParcel={keyItem=true}},
        validateWorld=WorldDeltas.validate,resolveLocation=WorldDeltas.resolveLocation}
end
function SessionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local initialRNG=RulesRNG.toData()
    local priorOwner=GameSession.activeRNGSession()
    local created={}
    local function test(name,fn)
        local ok,err=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(err) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1; report.ok=false end
    end
    local function fresh(seed)
        local session=GameSession.newSession(SessionContracts.dependencies(),{location=start(),seed=seed or 42,
            checkpoint={zone_id="reds_house",x=3,y=7,facing="up"}})
        created[#created+1]=session
        return session
    end
    local function starter(seed)
        local session=fresh(seed)
        local pokemon=Pokemon("charmander",5)
        assert(session:recruit(pokemon))
        assert(session:setIntro({stage="done",starter="charmander",rivalStarter="squirtle",rivalOutcome=false}))
        return session,pokemon
    end
    local function data(session) return assert(SessionCodec.encode(session,gate)) end
    local function decode(record)
        local session=assert(SessionCodec.decode(record,SessionContracts.dependencies()))
        created[#created+1]=session; return session
    end
    test("new empty session derives active member and preserves pre-starter metadata",function()
        local before=RulesRNG.toData()
        local session=fresh(2147483646)
        eq(session:activePokemon(),nil); eq(session:party():count(),0); eq(session:storage():count(),0)
        eq(session:title().playerName,"RED"); eq(session:title().rivalName,"BLUE")
        local record=data(session)
        eq(record.intro.starter,"none"); eq(record.intro.rivalOutcome,"none"); eq(record.rng.seed,"2147483646")
        local restored=decode(json.decode(json.encode(record)))
        assert(same(data(restored),record)); assert(same(before,RulesRNG.toData()))
        eq(restored:getIntro().starter,nil)
    end)
    test("recruit starter party six current box full failures and ownership",function()
        local session,pokemon=starter()
        eq(session:activePokemon(),pokemon); eq(session:activePokemon(),session:party():active())
        assert(session:pokedex().owned.charmander and session:pokedex().seen.charmander)
        for i=2,6 do assert(session:recruit(Pokemon("squirtle",5))) end
        for i=1,20 do
            local ok,result=session:recruit(Pokemon("rattata",3)); assert(ok); eq(result.destination,"storage"); eq(result.box,1)
        end
        local before=data(session); local extra=Pokemon("mew",5)
        local ok,reason=session:recruit(extra); eq(ok,false); eq(reason,"box-full")
        assert(same(before,data(session))); eq(session:pokedex().owned.mew,nil); eq(session:storage():count(2),0)
        assert(session:storage():selectBox(2)); assert(session:recruit(extra)); eq(session:storage():get(1),extra)
        local other=fresh(); ok,reason=other:recruit(pokemon); eq(ok,false); eq(reason,"already-owned")
        eq(other:party():count(),0); eq(other:pokedex().owned.charmander,nil)
        assert(session:party():swap(1,2)); eq(session:activePokemon(),pokemon)
    end)
    test("aggregate JSON roundtrip preserves all domains and native wide counters",function()
        local session,pokemon=starter(2147483646)
        pokemon:gainXP(400)
        pokemon.nextMoveChoiceId=16777217
        pokemon.hp=3; pokemon.status="sleep"; pokemon.statusTurns=0; pokemon.sleepDuration=3
        pokemon.pp[pokemon.moves[1]]=0
        assert(session:inventory():add("potion",99)); assert(session:inventory():add("potion",2))
        assert(session:inventory():add("oaksParcel",1)); assert(session:inventory():credit(999999))
        assert(session:setQuestFlag("pallet/parcel_received",true))
        assert(session:setTrainerDefeated("pallet_town/npc/blue-rematch",true))
        assert(session:markSeen("mew"))
        for i=1,6 do if session:party():count()<6 then assert(session:recruit(Pokemon("squirtle",5))) end end
        assert(session:storage():selectBox(12)); assert(session:recruit(Pokemon("pidgey",4)))
        local original=data(session); eq(original.party.members[1].nextMoveChoiceId,"16777217")
        local restored=decode(json.decode(json.encode(original)))
        assert(same(data(restored),original)); eq(restored:getIntro().rivalOutcome,false)
        eq(math.type(restored:activePokemon().nextMoveChoiceId),"integer")
        eq(restored:activePokemon().nextMoveChoiceId,16777217)
        eq(restored:activePokemon().hp,3); eq(restored:activePokemon().status,"sleep"); eq(restored:activePokemon().statusTurns,0)
        eq(restored:activePokemon().pp[restored:activePokemon().moves[1]],0)
        local seen={}
        for _,mon in ipairs(restored:party():members()) do assert(not seen[mon]); seen[mon]=true end
        for box=1,12 do for i=1,restored:storage():count(box) do local mon=restored:storage():get(i,box); assert(not seen[mon]); seen[mon]=true end end
        assert(restored:activePokemon()~=pokemon)
        restored:activePokemon():takeDamage(1); eq(pokemon.hp,3)
        assert(restored:inventory():consume("potion",1)); eq(session:inventory():quantity("potion"),101)
        local flags=restored:flags(); flags.quest["pallet/parcel_received"]=false
        eq(restored:questFlag("pallet/parcel_received"),true)
        original.pokedex.seen.mew=nil; eq(session:pokedex().seen.mew,true)
    end)
    test("every malformed candidate leaves current objects world and global RNG unchanged",function()
        local session,pokemon=starter()
        local original=data(session); local rng=RulesRNG.toData(); local world=WorldDeltas.export()
        local changes={
            function(d) d.version=SessionCodec.VERSION+1 end,
            function(d) d.pokemonEncoding="unknown" end,
            function(d) d.title.playerName="ASH" end,
            function(d) d.intro.rivalStarter="bulbasaur" end,
            function(d) d.questFlags.bad=1 end,
            function(d) d.trainerFlags["bad key"]=true end,
            function(d) d.pokedex.seen.charmander=nil end,
            function(d) d.pokedex.owned.missingno=true end,
            function(d) d.location.zone_id="unknown-zone" end,
            function(d) d.location.x=9999 end,
            function(d) d.location={zone_id="reds_house_2f",x=5,y=2,facing="up"} end,
            function(d) d.checkpoint.facing="sideways" end,
            function(d) d.world.unsupportedPersistentField=true end,
            function(d) d.rng.state="2147483647" end,
            function(d) d.rng.rolls="01" end,
            function(d) d.party.active=0 end,
            function(d) d.party.members[1].xp="not-decimal" end,
            function(d) d.storage.boxes[13]={} end,
            function(d) d.inventory.slots={{id="potion",quantity=100}} end,
            function(d) d.unknown=true end,
        }
        for _,change in ipairs(changes) do
            local bad=copy(original); change(bad)
            local candidate=SessionCodec.decode(bad,SessionContracts.dependencies()); eq(candidate,nil)
            assert(same(data(session),original)); eq(session:activePokemon(),pokemon)
            assert(same(RulesRNG.toData(),rng)); assert(same(WorldDeltas.export(),world))
        end
        local bad=copy(original); bad.party.members[2]={}; bad.party.members[4]={}
        eq(SessionCodec.decode(bad,SessionContracts.dependencies()),nil)
    end)
    test("typed setters and complete candidate-world location checks are atomic",function()
        local session=starter(); local before=data(session)
        local ok=session:setQuestFlag("bad key",true); eq(ok,false)
        ok=session:setTrainerDefeated("valid:key",1); eq(ok,false)
        ok=session:setIntro({stage="done",starter="charmander",rivalStarter="bulbasaur"}); eq(ok,false)
        ok=session:setLocation({zone_id="reds_house_2f",x=5,y=2,facing="up"}); eq(ok,false)
        assert(same(data(session),before))
        local zone=zoneRegistry.reds_house_2f
        local revision=zone:exportDeltas().definition_revision
        local solid={schema=1,zone_count=1,zones={{schema=1,zone_id="reds_house_2f",definition_revision=revision,
            tile_count=1,tiles={{x=5,y=3,key="base:3"}}}}}
        local world=WorldDeltas.export()
        ok=session:setWorld(solid); eq(ok,false); assert(same(data(session),before)); assert(same(WorldDeltas.export(),world))
        local open=copy(solid); open.zones[1].tiles={{x=5,y=2,key="base:25"}}
        assert(session:setWorld(open))
        assert(session:setLocation({zone_id="reds_house_2f",x=5,y=2,facing="up"}))
        local encoded=data(session); local restored=decode(encoded)
        eq(restored:location().y,2); assert(same(WorldDeltas.export(),world))
        -- Removing that delta restores the initial solid TV; it cannot depend
        -- on an unrelated live-world mutation to validate the saved position.
        ok=restored:setWorld({schema=1,zones={},zone_count=0}); eq(ok,false)
    end)
    test("combined traversal snapshot can close old location and rejects partial invalid updates",function()
        local session=starter()
        local revision=zoneRegistry.reds_house_2f:exportDeltas().definition_revision
        local world={schema=1,zone_count=1,zones={{schema=1,zone_id="reds_house_2f",definition_revision=revision,
            tile_count=1,tiles={{x=5,y=3,key="base:3"}}}}}
        eq(session:setWorld(world),false)
        local global=WorldDeltas.export(); local rng=RulesRNG.toData()
        assert(session:captureTraversal({world=world,location={zone_id="reds_house_2f",x=6,y=3,facing="left"}}))
        eq(session:location().x,6)
        local before=data(session)
        eq(session:captureTraversal({world=world,location=start()}),false)
        assert(same(before,data(session)))
        eq(session:captureTraversal({world=world,location=session:location(),checkpoint=start()}),false)
        assert(same(before,data(session))); assert(same(global,WorldDeltas.export())); assert(same(rng,RulesRNG.toData()))
    end)
    test("bag quest transaction is atomic preserves bag identity and guards repeat rewards",function()
        local session=starter(); local bag=session:inventory()
        local expected={flags={EVENT_GOT_OAKS_PARCEL=false},items={oaksParcel=0}}
        local receive={items={{op="add",id="oaksParcel",quantity=1}},flags={EVENT_GOT_OAKS_PARCEL=true}}
        local rng=RulesRNG.toData()
        assert(session:transact(expected,receive)); eq(session:inventory(),bag)
        eq(bag:quantity("oaksParcel"),1); eq(session:questFlag("EVENT_GOT_OAKS_PARCEL"),true)
        local before=data(session)
        eq(session:transact(expected,receive),false); assert(same(before,data(session)))
        assert(session:transact({flags={EVENT_GOT_OAKS_PARCEL=true,EVENT_OAK_GOT_PARCEL=false},items={oaksParcel=1}},
            {items={{op="handoff",id="oaksParcel",quantity=1}},flags={EVENT_OAK_GOT_PARCEL=true,EVENT_GOT_POKEDEX=true}}))
        eq(session:inventory(),bag); eq(bag:quantity("oaksParcel"),0)
        eq(session:questFlag("EVENT_GOT_POKEDEX"),true)
        before=data(session)
        eq(session:transact({flags={MISSING_PARCEL_TEST=false},items={oaksParcel=0}},
            {items={{op="add",id="potion",quantity=1},{op="handoff",id="oaksParcel",quantity=1}},flags={MISSING_PARCEL_TEST=true}}),false)
        assert(same(before,data(session))); assert(same(rng,RulesRNG.toData()))
        -- A flag-only unlock is permitted, but must still have a one-time guard.
        assert(session:transact({flags={FLAG_ONLY_TEST=false},items={}}, {items={},flags={FLAG_ONLY_TEST=true}}))
        eq(session:transact({flags={FLAG_ONLY_TEST=true},items={}}, {items={},flags={OTHER_FLAG=true}}),false)
    end)
    test("full bag transaction keeps reward flag unchanged until successful retry",function()
        local session=starter(); local bag=session:inventory()
        for i=1,20 do assert(bag:add("pokeBall",99)) end
        local before=data(session); local rng=RulesRNG.toData()
        local expected={flags={EVENT_GOT_POTION_SAMPLE=false},items={potion=0}}
        local changes={items={{op="add",id="potion",quantity=1}},flags={EVENT_GOT_POTION_SAMPLE=true}}
        eq(session:transact(expected,changes),false); assert(same(before,data(session)))
        eq(session:questFlag("EVENT_GOT_POTION_SAMPLE"),false); eq(session:inventory(),bag)
        assert(bag:consume("pokeBall",99))
        assert(session:transact(expected,changes)); eq(session:questFlag("EVENT_GOT_POTION_SAMPLE"),true)
        eq(bag:quantity("potion"),1); eq(session:inventory(),bag)
        before=data(session)
        eq(session:transact(expected,changes),false); assert(same(before,data(session)))
        eq(session:transact({flags={STALE_QUANTITY_TEST=false},items={potion=0}},
            {items={{op="add",id="potion",quantity=1}},flags={STALE_QUANTITY_TEST=true}}),false)
        assert(same(before,data(session))); assert(same(rng,RulesRNG.toData()))
    end)
    test("save gate rejects battle movement overlays and transient story states",function()
        local session=starter()
        for _,bad in ipairs({{root="battle",overworld="explore",settled=true},
            {root="dialog",overworld="explore",settled=true},{root="overworld",overworld="doorWarp",settled=true},
            {root="overworld",overworld="explore",settled=false}}) do
            eq(SessionCodec.encode(session,bad),nil)
        end
        assert(session:setIntro({stage="rival_fight",starter="charmander",rivalStarter="squirtle"}))
        eq(SessionCodec.encode(session,gate),nil)
        assert(session:setIntro({stage="pre_rival",starter="charmander",rivalStarter="squirtle"}))
        assert(SessionCodec.encode(session,gate))
    end)
    test("RNG install is explicit single-owner and retires previous session state",function()
        local a=starter(2147483646); local b=starter(42)
        local before=RulesRNG.toData(); local wire=data(a)
        local candidate=decode(json.decode(json.encode(wire)))
        assert(same(before,RulesRNG.toData()))
        assert(candidate:activateRNG()); eq(GameSession.activeRNGSession(),candidate)
        assert(same(candidate:rngData(),wire.rng))
        RulesRNG.random(1,100)
        local advanced=candidate:rngData()
        assert(advanced.rolls~=wire.rng.rolls)
        assert(b:activateRNG()); eq(GameSession.activeRNGSession(),b)
        assert(same(candidate:rngData(),advanced))
        RulesRNG.random(1,100); assert(same(candidate:rngData(),advanced))
        assert(b:deactivateRNG()); eq(GameSession.activeRNGSession(),nil)
    end)
    local private=HarnessBuild and HarnessBuild.enabled and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%.")
    test("real SaveStore session composition roundtrip never auto-installs candidate",function()
        assert(private,"private SDK test bundle required")
        invocation=invocation+1
        local prefix="session-contract-"..HarnessBuild.session_id.."-"..invocation
        local store=SessionCodec.store(prefix,SessionContracts.dependencies())
        local session=starter(2147483646)
        assert(session:setQuestFlag("parcel/received",true))
        assert(SessionCodec.save(store,session,gate))
        local before=RulesRNG.toData()
        local restored,metadata=SessionCodec.load(store,SessionContracts.dependencies())
        assert(restored,json.encode(metadata)); created[#created+1]=restored
        assert(same(data(restored),data(session))); assert(same(RulesRNG.toData(),before))
        assert(restored:activePokemon()~=session:activePokemon())
        local ok=SessionCodec.save(store,session,{root="battle",overworld="explore",settled=true}); eq(ok,false)
        local loaded=assert(SessionCodec.load(store,SessionContracts.dependencies())); created[#created+1]=loaded
        assert(same(data(loaded),data(session)))
    end)
    -- Restore only the explicit test activation effects. Pure decoding failures
    -- above independently assert that they never required this cleanup.
    for _,session in ipairs(created) do session:deactivateRNG() end
    if priorOwner then assert(priorOwner:activateRNG()) end
    RulesRNG.restoreData(initialRNG)
    return report
end
