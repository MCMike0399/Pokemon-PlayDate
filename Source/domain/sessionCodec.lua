-- Complete session snapshot, validated before candidate objects are published.
SessionCodec={VERSION=3,POKEMON_ENCODING="decimal-counters-v1"}
local function copy(value) return GameSession._copy(value) end
local function object(value,fields) GameSession._object(value,fields) end
local function array(value,limit)
    assert(Party._array(value,limit),"invalid collection array")
end
local function integer(value,low,high)
    assert(Party._integer(value,low,high),"invalid collection integer")
    return assert(math.tointeger(value))
end
local function pokemonToWire(mon)
    local data=assert(PokemonCodec.encode(mon))
    data.xp=assert(DecimalInteger.encode(assert(math.tointeger(data.xp)),0,DecimalInteger.MAX))
    data.nextMoveChoiceId=assert(DecimalInteger.encode(assert(math.tointeger(data.nextMoveChoiceId)),1,DecimalInteger.MAX))
    for _,choice in ipairs(data.pendingMoveChoices) do choice.id=assert(DecimalInteger.encode(assert(math.tointeger(choice.id)),1,DecimalInteger.MAX)) end
    return data
end
-- Shared lossless record seam for explicit development/import transactions.
-- Validation is still delegated to the production Pokémon codec.
SessionCodec.encodePokemon = pokemonToWire
local function pokemonFromWire(record,construct)
    local data=copy(record)
    assert(type(data)=="table","Pokemon record required")
    data.xp=assert(DecimalInteger.decode(data.xp,0,DecimalInteger.MAX))
    data.nextMoveChoiceId=assert(DecimalInteger.decode(data.nextMoveChoiceId,1,DecimalInteger.MAX))
    array(data.pendingMoveChoices,1024)
    for _,choice in ipairs(data.pendingMoveChoices) do
        assert(type(choice)=="table","move choice required")
        choice.id=assert(DecimalInteger.decode(choice.id,1,DecimalInteger.MAX))
    end
    local valid,reason=PokemonCodec.validate(data); assert(valid,reason)
    return construct and assert(PokemonCodec.decode(data)) or data
end
local function introToWire(value)
    return {stage=value.stage,starter=value.starter or "none",rivalStarter=value.rivalStarter or "none",
        rivalOutcome=value.rivalOutcome==nil and "none" or value.rivalOutcome}
end
local function introFromWire(value)
    object(value,{stage=true,starter=true,rivalStarter=true,rivalOutcome=true})
    assert(type(value.starter)=="string" and type(value.rivalStarter)=="string"
        and(value.rivalOutcome=="none" or type(value.rivalOutcome)=="boolean"),"invalid intro wire fields")
    local result={stage=value.stage,starter=value.starter~="none" and value.starter or nil,
        rivalStarter=value.rivalStarter~="none" and value.rivalStarter or nil}
    if value.rivalOutcome~="none" then result.rivalOutcome=value.rivalOutcome end
    return GameSession._intro(result)
