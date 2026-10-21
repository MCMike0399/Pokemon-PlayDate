-- Original151 Gen5 evolution owner. Prepared requests are private, never save data.
import "data/evolutionData"
Evolution={}
Class("EvolutionRequest")
local requests=setmetatable({}, {__mode="k"})
local stones={moonStone=true,fireStone=true,thunderStone=true,waterStone=true,leafStone=true}
local function object(value,fields)
    if type(value)~="table" or getmetatable(value) then return false end
    for key in pairs(value) do if not fields[key] then return false end end
    return true
end
local function owned(session,mon)
    return type(session)=="table" and type(session.is)=="function" and session:is("GameSession")
        and Party._validPokemon(mon) and Party._owner(mon)==session:party()
end
local function ruleFor(mon,trigger)
    if not object(trigger,{kind=true,item=true}) then return nil,"invalid-trigger" end
    if trigger.kind~="level" and trigger.kind~="stone" and trigger.kind~="trade" then return nil,"invalid-trigger" end
    if trigger.kind~="stone" and trigger.item~=nil then return nil,"unexpected-item" end
    if trigger.kind=="stone" and not stones[trigger.item] then return nil,"invalid-stone" end
    for _,rule in ipairs(EvolutionData.rules[mon.species] or {}) do
        if rule.trigger==trigger.kind and (trigger.kind~="stone" or rule.item==trigger.item)
            and (trigger.kind~="level" or mon.level>=rule.minimum) then return rule end
    end
    return nil,"no-evolution"
end
function Evolution.isStone(id) return stones[id]==true end
function Evolution.hasPending(mon) return mon and mon.pendingEvolution~=nil or false end
function Evolution.candidates(session,mon,trigger)
    if not owned(session,mon) then return nil,"not-owned-party-member" end
    local valid,problem=PokemonCodec.encode(mon)
    if not valid then return nil,problem end
    if mon.maxHP~=calcHP(pokemonData[mon.species].baseHP,mon.level) then return nil,"invalid-derived-stats" end
    local rule,reason=ruleFor(mon,trigger)
    if not rule then return nil,reason end
    if trigger.kind=="level" then
        local pending=mon.pendingEvolution
        if not pending or pending.species~=mon.species or pending.level~=mon.level then return nil,"no-level-event" end
    end
    if trigger.kind=="stone" and (session:inventory():quantity(trigger.item) or 0)<1 then return nil,"insufficient-items" end
    return {{from=mon.species,to=rule.to,kind=rule.trigger,level=mon.level,item=rule.item}}
end
local function prepare(session,mon,trigger,tradeAuthorized)
    local choices,reason=Evolution.candidates(session,mon,trigger)
    if not choices then return nil,reason end
    if #mon:getPendingMoveChoices()>0 then return nil,"learning-pending" end
    if trigger.kind=="trade" and not tradeAuthorized then return nil,"trade-hook-required" end
    local valid,why=PokemonCodec.encode(mon)
    if not valid then return nil,why end
    local request=EvolutionRequest()
    local choice=choices[1]
    requests[request]={session=session,pokemon=mon,trigger={kind=choice.kind,item=choice.item},from=choice.from,
        target=choice.to,oldName=mon.name,level=choice.level,status="prepared",tradeAuthorized=tradeAuthorized==true}
    return request
end
function Evolution.prepare(session,mon,trigger) return prepare(session,mon,trigger,false) end
-- Explicit external policy seam. No Link Cable, NPC or multiplayer availability is invented.
function Evolution.prepareTrade(session,mon,authorize)
    if type(authorize)~="function" then return nil,"trade-hook-required" end
    local candidates,reason=Evolution.candidates(session,mon,{kind="trade"})
    if not candidates then return nil,reason end
    local ok,confirmed=pcall(authorize,session,mon,candidates[1].to)
    if not ok or confirmed~=true then return nil,"trade-not-authorized" end
    return prepare(session,mon,{kind="trade"},true)
end
function EvolutionRequest:getSnapshot()
    local r=requests[self]
    if not r then return {status="invalid"} end
    return {status=r.status,from=r.from,species=r.target,level=r.level,kind=r.trigger.kind,item=r.trigger.item,
        can_cancel=r.trigger.kind=="level",from_name=r.oldName,to_name=PokemonNames[r.target]}
