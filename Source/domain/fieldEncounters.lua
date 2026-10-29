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
    for key in pairs(value)do assert(fields[key],"unknown encounter descriptor field: "..tostring(key))end
end
local function roster(party)
    local result = {active=party:activeIndex(), members={}}
    for i, mon in ipairs(party:members()) do
        -- These private snapshots are immutable and replaced after a change.
        -- Keeping their references avoids copying every move and trait per step.
        result.members[i] = assert(PokemonCodec._snapshot(mon))
    end
    return result
end
local function policy(zone,x,y)
    local data,reason=Zone._readEncounterPolicyAt(zone,x,y)
    if not data then return nil,reason end
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
function FieldEncounters.prepare(context)
    local ok,plan,reason=pcall(function()
        assert(type(context)=="table"and getmetatable(context)==nil,"explicit encounter context required")
        for key in pairs(context)do assert(key=="session"or key=="party"or key=="zone"or key=="x"or key=="y","unknown encounter context")end
        local session,party,zone=context.session,context.party,context.zone
        assert(Specimen.isActiveSession(session),"inactive-encounter-session")
        assert(party==session:party(),"foreign-encounter-party")
        local usable=party:firstUsable();if not usable then return nil,"no-usable-party"end
        assert(type(zone)=="table"and type(zone.is)=="function"and zone:is("Zone"),"encounter Zone required")
        local data,total=policy(zone,context.x,context.y);if not data then return nil,total end
        -- Never retain the borrowed live policy, including callback results.
        local captured = capturePolicy(data)
        local members=party:members();local lead=assert(members[1]);local ability=lead:ability()
        local token={};plans[token]={session=session,party=party,zone=zone,x=context.x,y=context.y,data=captured,total=total,
            members=members,roster=roster(party),lead=lead,ability=ability,usable=usable,level=party:get(usable).level,
            rules=RulesRNG.snapshot(),rulesData=RulesRNG.toData(),specimen=assert(Specimen.planEncounter(session)),done=false}
        return token
    end)
    if not ok then return nil,tostring(plan)end
    return plan,reason
end
local function current(r)
    assert(Specimen.isActiveSession(r.session)and r.session:party()==r.party,"stale-encounter-owner")
    assert(same(r.rules,RulesRNG.snapshot()),"stale-encounter-rng")
    local members = r.party:members()
    assert(#members == #r.members and r.party:activeIndex() == r.roster.active, "stale-encounter-roster")
    for i, mon in ipairs(members) do
        assert(mon == r.members[i], "stale-encounter-member")
        local record = PokemonCodec._snapshot(mon)
        assert(record and (record == r.roster.members[i] or same(r.roster.members[i], record)),
            "stale-encounter-roster")
    end
    local data,total=policy(r.zone,r.x,r.y)
    assert(data and total==r.total and same(data,r.data),"stale-encounter-table-or-terrain")
end
-- Slot-index preference, never species deduplication or a weighted reroll.
function FieldEncounters.electricSlots(slots)
    local out={}
    for i,slot in ipairs(slots)do local d=assert(pokemonData[slot.species]);if d.type=="electric"or d.type2=="electric"then out[#out+1]=i end end
    return out
end
function FieldEncounters.resolve(token)
    local r=plans[token]
    if not r or r.done then return false,"stale-encounter-plan"end
    r.done=true
    local acquisitionGap
    local ok,result=pcall(function()
        current(r)
        local chosenPokemon
        local planned=RulesRNG.new(1);planned:restore(r.rules)
        local specimen,field=Specimen.rollEncounterAbilities(r.specimen,planned)
        local receipt={version=FieldEncounters.VERSION,kind="none",reason="rate",policy="blue-tables-gen5-field-v2",ability=r.ability,
            physical_lead={species=r.lead.species,level=r.lead.level,fainted=not r.lead:isAlive(),slot=1},
            usable_lead={index=r.usable,level=r.level},rules_before=r.rulesData,
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
    if not ok then return false,tostring(result),acquisitionGap end
    return true,result
end
