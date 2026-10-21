-- Pure durable attributes and explicit creation. No battle effects/availability.
Specimen={CREATION_VERSION=2}
local slots={first=true,second=true,hidden=true}
local origins={wild=true,starter=true,trainer=true,gift=true,debug=true}
local function object(value,allowed)
    assert(type(value)=="table" and getmetatable(value)==nil,"invalid-specimen-attributes")
    for key in pairs(value) do assert(allowed[key],"unknown-specimen-attribute: "..tostring(key)) end
end
local function integer(value,low,high)
    local n=type(value)=="number" and math.tointeger(value) or nil
    assert(n and n>=low and n<=high,"invalid-sex-byte")
    return n
end
function Specimen.sex(species,byte)
    local ratio=assert(SpecimenTraits.ratios[species],"unknown-species-sex-ratio")
    byte=integer(byte,0,255)
    if ratio==255 then return "genderless" elseif ratio==254 then return "female" elseif ratio==0 then return "male" end
    return byte<ratio and "female" or "male"
end
function Specimen.defaultSex(species)
    local ratio=assert(SpecimenTraits.ratios[species],"unknown-species-sex-ratio")
    if ratio==255 then return "genderless" end
    return ratio>127 and "female" or "male"
end
function Specimen.sexAttributes(species,sex,provenance)
    local ratio=assert(SpecimenTraits.ratios[species],"unknown-species-sex-ratio")
    assert(sex=="male" or sex=="female" or sex=="genderless","invalid-sex")
    assert((ratio==255 and sex=="genderless") or (ratio==254 and sex=="female")
        or (ratio==0 and sex=="male") or (ratio>0 and ratio<254 and sex~="genderless"),"species-sex-mismatch")
    object(provenance,{version=true,kind=true,protocol=true,origin=true,byte=true})
    assert(provenance.version==1,"unsupported-sex-provenance")
    local kind=provenance.kind
    if kind=="generated" then
        assert(provenance.protocol==2 and origins[provenance.origin],"invalid-generated-sex-provenance")
        local byte=integer(provenance.byte,0,255)
        assert(Specimen.sex(species,byte)==sex,"sex-byte-mismatch")
        return sex,{version=1,kind=kind,protocol=2,origin=provenance.origin,byte=byte}
    end
    assert(kind=="constructor-default" or kind=="legacy-default" or kind=="explicit","invalid-sex-provenance-kind")
    assert(provenance.protocol==nil and provenance.origin==nil and provenance.byte==nil,"fabricated-sex-history")
    if kind~="explicit" then assert(sex==Specimen.defaultSex(species),"sex-default-mismatch") end
    return sex,{version=1,kind=kind}
end
function Specimen.attributes(attributes,species)
    if attributes==nil then attributes={natureId=0,abilitySlot="first",heldItem="none"} end
    object(attributes,{natureId=true,abilitySlot=true,heldItem=true,sex=true,sexProvenance=true})
    local nature=type(attributes.natureId)=="number" and math.tointeger(attributes.natureId) or nil
    assert(nature and SpecimenData.natures[nature],"invalid-nature")
    assert(slots[attributes.abilitySlot],"invalid-ability-slot")
    local held=attributes.heldItem
    assert(held=="none" or type(held)=="string" and SpecimenData.holdable[held],"invalid-or-nonholdable-item")
    local sex=attributes.sex
    local provenance=attributes.sexProvenance
    if sex==nil then
        assert(provenance==nil,"sex-required-with-provenance")
        sex,provenance=Specimen.defaultSex(species),{version=1,kind="constructor-default"}
    elseif provenance==nil then provenance={version=1,kind="explicit"} end
    sex,provenance=Specimen.sexAttributes(species,sex,provenance)
    return {natureId=nature,abilitySlot=attributes.abilitySlot,heldItem=held,sex=sex,sexProvenance=provenance}
