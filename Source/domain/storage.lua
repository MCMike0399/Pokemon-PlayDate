-- Twelve explicitly selected boxes; no automatic overflow to another box.
-- Import after domain/party. Actual Pokemon identities move, never copies.
Class("Storage")
Storage.BOX_COUNT, Storage.BOX_CAPACITY = 12, 20
local states = setmetatable({}, { __mode = "k" })
local integer, array = Party._integer, Party._array
local function isParty(value)
    return type(value) == "table" and type(value.is) == "function" and value:is("Party")
end
function Storage:init()
    local boxes = {}
    for box = 1, Storage.BOX_COUNT do boxes[box] = {} end
    states[self] = { boxes = boxes, active = 1 }
end
function Storage:activeBox() return states[self].active end
function Storage:selectBox(box)
    if not integer(box, 1, Storage.BOX_COUNT) then return false, "invalid-box" end
    states[self].active = box
    return true
end
function Storage:count(box)
    box = box or self:activeBox()
    if not integer(box, 1, Storage.BOX_COUNT) then return nil, "invalid-box" end
    return #states[self].boxes[box]
end
function Storage:get(index, box)
    box = box or self:activeBox()
    local count, err = self:count(box)
    if not count then return nil, err end
    if not integer(index, 1, count) then return nil, "invalid-index" end
    return states[self].boxes[box][index]
end
function Storage:receive(mon)
    local box = states[self].boxes[self:activeBox()]
    if #box >= Storage.BOX_CAPACITY then return false, "box-full" end
    if not Party._validPokemon(mon) then return false, "invalid-pokemon" end
    local ok, err = Party._claimMany({mon}, self)
    if not ok then return false, err end
    box[#box + 1] = mon
    return true, #box
end
function Storage:deposit(party, index)
    if not isParty(party) then return false, "invalid-party" end
    local box = states[self].boxes[self:activeBox()]
    if #box >= Storage.BOX_CAPACITY then return false, "box-full" end
    local mon, err = party:_take(index, self)
    if not mon then return false, err end
    box[#box + 1] = mon
    return true, #box
end
function Storage:withdraw(party, index)
    if not isParty(party) then return false, "invalid-party" end
    local mon, err = self:get(index)
    if not mon then return false, err end
    if party:count() >= Party.CAPACITY then return false, "party-full" end
    local ok, problem = party:_receive(mon, self)
    if not ok then return false, problem end
    table.remove(states[self].boxes[self:activeBox()], index)
    return true, party:count()
end
function Storage:move(index, targetBox)
    local mon, err = self:get(index)
    if not mon then return false, err end
    if not integer(targetBox, 1, Storage.BOX_COUNT) then return false, "invalid-box" end
    local source = self:activeBox()
    if targetBox == source then return true end
    local target = states[self].boxes[targetBox]
    if #target >= Storage.BOX_CAPACITY then return false, "box-full" end
    table.remove(states[self].boxes[source], index)
    target[#target + 1] = mon
    return true
end
function Storage:toData(encodePokemon)
    if type(encodePokemon) ~= "function" then return nil, "codec-required" end
    local ok, data = pcall(function()
        local out = { version = 1, active = self:activeBox(), boxes = {} }
        for b = 1, Storage.BOX_COUNT do
            out.boxes[b] = {}
            for i, mon in ipairs(states[self].boxes[b]) do out.boxes[b][i] = Party._primitive(encodePokemon(mon)) end
        end
        return out
    end)
    if not ok then return nil, "encode-failed" end
    return data
end
function Storage.fromData(data, decodePokemon)
    if type(data) ~= "table" or data.version ~= 1 or not integer(data.active, 1, Storage.BOX_COUNT)
        or not array(data.boxes, Storage.BOX_COUNT) or #data.boxes ~= Storage.BOX_COUNT
        or type(decodePokemon) ~= "function" then return nil, "invalid-storage-data" end
    local boxes, all = {}, {}
    local ok = pcall(function()
        for b = 1, Storage.BOX_COUNT do
            assert(array(data.boxes[b], Storage.BOX_CAPACITY), "invalid-box-data")
            boxes[b] = {}
            for i, record in ipairs(data.boxes[b]) do
                local mon = decodePokemon(Party._primitive(record))
                assert(Party._validPokemon(mon), "invalid-pokemon")
                boxes[b][i] = mon
                all[#all + 1] = mon
            end
        end
    end)
    if not ok then return nil, "decode-failed" end
    local storage = Storage()
    local claimed, err = Party._claimMany(all, storage)
    if not claimed then return nil, err end
    states[storage] = { boxes = boxes, active = data.active }
    return storage
end
