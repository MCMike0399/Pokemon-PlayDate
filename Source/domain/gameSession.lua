-- Persistent session owner. No sprites, Story singleton or filesystem access.
import "domain/sourceEncounters"
import "domain/fieldCycling"
Class("GameSession")
local state=setmetatable({}, {__mode="k"})
local activeRNGSession=nil
local fieldEpoch = 0
local function nextFieldEpoch()
    fieldEpoch = fieldEpoch + 1
    return fieldEpoch
end
local stages={pre_oak=true,lab_greet=true,choose=true,pre_rival=true,rival_fight=true,goodbye=true,done=true}
local counters={bulbasaur="charmander",charmander="squirtle",squirtle="bulbasaur"}
local facings={up=true,down=true,left=true,right=true}
local function copy(value) return Party._primitive(value) end
local function object(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"plain object required")
    for key in pairs(value) do assert(allowed[key],"unknown field: "..tostring(key)) end
end
-- wMapPalOffset belongs to the saved session, not a per-map flag.
local function fieldData(value)
    object(value, {version = true, mapPalOffset = true})
    assert(value.version == 1 and (value.mapPalOffset == 0 or value.mapPalOffset == 6), "invalid field world data")
    return {version = 1, mapPalOffset = value.mapPalOffset}
end
GameSession._fieldData = fieldData

local function stable(id)
    return type(id)=="string" and #id>=1 and #id<=128 and id:match("^[A-Za-z0-9][A-Za-z0-9_:.%/-]*$")~=nil
end
local function flags(values,limit)
    assert(type(values)=="table" and getmetatable(values)==nil,"flag object required")
    local out,count={},0
    for id,value in pairs(values) do
        assert(stable(id) and type(value)=="boolean","invalid stable boolean flag")
        count=count+1; assert(count<=limit,"too many flags"); out[id]=value
    end
    return out
end
local function intro(value)
    object(value,{stage=true,starter=true,rivalStarter=true,rivalOutcome=true})
    assert(stages[value.stage],"unknown intro stage")
    local early=value.stage=="pre_oak" or value.stage=="lab_greet" or value.stage=="choose"
    if early then assert(value.starter==nil and value.rivalStarter==nil and value.rivalOutcome==nil,"premature starter/outcome")
    else
        assert(counters[value.starter] and value.rivalStarter==counters[value.starter],"invalid starter/counter pair")
        assert(value.rivalOutcome==nil or type(value.rivalOutcome)=="boolean","invalid rival outcome")
        if value.stage=="pre_rival" or value.stage=="rival_fight" then assert(value.rivalOutcome==nil,"premature rival outcome") end
        if value.stage=="goodbye" then assert(type(value.rivalOutcome)=="boolean","missing rival outcome") end
    end
    return copy(value)
end
local function dex(values)
    object(values,{seen=true,owned=true})
    local out={seen={},owned={}}
    for _,kind in ipairs({"seen","owned"}) do
        assert(type(values[kind])=="table" and getmetatable(values[kind])==nil,"dex species flags required")
        for species,value in pairs(values[kind]) do
            assert(pokemonData[species] and value==true,"invalid dex species/flag")
            out[kind][species]=true
        end
    end
    for species in pairs(out.owned) do assert(out.seen[species],"owned species must be seen") end
    return out
end
local function retainedFields(before,after)
    assert(type(after)=="table","normalized world structure changed")
    for key,value in pairs(before) do
        assert(after[key]~=nil,"world validator discarded unsupported data")
        if type(value)=="table" then retainedFields(value,after[key]) end
    end
end
local function world(deps,payload)
    local input=copy(payload)
    local before=copy(input)
    local normalized=deps.validateWorld(input)
    assert(type(normalized)=="table","world validator must return normalized payload")
    retainedFields(before,normalized)
    return copy(normalized)
end
local function location(deps,value,candidateWorld,player,travel)
    object(value,{zone_id=true,x=true,y=true,facing=true})
    assert(stable(value.zone_id) and Party._integer(value.x,0,4095) and Party._integer(value.y,0,4095) and facings[value.facing],"invalid location fields")
    local resolver = player and deps.resolvePlayerLocation or deps.resolveLocation
    local resolved = resolver(copy(value), copy(candidateWorld), copy(travel or FieldTravel.empty()))
    assert(type(resolved)=="table","unsupported/blocked session location")
    object(resolved,{zone_id=true,x=true,y=true,facing=true})
    assert(resolved.zone_id==value.zone_id and resolved.x==value.x and resolved.y==value.y and resolved.facing==value.facing,"resolver must validate without relocating")
    return copy(resolved)
end
local function rngData(value)
    local probe=RulesRNG.new(1)
    probe:restoreData(copy(value))
    return probe:toData()
end
local function dependencies(deps)
    assert(type(deps)=="table" and type(deps.validateWorld)=="function" and type(deps.resolveLocation)=="function","pure world/location dependencies required")
    assert(deps.validateActors==nil or type(deps.validateActors)=="function","pure actor validator required")
    assert(deps.resolvePlayerLocation == nil or type(deps.resolvePlayerLocation) == "function",
        "pure player location validator required")
    local definitions={}
    for id,entry in pairs(assert(deps.itemDefinitions,"item definitions required")) do definitions[id]={keyItem=entry.keyItem} end
    Inventory(definitions) -- validates configuration without modifying callers.
    return {
        itemDefinitions = definitions,
        validateWorld = deps.validateWorld,
        resolveLocation = deps.resolveLocation,
        validateActors = deps.validateActors,
        resolvePlayerLocation = deps.resolvePlayerLocation or deps.resolveLocation
    }
end
-- Internal serialization seam; consumers use SessionCodec rather than mutating.
GameSession._copy,GameSession._object,GameSession._flags=copy,object,flags
GameSession._intro,GameSession._dex,GameSession._world=intro,dex,world
GameSession._location,GameSession._rngData,GameSession._dependencies=location,rngData,dependencies
function GameSession:init(deps,options)
    deps=dependencies(deps); options=options or {}
    object(options,{world=true,location=true,checkpoint=true,seed=true})
    local payload=world(deps,options.world or {schema=1,zones={},zone_count=0})
    local start=location(deps,assert(options.location,"starting location required"),payload,true)
    local checkpoint=location(deps,options.checkpoint or start,payload)
    local stream=RulesRNG.new(options.seed or 1)
    state[self]={daycare=Daycare.empty(),deps=deps,party=Party(),storage=Storage(),inventory=Inventory(deps.itemDefinitions),itemStorage=ItemStorage(deps.itemDefinitions),
        intro={stage="pre_oak"},questFlags={},trainerFlags={},dex={seen={},owned={}},location=start,checkpoint=checkpoint,
        fieldWorld = {version = 1, mapPalOffset = 0},
        fieldTravel = FieldTravel.empty(),
        safari = SafariGame.empty(),
        coins = CoinWallet.empty(),
        fieldEpoch = nextFieldEpoch(),
        world=payload,rng=stream:toData(),rngActive=false,worldRng=RulesRNG.new(options.seed or 1),currentActors=WorldMotionData.empty()}
