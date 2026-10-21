-- One-shot, physical-row transfers. UI chooses; session owns both containers.
PCItems={}
local requests=setmetatable({},{__mode="k"})
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
function PCItems.prepare(session,operation,index)
    if operation~="deposit"and operation~="withdraw"and operation~="toss"then return nil,"invalid-operation"end
    local state=GameSession._state(session);local bag,pc=state.inventory,state.itemStorage
    local bagData,pcData=bag:toData(),pc:toData();local source=operation=="deposit"and bagData or pcData
    if not Party._integer(index,1,#source.slots)then return nil,"invalid-index"end
    local slot=source.slots[index];local definition=state.deps.itemDefinitions[slot.id]
    if operation=="toss"and definition.keyItem then return nil,"important-item"end
    local request={};requests[request]={session=session,bag=bag,pc=pc,bagData=bagData,pcData=pcData,operation=operation,index=index,id=slot.id,max=slot.quantity,key=definition.keyItem,done=false}
    return request,{id=slot.id,quantity=slot.quantity,keyItem=definition.keyItem}
end
function PCItems.resolve(session,request,quantity,decision)
    local r=requests[request]
    if not r or r.session~=session or r.done then return false,"stale-selection"end
    r.done=true -- Terminal failures/cancel never leave a reusable request.
    if decision=="cancel"then return false,"cancelled"end
    if decision~="confirm"then return false,"invalid-decision"end
    local state=GameSession._state(session)
    if state.inventory~=r.bag or state.itemStorage~=r.pc or not same(r.bagData,r.bag:toData())or not same(r.pcData,r.pc:toData())then return false,"stale-selection"end
    if not Party._integer(quantity,1,r.max)or r.key and quantity~=1 then return false,"invalid-quantity"end
    local bagData,pcData=Party._primitive(r.bagData),Party._primitive(r.pcData)
    local source=r.operation=="deposit"and bagData or pcData
    local removed,reason=ItemStorage.removeSelected(source.slots,r.index,quantity)
    if not removed then return false,reason end
    source.slots=removed
    if r.operation~="toss"then
        local destination=r.operation=="deposit"and pcData or bagData
        local capacity=r.operation=="deposit"and 50 or 20
        local added=ItemStorage.planAdd(destination.slots,capacity,r.id,quantity)
        if not added then return false,r.operation=="deposit"and "pc-full"or "bag-full"end
        destination.slots=added
    end
    -- All schema/uniqueness/capacity validation precedes either assignment.
    local valid=Inventory.fromData(state.deps.itemDefinitions,bagData)
    if not valid then return false,"invalid-bag"end
    local validPC=ItemStorage.fromData(state.deps.itemDefinitions,pcData)
    if not validPC then return false,"invalid-pc"end
    local commitPC=r.pc:_prepareCommit(pcData)
    local ok,error=r.bag:_replaceData(bagData)
    if not ok then return false,error end
    commitPC()
    return true,{operation=r.operation,id=r.id,quantity=quantity,index=r.index}
end
