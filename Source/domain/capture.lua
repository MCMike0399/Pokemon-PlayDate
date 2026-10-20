-- Gen V ordinary-wild capture rules; no bag/battle/recruitment ownership.
-- Imports required: data/captureData, data/pokemon, lib/rng.
Capture = {}
local SCALE <const> = 4096
local MAX_RATE <const> = 1044480 -- 255 *4096
local balls = {pokeBall=2,greatBall=3,ultraBall=4,masterBall=0} -- half units
local types = {normal=true,fire=true,water=true,electric=true,grass=true,ice=true,fighting=true,
    poison=true,ground=true,flying=true,psychic=true,bug=true,rock=true,ghost=true,dragon=true,dark=true,steel=true}
local statusBonus = {burn=3,poison=3,paralyze=3,sleep=5,freeze=5} -- half units
local function integer(value,low,high)
    local n=type(value)=="number" and math.tointeger(value) or nil
    return n and n>=low and n<=high and n or nil
end
-- Exact quotient and remainder of a*b/d, without wide int products or floats.
-- Call-site bounds keep quotient <=2^28 and every remainder intermediate <2^29.
local function multiplyDivide(a,b,d)
    local q,r,bit=0,0,1
    while bit<=b//2 do bit=bit*2 end
    while bit>0 do
        q=q*2;r=r*2
        if b//bit%2==1 then r=r+a end
        q=q+r//d;r=r%d;bit=bit//2
    end
    return q,r
end
local function roundedDivide(a,b,d)
    local q,r=multiplyDivide(a,b,d)
    return q+(r*2>=d and 1 or 0)
end
-- round(sqrt(n/4096)*4096). Compare via division, never square a 16-bit
-- root into signed overflow. Integer remainder decides nearest, half up.
local function sqrtQ12(n)
    local low,high,root=1,65536,0
    while low<=high do
        local mid=(low+high)//2
        if mid<=multiplyDivide(n,SCALE,mid) then root=mid;low=mid+1 else high=mid-1 end
    end
    local quotient,remainder=multiplyDivide(n,SCALE,root)
    local difference=root*(quotient-root)+remainder
    if difference>root then root=root+1 end
    return root
end
local function checked(context,ballId,caughtCount)
    if type(context)~="table" or getmetatable(context)~=nil then return nil,"invalid-capture-context" end
    for key in pairs(context) do
        if key~="pokemon" and key~="wild" and key~="terrain" and key~="capturePower" then return nil,"unsupported-capture-context" end
    end
    if context.wild~=true then return nil,"not-wild-target" end
    if (context.terrain~=nil and context.terrain~="ordinary") or (context.capturePower~=nil and context.capturePower~=100) then return nil,"unsupported-capture-context" end
    local mon=context.pokemon
    if type(mon)~="table" or type(mon.is)~="function" or not mon:is("Pokemon") then return nil,"invalid-pokemon" end
    local data=pokemonData[mon.species]
    if not data or mon.dex~=data.dex or not integer(mon.level,1,100) or not types[mon.type]
        or (mon.type2~=nil and not types[mon.type2]) then return nil,"invalid-pokemon" end
    local maxHP=integer(mon.maxHP,1,65535)
    local hp=maxHP and integer(mon.hp,1,maxHP)
    if not hp then return nil,"invalid-target-hp" end
    if (mon.status~=nil and not statusBonus[mon.status]) or not integer(mon.statusTurns,0,3)
        or (mon.status~="sleep" and mon.statusTurns~=0) then return nil,"invalid-target-status" end
    local duration=integer(mon.sleepDuration,mon.status=="sleep" and 1 or 0,mon.status=="sleep" and 3 or 0)
    if duration==nil or (mon.status=="sleep" and mon.statusTurns>duration) then return nil,"invalid-target-status" end
    if type(ballId)~="string" or balls[ballId]==nil then return nil,"unsupported-ball" end
    caughtCount=integer(caughtCount,0,151)
    if not caughtCount then return nil,"invalid-caught-count" end
    local catchRate=CaptureData[data.dex]
    assert(integer(catchRate,1,255),"missing B2W2 catch rate")
    return {mon=mon,hp=hp,maxHP=maxHP,catchRate=catchRate,ball=balls[ballId],caughtCount=caughtCount}
