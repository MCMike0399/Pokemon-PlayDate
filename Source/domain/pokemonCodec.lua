-- Authoritative durable record for the current Pokemon model. No battle resume.
-- Import after data/pokemon, battle/moves. Caller restricts session saves to
-- outside battle; stat stages/confusion/flinch are intentionally transient.
PokemonCodec = { VERSION = 8 }
local MAX_INTEGER = 2147483647 -- Installed SDK signed-int ceiling; no float counter coercion.
local statuses = { none=true, burn=true, poison=true,badPoison=true, paralyze=true, sleep=true, freeze=true }
local fields = {acquisition=true,version=true,species=true,name=true,level=true,xp=true,hp=true,status=true,statusTurns=true,sleepDuration=true,
    moves=true,pp=true,pendingMoveChoices=true,nextMoveChoiceId=true,pendingEvolution=true,natureId=true,abilitySlot=true,heldItem=true,sex=true,sexProvenance=true,ivs=true,evs=true}
local choiceFields = {id=true,move=true,level=true,sourceOrder=true,sourceMoveId=true,reason=true}
local function integer(n, low, high)
    return type(n)=="number" and n==math.floor(n) and n>=low and n<=high
end
local function object(value, allowed)
    if type(value)~="table" or getmetatable(value)~=nil then return false end
    for key in pairs(value) do if not allowed[key] then return false end end
    return true
