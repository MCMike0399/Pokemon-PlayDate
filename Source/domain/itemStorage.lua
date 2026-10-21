-- Blue item PC:50 physical rows,99 per row. No Pokémon boxes or currency.
Class("ItemStorage")
ItemStorage.CAPACITY,ItemStorage.STACK_LIMIT=50,99
local states=setmetatable({},{__mode="k"})
local function copy(v)return Party._primitive(v)end
local function object(v,fields)
    assert(type(v)=="table"and getmetatable(v)==nil,"plain item storage record required")
    for key in pairs(v)do assert(fields[key],"unknown item storage field: "..tostring(key))end
end
function ItemStorage.normalize(definitions,data)
    object(data,{version=true,slots=true});assert(data.version==1,"unsupported item storage version")
    assert(Party._array(data.slots,50),"invalid item storage slots")
    local keys={};local out={version=1,slots={}}
    for _,slot in ipairs(data.slots)do
        object(slot,{id=true,quantity=true});local definition=definitions[slot.id]
        assert(definition and Party._integer(slot.quantity,1,99),"invalid stored item/quantity")
        if definition.keyItem then assert(slot.quantity==1 and not keys[slot.id],"duplicate stored key item");keys[slot.id]=true end
        out.slots[#out.slots+1]={id=slot.id,quantity=slot.quantity}
    end
    return out
end
function ItemStorage:init(definitions)
    Inventory(definitions) -- Reuse definition validation; no shared owner mutation.
    states[self]={definitions=copy(definitions),data={version=1,slots={}}}
end
function ItemStorage:slots()return copy(states[self].data.slots)end
function ItemStorage:count()return #states[self].data.slots end
function ItemStorage:quantity(id)
    if not states[self].definitions[id]then return nil,"unknown-item"end
    local n=0;for _,slot in ipairs(states[self].data.slots)do if slot.id==id then n=n+slot.quantity end end;return n
end
function ItemStorage:toData()return copy(states[self].data)end
function ItemStorage.fromData(definitions,data)
    local ok,normalized=pcall(ItemStorage.normalize,definitions,data)
    if not ok then return nil,tostring(normalized)end
    local storage=ItemStorage(definitions);states[storage].data=normalized;return storage
end
-- Internal preflight returns a non-yielding assignment only. Called before the
-- bag's validated commit so no throwing validation follows the first mutation.
function ItemStorage:_prepareCommit(data)
    local current=states[self];local prepared=ItemStorage.normalize(current.definitions,data)
    return function()current.data=prepared end
end
-- Literal AddItemToInventory ordering. A full container rejects FIRST matching
-- row overflow before scanning later duplicates, even if they have free room.
function ItemStorage.planAdd(slots,capacity,id,quantity)
    assert(Party._array(slots,capacity)and Party._integer(quantity,1,99),"invalid item add plan")
    local out=copy(slots);local full=#out>=capacity;local left=quantity
    for _,slot in ipairs(out)do if slot.id==id then
        local total=slot.quantity+left
        if total<100 then slot.quantity=total;return out end
        if full then return nil,"full"end
        slot.quantity=99;left=total-99
    end end
    if full then return nil,"full"end
    out[#out+1]={id=id,quantity=left};return out
end
function ItemStorage.removeSelected(slots,index,quantity)
    local out=copy(slots);local slot=out[index]
    if not slot or not Party._integer(quantity,1,slot.quantity)then return nil,"invalid-quantity"end
    slot.quantity=slot.quantity-quantity;if slot.quantity==0 then table.remove(out,index)end
    return out
end
function ItemStorage.checkUnique(definitions,bag,pc)
    local seen={}
    for _,slots in ipairs({bag.slots,pc.slots})do for _,slot in ipairs(slots)do
        if definitions[slot.id].keyItem then assert(not seen[slot.id],"key item owned in bag and PC");seen[slot.id]=true end
    end end
end
