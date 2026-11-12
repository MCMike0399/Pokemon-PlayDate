import "game/saveBuildPolicy"
import "domain/hallOfFame"
import "domain/playTime"
-- Complete session snapshot, validated before candidate objects are published.
SessionCodec={VERSION=4,POKEMON_ENCODING="decimal-counters-v1"}
local exportingSession, exportingRecords
local function copy(value) return GameSession._copy(value) end
local function checkpoint()
    if GameBootstrap then
        GameBootstrap.yieldIfDue()
    end
end
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
    checkpoint()
    local result = construct and assert(PokemonCodec.decode(data)) or data
    checkpoint()
    return result
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
-- wFossilItem is the saved item byte: 0, OLD_AMBER $1F, DOME_FOSSIL $29, HELIX_FOSSIL $2A.
local FOSSIL_ITEM_BYTES={OLD_AMBER=31,DOME_FOSSIL=41,HELIX_FOSSIL=42}
local function fossilItemByte(quests)
    local byte=0
    if type(quests)~="table" then return 0 end
    for id,value in pairs(quests) do
        if value==true and type(id)=="string" and id:sub(1,12)=="wFossilItem:" then
            local item=FOSSIL_ITEM_BYTES[id:sub(13)]
            assert(item and byte==0,"invalid wFossilItem")
            byte=item
        end
    end
    return byte
