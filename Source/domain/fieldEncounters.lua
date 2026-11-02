-- Owned normal grass attempts. Blue tables/rates, bounded B2W2 field effects.
-- No implicit current game/zone, battle overrides, actor RNG, Repel or Egg owner.
FieldEncounters={VERSION=2}
local rateUp <const> = {[35]=true,[71]=true,[99]=true}
local rateDown <const> = {[1]=true,[73]=true,[95]=true}
-- Blue bytes and authored unit rates retain their own denominator. Native
-- rateDown truncates integer rates; unit policies keep their fractional units.
function FieldEncounters.effectiveRate(rate,ability)
    local value = rate.value
    if rateUp[ability] then
        value=value*2
    elseif rateDown[ability] then
        value=rate.kind=="byte" and value//2 or value/2
    end
    return math.min(value,rate.kind=="byte" and 256 or 1)
end
local plans=setmetatable({},{__mode="k"})
local affected={[9]="static",[22]="intimidate",[51]="keen-eye"}
local policyFields <const> = {rate=true, slots=true}
local rateFields <const> = {kind=true, value=true}
local slotFields <const> = {species=true, minLevel=true, maxLevel=true, weight=true}
local function copy(v)return Party._primitive(v)end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function object(value,fields)
    assert(type(value)=="table"and getmetatable(value)==nil,"plain encounter descriptor required")
    for key in pairs(value) do
        if not fields[key] then
            error("unknown encounter descriptor field: " .. tostring(key))
        end
    end