end
local encounters=setmetatable({},{__mode="k"})
local function encounterInfo(token)
    local value=encounters[token]
    assert(value and Specimen.isActiveSession(value.session),"stale-encounter-owner")
    assert(value.session:party()==value.party and value.party:get(1)==value.lead
        and value.lead.species==value.species and value.lead.abilitySlot==value.slot
        and value.lead:ability()==value.ability,"stale-encounter-lead")
    assert(PokemonCodec.encode(value.lead),"invalid-encounter-lead")
    local now=RulesRNG.snapshot()
    for _,key in ipairs({"algorithm","seed","state","rolls"}) do assert(now[key]==value.rules[key],"stale-encounter-rng") end
    return value
end
-- Physical slot1 includes a fainted lead (B2W2 encounter manager semantics).
-- A token contains no public facts that a caller can substitute or mutate.
function Specimen.planEncounter(session)
    local ok,token=pcall(function()
        assert(Specimen.isActiveSession(session),"inactive-encounter-session")
        local party=session:party();local lead=assert(party:get(1),"missing-encounter-lead")
        assert(PokemonCodec.encode(lead),"invalid-encounter-lead")
        local token={};encounters[token]={session=session,party=party,lead=lead,species=lead.species,
            slot=lead.abilitySlot,ability=lead:ability(),rules=RulesRNG.snapshot()};return token
    end)
    if not ok then return nil,tostring(token) end
    return token
end
-- Only Pikachu's current ordinary acquisition is enabled. Other native held
-- rows remain explicitly pending; no invented rates/items are used for them.
function Specimen.ordinaryPikachuItem(roll,compoundEyes)
    roll=integer(roll,0,99)
    assert(compoundEyes==nil or type(compoundEyes)=="boolean","invalid-held-policy")
    local low,high=compoundEyes and 60 or 50,compoundEyes and 79 or 54
    return roll>=low and roll<=high and "lightBall" or "none"
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
-- Normal origins never roll hidden. Detached samples: normal slot, nature,
-- sex byte; ordinary wild Pikachu alone then samples its approved held policy.
-- Species/level/chance draws preceding this call are outside this transaction.
function Specimen.create(species,level,origin,rng,encounter)
    local ok,mon,receipt=pcall(function()
        assert(type(species)=="string" and pokemonData[species],"unknown-species")
        local normalized=type(level)=="number" and math.tointeger(level) or nil
        assert(normalized and normalized>=1 and normalized<=100,"invalid-specimen-level")
        assert(type(origin)=="string" and origins[origin],"invalid-specimen-origin")
        assert(encounter==nil or origin=="wild","unexpected-encounter-context")
        local context=encounter~=nil and encounterInfo(encounter) or nil
        local compound=context~=nil and context.ability==14
        local before=readRNG(rng)
        local planned=RulesRNG.new(1);planned:restore(before)
        local slot=planned:random(1,2)==1 and "first" or "second"
        local nature=planned:random(0,24)
        local byte=planned:random(0,255)
        local sex=Specimen.sex(species,byte)
        local held,heldRoll,draws="none",nil,3
        if origin=="wild" and species=="pikachu" then
            assert(SpecimenData.holdable.lightBall==236 and ItemData and ItemData.definitions.lightBall
                and ItemData.definitions.lightBall.gen5Id==236,"missing-Light-Ball-acquisition-definition")
            heldRoll=planned:random(0,99);draws=4;held=Specimen.ordinaryPikachuItem(heldRoll,compound)
        end
        local created=Pokemon(species,normalized,{natureId=nature,abilitySlot=slot,heldItem=held,sex=sex,
            sexProvenance={version=1,kind="generated",protocol=2,origin=origin,byte=byte}})
        local after=planned:snapshot()
        local result={version=Specimen.CREATION_VERSION,origin=origin,draws=draws,abilitySlot=slot,natureId=nature,sex=sex,sexByte=byte,heldItem=held,heldRoll=heldRoll,heldPolicy=origin=="wild" and (compound and "compound-eyes" or "ordinary") or "none",
            rngBefore=before,rngAfter=after,rawRolls=after.rolls-before.rolls}
        if encounter~=nil then encounterInfo(encounter) end
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
    local encounter
    if origin=="wild" then
        local why;encounter,why=Specimen.planEncounter(session)
        if not encounter then return nil,why end
    end
    return Specimen.create(species,level,origin,RulesRNG,encounter)
end
