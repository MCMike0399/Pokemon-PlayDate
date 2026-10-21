-- Ephemeral, one-shot machine intent. Durable learning queues retain their
-- level/evolution provenance; teaching never forges an event into that queue.
import "data/machineData"
Teaching={}
Class("TeachingRequest")
local requests=setmetatable({}, {__mode="k"})
local hmMoves={cut=true,fly=true,surf=true,strength=true,flash=true}
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function owned(session,mon)
    return type(session)=="table" and type(session.is)=="function" and session:is("GameSession")
        and Party._validPokemon(mon) and Party._owner(mon)==session:party()
end
local function eligible(session,mon,id)
    if not owned(session,mon) then return nil,"not-owned-party-member" end
    local machine=MachineData.definitions[id]
    if not machine then return nil,"unknown-machine" end
    if not moveData[machine.move] then return nil,"move-not-implemented" end
    if not (MachineData.compatibility[mon.species]or {})[id] then return nil,"incompatible" end
    if mon:hasMove(machine.move) then return nil,"already-known" end
    if #mon:getPendingMoveChoices()>0 or mon.pendingEvolution then return nil,"progression-pending" end
    if session:inventory():quantity(id)<1 then return nil,"insufficient-items" end
    local record,why=PokemonCodec.encode(mon)
    if not record then return nil,why end
    return {machine=machine,record=record}
end
function Teaching.isMachine(id) return type(id)=="string" and MachineData.definitions[id]~=nil end
function Teaching.protectedMove(key) return hmMoves[key]==true end
function Teaching.prepare(session,mon,id)
    local plan,why=eligible(session,mon,id)
    if not plan then return nil,why end
    local request=TeachingRequest()
    requests[request]={session=session,pokemon=mon,bag=session:inventory(),item=id,
        quantity=session:inventory():quantity(id),record=plan.record,move=plan.machine.move,status="prepared"}
    return request
end
function TeachingRequest:getSnapshot()
    local r=requests[self]
    if not r then return {status="invalid"} end
    return {status=r.status,item=r.item,move=r.move,species=r.record.species,name=r.record.name}
end
function Teaching.pokemon(request) local r=requests[request];return r and r.pokemon end
function Teaching.cancel(request)
    local r=requests[request]
    if not r or r.status~="prepared" then return false,"not-prepared" end
    r.status="cancelled";return true
end
-- Every validation, allocation, bag candidate and codec decode precedes commit.
function Teaching._commitPlan(session,request,decision,slot)
    local r=requests[request]
    if not r or r.session~=session or r.status~="prepared" then return nil,"not-prepared" end
    if decision~="learn" and decision~="decline" then return nil,"invalid-decision" end
    if decision=="decline" and slot~=nil then return nil,"unexpected-slot" end
    local plan,why=eligible(session,r.pokemon,r.item)
    if not plan then return nil,why end
    if session:inventory()~=r.bag or session:inventory():quantity(r.item)~=r.quantity
        or not same(plan.record,r.record) then return nil,"stale-request" end
    local result={move=r.move,item=r.item,kind=decision=="learn" and "learned" or "declined",consumed=false}
    if decision=="decline" then return {request=r,result=result} end
    local count=#plan.record.moves
    if slot==nil then
        if count>=4 then return nil,"replacement-required" end
        slot=count+1
    elseif type(slot)~="number" or not math.tointeger(slot) or slot<1 or slot>count then return nil,"invalid-slot" end
    local forgotten=plan.record.moves[slot]
    if forgotten and hmMoves[forgotten] then return nil,"protected-hm" end
    local oldPP=forgotten and plan.record.pp[forgotten]
    plan.record.moves[slot]=r.move
    if forgotten then plan.record.pp[forgotten]=nil end
    plan.record.pp[r.move]=oldPP and math.min(oldPP,moveData[r.move].maxPP) or moveData[r.move].maxPP
    local candidate,error=PokemonCodec.decode(plan.record)
    if not candidate then return nil,error end
    local bag,problem=Inventory.fromData(GameSession._state(session).deps.itemDefinitions,r.bag:toData())
    if not bag then return nil,problem end
    if plan.machine.consume then
        local ok,reason=bag:consume(r.item,1)
        if not ok then return nil,reason end
        result.consumed=true
    end
    result.forgotten=forgotten
    return {request=r,pokemon=r.pokemon,moves=candidate.moves,pp=candidate.pp,
        bag=r.bag,bagData=bag:toData(),result=result}
end
function Teaching.complete(request,decision,slot)
    local r=requests[request]
    if not r then return false,"invalid-request" end
    return r.session:resolveTeaching(request,decision,slot)
end