end
function GameSession.newSession(deps,options) return GameSession(deps,options) end
function GameSession:resolveDaycare(request, decision)
    local ok, result = Daycare._resolve(self, request, decision)
    if ok and result.kind ~= "cancelled" then
        self:invalidateFieldWorldContext()
    end
    return ok, result
end

function GameSession:daycareStep()
    return Daycare._step(self)
end

function GameSession:party() return state[self].party end
function GameSession:storage() return state[self].storage end
function GameSession:inventory() return state[self].inventory end
function GameSession:activePokemon() return self:party():active() end
function GameSession:title() return {playerName="RED",rivalName="BLUE"} end
function GameSession:getIntro() return copy(state[self].intro) end
function GameSession:setIntro(value)
    local ok,normalized=pcall(intro,value)
    if not ok then return false,tostring(normalized) end
    state[self].intro=normalized; return true
end
function GameSession:recruit(mon)
    if not Party._validPokemon(mon) then return false,"invalid-pokemon" end
    local current=state[self]
    local ok,index=current.party:add(mon)
    local destination="party"
    if not ok and index=="party-full" then ok,index=current.storage:receive(mon); destination="storage" end
    if not ok then return false,index end
    current.dex.seen[mon.species],current.dex.owned[mon.species]=true,true
    return true,{destination=destination,index=index,box=destination=="storage" and current.storage:activeBox() or nil}
end
function GameSession:markSeen(species)
    if not pokemonData[species] then return false,"unknown-species" end
    state[self].dex.seen[species]=true; return true
end
-- Paid gifts use ordinary Gen V acquisition, including selected-box overflow.
-- Prepare every fallible value on detached owners before claiming the specimen.
-- No callback/yield is allowed between the validated claim and final assignments.
function GameSession:purchaseGiftPokemon(offer, expectedMoney)
    local current = state[self]
    local ok, prepared = pcall(function()
        object(offer, {species=true, level=true, price=true, flag=true, guard_flags=true, extra_flags=true})
        assert(Specimen.isActiveSession(self), "inactive-specimen-session")
        assert(stable(offer.flag), "invalid-gift-flag")
        assert(Party._integer(offer.price, 0, Inventory.MONEY_LIMIT), "invalid-gift-price")
        assert(Party._integer(expectedMoney, 0, Inventory.MONEY_LIMIT), "invalid-money-guard")
        if self:questFlag(offer.flag) then error("already-complete", 0) end
        local giftGuards = flags(offer.guard_flags or {}, 32)
        local giftWrites = flags(offer.extra_flags or {}, 32)
        for id, value in pairs(giftGuards) do
            if self:questFlag(id) ~= value then error("stale-flag", 0) end
        end
        for id, value in pairs(giftWrites) do
            assert(value == true and giftGuards[id] == false, "guarded one-time gift flag required")
        end
        if current.inventory:money() ~= expectedMoney then error("stale-money", 0) end
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
        local paid, reason = bag:spend(offer.price)
        if not paid then error(reason, 0) end
        local destination = current.party:count() < Party.CAPACITY and "party" or "storage"
        if destination == "storage" and current.storage:count() >= Storage.BOX_CAPACITY then
            error("box-full", 0)
        end
        local combined = copy(current.questFlags)
        combined[offer.flag] = true
        for id, value in pairs(giftWrites) do
            combined[id] = value
        end
        combined = flags(combined, 4096)
        local stream = RulesRNG.new(1)
        stream:restoreData(self:rngData())
        local mon, receipt = Specimen.create(offer.species, offer.level, "gift", stream)
        assert(mon, receipt)
        assert(PokemonCodec.encode(mon), "invalid-gift-specimen")
        local pokedex = self:pokedex()
        pokedex.seen[mon.species], pokedex.owned[mon.species] = true, true
        return {mon=mon, receipt=receipt, rng=stream:snapshot(), bag=bag:toData(),
            flags=combined, dex=dex(pokedex), destination=destination,
            box=destination == "storage" and current.storage:activeBox() or nil}
    end)
    if not ok then return false, tostring(prepared) end
    local accepted, index
    if prepared.destination == "party" then
        accepted, index = current.party:add(prepared.mon)
    else
        accepted, index = current.storage:receive(prepared.mon)
    end
    -- Claim validates before mutation. A rejection still owns no cash or RNG.
    if not accepted then return false, index end
    assert(Inventory._replaceData(current.inventory, prepared.bag))
    current.questFlags, current.dex = prepared.flags, prepared.dex
    current.currentActors = WorldMotionData.empty()
    RulesRNG.restore(prepared.rng)
    return true, {destination=prepared.destination, index=index, box=prepared.box,
        specimen=prepared.receipt}
end
function GameSession:pokedex() return copy(state[self].dex) end
local function setFlag(self,kind,id,value)
    if not stable(id) or type(value)~="boolean" then return false,"invalid-flag" end
    local values=state[self][kind]
    if values[id]==nil then
        local count=0; for _ in pairs(values) do count=count+1 end
        if count>=4096 then return false,"flag-limit" end
    end
    values[id]=value;state[self].currentActors=WorldMotionData.empty();return true