end
local function normalize(record,deps)
    deps=GameSession._dependencies(deps)
    local data=copy(record)
    checkpoint()
    object(data,{version=true,pokemonEncoding=true,title=true,intro=true,questFlags=true,trainerFlags=true,pokedex=true,
        location=true,checkpoint=true,world=true,party=true,storage=true,inventory=true,rng=true,worldMotion=true,itemStorage=true,fieldWorld=true,daycare=true,fieldTravel=true,safari=true,coins=true,hallOfFame=true,playTime=true,wFossilItem=true})
    assert((data.version==1 or data.version==2 or data.version==3 or data.version==SessionCodec.VERSION) and data.pokemonEncoding==SessionCodec.POKEMON_ENCODING,"unsupported-session-version-or-Pokemon-encoding")
    if data.wFossilItem~=nil then
        assert(type(data.wFossilItem)=="number" and data.wFossilItem==math.floor(data.wFossilItem),"invalid wFossilItem")
        assert(data.wFossilItem==fossilItemByte(data.questFlags),"wFossilItem does not match the saved fossil")
    end
    object(data.title,{playerName=true,rivalName=true})
    assert(data.title.playerName=="RED" and data.title.rivalName=="BLUE","unsupported player/rival title")
    local intro=introFromWire(data.intro)
    assert(safeStages[intro.stage],"transient intro stage cannot be saved")
    local quests=GameSession._flags(data.questFlags,4096)
    local trainers=GameSession._flags(data.trainerFlags,4096)
    local dex=GameSession._dex(data.pokedex)
    local world=GameSession._world(deps,data.world)
    checkpoint()
    local travel = data.fieldTravel
    if data.version < 4 then
        assert(travel == nil, "legacy session cannot contain fieldTravel")
        travel = FieldTravel.empty()
    end
    travel = FieldTravel.normalize(travel)
    -- Early private v4 checkpoints predate Safari/coins. Both fields must be
    -- absent together; source flags below must still prove no Safari progress.
    local earlyPrivateV4 = data.version == 4 and data.safari == nil and data.coins == nil
    local safari = data.safari
    if data.version < 4 or earlyPrivateV4 then
        assert(safari == nil, "legacy session cannot contain Safari provenance")
        safari = SafariGame.empty()
    end
    safari = SafariGame.normalize(safari)
    local coins = data.coins
    if data.version < 4 or earlyPrivateV4 then
        assert(coins == nil, "legacy session cannot contain coin provenance")
        coins = CoinWallet.empty()
    end
    coins = CoinWallet.normalize(coins)
    -- Hall of Fame teams arrived after the private v4 Safari/coin saves.
    -- Older versions cannot contain the field. A v4 save that predates it
    -- migrates to an empty record.
    local hall = data.hallOfFame
    if data.version < 4 then
        assert(hall == nil, "legacy session cannot contain a hall of fame record")
        hall = HallOfFame.empty()
    elseif hall == nil then
        hall = HallOfFame.empty()
    end
    hall = HallOfFame.normalize(hall)
    -- Play time arrived with the Hall of Fame card. Older versions cannot
    -- contain it. A v4 save that predates the field migrates to a zero clock.
    local playTime = data.playTime
    if data.version < 4 then
        assert(playTime == nil, "legacy session cannot contain play time")
        playTime = PlayTime.empty()
    elseif playTime == nil then
        playTime = PlayTime.empty()
    end
    playTime = PlayTime.normalize(playTime)
    for id, value in pairs(SafariGame.flags(safari)) do
        assert((quests[id] or false) == value, "inconsistent saved Safari source flag")
    end
    local location=GameSession._location(deps,data.location,world,true,travel)
    local savedCheckpoint=GameSession._location(deps,data.checkpoint,world)
    checkpoint()
    -- Version1 has no palette provenance. Migrate deterministically to light;
    -- never infer a Flash use or grant a field effect from map names.
    if data.version==1 then assert(data.fieldWorld==nil,"v1 cannot contain fieldWorld") end
    local fieldWorld=GameSession._fieldData(data.version==1 and {version=1,mapPalOffset=0} or data.fieldWorld)
    local rng=GameSession._rngData(data.rng)
    local motion=data.worldMotion
    if motion==nil then motion={version=1,rng=WorldMotionData.newWorldRNG(rng):toData(),actors=WorldMotionData.empty()}end
    object(motion,{version=true,rng=true,actors=true});assert(motion.version==1,"unsupported world motion version")
    motion={version=1,rng=GameSession._rngData(motion.rng),actors=GameSession._validateActors(deps,motion.actors,world,location,{quest=quests,trainers=trainers})}
    checkpoint()
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
        checkpoint()
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
    checkpoint()
    -- Old valid schema1 has no provenance for an initial Potion withdrawal.
    -- Missing itemStorage migrates EMPTY, never an inferred reward/regrant.
    local stored=data.itemStorage
    if stored==nil then stored={version=1,slots={}}end
    local itemStorage=ItemStorage.normalize(deps.itemDefinitions,stored)
    ItemStorage.checkUnique(deps.itemDefinitions,data.inventory,itemStorage)
    return {daycare=daycare,itemStorage=itemStorage,deps=deps,data=data,intro=intro,questFlags=quests,trainerFlags=trainers,dex=dex,world=world,
        location=location,checkpoint=savedCheckpoint,rng=rng,worldMotion=motion,fieldWorld=fieldWorld,fieldTravel=travel,safari=safari,coins=coins,hallOfFame=hall,playTime=playTime}
end
function SessionCodec.encode(session,gate)
    SessionCodec.relieveHeap()
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
            coins=session:coins(),safari=session:safariData(),hallOfFame=session:hallOfFame(),playTime=session:playTime(),fieldTravel=session:fieldTravelData(),fieldWorld=session:fieldWorldData(),title={playerName="RED",rivalName="BLUE"},intro=introToWire(current.intro),
            questFlags=copy(current.questFlags),trainerFlags=copy(current.trainerFlags),pokedex=copy(current.dex),
            location=copy(current.location),checkpoint=copy(current.checkpoint),world=copy(current.world),rng=session:rngData(),
            worldMotion={version=1,rng=session:worldRngData(),actors=session:actorData()},
            party=assert(current.party:toData(unique)),storage=assert(current.storage:toData(unique)),inventory=current.inventory:toData(),itemStorage=current.itemStorage:toData()}
        data.daycare = Daycare.toData(session, unique)
        data.wFossilItem = fossilItemByte(data.questFlags)
        if exportingSession ~= session then
            normalize(data, current.deps)
        else
            -- Seal the exact codec result before returning it to any caller.
            exportingRecords[data] = copy(data)
        end
        return data
    end)
    if not ok then return nil,tostring(result) end
    return result