end
local function array(value, low, high)
    if type(value)~="table" or getmetatable(value)~=nil or #value<low or #value>high then return false end
    local count=0
    for key in pairs(value) do if not integer(key,1,#value) then return false end; count=count+1 end
    return count==#value
end
-- Keep neutral v8 records readable after parking the unreleased trade feature.
local function neutralAcquisition(value)
    if value ~= nil then
        assert(object(value, {version=true, kind=true}), "invalid-neutral-acquisition")
        assert(value.version == 1 and value.kind == "neutral", "trade-save-feature-parked")
    end
    return {version=1, kind="neutral"}
end
local function checked(record)
    assert(object(record,fields),"invalid-record-fields")
    assert(record.version==PokemonCodec.VERSION or record.version==7 or record.version==6 or record.version==5 or record.version==4 or record.version==3,"unsupported-pokemon-record-version")
    assert(type(record.species)=="string" and pokemonData[record.species],"unknown-species")
    if record.version<8 then assert(record.acquisition==nil,"legacy-acquisition-field") end
    if record.version == 8 then
        assert(type(record.acquisition) == "table", "required-acquisition-provenance")
    end
    local acquisition <const> = neutralAcquisition(record.acquisition)
    if record.version<6 then assert(record.sex==nil and record.sexProvenance==nil,"legacy-sex-fields") end
    local attributes
    if record.version==3 or record.version==4 then
        assert(record.natureId==nil and record.abilitySlot==nil and record.heldItem==nil,"legacy-specimen-fields")
        -- Deliberate unreleased legacy defaults, never historical reconstruction.
        attributes=Specimen.attributes(nil,record.species)
    else
        attributes=Specimen.attributes({natureId=record.natureId,abilitySlot=record.abilitySlot,heldItem=record.heldItem,sex=record.sex,sexProvenance=record.sexProvenance},record.species)
    end
    if record.version<6 then
        attributes.sex=Specimen.defaultSex(record.species)
        attributes.sexProvenance={version=1,kind="legacy-default"}
    else assert(type(record.sex)=="string" and type(record.sexProvenance)=="table","required-sex-fields") end
    if record.version<7 then
        assert(record.ivs==nil and record.evs==nil,"legacy-individual-fields")
        attributes.ivs,attributes.evs=IndividualStats.zero(),IndividualStats.zero()
    else
        attributes.ivs,attributes.evs=IndividualStats.normalize(record.ivs,record.evs)
    end
    if record.version==3 then assert(record.pendingEvolution==nil,"legacy-evolution-field") end
    assert(type(record.species)=="string" and pokemonData[record.species],"unknown-species")
    assert(type(record.name)=="string" and #record.name>=1 and #record.name<=10 and not record.name:find("[^ -~]"),"invalid-name")
    assert(integer(record.level,1,100),"invalid-level")
    assert(integer(record.xp,xpForLevel(record.level, record.species),xpForLevel(100, record.species)),"invalid-xp")
    assert(record.level==100 or record.xp<xpForLevel(record.level+1, record.species),"xp-level-mismatch")
    assert(integer(record.hp,0,IndividualStats.calculate(pokemonData[record.species],record.level,attributes.natureId,attributes.ivs,attributes.evs).maxHP),"invalid-hp")
    assert(statuses[record.status],"invalid-status")
    assert(integer(record.statusTurns,0,3),"invalid-status-turns")
    assert(record.status=="sleep" or record.statusTurns==0,"status-counter-mismatch")
    assert(integer(record.sleepDuration,record.status=="sleep" and 1 or 0,record.status=="sleep" and 3 or 0),"invalid-sleep-duration")
    assert(record.status~="sleep" or record.statusTurns<=record.sleepDuration,"sleep-duration-mismatch")
    assert(array(record.moves,1,4) and type(record.pp)=="table" and getmetatable(record.pp)==nil,"invalid-moves-or-pp")
    local moves, pp, known={}, {}, {}
    for i,key in ipairs(record.moves) do
        assert(type(key)=="string" and moveData[key] and not moveData[key].noPP and not known[key],"unknown-or-duplicate-move")
        assert(integer(record.pp[key],0,moveData[key].maxPP),"invalid-pp")
        moves[i],pp[key],known[key]=key,record.pp[key],true
    end
    for key in pairs(record.pp) do assert(known[key],"extra-pp-entry") end
    assert(array(record.pendingMoveChoices,0,1024),"invalid-choice-array")
    assert(integer(record.nextMoveChoiceId,1,MAX_INTEGER),"invalid-next-choice-id")
    local pending, seenMoves, lastId={}, {}, 0
    for i,choice in ipairs(record.pendingMoveChoices) do
        assert(object(choice,choiceFields) and (choice.reason=="level-up" or (record.version~=3 and choice.reason=="evolution")),"invalid-choice-record")
        assert(integer(choice.id,1,record.nextMoveChoiceId-1) and choice.id>lastId,"invalid-choice-id")
        assert(type(choice.move)=="string" and moveData[choice.move] and not seenMoves[choice.move],"unknown-or-duplicate-choice-move")
        assert(integer(choice.level,1,record.level),"invalid-choice-level")
        local found=false
        for _,entry in ipairs(pokemonData[record.species].learnset) do
            if entry.move==choice.move and entry.level==choice.level and entry.id==choice.sourceMoveId
                and entry.order==choice.sourceOrder then found=true; break end
        end
        assert(found,"choice-source-mismatch")
        pending[i]={id=choice.id,move=choice.move,level=choice.level,sourceOrder=choice.sourceOrder,
            sourceMoveId=choice.sourceMoveId,reason=choice.reason}
        seenMoves[choice.move],lastId=true,choice.id
    end
    local evolution
    if record.pendingEvolution~=nil then
        local value=record.pendingEvolution
        assert(object(value,{species=true,level=true}) and value.species==record.species
            and integer(value.level,2,100) and value.level==record.level,"invalid-pending-evolution")
        local eligible=false
        for _,rule in ipairs(EvolutionData.rules[record.species] or {}) do
            if rule.trigger=="level" and value.level>=rule.minimum then eligible=true;break end
        end
        assert(eligible,"invalid-evolution-source")
        evolution={species=value.species,level=value.level}
    end
    return {acquisition=acquisition,version=PokemonCodec.VERSION,species=record.species,name=record.name,level=record.level,xp=record.xp,hp=record.hp,
        status=record.status,statusTurns=record.statusTurns,sleepDuration=record.sleepDuration,moves=moves,pp=pp,pendingMoveChoices=pending,nextMoveChoiceId=record.nextMoveChoiceId,pendingEvolution=evolution,
        natureId=attributes.natureId,abilitySlot=attributes.abilitySlot,heldItem=attributes.heldItem,sex=attributes.sex,sexProvenance=attributes.sexProvenance,ivs=attributes.ivs,evs=attributes.evs}
end
function PokemonCodec.encode(mon)
    if type(mon)~="table" or type(mon.is)~="function" or not mon:is("Pokemon") then return nil,"invalid-pokemon" end
    local acquisition = mon.acquisition
    if acquisition == nil then
        acquisition = {version=1, kind="neutral"}
    end
    local ok,data=pcall(checked,{acquisition=acquisition,version=PokemonCodec.VERSION,species=mon.species,name=mon.name,level=mon.level,xp=mon.xp,hp=mon.hp,
        status=mon.status or "none",statusTurns=mon.statusTurns,sleepDuration=mon.sleepDuration,moves=mon.moves,pp=mon.pp,
        pendingMoveChoices=mon.pendingMoveChoices,nextMoveChoiceId=mon.nextMoveChoiceId,pendingEvolution=mon.pendingEvolution,
        natureId=mon.natureId,abilitySlot=mon.abilitySlot,heldItem=mon.heldItem,sex=mon.sex,sexProvenance=mon.sexProvenance,ivs=mon.ivs,evs=mon.evs})
    if not ok then return nil,tostring(data) end
    return data
end
function PokemonCodec.decode(record)
    local ok,data=pcall(checked,record)
    if not ok then return nil,tostring(data) end
    local created,mon=pcall(Pokemon,data.species,data.level,{natureId=data.natureId,abilitySlot=data.abilitySlot,heldItem=data.heldItem,sex=data.sex,sexProvenance=data.sexProvenance,ivs=data.ivs,evs=data.evs})
    if not created then return nil,"pokemon-construction-failed: "..tostring(mon) end
    -- Constructor derives stats/types/dex/XP threshold from current production
    -- definitions. Override durable player choices instead of re-deriving them.
    mon.name,mon.xp,mon.hp=data.name,data.xp,data.hp
    mon.status,mon.statusTurns=data.status~="none" and data.status or nil,data.statusTurns
    mon.sleepDuration=data.sleepDuration
    mon.moves,mon.pp=data.moves,data.pp
    mon.pendingMoveChoices,mon.nextMoveChoiceId=data.pendingMoveChoices,data.nextMoveChoiceId
    mon.acquisition=data.acquisition
    mon.pendingEvolution=data.pendingEvolution
    mon:resetStages()
    return mon
end
function PokemonCodec.validate(record)
    local ok,result=pcall(checked,record)
    return ok,not ok and tostring(result) or nil
end