end
local function validatePolicy(data)
    object(data,policyFields)
    local rate=data.rate
    object(rate,rateFields)
    assert(type(rate)=="table"and type(rate.value)=="number"and rate.value==rate.value,"invalid encounter rate")
    if rate.kind=="byte"then assert(Party._integer(rate.value,0,255),"invalid Blue encounter byte")
    else assert(rate.kind=="unit"and rate.value>=0 and rate.value<=1,"invalid authored encounter rate")end
    if rate.value==0 then return nil,"disabled-rate"end
    assert(Party._array(data.slots,64)and #data.slots>0,"missing bounded encounter slots")
    local total=0
    for _,slot in ipairs(data.slots)do
        object(slot,slotFields)
        assert(pokemonData[slot.species],"unknown encounter species")
        assert(Party._integer(slot.minLevel,1,100)and Party._integer(slot.maxLevel,slot.minLevel,100),"invalid encounter level range")
        assert(Party._integer(slot.weight,1,65535),"invalid encounter weight")
        total=total+slot.weight
    end
    assert(total<=1073741823,"encounter weight total out of RNG bounds")
    return data,total
end
-- Only called after full schema validation. Keep the request independent
-- without recursively validating and copying every primitive a second time.
local function capturePolicy(data)
    local capturedSlots = {}
    for i, slot in ipairs(data.slots) do
        capturedSlots[i] = {
            species = type(slot.species) == "table" and copy(slot.species) or slot.species,
            minLevel = slot.minLevel,
            maxLevel = slot.maxLevel,
            weight = slot.weight,
        }
    end
    return {
        rate = {kind=data.rate.kind, value=data.rate.value},
        slots = capturedSlots,
    }
end
-- One current-map capture only. Retained requests own their older captures,
-- so eviction never changes a published token's values or freshness checks.
local preparedZone, preparedData, preparedTotal
local policyScratch = {rate={}}
local function clearPolicyScratch()
    policyScratch.slots = nil
    policyScratch.rate.kind = nil
    policyScratch.rate.value = nil
end

-- Equality against a validated private capture is also schema validation. Check
-- metatables at every depth: a live descriptor must never gain cached trust by
-- retaining the same table identity or adding a projecting metatable.
local function samePlain(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    if getmetatable(a) ~= nil then
        return false
    end
    for key, value in pairs(a) do
        if not samePlain(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local function preparedPolicy(zone, data)
    if zone == preparedZone and preparedData and samePlain(data, preparedData) then
        return preparedData, preparedTotal
    end
    local validated, total = validatePolicy(data)
    if not validated then
        return nil, total
    end
    local captured = capturePolicy(validated)
    preparedZone, preparedData, preparedTotal = zone, captured, total
    return captured, total
end

-- Call after map bindings are installed, before ordinary exploration. Public
-- callbacks remain per-coordinate and are never treated as map-wide policy.
function FieldEncounters.prepareZone(zone)
    preparedZone, preparedData, preparedTotal = nil, nil, nil
    local ok, data, reason = pcall(function()
        assert(type(zone) == "table" and type(zone.is) == "function" and zone:is("Zone"),
            "encounter Zone required")
        if not Zone._usesDefaultEncounterPolicy(zone) then
            return nil, "coordinate-policy"
        end
        local descriptor, why = Zone._readEncounterMapPolicy(zone, policyScratch)
        if not descriptor then
            return nil, why
        end
        -- Authored rooms commonly have no slots and the default unit rate.
        -- Do not invent an entry failure where terrain rejects every attempt.
        -- Any eligible completed step still performs the complete validation.
        if Party._array(descriptor.slots, 64) and #descriptor.slots == 0 then
            return nil, "no-encounter-slots"
        end
        return preparedPolicy(zone, descriptor)
    end)
    clearPolicyScratch()
    if not ok then
        return false, tostring(data)
    end
    if not data then
        return reason == "disabled-rate" or reason == "no-encounter-slots"
            or reason == "coordinate-policy", reason
    end
    return true
end

local function policy(zone, x, y, mode)
    local data, reason = Zone._readEncounterPolicyAt(zone, x, y, policyScratch, mode)
    if not data then
        return nil, reason
    end
    local captured, total = preparedPolicy(zone, data)
    clearPolicyScratch()
    return captured, total
end

local function travelMode(session)
    -- Borrow only the scalar from the existing authoritative session owner.
    -- fieldTravelData() intentionally returns a detached copy for public users.
    local mode = GameSession._state(session).fieldTravel.mode
    assert(mode == "walking" or mode == "bicycle" or mode == "surfing", "invalid travel mode")
    return mode
end

local function requestStorage()
    return {members={}, roster={members={}}, rules={}}
end

-- The ordinary path reuses only private storage. PokemonCodec still examines
-- every live durable field, including nested HP/PP/traits, on every attempt.
-- Changed Pokemon values may require a fresh validated codec snapshot.
local function prepareRequest(r, session, party, zone, x, y)
    assert(Specimen.isActiveSession(session), "inactive-encounter-session")
    assert(party == session:party(), "foreign-encounter-party")
    local usable = party:firstUsable()
    if not usable then
        return nil, "no-usable-party"
    end
    assert(type(zone) == "table" and type(zone.is) == "function" and zone:is("Zone"),
        "encounter Zone required")
    local mode = travelMode(session)
    local data, total = policy(zone, x, y, mode == "surfing" and "water" or "land")
    if not data then
        return nil, total
    end
    r.session, r.party, r.zone = session, party, zone
    r.travelMode = mode
    r.x, r.y, r.data, r.total = x, y, data, total
    r.lead = assert(party:get(1))
    r.ability = r.lead:ability()
    r.usable, r.level = usable, party:get(usable).level
    r.roster.active = party:activeIndex()
    local count = party:count()
    for i = 1, count do
        local mon = party:get(i)
        r.members[i] = mon
        r.roster.members[i] = assert(PokemonCodec._snapshot(mon))
    end
    for i = #r.members, count + 1, -1 do
        r.members[i] = nil
        r.roster.members[i] = nil
    end
    RulesRNG._snapshotInto(r.rules)
    r.done = false
    return true
end

function FieldEncounters.prepare(context)
    local ok, plan, reason = pcall(function()
        assert(type(context) == "table" and getmetatable(context) == nil,
            "explicit encounter context required")
        for key in pairs(context) do
            assert(key == "session" or key == "party" or key == "zone" or key == "x" or key == "y",
                "unknown encounter context")
        end
        local r = requestStorage()
        local ready, why = prepareRequest(r, context.session, context.party, context.zone, context.x, context.y)
        if not ready then
            return nil, why
        end
        r.rulesData = RulesRNG.toData()
        r.specimen = assert(Specimen.planEncounter(r.session))
        -- Retained plans always receive separate storage and a fresh token.
        local token = {}
        plans[token] = r
        return token
    end)
    clearPolicyScratch()
    if not ok then
        return nil, tostring(plan)
    end
    return plan, reason
end
local rngScratch = {}
local function current(r)
    assert(Specimen.isActiveSession(r.session) and r.session:party() == r.party,
        "stale-encounter-owner")
    assert(travelMode(r.session) == r.travelMode, "stale-encounter-travel-mode")
    local data, total = policy(r.zone, r.x, r.y, r.travelMode == "surfing" and "water" or "land")
    assert(data and total == r.total and (data == r.data or same(data, r.data)),
        "stale-encounter-table-or-terrain")
    -- A coordinate callback may itself run code. Inspect live mutable owners
    -- after reading its policy, at both resolve boundaries, before committing.
    assert(Specimen.isActiveSession(r.session) and r.session:party() == r.party,
        "stale-encounter-owner")
    assert(travelMode(r.session) == r.travelMode, "stale-encounter-travel-mode")
    assert(same(r.rules, RulesRNG._snapshotInto(rngScratch)), "stale-encounter-rng")
    assert(r.party:count() == #r.members and r.party:activeIndex() == r.roster.active,
        "stale-encounter-roster")
    for i = 1, #r.members do
        local mon = r.party:get(i)
        assert(mon == r.members[i], "stale-encounter-member")
        local record = PokemonCodec._snapshot(mon)
        assert(record and (record == r.roster.members[i] or same(r.roster.members[i], record)),
            "stale-encounter-roster")
    end
    assert(r.lead:ability() == r.ability, "stale-encounter-ability")
end
-- Slot-index preference, never species deduplication or a weighted reroll.
function FieldEncounters.electricSlots(slots)
    local out={}
    for i,slot in ipairs(slots)do local d=assert(pokemonData[slot.species]);if d.type=="electric"or d.type2=="electric"then out[#out+1]=i end end
    return out
end
local function resolveRequest(r)
    r.done = true
    local acquisitionGap
    local ok,result=pcall(function()
        current(r)
        -- Synchronous steps never publish a token. Allocate the acquisition
        -- request and receipt only in resolution, after live freshness checks.
        local specimenPlan = r.specimen or assert(Specimen.planEncounter(r.session))
        local rulesData = r.rulesData or RulesRNG.toData()
        local chosenPokemon
        local planned=RulesRNG.new(1);planned:restore(r.rules)
        local specimen,field=Specimen.rollEncounterAbilities(specimenPlan,planned)
        local receipt={version=FieldEncounters.VERSION,kind="none",reason="rate",policy="blue-tables-gen5-field-v2",ability=r.ability,
            physical_lead={species=r.lead.species,level=r.lead.level,fainted=not r.lead:isAlive(),slot=1},
            usable_lead={index=r.usable,level=r.level},rules_before=rulesData,
            zone_id=r.zone.stableID,x=r.x,y=r.y,rate=copy(r.data.rate),repel_producer="unavailable",gate_active=false}
        if affected[r.ability]then
            receipt.gate=affected[r.ability];receipt.gate_roll=planned:random(0,99);receipt.gate_active=receipt.gate_roll>=50
        else receipt.gate="none"end
        receipt.field=field
        local rate=r.data.rate
        receipt.effective_rate=FieldEncounters.effectiveRate(rate,r.ability)
        local roll=rate.kind=="byte"and planned:random(0,255)or planned:random()
        receipt.rate_roll=roll
        if roll<receipt.effective_rate then
            local candidates=r.ability==9 and receipt.gate_active and FieldEncounters.electricSlots(r.data.slots)or {}
            receipt.preferred_slots=copy(candidates)
            local index
            if #candidates>0 then
                receipt.preferred_roll=planned:random(1,#candidates);index=candidates[receipt.preferred_roll]
            else
                receipt.slot_roll=planned:random(1,r.total);local sum=0
                for i,slot in ipairs(r.data.slots)do sum=sum+slot.weight;if receipt.slot_roll<=sum then index=i;break end end
            end
            local slot=assert(r.data.slots[index]);local level=planned:random(slot.minLevel,slot.maxLevel)
            receipt.slot=index;receipt.species=slot.species;receipt.level=level
            if receipt.gate_active and(r.ability==22 or r.ability==51)and r.level>=level+5 then
                receipt.reason="ability-suppressed"
            else
                local gap <const> = Specimen.encounterGap(specimen)
                if gap then
                    acquisitionGap = {kind="field-acquisition-gap", hook=gap, ability=r.ability,
                        leadSpecies=r.lead.species, species=slot.species}
                    error("unimplemented-field-acquisition:" .. gap, 0)
                end
                local mon,creation=Specimen.create(slot.species,level,"wild",planned,specimen)
                assert(mon,creation)
                receipt.kind,receipt.reason="encounter","accepted"
                receipt.creation={version=creation.version,origin=creation.origin,draws=creation.draws,rawRolls=creation.rawRolls,
                    abilitySlot=creation.abilitySlot,natureId=creation.natureId,sex=creation.sex,sexByte=creation.sexByte,
                    heldItem=creation.heldItem,heldRoll=creation.heldRoll,heldPolicy=creation.heldPolicy,
                    individualPolicy=creation.individualPolicy,individualSource=creation.individualSource,ivs=creation.ivs,evs=creation.evs}
                chosenPokemon=mon
            end
        end
        current(r) -- Constructors cannot substitute the owner/table/continuation.
        receipt.rules_after=planned:toData()
        RulesRNG.restore(planned:snapshot())
        return {kind=receipt.kind,reason=receipt.reason,pokemon=chosenPokemon,receipt=receipt}
    end)
    clearPolicyScratch()
    if not ok then return false,tostring(result),acquisitionGap end
    return true,result
end

function FieldEncounters.resolve(token)
    local r = plans[token]
    if not r or r.done then
        return false, "stale-encounter-plan"
    end
    return resolveRequest(r)
end

local stepRequest = requestStorage()
local stepBusy = false

local function clearStepRequest()
    -- Release map/session/party references even after a failed preparation or
    -- constructor. Keep just bounded scratch arrays and the RNG scalar capture.
    stepRequest.session, stepRequest.party, stepRequest.zone = nil, nil, nil
    stepRequest.data, stepRequest.lead = nil, nil
    clearPolicyScratch()
    for i = Party.CAPACITY, 1, -1 do
        stepRequest.members[i] = nil
        stepRequest.roster.members[i] = nil
    end
    stepBusy = false
end

-- Complete one step synchronously. No reusable request token escapes. The
-- warmed ordinary preparation uses no new tables/closures; policy changes and
-- changed Pokemon still take their full validation/capture paths. Resolution
-- deliberately returns independent receipts and allocates actual encounters.
-- nil, reason means no eligible attempt; false, reason, gap means a failed one.
function FieldEncounters.attemptStep(session, party, zone, x, y)
    if stepBusy then
        return false, "encounter-step-reentry"
    end
    stepBusy = true
    local ok, ready, reason = pcall(prepareRequest, stepRequest, session, party, zone, x, y)
    if not ok or not ready then
        clearStepRequest()
        if not ok then
            return nil, tostring(ready)
        end
        return nil, reason
    end
    local ran, resolved, result, gap = pcall(resolveRequest, stepRequest)
    clearStepRequest()
    if not ran then
        return false, tostring(resolved)
    end
    return resolved, result, gap
end