end
function GameSession:setQuestFlag(id,value) return setFlag(self,"questFlags",id,value) end
function GameSession:questFlag(id) return state[self].questFlags[id] or false end
function GameSession:setTrainerDefeated(id,value) return setFlag(self,"trainerFlags",id,value) end
function GameSession:trainerDefeated(id) return state[self].trainerFlags[id] or false end
function GameSession:flags() return {quest=copy(state[self].questFlags),trainers=copy(state[self].trainerFlags)} end
-- A deliberately small event transaction: item transfers + boolean quest
-- flags, trainer outcomes and saturating currency. Dialogue/world/UI actions
-- remain the root event executor's work.
function GameSession:transact(expected,changes)
    local current=state[self]
    local ok,result=pcall(function()
        expected,changes=copy(expected),copy(changes)
        object(expected,{flags=true,items=true,trainers=true,money=true}); object(changes,{flags=true,items=true,trainers=true,money=true})
        local required=flags(expected.flags,32)
        local writes=flags(changes.flags,32)
        local trainerRequired=flags(expected.trainers or {},32)
        local trainerWrites=flags(changes.trainers or {},32)
        assert(type(expected.items)=="table" and getmetatable(expected.items)==nil,"item quantity guards required")
        local once,guardCount=false,0
        for id,value in pairs(required) do
            guardCount=guardCount+1
            if value==false and writes[id]==true then once=true end
            if (current.questFlags[id] or false)~=value then error("stale-flag",0) end
        end
        for id,value in pairs(trainerRequired) do
            guardCount=guardCount+1
            if value==false and trainerWrites[id]==true then once=true end
            if (current.trainerFlags[id] or false)~=value then error("stale-trainer",0) end
        end
        assert(guardCount<=32,"too many transaction guards")
        local writeCount=0;for _ in pairs(writes) do writeCount=writeCount+1 end
        for _ in pairs(trainerWrites) do writeCount=writeCount+1 end
        assert(writeCount<=32,"too many transaction flag writes")
        assert(guardCount>=1 and once,"guarded one-time completion flag required")
        if expected.money~=nil then
            assert(Party._integer(expected.money,0,Inventory.MONEY_LIMIT),"invalid money guard")
            if current.inventory:money()~=expected.money then error("stale-money",0) end
        end
        local quantities=0
        for id,value in pairs(expected.items) do
            assert(type(id)=="string" and Party._integer(value,0,Inventory.CAPACITY*Inventory.STACK_LIMIT),"invalid item quantity guard")
            local actual,quantityError=Inventory.quantity(current.inventory,id)
            if actual==nil then error(quantityError,0) end
            if actual~=value then error("stale-item",0) end
            quantities=quantities+1; assert(quantities<=32,"too many item guards")
        end
        assert(Party._array(changes.items,32),"bounded item operation array required")
        local bag=assert(Inventory.fromData(current.deps.itemDefinitions,current.inventory:toData()))
        for _,operation in ipairs(changes.items) do
            object(operation,{op=true,id=true,quantity=true})
            assert(type(operation.id)=="string" and Party._integer(operation.quantity,1,99),"invalid item operation")
            local accepted,reason
            if operation.op=="add" then accepted,reason=bag:add(operation.id,operation.quantity)
            elseif operation.op=="take" then accepted,reason=bag:consume(operation.id,operation.quantity)
            elseif operation.op=="handoff" then
                assert(operation.quantity==1,"key handoff quantity must be one")
                accepted,reason=bag:handoffKey(operation.id)
            else error("unknown item operation") end
            if not accepted then error(reason,0) end
        end
        if changes.money~=nil then
            object(changes.money,{op=true,amount=true})
            assert(expected.money~=nil and Party._integer(changes.money.amount,0,Inventory.MONEY_LIMIT),"guarded integer currency required")
            assert(changes.money.op=="credit" or changes.money.op=="debit","unknown currency operation")
            local accepted,reason
            if changes.money.op=="credit" then
                -- Original AddBCD saturates all result bytes to99 on carry.
                accepted,reason=bag:credit(math.min(changes.money.amount,Inventory.MONEY_LIMIT-bag:money()))
            else accepted,reason=bag:spend(changes.money.amount) end
            assert(accepted,reason)
        end
        local combined=copy(current.questFlags)
        for id,value in pairs(writes) do combined[id]=value end
        local trainerCombined=copy(current.trainerFlags)
        for id,value in pairs(trainerWrites) do trainerCombined[id]=value end
        return {bag=bag:toData(),flags=flags(combined,4096),trainers=flags(trainerCombined,4096),actors=WorldMotionData.empty()}
    end)
    if not ok then return false,tostring(result) end
    -- _replaceData validates before assignment and cannot yield/call scripts.
    local committed,reason=Inventory._replaceData(current.inventory,result.bag)
    if not committed then return false,reason end
    current.questFlags,current.trainerFlags,current.currentActors=result.flags,result.trainers,result.actors
    return true
end
-- Badge bits are represented by stable quest flags in the existing codec.
local badgeFlags = {
    boulder = "BADGE_BOULDER",
    cascade = "BADGE_CASCADE",
    thunder = "BADGE_THUNDER",
    rainbow = "BADGE_RAINBOW",
    soul = "BADGE_SOUL",
}
function GameSession:hasBadge(name)
    local id=assert(badgeFlags[name],"unsupported badge name")
    return self:questFlag(id)
