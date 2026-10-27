-- Domain-only party. Import after lib/oop and data/pokemon.
Class("Party")
Party.CAPACITY = 6
local states = setmetatable({}, { __mode = "k" })
local owners = setmetatable({}, { __mode = "k" })
local function integer(n, low, high)
    return type(n) == "number" and n % 1 == 0 and n >= low and n <= high
end
local function valid(mon)
    return type(mon) == "table" and type(mon.is) == "function" and mon:is("Pokemon")
        and pokemonData[mon.species] ~= nil and integer(mon.maxHP, 1, 1000000) and integer(mon.hp, 0, mon.maxHP)
end
local function primitive(value, visited)
    local kind = type(value)
    if kind == "boolean" or kind == "string" then return value end
    if kind == "number" then assert(value == value and math.abs(value) < math.huge, "nonfinite number"); return value end
    assert(kind == "table" and getmetatable(value) == nil, "primitive table required")
    visited = visited or {}
    assert(not visited[value], "cyclic data")
    visited[value] = true
    local out = {}
    for key, item in pairs(value) do
        assert(type(key) == "string" or integer(key, 1, 1000000), "invalid primitive key")
        out[key] = primitive(item, visited)
    end
    visited[value] = nil
    return out
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
-- Internal transfer/codec seam shared only with Storage.
Party._integer, Party._validPokemon, Party._primitive, Party._array = integer, valid, primitive, array
function Party._owner(mon) return owners[mon] end
function Party._claimMany(mons, owner)
    local seen = {}
    for _, mon in ipairs(mons) do
        if not valid(mon) then return false, "invalid-pokemon" end
        if seen[mon] or owners[mon] then return false, "already-owned" end
        seen[mon] = true
    end
    for _, mon in ipairs(mons) do owners[mon] = owner end
    return true
end
function Party._moveOwner(mon, from, to)
    assert(owners[mon] == from, "ownership invariant")
    owners[mon] = to
end
function Party:init()
    states[self] = { members = {}, active = 0 }
end
function Party:count() return #states[self].members end
function Party:get(index)
    if not integer(index, 1, self:count()) then return nil, "invalid-index" end
    return states[self].members[index]
end
function Party:members()
    local out = {}
    for i, mon in ipairs(states[self].members) do out[i] = mon end
    return out
end
function Party:activeIndex() return states[self].active end
function Party:active() return self:get(states[self].active) end
function Party:firstUsable()
    for i, mon in ipairs(states[self].members) do if mon:isAlive() then return i end end
    return nil
end
function Party:allFainted() return self:count() > 0 and self:firstUsable() == nil end
function Party:add(mon)
    if self:count() >= Party.CAPACITY then return false, "party-full" end
    if not valid(mon) then return false, "invalid-pokemon" end
    local ok, err = Party._claimMany({mon}, self)
    if not ok then return false, err end
    local state = states[self]
    state.members[#state.members + 1] = mon
    if state.active == 0 then state.active = 1 end
    return true, #state.members
end
function Party:switch(index)
    local mon, err = self:get(index)
    if not mon then return false, err end
    if not mon:isAlive() then return false, "fainted" end
    states[self].active = index
    return true
end
function Party:swap(a, b)
    if not integer(a, 1, self:count()) or not integer(b, 1, self:count()) then return false, "invalid-index" end
    local state = states[self]
    state.members[a], state.members[b] = state.members[b], state.members[a]
    if state.active == a then state.active = b elseif state.active == b then state.active = a end
    return true
end
function Party:_canTake(index)
    local mon, err = self:get(index)
    if not mon then return false, err end
    if self:count() == 1 then return false, "last-member" end
    if mon:isAlive() then
        local usable = 0
        for _, item in ipairs(states[self].members) do if item:isAlive() then usable = usable + 1 end end
        if usable == 1 then return false, "last-usable" end
    end
    return true
end
function Party:_take(index, destination)
    local ok, err = self:_canTake(index)
    if not ok then return nil, err end
    local state = states[self]
    local mon = table.remove(state.members, index)
    Party._moveOwner(mon, self, destination)
    if state.active == index then
        state.active = self:firstUsable() or math.min(index, #state.members)
    elseif state.active > index then state.active = state.active - 1 end
    return mon
end
function Party:_receive(mon, previousOwner)
    if self:count() >= Party.CAPACITY then return false, "party-full" end
    if not valid(mon) or owners[mon] ~= previousOwner then return false, "ownership" end
    local state = states[self]
    Party._moveOwner(mon, previousOwner, self)
    state.members[#state.members + 1] = mon
    if state.active == 0 then state.active = 1 end
    return true
end
function Party:healAll()
    for _, mon in ipairs(states[self].members) do mon:fullRestore() end
    return true
end
function Party:toData(encodePokemon)
    if type(encodePokemon) ~= "function" then return nil, "codec-required" end
    local ok, result = pcall(function()
        local data = { version = 1, active = self:activeIndex(), members = {} }
        for i, mon in ipairs(states[self].members) do data.members[i] = primitive(encodePokemon(mon)) end
        return data
    end)
    if not ok then return nil, "encode-failed" end
    return result
end
function Party.fromData(data, decodePokemon)
    if type(data) ~= "table" or data.version ~= 1 or not array(data.members, Party.CAPACITY)
        or not integer(data.active, #data.members > 0 and 1 or 0, #data.members) or type(decodePokemon) ~= "function" then
        return nil, "invalid-party-data"
    end
    local mons = {}
    local ok = pcall(function()
        for i, record in ipairs(data.members) do mons[i] = decodePokemon(primitive(record)) end
    end)
    if not ok or not array(mons, Party.CAPACITY) or #mons ~= #data.members then return nil, "decode-failed" end
    local party = Party()
    local claimed, err = Party._claimMany(mons, party)
    if not claimed then return nil, err end
    states[party] = { members = mons, active = data.active }
    return party
end

-- Internal controller construction scope. Restore even a previously fainted
-- active member if admission fails; never reorder or recreate the roster.
function Party:_withActiveForEntry(index, build)
    local mon=self:get(index)
    assert(mon and mon:isAlive() and type(build)=="function","invalid field lead")
    local state=states[self];local previous=state.active
    state.active=index
    local result=table.pack(pcall(build,mon))
    if not result[1] then state.active=previous;error(result[2],0) end
    return table.unpack(result,2,result.n)
end

-- Session-only atomic exchange: source remove-and-append ordering, with a
-- prebuilt roster so even a last-member exchange never exposes an empty party.
-- Keep the old active object's identity if it survives and remains usable.
function Party:_prepareExchange(index, outgoing, incoming)
    local current <const> = states[self]
    if self:get(index) ~= outgoing or owners[outgoing] ~= self then
        return nil, "stale-party-member"
    end
    if not valid(incoming) or not incoming:isAlive() or owners[incoming] then
        return nil, "invalid-replacement"
    end
    local members <const> = {}
    local activeObject <const> = current.members[current.active]
    local active
    for _, mon in ipairs(current.members) do
        if mon ~= outgoing then
            members[#members + 1] = mon
            if mon == activeObject and mon:isAlive() then active = #members end
        end
    end
    members[#members + 1] = incoming
    active = active or #members
    local candidate <const> = {members=members, active=active}
    return function()
        owners[outgoing] = nil
        owners[incoming] = self
        states[self] = candidate
    end
end