end
local function values(input)
    -- Normal terrain G=1 and no Capture Power E=100. Both half-unit ball
    -- bonuses are exact Q12 values, leaving the HP division as the first floor.
    local numerator=(3*input.maxHP-2*input.hp)*input.catchRate*input.ball
    local denominator=6*input.maxHP
    local a=(numerator//denominator)*SCALE+(numerator%denominator)*SCALE//denominator
    a=(a*(statusBonus[input.mon.status] or 2)+1)//2 -- nearest Q12, half up
    a=math.min(a,MAX_RATE)
    if a>=MAX_RATE then return a,65536,0 end
    local ratio=roundedDivide(MAX_RATE,SCALE,a)
    local root=sqrtQ12(sqrtQ12(ratio))
    local threshold=roundedDivide(268435456,SCALE,root)//SCALE -- floor(round(65536/rootReal))
    local p=input.caughtCount>150 and 2 or (input.caughtCount>30 and 1 or 0)
    local scaledCritical=(a*p+1)//2
    scaledCritical=(scaledCritical+3)//6
    return a,threshold,scaledCritical//SCALE
end
-- Pure numeric preview, useful to diagnostics/UI and independent expected vectors.
function Capture.parameters(enemyContext,ballId,caughtCount)
    local input,problem=checked(enemyContext,ballId,caughtCount)
    if not input then return nil,problem end
    if ballId=="masterBall" then return {catchRate=input.catchRate,modifiedRate4096=MAX_RATE,
        shakeThreshold=65536,criticalThreshold=0,guaranteed=true,guarantee="master-ball"} end
    local a,y,cc=values(input)
    return {catchRate=input.catchRate,modifiedRate4096=a,shakeThreshold=y,criticalThreshold=cc,
        guaranteed=a>=MAX_RATE,guarantee=a>=MAX_RATE and "modified-rate" or nil}
end
-- rng is an actual RulesRNG stream (or RulesRNG's active global stream facade).
-- Trial on a local stream first, so counter exhaustion cannot partially advance
-- the caller. Invalid context/arguments never even inspect the RNG.
function Capture.attempt(enemyContext,ballId,caughtCount,rng)
    local result,problem=Capture.parameters(enemyContext,ballId,caughtCount)
    if not result then return nil,problem end
    if type(rng)~="table" or type(rng.snapshot)~="function" or type(rng.restore)~="function" or type(rng.random)~="function" then return nil,"invalid-rng" end
    local global=rng==RulesRNG
    local ok,before=pcall(function() return global and rng.snapshot() or rng:snapshot() end)
    if not ok then return nil,"invalid-rng" end
    local working=RulesRNG.new(1)
    if not pcall(working.restore,working,before) then return nil,"invalid-rng" end
    result.ballId=ballId;result.critical=false;result.caught=true
    result.shakeRolls={};result.checks=0;result.successfulChecks=0;result.rngRolls=0;result.randomCalls=0
    result.displayShakes=3
    if result.guaranteed then return result end
    ok,problem=pcall(function()
        -- Always test critical once, even when its threshold is0. The project's
        -- replay cadence is explicit; this is not a cartridge PRNG clone.
        result.criticalRoll=working:random(0,255)
        result.critical=result.criticalRoll<result.criticalThreshold
        local needed=result.critical and 1 or 3
        for check=1,needed do
            local roll=working:random(0,65535)
            result.shakeRolls[#result.shakeRolls+1]=roll;result.checks=check
            if roll>=result.shakeThreshold then result.caught=false;break end
            result.successfulChecks=result.successfulChecks+1
        end
    end)
    if not ok then
        if tostring(problem):find("RNG roll counter exhausted",1,true) then return nil,"rng-exhausted" end
        error(problem) -- Surface unexpected production RNG defects with detail.
    end
    local after=working:snapshot()
    result.rngRolls=after.rolls-before.rolls
    result.randomCalls=1+result.checks
    if result.critical then result.displayShakes=1
    elseif not result.caught then result.displayShakes=({[1]=0,[2]=1,[3]=3})[result.checks] end
    if global then rng.restore(after) else rng:restore(after) end
    return result
end