end
-- The battle controller's terminal guard owns one invocation. Compare-and-set
-- rejects stale balances; the detached bag commits while preserving identity.
function GameSession:halveMoneyOnBlackout(expectedMoney)
    local current=state[self]
    if not Party._integer(expectedMoney,0,Inventory.MONEY_LIMIT) then return false,"invalid-money-guard" end
    if current.inventory:money()~=expectedMoney then return false,"stale-money" end
    local bag=assert(Inventory.fromData(current.deps.itemDefinitions,current.inventory:toData()))
    assert(bag:spend(expectedMoney-expectedMoney//2))
    return Inventory._replaceData(current.inventory,bag:toData())
end
function GameSession:location() return copy(state[self].location) end
function GameSession:checkpoint() return copy(state[self].checkpoint) end
function GameSession:captureTraversal(snapshot)
    local current = state[self]
    local ok, prepared = pcall(function()
        object(snapshot, {location = true, world = true, checkpoint = true, actors = true,
            fieldWorld = true, fieldTravel = true, cyclingForced = true})
        local questFlags = copy(current.questFlags)
        if snapshot.cyclingForced ~= nil then
            assert(type(snapshot.cyclingForced) == "boolean", "boolean cycling source bit required")
            questFlags[FieldCycling.FLAG] = snapshot.cyclingForced
        end
        questFlags = flags(questFlags, 4096)
        local normalized = world(current.deps, assert(snapshot.world, "candidate world required"))
        local travel = FieldTravel.normalize(snapshot.fieldTravel or current.fieldTravel)
        local position = location(current.deps, assert(snapshot.location, "candidate location required"), normalized, true, travel)
        local checkpoint = location(current.deps, snapshot.checkpoint or current.checkpoint, normalized)
        local actors = GameSession._validateActors(current.deps,
            snapshot.actors or WorldMotionData.empty(), normalized, position,
            {quest = questFlags, trainers = copy(current.trainerFlags)})
        return {
            world = normalized,
            location = position,
            checkpoint = checkpoint,
            actors = actors,
            fieldWorld = fieldData(snapshot.fieldWorld or current.fieldWorld),
            fieldTravel = travel,
            questFlags = questFlags
        }
    end)
    if not ok then
        return false, tostring(prepared)
    end
    current.questFlags = prepared.questFlags
    current.world, current.location, current.checkpoint = prepared.world, prepared.location, prepared.checkpoint
    current.currentActors = prepared.actors
    current.fieldTravel = prepared.fieldTravel
    current.fieldWorld, current.fieldEpoch = prepared.fieldWorld, nextFieldEpoch()
    return true
end

function GameSession:setLocation(value,asCheckpoint)
    if asCheckpoint~=nil and type(asCheckpoint)~="boolean" then return false,"invalid-checkpoint-mode" end
    local current=state[self]
    return self:captureTraversal({location=value,world=current.world,checkpoint=asCheckpoint and value or current.checkpoint})
end
function GameSession:worldData() return copy(state[self].world) end
function GameSession:setWorld(payload)
    local current=state[self]
    return self:captureTraversal({location=current.location,world=payload,checkpoint=current.checkpoint})
end
function GameSession:rngData()
    local current=state[self]
    return current.rngActive and RulesRNG.toData() or copy(current.rng)
end
function GameSession:activateRNG()
    local current=state[self]
    if activeRNGSession==self then return true end
    local ok,prepared=pcall(rngData,current.rng)
    if not ok then return false,tostring(prepared) end
    local captured,prior=pcall(RulesRNG.toData)
    if not captured then return false,tostring(prior) end
    local restored,err=pcall(RulesRNG.restoreData,prepared)
    if not restored then return false,tostring(err) end -- production restore is atomic.
    if activeRNGSession then
        local old=state[activeRNGSession]; old.rng,old.rngActive=prior,false
    end
    current.rng,current.rngActive=nil,true
    activeRNGSession=self; return true
end
function GameSession:deactivateRNG()
    if activeRNGSession~=self then return true end
    local current=state[self]
    local ok,captured=pcall(RulesRNG.toData)
    if not ok then return false,tostring(captured) end
    current.rng,current.rngActive=captured,false; activeRNGSession=nil; return true
end
function GameSession.activeRNGSession() return activeRNGSession end
function GameSession._state(session) return state[session] end
function GameSession._restore(deps,values)
    -- All values are privately constructed by SessionCodec after full preflight.
    local session=setmetatable({},GameSession)
    values.deps=dependencies(deps); values.rngActive=false
    values.fieldWorld = fieldData(values.fieldWorld)
    values.fieldTravel = FieldTravel.normalize(values.fieldTravel)
    values.safari = SafariGame.normalize(values.safari)
    values.coins = CoinWallet.normalize(values.coins)
    values.fieldEpoch = nextFieldEpoch()
    values.worldRng=WorldMotionData.newWorldRNG(values.rng);values.currentActors=WorldMotionData.empty()
    state[session]=values
    return session
end

-- Same-owned identity commit. Evolution privately prepares every candidate before
-- the first assignment; no callbacks or fallible validation follow bag commit.
function GameSession:evolvePokemon(request)
    local current=state[self]
    local prepared,reason=Evolution._commitPlan(self,request,current.deps.itemDefinitions)
    if not prepared then return false,reason end
    if prepared.bagData then
        local ok,problem=current.inventory:_replaceData(prepared.bagData)
        if not ok then return false,problem end
    end
    for key,value in pairs(prepared.replacement) do prepared.pokemon[key]=value end
    prepared.pokemon.type2=prepared.replacement.type2
    prepared.pokemon.status=prepared.replacement.status
    prepared.pokemon.pendingEvolution=nil
    prepared.pokemon.confusion=nil
    prepared.pokemon.flinched=false
    current.dex=prepared.dex
    prepared.request.status="complete"
    return true,prepared.result
end

-- Independent persistent logical-world stream. Read methods never initialize or
-- mutate it; new/legacy-restored sessions construct it explicitly with zero rolls.
function GameSession:worldRandom(low,high)return assert(state[self].worldRng):random(low,high)end
function GameSession:worldRngData()return assert(state[self].worldRng):toData()end
function GameSession:actorData()return copy(assert(state[self].currentActors))end
function GameSession._validateActors(deps,payload,candidateWorld,position,candidateFlags)
    if deps.validateActors then
        local input=copy(payload);local before=copy(input)
        local normalized=deps.validateActors(input,copy(candidateWorld),copy(position),copy(candidateFlags))
        retainedFields(before,normalized);return copy(normalized)
    end
    assert(payload.zone_id=="none","source actor validator required")
    return WorldMotionData.normalize(payload,nil,position,candidateFlags)
end
function GameSession:_installWorldMotion(payload)
    object(payload,{version=true,rng=true,actors=true});assert(payload.version==1,"unsupported world motion version")
    local current=state[self];local stream=RulesRNG.new(1);stream:restoreData(rngData(payload.rng))
    local actors=GameSession._validateActors(current.deps,payload.actors,current.world,current.location,self:flags())
    current.worldRng,current.currentActors=stream,actors
end

-- Deterministic same-owner transfer. Candidate bag and primitive receipt are
-- fully prepared before either retained Inventory or Pokemon is committed.
local function prepareHeldTransfer(session,mon,id,taking)
    local current=GameSession._state(session)
    if not current then return nil,"invalid-session" end
    if type(mon)~="table" or Party._owner(mon)~=current.party then return nil,"not-party-member" end
    local index
    for i,value in ipairs(current.party:members()) do if value==mon then index=i;break end end
    if not index then return nil,"not-party-member" end
    local valid,why=PokemonCodec.encode(mon)
    if not valid then return nil,"invalid-pokemon" end
    local previous=mon.heldItem
    if taking then
        if previous=="none" then return nil,"no-held-item" end
    else
        if type(id)~="string" or not SpecimenData.holdable[id] then return nil,"invalid-or-nonholdable-item" end
        if previous==id then return nil,"already-holding" end
    end
    local bag=current.inventory
    local candidate,problem=Inventory.fromData(current.deps.itemDefinitions,bag:toData())
    if not candidate then return nil,problem end
    if not taking then
        local accepted,reason=candidate:consume(id,1)
        if not accepted then return nil,reason end
    end
    if previous~="none" then
        local accepted,reason=candidate:add(previous,1)
        if not accepted then return nil,reason end
    end
    local nextItem=taking and "none" or id
    local changedItem=taking and previous or id
    local receipt={kind=taking and "taken" or "given",item=changedItem,previous=previous,heldItem=nextItem,
        partyIndex=index,quantityBefore=bag:quantity(changedItem),quantityAfter=candidate:quantity(changedItem)}
    return {bag=bag,pokemon=mon,data=candidate:toData(),heldItem=nextItem,receipt=receipt}
end
local function commitHeldTransfer(plan)
    local accepted,reason=plan.bag:_replaceData(plan.data)
    if not accepted then return false,reason end
    plan.pokemon.heldItem=plan.heldItem -- Existing scalar field; no callbacks or validation after bag commit.
    return true,plan.receipt
end
function GameSession:giveHeldItem(mon,id)
    local plan,reason=prepareHeldTransfer(self,mon,id,false)
    if not plan then return false,reason end
    return commitHeldTransfer(plan)
end
function GameSession:takeHeldItem(mon)
    local plan,reason=prepareHeldTransfer(self,mon,nil,true)
    if not plan then return false,reason end
    return commitHeldTransfer(plan)
end

-- Retain session, Pokemon and Inventory identities; no callbacks after commit.
function GameSession:resolveTeaching(request,decision,slot)
    local plan,why=Teaching._commitPlan(self,request,decision,slot)
    if not plan then return false,why end
    if plan.bagData then
        local ok,problem=plan.bag:_replaceData(plan.bagData)
        if not ok then return false,problem end
        plan.pokemon.moves,plan.pokemon.pp=plan.moves,plan.pp
    end
    plan.request.status="complete"
    return true,plan.result
end

-- Field transport commits only its private validated plan.
function GameSession:useEscapeRope(request)
    local current = state[self]
    local checked, prepared = pcall(function()
        local plan, reason = SafariGame.escape(current.safari)
        assert(plan, reason)
        local combined = copy(current.questFlags)
        for id, value in pairs(SafariGame.flags(plan.after)) do
            if value or combined[id] ~= nil then
                combined[id] = value
            end
        end
        return {after = plan.after, flags = flags(combined, 4096)}
    end)
    if not checked then
        return false, tostring(prepared)
    end
    -- Existing Escape Rope owns item/world/arrival validation and rollback.
    -- No Safari mutation precedes that guarded commit. All values below are
    -- already prepared; no fallible callback follows the item's success.
    local accepted, result = FieldItems._commit(self, request)
    if not accepted then
        return false, result
    end
    current.safari, current.questFlags = prepared.after, prepared.flags
    self:invalidateFieldWorldContext()
    return true, result
end

-- Item PC owns physical stacks separately from Pokémon boxes and the bag.
function GameSession:itemStorage()return state[self].itemStorage end
function GameSession:selectPCItem(operation,index)return PCItems.prepare(self,operation,index)end
function GameSession:resolvePCItem(request,quantity,decision)return PCItems.resolve(self,request,quantity,decision)end

function GameSession:fieldTravelData()
    return copy(state[self].fieldTravel)
end

function GameSession:fieldWorldData()
    return copy(state[self].fieldWorld)
end

function GameSession:fieldWorldEpoch()
    return state[self].fieldEpoch
end

-- CAS changes only the persisted palette offset; reads never initialize or roll.
function GameSession:clearFieldDarkness(expectedEpoch)
    local current = state[self]
    if current.fieldEpoch ~= expectedEpoch or current.fieldWorld.mapPalOffset ~= 6 then
        return false, "stale-darkness"
    end
    current.fieldWorld = {version = 1, mapPalOffset = 0}
    current.fieldEpoch = nextFieldEpoch()
    return true
end

-- Existing source-scene owners call this after a successful same-map commit.
function GameSession:invalidateFieldWorldContext()
    state[self].fieldEpoch = nextFieldEpoch()
end

local function sceneEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not sceneEqual(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local sceneIntents = setmetatable({}, {__mode = "k"})
function GameSession:forkWorldRNG()
    local stream = RulesRNG.new(1)
    stream:restoreData(self:worldRngData())
    local token = {}
    sceneIntents[token] = {
        session = self,
        epoch = state[self].sceneEpoch or 0,
        fieldEpoch = self:fieldWorldEpoch(),
    }
    return stream, token
end

function GameSession:transactScene(expected, changes, scene)
    local current = state[self]
    local ticket = type(scene) == "table" and sceneIntents[scene.token]
    if not ticket or ticket.session ~= self
        or ticket.epoch ~= (current.sceneEpoch or 0)
        or ticket.fieldEpoch ~= self:fieldWorldEpoch() then
        return false, "stale-scene-intent"
    end
    -- A ticket allows one attempt, including a rejected validation.
    sceneIntents[scene.token] = nil
    local ok, prepared = pcall(function()
        assert(GameSession.activeRNGSession() == self, "inactive-scene-session")
        object(scene, {beforeWorld=true, world=true, beforeRng=true,
            rng=true, location=true, token=true})
        assert(sceneEqual(WorldDeltas.export(), scene.beforeWorld), "stale-scene-world")
        assert(sceneEqual(self:worldRngData(), scene.beforeRng), "stale-scene-world-rng")
        local candidate = world(current.deps, scene.world)
        local position = location(current.deps, scene.location, candidate, true, current.fieldTravel)
        local checkpoint = location(current.deps, current.checkpoint, candidate)
        local stream = RulesRNG.new(1)
        stream:restoreData(rngData(scene.rng))
        return {
            world = candidate,
            location = position,
            checkpoint = checkpoint,
            stream = stream,
            actors = WorldMotionData.empty(),
        }
    end)
    if not ok then
        return false, tostring(prepared)
    end
    -- Native application returns an undo. No callback or yield separates it
    -- from the session transaction, which retains bag and party identities.
    local applied, undo = pcall(WorldDeltas.apply, prepared.world)
    if not applied then
        return false, tostring(undo)
    end
    local accepted, reason = self:transact(expected, changes)
    if not accepted then
        undo()
        return false, reason
    end
    current.world = prepared.world
    current.location = prepared.location
    current.checkpoint = prepared.checkpoint
    current.worldRng = prepared.stream
    current.currentActors = prepared.actors
    current.sceneEpoch = (current.sceneEpoch or 0) + 1
    self:invalidateFieldWorldContext()
    return true
end

-- One field-battle receipt, then detached planning; no bag-capacity dependency.
function GameSession:beginPickupBattle(battle, fieldType)
    return Pickup._bind(self, battle, fieldType)
end

function GameSession:resolvePickupBattle(battle, won, kind)
    local ok, plan = pcall(Pickup._plan, self, battle, won, kind)
    if not ok then
        return false, tostring(plan)
    end
    -- The production restore validates before assignment and cannot yield.
    -- All following assignments are existing primitive Pokemon fields.
    if plan.rng then
        RulesRNG.restore(plan.rng)
    end
    for _, award in ipairs(plan.awards) do
        award.mon.heldItem = award.item
    end
    return true, plan.report
end

-- Repeating source dialogue may clear flags or add a seen entry. Item/reward
-- grants retain their separate one-time transaction and inventory guards.
function GameSession:transactSourceEffects(expected, changes)
    local current <const> = state[self]
    local ok, result = pcall(function()
        object(expected, {flags=true, seen=true, items=true})
        object(changes, {flags=true, seen=true, items=true})
        assert(next(expected.items or {}) == nil and next(changes.items or {}) == nil,
            "source effects cannot transfer items")
        local required <const> = flags(expected.flags, 32)
        local writes <const> = flags(changes.flags, 32)
        local seenRequired <const> = expected.seen or {}
        local seenWrites <const> = changes.seen or {}
        object(seenRequired, pokemonData)
        object(seenWrites, pokemonData)
        local count = 0
        for id, value in pairs(required) do
            if (current.questFlags[id] == true) ~= value then
                error("stale-flag", 0)
            end
            count = count + 1
        end
        for id in pairs(writes) do
            assert(required[id] ~= nil, "unguarded source flag")
        end
        for species, value in pairs(seenRequired) do
            assert(type(value) == "boolean", "boolean seen guard required")
            if (current.dex.seen[species] == true) ~= value then
                error("stale-seen", 0)
            end
            count = count + 1
        end
        for species, value in pairs(seenWrites) do
            assert(value == true and seenRequired[species] ~= nil, "guarded seen addition required")
        end
        assert(count > 0 and count <= 32, "bounded source effect guards required")
        local combined <const> = copy(current.questFlags)
        local discovered <const> = copy(current.dex)
        for id, value in pairs(writes) do
            combined[id] = value
        end
        for species in pairs(seenWrites) do
            discovered.seen[species] = true
        end
        return {flags=flags(combined, 4096), dex=dex(discovered)}
    end)
    if not ok then
        return false, tostring(result)
    end
    current.questFlags = result.flags
    current.dex = result.dex
    return true
end

-- The sole authoritative trade transaction. Preparation allocates and validates
-- the complete incoming specimen, roster, flags, dex and detached continuation.
-- Publication has no yield, callback, recruitment or capacity-dependent work.
function GameSession:resolveNPCTrade(request, context)
    local ok, prepared = pcall(function()
        local plan <const> = NPCTrades._plan(self, request, context)
        local current <const> = state[self]
        local combined <const> = copy(current.questFlags)
        combined[plan.offer.flag] = true
        plan.flags = flags(combined, 4096)
        local pokedex <const> = self:pokedex()
        pokedex.seen[plan.incoming.species] = true
        pokedex.owned[plan.incoming.species] = true
        plan.dex = dex(pokedex)
        -- Validate restoration before publication. The second restore below
        -- receives the same private validated snapshot and cannot call user code.
        local stream <const> = RulesRNG.new(1)
        stream:restore(plan.rng)
        plan.result = {sourceId=plan.offer.sourceId, tradeIndex=plan.offer.index,
            pokemon=plan.incoming, specimen=plan.receipt}
        return plan
    end)
    if not ok then return false, tostring(prepared) end
    local current <const> = state[self]
    RulesRNG.restore(prepared.rng)
    prepared.swap()
    current.questFlags, current.dex = prepared.flags, prepared.dex
    prepared.request.status = "committed"
    self:invalidateFieldWorldContext()
    return true, prepared.result
end

-- Transient source encounter lifecycle is attached to this authoritative owner.
-- It is never serialized or owned by an event/controller singleton.
function GameSession:prepareSourceEncounter(request, location)
    local current = state[self]
    if current.sourcePending or current.sourceBattle then
        return nil, "source-encounter-already-active"
    end
    local ok, prepared = pcall(SourceEncounters.prepare, self, request, location)
    if not ok then return nil, tostring(prepared) end
    current.sourcePending = prepared
    return prepared.token, prepared.enemy
end
function GameSession:sourceEncounterToken(enemy)
    local prepared = state[self].sourcePending
    return prepared and prepared.enemy == enemy and prepared.token or nil
end
function GameSession:cancelSourceEncounter(token)
    local current = state[self]
    if not current.sourcePending or current.sourcePending.token ~= token then
        return false, "stale-source-intent"
    end
    current.sourcePending = nil
    return true
end
function GameSession:bindSourceBattle(battle, token, zoneID)
    local current = state[self]
    local ok, prepared = pcall(function()
        assert(battle.session == self and battle.party == current.party and not battle.trainerName,
            "foreign-source-battle")
        assert(not current.sourceBattle, "source-battle-already-bound")
        local record
        if token then
            record = assert(current.sourcePending, "absent-source-intent")
            assert(record.token == token and record.enemy == battle.enemy and record.zone_id == zoneID
                and record.party == current.party and record.phase == "prepared", "stale-source-intent")
            assert(SourceEncounters.equal(RulesRNG.snapshot(), record.beforeRng), "stale-source-rng")
            for id, value in pairs(record.guards.flags) do
                assert(self:questFlag(id) == value, "stale-source-flag")
            end
            for id, value in pairs(record.guards.items) do
                assert(current.inventory:quantity(id) == value, "stale-source-item")
            end
        else
            local policy = zoneID and SourceEncounters.policy(self, zoneID)
            if not policy then return nil end
            record = {enemy = battle.enemy, party = current.party, zone_id = zoneID, policy = policy, guards = {}}
        end
        assert(GameSession.activeRNGSession() == self, "inactive-source-session")
        record.fieldEpoch = self:fieldWorldEpoch()
        record.beforeFlags = copy(current.questFlags)
        record.beforeDex = copy(current.dex)
        local combined = copy(current.questFlags)
        if record.definition and record.definition.fight then
            combined[record.definition.fight] = false
        end
        return {record = record, flags = flags(combined, 4096)}
    end)
    if not ok then return false, tostring(prepared) end
    if not prepared then return true, nil end
    local record = prepared.record
    record.phase, record.battle = "active", battle
    current.sourcePending, current.sourceBattle = nil, record
    current.questFlags = prepared.flags
    if record.rng then RulesRNG.restore(record.rng) end
    return true, copy(record.policy)
end
function GameSession:sourceBattlePolicy(battle)
    local record = state[self].sourceBattle
    if record and record.battle == battle then
        SourceEncounters.current(self, record, battle)
        return copy(record.policy)
    end
end
function GameSession:abortSourceBattle(battle, failedConstruction)
    local current = state[self]
    local record = current.sourceBattle
    if not record or record.battle ~= battle then return false end
    if failedConstruction then
        current.questFlags, current.dex = record.beforeFlags, record.beforeDex
        if record.beforeRng then RulesRNG.restore(record.beforeRng) end
    end
    current.sourceBattle = nil
    return true
end
function GameSession:attemptSourceCapture(battle, ballID)
    local current = state[self]
    local record = current.sourceBattle
    local ok, prepared = pcall(function()
        SourceEncounters.current(self, record, battle)
        assert(battle:isAwaitingCommand() and not battle.outcome and not battle.endEmitted,
            "wrong-source-capture-phase")
        assert(not record.capture or not record.capture.caught, "source-capture-already-pending")
        assert(battle.enemy:isAlive() and not Party._owner(battle.enemy), "invalid-source-capture-target")
        local context = {pokemon = battle.enemy, wild = true}
        local caughtCount = 0
        for _, owned in pairs(current.dex.owned) do
            if owned then caughtCount = caughtCount + 1 end
        end
        local parameters, reason = Capture.parameters(context, ballID, caughtCount)
        assert(parameters, reason)
        if current.party:count() >= Party.CAPACITY and current.storage:count() >= Storage.BOX_CAPACITY then
            error("storage-full", 0)
        end
        assert(PokemonCodec.encode(battle.enemy), "invalid-source-capture-specimen")
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
        local consumed
        consumed, reason = bag:consume(ballID, 1)
        assert(consumed, reason)
        local futureFlags = copy(current.questFlags)
        if record.definition then futureFlags[record.definition.flag] = true end
        flags(futureFlags, 4096)
        local stream = RulesRNG.new(1)
        stream:restore(RulesRNG.snapshot())
        local result
        if record.policy.capture == false then
            -- Blue removes the thrown ball, but never rolls capture for ghosts.
            result = {caught = false, source_blocked = true, displayShakes = 0}
        else
            result, reason = Capture.attempt(context, ballID, caughtCount, stream)
            assert(result, reason)
        end
        return {result = result, bag = bag:toData(), rng = stream:snapshot(),
            partyCount = current.party:count(), box = current.storage:activeBox(), boxCount = current.storage:count()}
    end)
    if not ok then return nil, tostring(prepared) end
    local accepted, reason = Inventory._replaceData(current.inventory, prepared.bag)
    if not accepted then return nil, reason end
    RulesRNG.restore(prepared.rng)
    record.capture = {caught = prepared.result.caught, result = prepared.result, enemy = battle.enemy,
        partyCount = prepared.partyCount, box = prepared.box, boxCount = prepared.boxCount}
    return prepared.result
end
function GameSession:resolveSourceEncounter(battle, won, kind)
    local current = state[self]
    local record = current.sourceBattle
    if not record or record.battle ~= battle then
        if battle.session == self and battle.sourceEncounter then
            return false, "source-battle-not-bound"
        end
        return true, nil
    end
    local ok, prepared = pcall(function()
        local terminal = SourceEncounters.terminal(self, record, battle, won, kind)
        local combined = copy(current.questFlags)
        for id, value in pairs(terminal.flags) do combined[id] = value end
        combined = flags(combined, 4096)
        local discovered = copy(current.dex)
        local destination
        if kind == "caught" then
            assert(current.party:count() == record.capture.partyCount
                and current.storage:activeBox() == record.capture.box
                and current.storage:count() == record.capture.boxCount, "stale-source-capture-capacity")
            assert(not Party._owner(battle.enemy) and PokemonCodec.encode(battle.enemy), "invalid-source-capture-claim")
            destination = current.party:count() < Party.CAPACITY and "party" or "storage"
            if destination == "storage" then
                assert(current.storage:count() < Storage.BOX_CAPACITY, "storage-full")
            end
            discovered.seen[battle.enemy.species], discovered.owned[battle.enemy.species] = true, true
        end
        return {flags = combined, dex = dex(discovered), destination = destination,
            receipt = record.id and {id = record.id, zone_id = record.zone_id, confirmed = true,
                kind = kind, completed = terminal.completed} or nil}
    end)
    if not ok then return false, tostring(prepared) end
    if prepared.destination then
        local accepted, index
        if prepared.destination == "party" then
            accepted, index = current.party:add(battle.enemy)
        else
            accepted, index = current.storage:receive(battle.enemy)
        end
        if not accepted then return false, index end
        record.capture.result.destination = {destination = prepared.destination, index = index,
            box = prepared.destination == "storage" and current.storage:activeBox() or nil}
    end
    -- Recruitment and only this source actor's completion flags publish without
    -- any callback/yield or fallible operation between the owner assignments.
    current.questFlags, current.dex = prepared.flags, prepared.dex
    if record.definition and record.definition.fight then
        current.currentActors = WorldMotionData.empty()
    end
    record.phase, current.sourceBattle = "complete", nil
    if prepared.receipt and kind ~= "defeat" then
        current.sourceReceipt = prepared.receipt
    end
    return true, copy(prepared.receipt)
end
function GameSession:takeSourceReceipt(id)
    local current = state[self]
    local receipt = current.sourceReceipt
    if not receipt or receipt.id ~= id then return nil end
    current.sourceReceipt = nil
    return copy(receipt)
end

function GameSession:commitCycling(expectedEpoch, expectedTravel, expectedForced, candidate)
    local current = state[self]
    if current.fieldEpoch ~= expectedEpoch
        or not FieldMoves.same(current.fieldTravel, expectedTravel)
        or self:questFlag(FieldCycling.FLAG) ~= expectedForced then
        return false, "stale-cycling-context"
    end
    if type(candidate) ~= "table" then
        return false, "invalid-cycling-candidate"
    end
    local checked, travel = pcall(FieldTravel.normalize, candidate.travel)
    if not checked or type(candidate.forced) ~= "boolean" then
        return false, "invalid-cycling-candidate"
    end
    local modeOnly = copy(travel)
    modeOnly.mode = current.fieldTravel.mode
    if not FieldMoves.same(modeOnly, current.fieldTravel)
        or current.fieldTravel.mode == "surfing" or travel.mode == "surfing"
        or self:inventory():quantity("bicycle") ~= 1 and (travel.mode == "bicycle" or candidate.forced) then
        return false, "invalid-cycling-transition"
    end
    -- A Bicycle toggle is reversible, including false->false for the forced
    -- source bit. Reuse the guarded repeating-effects transaction; the ordinary
    -- gift transaction intentionally requires a one-time completion guard.
    local accepted, reason = self:transactSourceEffects(
        {flags = {[FieldCycling.FLAG] = expectedForced}, items = {}},
        {flags = {[FieldCycling.FLAG] = candidate.forced}, items = {}})
    if not accepted then
        return false, reason
    end
    current.fieldTravel = travel
    self:invalidateFieldWorldContext()
    return true, {kind = candidate.kind, mode = travel.mode, forced = candidate.forced}
end

-- Wallet state shares private codec v4; actual services publish through later
-- root-owned economy transactions, never an inventory stack or boolean flags.
function GameSession:coins()
    return state[self].coins
end
-- Root composes these methods inside GameSession, where `state` is private.
-- No shared owner is modified by the worker.
function GameSession:safariData()
    return copy(state[self].safari)
end
function GameSession:commitSafari(plan, expectedEpoch)
    local current = state[self]
    if current.fieldEpoch ~= expectedEpoch then
        return false, "stale-safari-context"
    end
    local called, prepared = pcall(function()
        local candidate = SafariGame.validatePlan(plan)
        assert(FieldMoves.same(current.safari, candidate.before), "stale-safari-state")
        local expectedFlags = SafariGame.flags(candidate.before)
        for id, value in pairs(expectedFlags) do
            assert(self:questFlag(id) == value, "inconsistent-safari-source-flags")
        end
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
        if candidate.kind == "admission" then
            assert(current.location.zone_id == SafariGame.data().gate, "Safari admission belongs at gate")
            assert(bag:money() == candidate.money, "stale-safari-money")
            assert(bag:spend(candidate.debit))
        end
        local combined = copy(current.questFlags)
        for id, value in pairs(SafariGame.flags(candidate.after)) do
            combined[id] = value
        end
        return {after = candidate.after, flags = flags(combined, 4096), bag = bag:toData()}
    end)
    if not called then
        return false, tostring(prepared)
    end
    local accepted, reason = Inventory._replaceData(current.inventory, prepared.bag)
    if not accepted then
        return false, reason
    end
    current.safari, current.questFlags = prepared.after, prepared.flags
    self:invalidateFieldWorldContext()
    return true
end
function GameSession:commitSafariBattle(token)
    local prepared, reason = SafariBattle._commitPlan(self, token)
    if not prepared then
        return false, reason
    end
    local destination
    if prepared.caught then
        local accepted
        accepted, destination = self:recruit(prepared.caught)
        if not accepted then
            return false, destination
        end
    end
    -- The plan prevalidated these exact primitive values and the active stream.
    -- No fallible callback, allocation or capacity decision follows recruitment.
    state[self].safari = prepared.after
    RulesRNG.restore(prepared.rulesAfter)
    self:invalidateFieldWorldContext()
    return true, {battle = prepared.battle, receipt = prepared.receipt, destination = destination}
end

-- Root applies inside GameSession, where state/copy/flags/dex are private.
-- CoinWallet's existing schema4 field/getter must be installed first. No codec
-- field or separate economy owner is added by these Celadon operations.
function GameSession:commitCeladonService(operation, expected)
    local current = state[self]
    local called, prepared = pcall(function()
        assert(FieldMoves.same(CeladonEconomy.observe(self), expected), "stale-Celadon-service")
        local plan, reason = CeladonEconomy.prepare(expected, operation)
        if not plan then
            error(reason, 0)
        end
        local candidateCoins = CoinWallet.normalize(plan.coins)
        local combined = copy(current.questFlags)
        for id, value in pairs(plan.flags) do
            combined[id] = value
        end
        combined = flags(combined, 4096)
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, plan.bag))
        local destination, mon, stream
        local discovered = copy(current.dex)
        if plan.pokemon then
            assert(Specimen.isActiveSession(self), "inactive-specimen-session")
            destination = current.party:count() < Party.CAPACITY and "party" or "storage"
            if destination == "storage" and current.storage:count() >= Storage.BOX_CAPACITY then
                error("box-full", 0)
            end
            stream = RulesRNG.new(1)
            stream:restoreData(self:rngData())
            mon, reason = Specimen.create(plan.pokemon.species, plan.pokemon.level, "gift", stream)
            assert(mon, reason)
            assert(PokemonCodec.encode(mon), "invalid-Celadon-prize-specimen")
            discovered.seen[mon.species], discovered.owned[mon.species] = true, true
        end
        return {coins=candidateCoins,flags=combined,bag=bag:toData(),dex=dex(discovered),
            mon=mon,destination=destination,rng=stream and stream:snapshot(),item=plan.item,kind=plan.kind,
            received=plan.received,dropped=plan.dropped}
    end)
    if not called then
        return false, tostring(prepared)
    end
    local index
    if prepared.mon then
        local claimed
        if prepared.destination == "party" then
            claimed, index = current.party:add(prepared.mon)
        else
            claimed, index = current.storage:receive(prepared.mon)
        end
        if not claimed then
            return false, index
        end
    end
    assert(Inventory._replaceData(current.inventory, prepared.bag))
    current.coins, current.questFlags, current.dex = prepared.coins, prepared.flags, prepared.dex
    if prepared.rng then
        RulesRNG.restore(prepared.rng)
    end
    self:invalidateFieldWorldContext()
    return true, {kind=prepared.kind,item=prepared.item,destination=prepared.destination,index=index,
        received=prepared.received,dropped=prepared.dropped,
        box=prepared.destination == "storage" and current.storage:activeBox() or nil}
end

-- Root applies inside GameSession. This is transient owner state, never codec
-- data. CeladonSlots is a pure reducer; the scene holds only an opaque token.
local function celadonSlotRecord(session, token)
    local current = state[session]
    local record = current.celadonSlot
    assert(record and record.token == token, "stale-slot-token")
    local owner = record.owner
    assert(owner.epoch == record.epoch and owner.game.session == session and owner.session == session
        and owner.player == record.player and owner.zone == record.zone and owner:valid() and owner:isTop(),
        "stale-slot-owner")
    assert(GameSession.activeRNGSession() == session and session:fieldWorldEpoch() == record.fieldEpoch,
        "stale-slot-session")
    assert(current.coins == record.coins and FieldMoves.same(RulesRNG.snapshot(), record.rng), "stale-slot-economy")
    return current, record
end
function GameSession:celadonCornerLuck()
    return state[self].celadonLucky
end
function GameSession:enterCeladonCorner(expectedEpoch)
    if self:fieldWorldEpoch() ~= expectedEpoch or GameSession.activeRNGSession() ~= self then
        return false, "stale-Game-Corner-entry"
    end
    local stream = RulesRNG.new(1)
    stream:restore(RulesRNG.snapshot())
    local lucky = CeladonSlots.luckyIndex(stream:random(0,255))
    state[self].celadonLucky = lucky
    RulesRNG.restore(stream:snapshot())
    return true, lucky
end
function GameSession:openCeladonSlots(owner, machineID)
    local current = state[self]
    local called, record = pcall(function()
        assert(not current.celadonSlot and owner.session == self and owner.game.session == self
            and owner.id == machineID and owner:valid() and owner:isTop(), "invalid-slot-owner")
        assert(owner.zone.stableID == "pokered:GAME_CORNER", "slots-outside-Game-Corner")
        assert(owner.player.facing == "left" or owner.player.facing == "right", "source-slot-facing-required")
        local machine = assert(CeladonServices.machine(machineID), "source slot machine required")
        assert(machine.condition == "ANY_FACING", "source-slot-unavailable")
        local x,y = owner.player:getFacingTile()
        assert(x == machine.x and y == machine.y, "source slot position required")
        assert(current.inventory:quantity("coinCase") > 0, "no-coin-case")
        assert(CoinWallet.normalize(current.coins) > 0, "no-coins")
        assert(GameSession.activeRNGSession() == self, "inactive-slot-session")
        local lucky = current.celadonLucky
        if lucky == nil then
            local initialized, reason = self:enterCeladonCorner(self:fieldWorldEpoch())
            assert(initialized, reason)
            lucky = reason
        end
        return {token={},owner=owner,epoch=owner.epoch,player=owner.player,zone=owner.zone,
            fieldEpoch=self:fieldWorldEpoch(),coins=current.coins,rng=RulesRNG.snapshot(),
            value=CeladonSlots.open(machine.index,lucky)}
    end)
    if not called then return nil,tostring(record) end
    current.celadonSlot = record
    return record.token, copy(record.value)
end
function GameSession:betCeladonSlots(token, bet)
    local called, result = pcall(function()
        local current, record = celadonSlotRecord(self,token)
        assert(current.inventory:quantity("coinCase") > 0, "no-coin-case")
        assert(Party._integer(bet,1,3), "source slot bet required")
        if current.coins < bet then error("insufficient-coins",0) end
        local stream = RulesRNG.new(1)
        stream:restore(record.rng)
        local candidate = CeladonSlots.bet(record.value,bet,stream)
        local afterCoins = CoinWallet.normalize(current.coins-bet)
        current.coins, record.value, record.coins = afterCoins, candidate, afterCoins
        RulesRNG.restore(stream:snapshot())
        record.rng = stream:snapshot()
        self:invalidateFieldWorldContext()
        record.fieldEpoch = self:fieldWorldEpoch()
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:startCeladonSpin(token)
    local called, result = pcall(function()
        local _,record = celadonSlotRecord(self,token)
        record.value = CeladonSlots.start(record.value)
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:tickCeladonSlots(token, pressedA)
    local called, result = pcall(function()
        local current,record = celadonSlotRecord(self,token)
        local stream = RulesRNG.new(1)
        stream:restore(record.rng)
        local candidate = CeladonSlots.tick(record.value,pressedA,stream)
        local afterCoins = current.coins
        if candidate.phase == "result" then
            afterCoins = CoinWallet.normalize(math.min(CoinWallet.limit(),afterCoins+candidate.payout))
        end
        current.coins, record.value, record.coins = afterCoins, candidate, afterCoins
        RulesRNG.restore(stream:snapshot())
        record.rng = stream:snapshot()
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:againCeladonSlots(token)
    local called, result = pcall(function()
        local _,record = celadonSlotRecord(self,token)
        record.value = CeladonSlots.again(record.value)
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:closeCeladonSlots(token)
    local current = state[self]
    if not current.celadonSlot or current.celadonSlot.token ~= token then return false end
    current.celadonSlot = nil
    return true
end