end
-- One public Save calls this for the envelope and both readbacks. The later
-- calls see a newly decoded table with the same contents. Re-running normalize
-- would reconstruct every Pokemon and copy the record again. A detached proof
-- answers only when the dependencies and the record are unchanged. Any edit,
-- failure, or explicit release takes the full path.
local proven = setmetatable({}, {__mode="k"})
local function same(a, b, seen)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    if getmetatable(a) ~= nil or getmetatable(b) ~= nil then return false end
    seen = seen or {}
    if seen[a] then return seen[a] == b end
    seen[a] = b
    for key, value in pairs(a) do
        if not same(value, b[key], seen) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end
local function dependencyStamp(deps)
    if type(deps) ~= "table" then return nil end
    return {deps.validateWorld, deps.resolveLocation, deps.validateActors, deps.hiddenActors,
        deps.resolvePlayerLocation, deps.itemDefinitions}
end
local function sameStamp(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return false end
    for index = 1, 6 do
        if left[index] ~= right[index] then return false end
    end
    return true
end
function SessionCodec.releaseValidationProof()
    for key in pairs(proven) do proven[key] = nil end
end
-- Save readbacks are the only caller that compares a second decoded table
-- with this proof. Every other validate runs normalize itself and must not
-- leave a detached session copy in the pool.
local proofDepth = 0
function SessionCodec.retainValidationProof(retain)
    if retain then
        proofDepth = proofDepth + 1
        return
    end
    if proofDepth > 0 then proofDepth = proofDepth - 1 end
    if proofDepth == 0 then SessionCodec.releaseValidationProof() end
end
local relievingHeap = false
-- 11 MiB is above the 6/8/9 MiB admission guards. Those guards own production
-- and device-test processes: a frame or yield already rejects 9 MiB, and the
-- 8 MiB soft collect runs only after the hard check. This recovery stays out
-- of that path so it cannot collect a sample away before the guard sees it.
-- Private harness sessions, where the budget is off, use it to drop publication
-- copies before the 16 MiB pool fails. Journeys sit under 9 MiB, so the
-- threshold does not collect there or change snapshot cadence.
function SessionCodec.relieveHeap()
    if relievingHeap or collectgarbage("count") < 11 * 1024 then return end
    if BootTrace and BootTrace.memoryBudgetEnabled and BootTrace.memoryBudgetEnabled() then
        return
    end
    relievingHeap = true
    -- An open Save still needs its proof and the decoded byte cache. Dropping
    -- them here would make the second readback decode the payload again.
    if proofDepth == 0 then
        SessionCodec.releaseValidationProof()
        if SaveStore and SaveStore.dropDecodedRecords then SaveStore.dropDecodedRecords() end
    end
    if HarnessDiagnostics and HarnessDiagnostics.releaseRetainedViews then
        HarnessDiagnostics.releaseRetainedViews()
    end
    collectgarbage("collect")
    collectgarbage("collect")
    relievingHeap = false
end
-- True only when this record matches the detached proof for these dependencies.
-- The check only reads. Callers may skip a defensive copy when it is true and
-- the following validate takes that same path.
local proofHit = false
function SessionCodec.proofCovers(record, deps)
    proofHit = false
    local stamp = dependencyStamp(deps)
    local prior = type(deps) == "table" and proven[deps] or nil
    return prior ~= nil and sameStamp(prior.stamp, stamp) and same(prior.record, record)
end
function SessionCodec.proofSatisfied()
    return proofHit
end
function SessionCodec.validate(record,deps)
    SessionCodec.relieveHeap()
    proofHit = false
    local stamp = dependencyStamp(deps)
    local prior = proven[deps]
    if prior and sameStamp(prior.stamp, stamp) and same(prior.record, record) then
        proofHit = true
        return true, nil
    end
    local ok,reason=pcall(normalize,record,deps)
    if ok and stamp and proofDepth > 0 then
        proven[deps] = {record=copy(record), stamp=stamp}
    else
        proven[deps] = nil
    end
    return ok,not ok and tostring(reason) or nil
end
function SessionCodec.decode(record,deps)
    SessionCodec.relieveHeap()
    local ok,result=pcall(function()
        local prepared=normalize(record,deps)
        local party=assert(Party.fromData(prepared.data.party,function(value) return pokemonFromWire(value,true) end))
        local storage=assert(Storage.fromData(prepared.data.storage,function(value) return pokemonFromWire(value,true) end))
        local inventory=assert(Inventory.fromData(prepared.deps.itemDefinitions,prepared.data.inventory))
        local session=GameSession._restore(prepared.deps,{party=party,storage=storage,inventory=inventory,itemStorage=assert(ItemStorage.fromData(prepared.deps.itemDefinitions,prepared.itemStorage)),intro=prepared.intro,
            questFlags=prepared.questFlags,trainerFlags=prepared.trainerFlags,dex=prepared.dex,world=prepared.world,
            location=prepared.location,checkpoint=prepared.checkpoint,rng=prepared.rng,fieldWorld=prepared.fieldWorld,fieldTravel=prepared.fieldTravel,safari=prepared.safari,coins=prepared.coins,hallOfFame=prepared.hallOfFame,playTime=prepared.playTime})
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
    local store = SaveStore(prefix,function(record) return SessionCodec.validate(record,deps) end,filesystem)
    -- Public readbacks may reuse a covered record without copying it again.
    store._proofCovers = function(record) return SessionCodec.proofCovers(record, deps) end
    return store
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

-- GameSaves alone holds these closures. Foreign sessions, public encode/save,
-- and load/owner construction never acquire export authority.
function SessionCodec.gameSaveStore(game, prefix)
    local deps = GameSession._dependencies(game:getSessionDependencies())
    if not SaveBuildPolicy.ownerExports() then
        local store = SessionCodec.store(prefix, deps)
        -- The public path still checksums, decodes, and validates every new
        -- byte string. Continue's load fills that proof, and a public readback
        -- that has just accepted a published file does too. A later inspect of
        -- those exact bytes reuses the detached record. Owner export stays off.
        store:setValidationEpoch("session-public-dependencies-v1")
        store:retainVerifiedPublications()
        return store
    end
    local store, publish = SaveStore.ownerExportStore(prefix, function(record)
        return SessionCodec.validate(record, deps)
    end, nil, "session-owner-dependencies-v1")
    local exports = setmetatable({}, {__mode="k"})
    local function capture(callback)
        assert(exportingSession == nil, "nested-session-export")
        local session = game.session
        local records = {}
        exportingSession, exportingRecords = session, records
        local ok, data, problem = pcall(callback)
        exportingSession, exportingRecords = nil, nil
        if not ok then
            error(data)
        end
        if data and records[data] and game.session == session then
            exports[data] = {session=session, record=records[data]}
        end
        return data, problem
    end
    local function publishExport(data, ticket)
        local proof = exports[data]
        if proof then
            exports[data] = nil
        end
        -- A callback cannot substitute or mutate an issued record into trust.
        -- Only a sealed codec export can use the private publisher.
        if proof and proof.session == game.session then
            local function unchanged(a, b)
                if type(a) ~= type(b) then
                    return false
                end
                if type(a) ~= "table" then
                    return a == b
                end
                if getmetatable(a) ~= nil then
                    return false
                end
                for key, value in pairs(b) do
                    if not unchanged(a[key], value) then
                        return false
                    end
                end
                for key in pairs(a) do
                    if b[key] == nil then
                        return false
                    end
                end
                return true
            end
            if unchanged(data, proof.record) then
                return publish(proof.record, ticket)
            end
        end
        -- Arbitrary/foreign payloads retain the public deep-validation path.
        if ticket then
            return store:replace(data, ticket)
        end
        return store:save(data)
    end
    return store, capture, publishExport
end
