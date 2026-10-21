-- Durable six-stat identity. Pure validation/calculation; no reward producer/RNG.
IndividualStats={VERSION=1}
local keys <const> = {"hp","atk","def","spa","spd","spe"}
local allowed <const> = {hp=true,atk=true,def=true,spa=true,spd=true,spe=true}
local bases <const> = {hp="baseHP",atk="baseAtk",def="baseDef",spa="baseSpA",spd="baseSpD",spe="baseSpe"}
local function integer(value,low,high,label)
    local normalized=type(value)=="number" and math.tointeger(value) or nil
    assert(normalized and normalized>=low and normalized<=high,label)
    return normalized
end
local function values(value,maximum,label)
    assert(type(value)=="table" and getmetatable(value)==nil,"invalid-"..label)
    for key in pairs(value)do assert(allowed[key],"unknown-"..label.."-stat")end
    local out,total={},0
    for _,key in ipairs(keys)do out[key]=integer(value[key],0,maximum,"invalid-"..label.."-"..key);total=total+out[key]end
    return out,total
end
function IndividualStats.zero()return {hp=0,atk=0,def=0,spa=0,spd=0,spe=0}end
function IndividualStats.normalize(ivs,evs)
    local iv=values(ivs,31,"ivs")
    local ev,total=values(evs,255,"evs");assert(total<=510,"invalid-ev-total")
    return iv,ev
end
function IndividualStats.calculate(data,level,nature,ivs,evs)
    local iv,ev=IndividualStats.normalize(ivs,evs)
    integer(level,1,100,"invalid-individual-level")
    integer(nature,0,24,"invalid-individual-nature")
    assert(type(data)=="table","invalid-individual-species")
    local out={}
    for _,key in ipairs(keys)do
        local base=integer(data[bases[key]],1,255,"invalid-individual-base")
        local scaled=((2*base+iv[key]+ev[key]//4)*level)//100
        if key=="hp"then out.maxHP=scaled+level+10
        else out[key]=Specimen.stat(scaled+5,nature,key)end
    end
    return out
end
function IndividualStats.hpAfterRecalc(hp,oldMax,newMax)
    integer(oldMax,0,1000,"invalid-old-max-hp");integer(newMax,1,1000,"invalid-new-max-hp")
    integer(hp,0,oldMax,"invalid-old-hp")
    if oldMax==0 then return newMax end
    if hp==0 then return 0 end
    if newMax<oldMax then return math.min(hp,newMax)end
    return hp+(newMax-oldMax)
end
-- Explicit Blue fixed-DV individual contribution, not native B2W2 difficulty.
function IndividualStats.blueTrainer()return {hp=16,atk=18,def=16,spa=16,spd=16,spe=16}end
function IndividualStats.yieldFor(dex)
    integer(dex,1,151,"invalid-yield-species")
    local row=assert(IndividualData.yields[dex],"missing-effort-yield")
    local out={};for i,key in ipairs(keys)do out[key]=row[i]end;return out
end

-- Pure native-order bounded addition. Combat owns when/whom to award; this
-- helper neither infers rewards nor introduces unavailable item/virus state.
function IndividualStats.addEffort(evs,yield)
    local _,ev=IndividualStats.normalize(IndividualStats.zero(),evs)
    local amount=values(yield,3,"effort-yield")
    local room=510
    for _,key in ipairs(keys)do room=room-ev[key]end
    local delta,wasted={},{}
    for _,key in ipairs({"hp","atk","def","spe","spa","spd"})do
        local added=math.min(amount[key],255-ev[key],room)
        ev[key]=ev[key]+added;delta[key]=added;wasted[key]=amount[key]-added;room=room-added
    end
    return ev,delta,wasted
end
