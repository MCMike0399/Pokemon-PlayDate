-- Pure preview + immediate medicine/economy transactions on injected owners.
-- Import after data/items, domain/inventory, data/pokemon and battle/moves.
-- Does not own a bag, party, money, battle turn or session.
Items = {}
local statuses = {burn=true,poison=true,paralyze=true,sleep=true,freeze=true}
local function integer(value, low, high)
    local n = type(value) == "number" and math.tointeger(value) or nil
    return n and n >= low and n <= high and n or nil
end
local function instance(value, class)
    return type(value) == "table" and type(value.is) == "function" and value:is(class)
end
local function definition(id)
    return type(id) == "string" and ItemData.definitions[id] or nil
end
local function target(mon)
    if not instance(mon,"Pokemon") or not integer(mon.maxHP,1,9999) or not integer(mon.hp,0,mon.maxHP)
        or (mon.status ~= nil and not statuses[mon.status]) or not integer(mon.statusTurns,0,3)
        or (mon.status ~= "sleep" and mon.statusTurns ~= 0)
        or not integer(mon.sleepDuration,mon.status=="sleep" and 1 or 0,mon.status=="sleep" and 3 or 0)
        or (mon.status=="sleep" and mon.statusTurns>mon.sleepDuration)
        or (mon.confusion ~= nil and not integer(mon.confusion,0,4)) or type(mon.moves) ~= "table" or type(mon.pp) ~= "table"
        or #mon.moves < 1 or #mon.moves > 4 then return false end
    local seen = {}
    for _, move in ipairs(mon.moves) do
        local data = moveData[move]
        if not data or data.noPP or seen[move] or not integer(mon.pp[move],0,data.maxPP) then return false end
        seen[move] = true
    end
    return true
end
function Items.planUse(id, mon, moveSlot)
    local item = definition(id)
    if not item then return nil,"unknown-item" end
    if item.effect == "unsupported" then return nil,"unsupported-item-use" end
    if not target(mon) then return nil,"invalid-pokemon" end
    local plan = {itemId=id,kind="medicine",hpBefore=mon.hp,hpAfter=mon.hp,hpRestored=0,
        ppRestored=0,ppChanges={},clearStatus=false,clearConfusion=false,revived=false}
    if item.effect ~= "pp" and moveSlot ~= nil then return nil,"unexpected-move-slot" end
    if item.effect == "heal" or item.effect == "fullRestore" then
        if mon.hp == 0 then return nil,"no-effect" end -- Potions never revive.
        local amount = item.amount == "all" or item.effect == "fullRestore"
        amount = amount and mon.maxHP or item.amount
        plan.hpAfter = math.min(mon.maxHP,mon.hp+amount)
        if item.effect == "fullRestore" then
            plan.clearStatus = mon.status ~= nil
            plan.clearConfusion = mon.confusion ~= nil and mon.confusion > 0
        end
    elseif item.effect == "cure" then
        if mon.hp == 0 then return nil,"no-effect" end
        plan.clearStatus = mon.status ~= nil and (item.status == "all" or item.status == mon.status)
        plan.clearConfusion = item.status == "all" and mon.confusion ~= nil and mon.confusion > 0
    elseif item.effect == "revive" then
        if mon.hp ~= 0 then return nil,"no-effect" end
        plan.hpAfter = item.amount == "all" and mon.maxHP or math.max(1,mon.maxHP // 2)
        plan.clearStatus,plan.clearConfusion,plan.revived = true,mon.confusion ~= nil,true
    elseif item.effect == "pp" then
        local first,last
        if item.allMoves then
            if moveSlot ~= nil then return nil,"unexpected-move-slot" end
            first,last = 1,#mon.moves
        else
            moveSlot = integer(moveSlot,1,#mon.moves)
            if not moveSlot then return nil,"invalid-move-slot" end
            first,last = moveSlot,moveSlot
        end
        for slot = first,last do
            local move = mon.moves[slot]
            local before,max = mon.pp[move],moveData[move].maxPP
            local after = item.amount == "all" and max or math.min(max,before+item.amount)
            if after > before then
                plan.ppChanges[#plan.ppChanges+1] = {slot=slot,move=move,before=before,after=after}
                plan.ppRestored = plan.ppRestored+after-before
            end
        end
    else return nil,"unsupported-item-use" end
    plan.hpRestored = plan.hpAfter-plan.hpBefore
    if plan.clearStatus then plan.statusCured=mon.status end
    if plan.hpRestored == 0 and plan.ppRestored == 0 and not plan.clearStatus and not plan.clearConfusion then return nil,"no-effect" end
    return plan
end
function Items.use(inventory, id, mon, moveSlot)
    if not instance(inventory,"Inventory") then return false,"invalid-inventory" end
    -- Never accept an old/tampered preview as authority: replan immediately.
    local plan,problem = Items.planUse(id,mon,moveSlot)
    if not plan then return false,problem end
    local ok,why = Inventory.consume(inventory,id,1)
    if not ok then return false,why end
    -- The remaining writes use only already-validated primitive fields, with
    -- no callbacks/yields/further fallible operations after consumption.
    mon.hp = plan.hpAfter
    if plan.clearStatus then mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0 end
    if plan.clearConfusion then mon.confusion=nil end
    for _, change in ipairs(plan.ppChanges) do mon.pp[change.move]=change.after end
    return true,plan
end
function Items.buy(inventory, martId, id, quantity)
    if not instance(inventory,"Inventory") then return false,"invalid-inventory" end
    quantity = integer(quantity,1,Inventory.STACK_LIMIT)
    if not quantity then return false,"invalid-quantity" end
    local item = definition(id)
    if not item then return false,"unknown-item" end
    local stock = type(martId) == "string" and ItemData.marts[martId] or nil
    if not stock then return false,"unknown-mart" end
    local stocked = false
    for _, key in ipairs(stock) do if key == id then stocked=true;break end end
    if not stocked then return false,"not-stocked" end
    local total = item.price*quantity -- Blue max price9800 * qty99 fits int32.
    if Inventory.money(inventory) < total then return false,"insufficient-money" end
    -- Inventory.add is itself atomic on bag-full/unknown/unique failures.
    local ok,problem = Inventory.add(inventory,id,quantity)
    if not ok then return false,problem end
    -- Both production methods are synchronous and do not invoke observers;
    -- after the precheck this debit cannot fail or race another command.
    assert(Inventory.spend(inventory,total),"item purchase debit invariant")
    return true,{kind="purchase",itemId=id,quantity=quantity,total=total,money=Inventory.money(inventory)}
end
function Items.sell(inventory, id, quantity)
    if not instance(inventory,"Inventory") then return false,"invalid-inventory" end
    quantity = integer(quantity,1,Inventory.STACK_LIMIT)
    if not quantity then return false,"invalid-quantity" end
    local item = definition(id)
    if not item then return false,"unknown-item" end
    if item.keyItem or item.category == "hm" or item.sellPrice == nil then return false,"unsellable-item" end
    local total = item.sellPrice*quantity
    if total > Inventory.MONEY_LIMIT-Inventory.money(inventory) then return false,"money-limit" end
    local ok,problem = Inventory.consume(inventory,id,quantity)
    if not ok then return false,problem end
    assert(Inventory.credit(inventory,total),"item sale credit invariant")
    return true,{kind="sale",itemId=id,quantity=quantity,total=total,money=Inventory.money(inventory)}
end
