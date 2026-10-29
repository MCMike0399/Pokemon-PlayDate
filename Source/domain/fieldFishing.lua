-- Blue rod responses and original-151 tables, with existing Gen V specimens.
-- Follows FieldEncounters' detached RNG commit; no second bag/session owner.
FieldFishing = {}
local requests = setmetatable({}, {__mode = "k"})
local rods <const> = {oldRod = true, goodRod = true, superRod = true}
local cached

local function policy()
    if not cached then
        local record = assert(json.decodeFile("data/fieldGear.json"))
        assert(record.schema == 1 and record.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified fishing data")
        cached = record.fishing
    end
    return cached
end

function FieldFishing.isRod(id)
    return rods[id] == true
end

-- Source samples one byte, tests its low bit, then rejects out-of-range 2-bit
-- indices and repeats the *whole* bite test. This is not a separate 50/50 roll.
function FieldFishing.sample(id, map, rng)
    if id == "oldRod" then
        local row = policy().old
        return {kind = "bite", species = row.species, level = row.level, draws = 0}
    end
    assert(id == "goodRod" or id == "superRod", "unknown-rod")
    local group = policy().super[map]
    local rows = id == "goodRod" and policy().good or group and policy().groups[group]
    if not rows then
        return {kind = "no-fish", draws = 0}
    end
    assert(#rows >= 1 and #rows <= 4, "invalid fishing group")
    for draw = 1, 1024 do
        local byte = rng:random(0, 255)
        if byte % 2 == 1 then
            return {kind = "no-bite", draws = draw}
        end
        local slot = (byte // 2) % 4 + 1
        if slot <= #rows then
            local row = rows[slot]
            assert(pokemonData[row.species] and Party._integer(row.level, 1, 100), "invalid fishing species/level")
            return {kind = "bite", species = row.species, level = row.level, slot = slot, draws = draw}
        end
    end
    error("fishing-source-rejection-limit", 0)
end

function FieldFishing.prepare(session, id, map)
    if not rods[id] then
        return nil, "unknown-rod"
    end
    if type(map) ~= "string" or #map > 64 or not map:match("^[A-Z][A-Z0-9_]+$") then
        return nil, "invalid-fishing-map"
    end
    if not Specimen.isActiveSession(session) then
        return nil, "inactive-fishing-session"
    end
    if session:inventory():quantity(id) ~= 1 then
        return nil, "rod-not-in-bag"
    end
    if not session:party():firstUsable() then
        return nil, "no-usable-party"
    end
    local specimen, reason = Specimen.planEncounter(session)
    if not specimen then
        return nil, reason
    end
    local token = {}
    requests[token] = {
        session = session, id = id, map = map, specimen = specimen,
        rules = RulesRNG.snapshot(), members = session:party():members(),
        roster = assert(session:party():toData(function(mon)
            return assert(PokemonCodec.encode(mon))
        end)),
        inventory = session:inventory():toData(), epoch = session:fieldWorldEpoch(), status = "prepared"
    }
    return token
end

local function current(request)
    if not request or request.status ~= "prepared" or not Specimen.isActiveSession(request.session)
        or request.session:fieldWorldEpoch() ~= request.epoch
        or not FieldMoves.same(RulesRNG.snapshot(), request.rules)
        or not FieldMoves.same(request.session:inventory():toData(), request.inventory) then
        return false
    end
    local members = request.session:party():members()
    if #members ~= #request.members then
        return false
    end
    for index, mon in ipairs(members) do
        if mon ~= request.members[index] then
            return false
        end
    end
    local roster = request.session:party():toData(function(mon)
        return assert(PokemonCodec.encode(mon))
    end)
    return FieldMoves.same(roster, request.roster)
end

function FieldFishing.cancel(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false, "stale-fishing-request"
    end
    request.status = "cancelled"
    return true
end

function FieldFishing.resolve(token)
    local request = requests[token]
    local ok, result = pcall(function()
        assert(current(request), "stale-fishing-request")
        local stream = RulesRNG.new(1)
        stream:restore(request.rules)
        local response = FieldFishing.sample(request.id, request.map, stream)
        local pokemon, creation
        if response.kind == "bite" then
            local specimen = Specimen.rollEncounterAbilities(request.specimen, stream)
            local gap = Specimen.encounterGap(specimen)
            assert(not gap, "unimplemented-fishing-acquisition:" .. tostring(gap))
            pokemon, creation = Specimen.create(response.species, response.level, "wild", stream, specimen)
            assert(pokemon, creation)
        end
        assert(current(request), "stale-fishing-request")
        -- The first mutation comes after every fallible sampling/creation check.
        -- A completed no-bite attempt legitimately advances only the rules RNG.
        RulesRNG.restore(stream:snapshot())
        return {kind = pokemon and "encounter" or response.kind, pokemon = pokemon,
            receipt = {rod = request.id, map = request.map, response = response,
                rules_before = request.rules, rules_after = stream:snapshot(), creation = creation}}
    end)
    if request and request.status == "prepared" then
        request.status = ok and "complete" or "failed"
    end
    if not ok then
        return false, tostring(result)
    end
    return true, result
end