end
function Evolution.abort(request)
    local r=requests[request]
    if not r or r.status~="prepared" then return false,"not-prepared" end
    r.status="aborted";return true -- Interrupted level event stays durable for resume.
end
function Evolution.cancel(request)
    local r=requests[request]
    if not r or r.status~="prepared" then return false,"not-prepared" end
    if r.trigger.kind~="level" then return false,"cannot-cancel" end
    if not owned(r.session,r.pokemon) or r.pokemon.species~=r.from or r.pokemon.level~=r.level then return false,"stale-request" end
    local pending=r.pokemon.pendingEvolution
    if not pending or pending.species~=r.from or pending.level~=r.level then return false,"stale-request" end
    r.pokemon.pendingEvolution=nil;r.status="cancelled";return true
end
-- Private plan consumed by the session owner. Every failure precedes mutation.
function Evolution._commitPlan(session,request,itemDefinitions)
    local r=requests[request]
    if not r or r.status~="prepared" or r.session~=session then return nil,"not-prepared" end
    local mon=r.pokemon
    if not owned(session,mon) or mon.species~=r.from or mon.level~=r.level then return nil,"stale-request" end
    local options,reason=Evolution.candidates(session,mon,r.trigger)
    if not options or options[1].to~=r.target then return nil,reason or "stale-request" end
    if #mon:getPendingMoveChoices()>0 then return nil,"learning-pending" end
    local record,why=PokemonCodec.encode(mon)
    if not record then return nil,why end
    local target=pokemonData[r.target]
    local nextMax=calcHP(target.baseHP,mon.level)
    if mon.hp==0 then record.hp=0
    elseif nextMax>=mon.maxHP then record.hp=mon.hp+nextMax-mon.maxHP
    else record.hp=math.min(mon.hp,nextMax) end
    record.species=r.target;record.pendingEvolution=nil
    local renamed=record.name==PokemonNames[r.from]
    if renamed then record.name=PokemonNames[r.target] end
    local known={};for _,move in ipairs(record.moves) do known[move]=true end
    local planned={}
    for _,entry in ipairs(Pokemon.learnsetEntriesFor(r.target,mon.level,mon.level)) do
        if not known[entry.move] then
            planned[#planned+1]=entry;known[entry.move]=true
        end
    end
    local nextId=math.tointeger(record.nextMoveChoiceId)
    if not nextId or #planned>2147483647-nextId then return nil,"move-choice-id-exhausted" end
    for _,entry in ipairs(planned) do
        record.pendingMoveChoices[#record.pendingMoveChoices+1]={id=nextId,move=entry.move,level=entry.level,
            sourceOrder=entry.order,sourceMoveId=entry.id,reason="evolution"}
        nextId=nextId+1
    end
    record.nextMoveChoiceId=nextId
    local replacement,error=PokemonCodec.decode(record)
    if not replacement then return nil,error end
    local bagData
    if r.trigger.kind=="stone" then
        local bag,bagError=Inventory.fromData(itemDefinitions,session:inventory():toData())
        if not bag then return nil,bagError end
        local ok,problem=bag:consume(r.trigger.item,1)
        if not ok then return nil,problem end
        bagData=bag:toData()
    end
    local dex=session:pokedex();dex.seen[r.target],dex.owned[r.target]=true,true
    return {pokemon=mon,replacement=replacement,bagData=bagData,dex=dex,request=r,
        result={from=r.from,species=r.target,kind=r.trigger.kind,item=r.trigger.item,
            consumed=r.trigger.kind=="stone",renamed=renamed,move_choices=#planned}}
end
function Evolution.complete(request)
    local r=requests[request]
    if not r then return false,"invalid-request" end
    return r.session:evolvePokemon(request)
end
-- The current singles campaign maps the game's qualifying return results to
-- victory/run/caught. Defeat discards the battle's pending evolution events.
function Evolution.afterBattle(session,kind)
    if kind~="victory" and kind~="run" and kind~="caught" and kind~="defeat" then return false,"invalid-outcome" end
    if kind=="defeat" then for _,mon in ipairs(session:party():members()) do mon.pendingEvolution=nil end end
    return true
end
