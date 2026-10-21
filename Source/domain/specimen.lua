-- Pure durable attributes and explicit creation. No battle effects/availability.
Specimen={CREATION_VERSION=1}
local slots={first=true,second=true,hidden=true}
local origins={wild=true,starter=true,trainer=true,gift=true,debug=true}
local function object(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"invalid-specimen-attributes")
    for key in pairs(value) do assert(allowed[key],"unknown-specimen-attribute: "..tostring(key)) end
end
function Specimen.attributes(attributes)
    if attributes==nil then return {natureId=0,abilitySlot="first",heldItem="none"} end
    object(attributes,{natureId=true,abilitySlot=true,heldItem=true})
    local nature=type(attributes.natureId)=="number" and math.tointeger(attributes.natureId) or nil
    assert(nature and SpecimenData.natures[nature],"invalid-nature")
    assert(slots[attributes.abilitySlot],"invalid-ability-slot")
    local held=attributes.heldItem
    assert(held=="none" or type(held)=="string" and SpecimenData.holdable[held],"invalid-or-nonholdable-item")
    return {natureId=nature,abilitySlot=attributes.abilitySlot,heldItem=held}
end
function Specimen.ability(species,slot)
    local data=assert(pokemonData[species],"unknown-species")
    assert(slots[slot],"invalid-ability-slot")
    return assert(SpecimenData.slots[data.dex][slot],"missing-species-ability")
end
function Specimen.stat(value,nature,stat)
    local row=assert(SpecimenData.natures[nature],"invalid-nature")
    local sign=assert(row[stat],"invalid-nature-stat")
    if sign==1 then return value*110//100 elseif sign==-1 then return value*90//100 end
    return value
end
local function readRNG(rng)
    assert(type(rng)=="table" and type(rng.snapshot)=="function" and type(rng.restore)=="function","invalid-specimen-rng")
    return rng==RulesRNG and rng.snapshot() or rng:snapshot()
end
local function writeRNG(rng,value)
    if rng==RulesRNG then rng.restore(value) else rng:restore(value) end
end
-- Normal origins deliberately never roll hidden. Two draws on a detached stream:
-- normal slot preference (even equal IDs), then independently stored nature.
-- Species/level/chance draws preceding this call are outside this transaction.
function Specimen.create(species,level,origin,rng)
    local ok,mon,receipt=pcall(function()
        assert(type(species)=="string" and pokemonData[species],"unknown-species")
        local normalized=type(level)=="number" and math.tointeger(level) or nil
        assert(normalized and normalized>=1 and normalized<=100,"invalid-specimen-level")
        assert(type(origin)=="string" and origins[origin],"invalid-specimen-origin")
        local before=readRNG(rng)
        local planned=RulesRNG.new(1);planned:restore(before)
        local slot=planned:random(1,2)==1 and "first" or "second"
        local nature=planned:random(0,24)
        local created=Pokemon(species,normalized,{natureId=nature,abilitySlot=slot,heldItem="none"})
        local after=planned:snapshot()
        local result={version=Specimen.CREATION_VERSION,origin=origin,draws=2,abilitySlot=slot,natureId=nature,
            rngBefore=before,rngAfter=after,rawRolls=after.rolls-before.rolls}
        writeRNG(rng,after) -- Pure construction/validation succeeded; commit continuation once.
        return created,result
    end)
    if not ok then return nil,tostring(mon) end
    return mon,receipt
end

-- Actor/controller creation must own the active global rules stream. The
-- low-level explicit-stream factory above remains independent for samplers/tests.
function Specimen.isActiveSession(session)
    return session~=nil and GameSession~=nil and GameSession._state(session)~=nil
        and GameSession.activeRNGSession()==session
end
function Specimen.createForSession(session,species,level,origin)
    if not Specimen.isActiveSession(session) then return nil,"inactive-specimen-session" end
    return Specimen.create(species,level,origin,RulesRNG)
end
