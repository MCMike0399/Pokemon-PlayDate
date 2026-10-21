-- Persistent session owner. No sprites, Story singleton or filesystem access.
Class("GameSession")
local state=setmetatable({}, {__mode="k"})
local activeRNGSession=nil
local stages={pre_oak=true,lab_greet=true,choose=true,pre_rival=true,rival_fight=true,goodbye=true,done=true}
local counters={bulbasaur="charmander",charmander="squirtle",squirtle="bulbasaur"}
local facings={up=true,down=true,left=true,right=true}
local function copy(value) return Party._primitive(value) end
local function object(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"plain object required")
    for key in pairs(value) do assert(allowed[key],"unknown field: "..tostring(key)) end
end
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
local function location(deps,value,candidateWorld)
    object(value,{zone_id=true,x=true,y=true,facing=true})
    assert(stable(value.zone_id) and Party._integer(value.x,0,4095) and Party._integer(value.y,0,4095) and facings[value.facing],"invalid location fields")
    local resolved=deps.resolveLocation(copy(value),copy(candidateWorld))
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
    local definitions={}
    for id,entry in pairs(assert(deps.itemDefinitions,"item definitions required")) do definitions[id]={keyItem=entry.keyItem} end
    Inventory(definitions) -- validates configuration without modifying callers.
    return {itemDefinitions=definitions,validateWorld=deps.validateWorld,resolveLocation=deps.resolveLocation}
end
-- Internal serialization seam; consumers use SessionCodec rather than mutating.
GameSession._copy,GameSession._object,GameSession._flags=copy,object,flags
GameSession._intro,GameSession._dex,GameSession._world=intro,dex,world
GameSession._location,GameSession._rngData,GameSession._dependencies=location,rngData,dependencies
function GameSession:init(deps,options)
    deps=dependencies(deps); options=options or {}
    object(options,{world=true,location=true,checkpoint=true,seed=true})
    local payload=world(deps,options.world or {schema=1,zones={},zone_count=0})
    local start=location(deps,assert(options.location,"starting location required"),payload)
    local checkpoint=location(deps,options.checkpoint or start,payload)
    local stream=RulesRNG.new(options.seed or 1)
    state[self]={deps=deps,party=Party(),storage=Storage(),inventory=Inventory(deps.itemDefinitions),
        intro={stage="pre_oak"},questFlags={},trainerFlags={},dex={seen={},owned={}},location=start,checkpoint=checkpoint,
        world=payload,rng=stream:toData(),rngActive=false}
end
function GameSession.newSession(deps,options) return GameSession(deps,options) end
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
function GameSession:pokedex() return copy(state[self].dex) end
local function setFlag(self,kind,id,value)
    if not stable(id) or type(value)~="boolean" then return false,"invalid-flag" end
    local values=state[self][kind]
    if values[id]==nil then
        local count=0; for _ in pairs(values) do count=count+1 end
        if count>=4096 then return false,"flag-limit" end
    end
    values[id]=value; return true
end
function GameSession:setQuestFlag(id,value) return setFlag(self,"questFlags",id,value) end
function GameSession:questFlag(id) return state[self].questFlags[id] or false end
function GameSession:setTrainerDefeated(id,value) return setFlag(self,"trainerFlags",id,value) end
function GameSession:trainerDefeated(id) return state[self].trainerFlags[id] or false end
function GameSession:flags() return {quest=copy(state[self].questFlags),trainers=copy(state[self].trainerFlags)} end
-- A deliberately small event transaction: item transfers + boolean quest
-- flags only. Dialogue/world/UI actions remain the root event executor's work.
function GameSession:transact(expected,changes)
    local current=state[self]
    local ok,result=pcall(function()
        expected,changes=copy(expected),copy(changes)
        object(expected,{flags=true,items=true}); object(changes,{flags=true,items=true})
        local required=flags(expected.flags,32)
        local writes=flags(changes.flags,32)
        assert(type(expected.items)=="table" and getmetatable(expected.items)==nil,"item quantity guards required")
        local once,guardCount=false,0
        for id,value in pairs(required) do
            guardCount=guardCount+1
            if value==false and writes[id]==true then once=true end
            if (current.questFlags[id] or false)~=value then error("stale-flag",0) end
        end
        assert(guardCount>=1 and once,"guarded one-time completion flag required")
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
        local combined=copy(current.questFlags)
        for id,value in pairs(writes) do combined[id]=value end
        return {bag=bag:toData(),flags=flags(combined,4096)}
    end)
    if not ok then return false,tostring(result) end
    -- _replaceData validates before assignment and cannot yield/call scripts.
    local committed,reason=Inventory._replaceData(current.inventory,result.bag)
    if not committed then return false,reason end
    current.questFlags=result.flags
    return true
end
function GameSession:location() return copy(state[self].location) end
function GameSession:checkpoint() return copy(state[self].checkpoint) end
function GameSession:captureTraversal(snapshot)
    local current=state[self]
    local ok,prepared=pcall(function()
        object(snapshot,{location=true,world=true,checkpoint=true})
        local normalized=world(current.deps,assert(snapshot.world,"candidate world required"))
        local position=location(current.deps,assert(snapshot.location,"candidate location required"),normalized)
        local checkpoint=location(current.deps,snapshot.checkpoint or current.checkpoint,normalized)
        return {world=normalized,location=position,checkpoint=checkpoint}
    end)
    if not ok then return false,tostring(prepared) end
    current.world,current.location,current.checkpoint=prepared.world,prepared.location,prepared.checkpoint
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
