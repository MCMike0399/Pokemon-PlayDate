-- Blue bag: 20 slots, stack size 99, shared key-item capacity.
-- Item definitions are supplied data {id={keyItem=boolean}}; no item effects/UI.
Class("Inventory")
Inventory.CAPACITY, Inventory.STACK_LIMIT, Inventory.MONEY_LIMIT = 20, 99, 999999
local states = setmetatable({}, { __mode = "k" })
local function integer(n, low, high)
    return type(n) == "number" and n % 1 == 0 and n >= low and n <= high
end
local function array(value, limit)
    if type(value) ~= "table" or getmetatable(value) ~= nil or #value > limit then return false end
    local count = 0
    for key in pairs(value) do
        if not integer(key, 1, #value) then return false end
        count = count + 1
    end
    return count == #value
end
local function copySlots(slots)
    local out = {}
    for i, slot in ipairs(slots) do out[i] = { id = slot.id, quantity = slot.quantity } end
    return out
end
function Inventory:init(definitions)
    assert(type(definitions) == "table", "item definitions required")
    local defs = {}
    for id, item in pairs(definitions) do
        assert(type(id) == "string" and id:match("^[a-z][A-Za-z0-9]*$") and type(item) == "table"
            and type(item.keyItem) == "boolean", "invalid item definition")
        defs[id] = { keyItem = item.keyItem }
    end
    states[self] = { definitions = defs, slots = {}, money = 0 }
end
function Inventory:slots() return copySlots(states[self].slots) end
function Inventory:count() return #states[self].slots end
function Inventory:money() return states[self].money end
function Inventory:quantity(id)
    if not states[self].definitions[id] then return nil, "unknown-item" end
    local n = 0
    for _, slot in ipairs(states[self].slots) do if slot.id == id then n = n + slot.quantity end end
    return n
end
function Inventory:add(id, quantity)
    local state = states[self]
    local definition = state.definitions[id]
    if not definition then return false, "unknown-item" end
    if not integer(quantity, 1, Inventory.STACK_LIMIT) then return false, "invalid-quantity" end
    if definition.keyItem and (quantity ~= 1 or self:quantity(id) > 0) then return false, "unique-key-item" end
    local slots, left = copySlots(state.slots), quantity
    for _, slot in ipairs(slots) do
        if slot.id == id then
            local add = math.min(left, Inventory.STACK_LIMIT - slot.quantity)
            slot.quantity, left = slot.quantity + add, left - add
        end
    end
    while left > 0 do
        if #slots >= Inventory.CAPACITY then return false, "bag-full" end
        local add = math.min(left, Inventory.STACK_LIMIT)
        slots[#slots + 1] = { id = id, quantity = add }
        left = left - add
    end
    state.slots = slots
    return true
end
local function take(self, id, quantity, keyHandoff)
    local state = states[self]
    local definition = state.definitions[id]
    if not definition then return false, "unknown-item" end
    if not integer(quantity, 1, Inventory.STACK_LIMIT) then return false, "invalid-quantity" end
    if definition.keyItem ~= keyHandoff then return false, keyHandoff and "not-key-item" or "key-item" end
    if self:quantity(id) < quantity then return false, "insufficient-items" end
    local slots, left = {}, quantity
    for _, slot in ipairs(state.slots) do
        local remove = slot.id == id and math.min(slot.quantity, left) or 0
        if slot.id == id then left = left - remove end
        if slot.quantity > remove then slots[#slots + 1] = { id = slot.id, quantity = slot.quantity - remove } end
    end
    state.slots = slots
    return true
end
function Inventory:consume(id, quantity) return take(self, id, quantity, false) end
function Inventory:handoffKey(id) return take(self, id, 1, true) end
function Inventory:credit(amount)
    if not integer(amount, 0, Inventory.MONEY_LIMIT) then return false, "invalid-money" end
    local state = states[self]
    if amount > Inventory.MONEY_LIMIT - state.money then return false, "money-limit" end
    state.money = state.money + amount
    return true
end
function Inventory:spend(amount)
    if not integer(amount, 0, Inventory.MONEY_LIMIT) then return false, "invalid-money" end
    local state = states[self]
    if amount > state.money then return false, "insufficient-money" end
    state.money = state.money - amount
    return true
end
function Inventory:toData()
    return { version = 1, slots = self:slots(), money = self:money() }
end
function Inventory.fromData(definitions, data)
    if type(data) ~= "table" or data.version ~= 1 or not integer(data.money, 0, Inventory.MONEY_LIMIT)
        or not array(data.slots, Inventory.CAPACITY) then return nil, "invalid-inventory-data" end
    local inventory = Inventory(definitions)
    local state, keys = states[inventory], {}
    for _, slot in ipairs(data.slots) do
        if type(slot) ~= "table" or not state.definitions[slot.id] or not integer(slot.quantity, 1, Inventory.STACK_LIMIT) then
            return nil, "invalid-slot"
        end
        if state.definitions[slot.id].keyItem then
            if keys[slot.id] or slot.quantity ~= 1 then return nil, "unique-key-item" end
            keys[slot.id] = true
        end
    end
    state.slots, state.money = copySlots(data.slots), data.money
    return inventory
end