end
local safeStages={pre_oak=true,choose=true,pre_rival=true,done=true}
local function normalize(record,deps)
    deps=GameSession._dependencies(deps)
    local data=copy(record)
    object(data,{version=true,pokemonEncoding=true,title=true,intro=true,questFlags=true,trainerFlags=true,pokedex=true,
        location=true,checkpoint=true,world=true,party=true,storage=true,inventory=true,rng=true,worldMotion=true,itemStorage=true,fieldWorld=true,daycare=true})
    assert((data.version==1 or data.version==2 or data.version==SessionCodec.VERSION) and data.pokemonEncoding==SessionCodec.POKEMON_ENCODING,"unsupported-session-version-or-Pokemon-encoding")
    object(data.title,{playerName=true,rivalName=true})
    assert(data.title.playerName=="RED" and data.title.rivalName=="BLUE","unsupported player/rival title")
    local intro=introFromWire(data.intro)
    assert(safeStages[intro.stage],"transient intro stage cannot be saved")
    local quests=GameSession._flags(data.questFlags,4096)
    local trainers=GameSession._flags(data.trainerFlags,4096)
    local dex=GameSession._dex(data.pokedex)
    local world=GameSession._world(deps,data.world)
    local location=GameSession._location(deps,data.location,world,true)
    local checkpoint=GameSession._location(deps,data.checkpoint,world)
    -- Version1 has no palette provenance. Migrate deterministically to light;
    -- never infer a Flash use or grant a field effect from map names.
    if data.version==1 then assert(data.fieldWorld==nil,"v1 cannot contain fieldWorld") end
    local fieldWorld=GameSession._fieldData(data.version==1 and {version=1,mapPalOffset=0} or data.fieldWorld)
    local rng=GameSession._rngData(data.rng)
    local motion=data.worldMotion
    if motion==nil then motion={version=1,rng=WorldMotionData.newWorldRNG(rng):toData(),actors=WorldMotionData.empty()}end
    object(motion,{version=true,rng=true,actors=true});assert(motion.version==1,"unsupported world motion version")
    motion={version=1,rng=GameSession._rngData(motion.rng),actors=GameSession._validateActors(deps,motion.actors,world,location,{quest=quests,trainers=trainers})}
    object(data.party,{version=true,active=true,members=true})
    assert(data.party.version==1,"unsupported-party-version"); array(data.party.members,6)
    data.party.active=integer(data.party.active,#data.party.members>0 and 1 or 0,#data.party.members)
    object(data.storage,{version=true,active=true,boxes=true})
    assert(data.storage.version==1,"unsupported-storage-version"); array(data.storage.boxes,12); assert(#data.storage.boxes==12,"twelve boxes required")
    data.storage.active=integer(data.storage.active,1,12)
    local count=0
    local function checkMon(record)
        local mon=pokemonFromWire(record,false)
        assert(dex.owned[mon.species] and dex.seen[mon.species],"owned Pokemon missing dex flags")
        count=count+1
        return mon
    end
    for _,record in ipairs(data.party.members) do checkMon(record) end
    for _,box in ipairs(data.storage.boxes) do
        array(box,20); for _,record in ipairs(box) do checkMon(record) end
    end
    -- v1/v2 had no Day Care provenance. They must migrate to an empty slot;
    -- v3 requires the field and never repairs a missing or malformed record.
    local daycareRecord = data.daycare
    if data.version < 3 then
        assert(daycareRecord == nil, "legacy session cannot contain daycare")
        daycareRecord = {version=1, earned="0"}
    end
    local daycare = Daycare.normalize(daycareRecord, checkMon)
    local early=intro.stage=="pre_oak" or intro.stage=="choose"
    if early then assert(count==0 and next(dex.owned)==nil,"pre-starter session cannot own Pokemon")
    else assert(#data.party.members>=1 and dex.owned[intro.starter],"starter session requires party and owned starter") end
    object(data.inventory,{version=true,slots=true,money=true})
    assert(data.inventory.version==1,"unsupported-inventory-version"); array(data.inventory.slots,20)
    for _,slot in ipairs(data.inventory.slots) do object(slot,{id=true,quantity=true}) end
    assert(Inventory.fromData(deps.itemDefinitions,data.inventory),"invalid inventory")
    -- Old valid schema1 has no provenance for an initial Potion withdrawal.
    -- Missing itemStorage migrates EMPTY, never an inferred reward/regrant.
    local stored=data.itemStorage
    if stored==nil then stored={version=1,slots={}}end
    local itemStorage=ItemStorage.normalize(deps.itemDefinitions,stored)
    ItemStorage.checkUnique(deps.itemDefinitions,data.inventory,itemStorage)
    return {daycare=daycare,itemStorage=itemStorage,deps=deps,data=data,intro=intro,questFlags=quests,trainerFlags=trainers,dex=dex,world=world,
        location=location,checkpoint=checkpoint,rng=rng,worldMotion=motion,fieldWorld=fieldWorld}
end
function SessionCodec.encode(session,gate)
    local ok,result=pcall(function()
        assert(type(session)=="table" and type(session.is)=="function" and session:is("GameSession"),"GameSession required")
        assert(type(gate)=="table" and gate.root=="overworld" and gate.overworld=="explore" and gate.settled==true,
            "save requires settled explored overworld with no overlay")
        local current=assert(GameSession._state(session))
        local owned={}
        local function unique(mon)
            assert(not owned[mon],"duplicate owned Pokemon identity"); owned[mon]=true
            return pokemonToWire(mon)
        end
        local data={version=SessionCodec.VERSION,pokemonEncoding=SessionCodec.POKEMON_ENCODING,
            fieldWorld=session:fieldWorldData(),title={playerName="RED",rivalName="BLUE"},intro=introToWire(current.intro),
            questFlags=copy(current.questFlags),trainerFlags=copy(current.trainerFlags),pokedex=copy(current.dex),
            location=copy(current.location),checkpoint=copy(current.checkpoint),world=copy(current.world),rng=session:rngData(),
            worldMotion={version=1,rng=session:worldRngData(),actors=session:actorData()},
            party=assert(current.party:toData(unique)),storage=assert(current.storage:toData(unique)),inventory=current.inventory:toData(),itemStorage=current.itemStorage:toData()}
        data.daycare = Daycare.toData(session, unique)
        normalize(data,current.deps)
        return data
    end)
    if not ok then return nil,tostring(result) end
    return result
end
function SessionCodec.validate(record,deps)
    local ok,reason=pcall(normalize,record,deps)
    return ok,not ok and tostring(reason) or nil
end
function SessionCodec.decode(record,deps)
    local ok,result=pcall(function()
        local prepared=normalize(record,deps)
        local party=assert(Party.fromData(prepared.data.party,function(value) return pokemonFromWire(value,true) end))
        local storage=assert(Storage.fromData(prepared.data.storage,function(value) return pokemonFromWire(value,true) end))
        local inventory=assert(Inventory.fromData(prepared.deps.itemDefinitions,prepared.data.inventory))
        local session=GameSession._restore(prepared.deps,{party=party,storage=storage,inventory=inventory,itemStorage=assert(ItemStorage.fromData(prepared.deps.itemDefinitions,prepared.itemStorage)),intro=prepared.intro,
            questFlags=prepared.questFlags,trainerFlags=prepared.trainerFlags,dex=prepared.dex,world=prepared.world,
            location=prepared.location,checkpoint=prepared.checkpoint,rng=prepared.rng,fieldWorld=prepared.fieldWorld})
        GameSession._state(session).daycare = Daycare.restore(session, prepared.daycare, function(value)
            return pokemonFromWire(value, true)
        end)
        session:_installWorldMotion(prepared.worldMotion)
        return session
    end)
    if not ok then return nil,tostring(result) end
    return result
end
function SessionCodec.store(prefix,deps,filesystem)
    deps=GameSession._dependencies(deps)
    return SaveStore(prefix,function(record) return SessionCodec.validate(record,deps) end,filesystem)
end
function SessionCodec.save(store,session,gate)
    local data,reason=SessionCodec.encode(session,gate)
    if not data then return false,{reason="invalid-session",error=reason} end
    return store:save(data)
end
function SessionCodec.load(store,deps)
    local data,metadata=store:load()
    if not data then return nil,metadata end
    local session,reason=SessionCodec.decode(data,deps)
    if not session then return nil,{reason="invalid-session",error=reason,store=metadata} end
    return session,metadata -- root must commit world/RNG/context deliberately.
end
