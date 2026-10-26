-- Gen V ability hooks owned by one actual Battle. No persistent volatile state.
Class("BattleEffects")
local function has(owner,mon,t) return owner.battle:hasType(mon,t) end
local function nativeAbility(mon) return mon and mon.ability and mon:ability() or 0 end
local function alive(mon) return mon and mon:isAlive() end
local function round(value,ratio) return (value*ratio+2047)//4096 end -- half down
local function chain(value,ratio) return (value*ratio+2048)//4096 end -- FX_Mul
BattleEffects.fixedRound=round
BattleEffects.chain=chain
local handlers={}
local function lowHP(t)
    return {attack=function(_,mon,move,value)
        if mon.hp<=mon.maxHP//3 and move.type==t then return round(value,6144) end
        return value
    end}
end
handlers[65],handlers[66],handlers[67],handlers[68]=lowHP("grass"),lowHP("fire"),lowHP("water"),lowHP("bug")
handlers[62]={attack=function(_,mon,move,value)
    if mon.status and move.category=="physical" then return round(value,6144) end
    return value
end}
handlers[14]={accuracy=function() return 5325 end}
handlers[77]={evasion=function(_,mon) return mon.confusion and 2048 or 4096 end}
handlers[8]={evasion=function(owner) return owner:weatherId()=="sandstorm" and 3277 or 4096 end}
handlers[5],handlers[9],handlers[19],handlers[50],handlers[51],handlers[61],handlers[69],handlers[71]={},{},{},{},{},{},{},{}
-- Captivate-only Oblivious dependency; Attract producer remains explicitly pending.
handlers[12],handlers[17],handlers[38],handlers[79]={},{},{},{}
handlers[20],handlers[15]={},{}
handlers[39],handlers[87]={},{}
function BattleEffects:init(battle)
    self.battle=battle;self.weather=nil;self.receipts=setmetatable({},{__mode="k"});self.closed=false;self.round=nil;self.abilityOverrides={}
end
-- Volatile identity-keyed ability changes never alter specimen slots/provenance.
function BattleEffects:effectiveAbility(mon)
    local override=self:active(mon) and self.abilityOverrides[mon]
    return override or nativeAbility(mon)
end
function BattleEffects:worrySeedAttempt(source,target)
    if not self:active(source) or not self:active(target) or source==target
        or not alive(source) or not alive(target) then return false,"stale-ability-target" end
    local id=self:effectiveAbility(target)
    if type(id)~="number" or not math.tointeger(id) or id<1 or id>164 then return false,"unsupported-ability" end
    if id==15 or id==54 then return false,"unchangeable-ability" end
    return true
end
function BattleEffects:worrySeed(source,target)
    local allowed,reason=self:worrySeedAttempt(source,target)
    if not allowed then return false,reason end
    -- GenV Multitype is checked after accuracy, at the actual ability-change hit.
    if self:effectiveAbility(target)==121 then return false,"unchangeable-ability" end
    local wake=target.status=="sleep"
    self.abilityOverrides[target]=15
    -- Commit the persistent cure before any presentation yield/cancellation.
    if wake then target.status,target.statusTurns,target.sleepDuration=nil,0,0 end
    self.battle:say(target.name.." acquired Insomnia!")
    if wake then self.battle:say(target.name.." woke up with Insomnia!") end
    return true
end
-- Each ID below has a concrete callback below; this is dispatch inventory,
-- never a blanket mechanics-acceptance claim.
local commonHooks = {
    [22]="entry", [108]="entry", [72]="statusImmunity", [41]="statusImmunity",
    [99]="accuracyBypassesCheck", [75]="criticalAllowed", [92]="multiHitMaximum",
    [97]="finalDamage", [43]="canAttempt",
}
function BattleEffects:supported(id) return handlers[id]~=nil or commonHooks[id]~=nil end
function BattleEffects:livingAbility(mon,id)
    return self:active(mon) and alive(mon) and self:effectiveAbility(mon)==id
end
function BattleEffects:active(mon) return not self.closed and (self.battle.player==mon or self.battle.enemy==mon) end
local critDenominators <const> = {[0]=16,[1]=8,[2]=4,[3]=3,[4]=2}
function BattleEffects.criticalDenominator(stage)
    return critDenominators[math.max(0,math.min(4,stage))]
end
function BattleEffects:criticalStage(mon,move)
    local state=self.battle.conditions.members[mon]
    return math.max(0,math.min(4,(move.critStage or 0)+(state and state.focusEnergy and 2 or 0)))
end

-- Rain makes declared weather-sensitive attacks always hit, independently of
-- accuracy/evasion/CompoundEyes/SandVeil; immunity still precedes this query.
function BattleEffects:accuracyBypassesCheck(move,attacker,defender)
    attacker,defender=attacker or self.battle.attacker,defender or self.battle.defender
    return (move.weatherAccuracy==true and self:weatherId()=="raindance")
        or self:livingAbility(attacker,99) or self:livingAbility(defender,99)
end
-- CriticalHit runs AFTER the critical trial, including guaranteed criticals.
-- Shell Armor changes the result, never the number of critical RNG trials.
function BattleEffects:criticalAllowed(target)
    return not self:livingAbility(target,75)
end
function BattleEffects:multiHitMaximum(source,move)
    if move.minHits and move.maxHits and self:livingAbility(source,92) then return move.maxHits end
end
-- Sniper is a final damage modifier after burn/minimum1, not a crit multiplier
-- before random/STAB/type flooring. Critical hits already ignore Light Screen.
function BattleEffects:finalDamage(source,damage,critical)
    if critical and self:livingAbility(source,97) then return round(damage,6144) end
    return damage
end
function BattleEffects:accuracy(attacker,defender,move)
    local ratio=4096;local a,d=handlers[self:effectiveAbility(attacker)],handlers[self:effectiveAbility(defender)]
    if a and a.accuracy then ratio=chain(ratio,a.accuracy(self,attacker)) end
    if d and d.evasion then ratio=chain(ratio,d.evasion(self,defender)) end
    local base=move.weatherAccuracy and self:weatherId()=="sunnyday" and 50 or move.accuracy
    return round(base,ratio)
end
-- One logical round, retained while the production script yields for learning.
-- Identity keys prevent a replacement from inheriting the outgoing action/damage.
function BattleEffects:beginRound(turns)
    local round={pending={},damaged={}}
    for _,turn in ipairs(turns or {}) do
        local mon=turn.actor
        assert(mon and mon==self.battle[turn.side],"actual pending actor required")
        round.pending[mon]={turn=turn,move=turn.move}
    end
    self.round=round
end
function BattleEffects:endRound() self.round=nil end
function BattleEffects:beginAction(turn,mon)
    local pending=self.round and self.round.pending[mon]
    if pending and pending.turn==turn then self.round.pending[mon]=nil end
end
function BattleEffects:pendingMove(mon)
    local pending=self.round and self.round.pending[mon]
    return self:active(mon) and alive(mon) and pending and pending.move or nil
end
function BattleEffects:damagedThisRound(mon)
    return self.round~=nil and self.round.damaged[mon]==true
end
-- All enabled HP-loss producers pass through this owner. HP payments and
-- Struggle recoil are directDamage provenance, not Assurance's hurtThisTurn.
function BattleEffects:damage(mon,amount,cause)
    local before=mon.hp
    mon:takeDamage(amount)
    local removed=before-mon.hp
    if self.round and removed>0 and cause~="cost" and cause~="struggle-recoil" then
        self.round.damaged[mon]=true
    end
    return removed
end
-- Pinned Gen5 sound flags, projected onto the actual generated move identities.
-- Sonic Boom is deliberately absent. Unsupported moves still fail at their own
-- dispatch gate; this guard is shared by all currently executable sound moves.
local soundMoves = {
    growl=true, roar=true, sing=true, supersonic=true, screech=true, snore=true,
    uproar=true, metalSound=true, hyperVoice=true, bugBuzz=true, round=true,
    perishSong=true,
}
function BattleEffects:canAttempt(move,attacker,defender)
    local key=self.battle.currentMoveKey
    if self:active(attacker) and alive(attacker)
        and self:livingAbility(defender,43) and soundMoves[key] and moveData[key]==move then
        return false, "soundproof"
    end
    if move.attemptRule=="worrySeed" then return self:worrySeedAttempt(attacker,defender) end
    if move.attemptRule=="oppositeSex" then
        -- GenV TryHit ability immunity precedes move-specific sex immunity.
        if self:effectiveAbility(defender)==12 then return false,"oblivious" end
        local a,d=attacker:getSex(),defender:getSex()
        if a=="genderless" or d=="genderless" or a==d then return false,"sex" end
    end
    if move.attemptRule=="singlesRedirect" then return false end
    if move.attemptRule=="suckerPunch" then
        local pending=self:pendingMove(defender)
        if not pending or pending.category=="status" then return false end
    end
    if move.damageRule=="endeavor" and attacker.hp>=defender.hp then return false end
    return true
end
function BattleEffects:fixedDamage(move,attacker,defender)
    if move.damageRule=="endeavor" then return defender.hp-attacker.hp end
end
-- Gen V TryHit: after type immunity/Protect, before accuracy and damage RNG.
-- An absorbed hit creates no direct-hit receipt, secondaries or contact event.
function BattleEffects:absorbsWater(source,target,move)
    if source==target or not self:active(source) or not self:active(target)
        or not alive(source) or not alive(target) or move.type~="water"
        or self:effectiveAbility(target)~=87 then return false end
    target:heal(math.max(1,target.maxHP//4))
    self.battle:say(target.name.." absorbed the water with Dry Skin!")
    return true
end
-- Move-defined power precedes conditional field modifiers (e.g. Mud Sport).
function BattleEffects:movePower(move,power,attacker,defender)
    if move.powerRule=="electroBall" then
        local ratio=self.battle:effectiveSpeed(attacker)//math.max(1,self.battle:effectiveSpeed(defender))
        return ({[0]=40,60,80,120,150})[math.min(4,ratio)]
    end
    if move.powerRule=="assurance" and self:damagedThisRound(defender) then return power*2 end
    return power
end
-- Canonical GenV query seam. Only Sand has a current producer; other IDs
-- are policy inputs for future real weather owners, not new acquisition.
function BattleEffects:weatherId()
    return self.weather and (self.weather.id or "sandstorm") or "none"
end
function BattleEffects.solarPolicy(weather)
    assert(weather=="none" or weather=="sunnyday" or weather=="raindance"
        or weather=="sandstorm" or weather=="hail","unsupported-GenV-weather")
    local weak=weather=="raindance" or weather=="sandstorm" or weather=="hail"
    return weather=="sunnyday",weak and 2048 or 4096
end
function BattleEffects:basePower(move,power,attacker,defender)
    attacker,defender=attacker or self.battle.attacker,defender or self.battle.defender
    local ratio=4096
    if power>0 and attacker and defender and self:effectiveAbility(attacker)==79 then
        local a,d=attacker:getSex(),defender:getSex()
        if a~="genderless" and d~="genderless" then ratio=chain(ratio,a==d and 5120 or 3072) end
    end
    -- Pinned PS Gen5 BasePower priorities: Rivalry24, Dry Skin17, Mud Sport1,
    -- Solar Beam0. Chain Q12 ratios first, then round the raw power once.
    if power>0 and move.type=="fire" and self:active(defender) and alive(defender)
        and self:effectiveAbility(defender)==87 then ratio=chain(ratio,5120) end
    if power>0 and move.type=="electric" then
        for _=1,self.battle.conditions:mudSportCount() do ratio=chain(ratio,1352) end
    end
    if move.sandWeakened and select(2,BattleEffects.solarPolicy(self:weatherId()))==2048 then ratio=chain(ratio,2048) end
    if power>0 and ratio~=4096 then return math.max(1,round(power,ratio)) end
    return power
end
-- Shared major-status query; no RNG or changes to persistent stats/status here.
function BattleEffects:statusImmunity(mon,status)
    if self:livingAbility(mon,72) and (status=="sleep" or status=="yawn") then return "Vital Spirit" end
    if self:livingAbility(mon,41) and status=="burn" then return "Water Veil" end
    if status=="flinch" and self:active(mon) and alive(mon)
        and self:effectiveAbility(mon)==39 then return "Inner Focus" end
    if self:effectiveAbility(mon)==15 and (status=="sleep" or status=="yawn") then return "Insomnia" end
    if self:effectiveAbility(mon)==17 and (status=="poison" or status=="badPoison") then return "Immunity" end
    if self:effectiveAbility(mon)==20 and status=="confuse" then return "Own Tempo" end
end
-- Forewarn uses declared base power, never effective power, PP or damage.
-- Gen5's fixed/variable-power attacks (including the reachable Low Kick) rank80.
-- Missing definitions cannot silently masquerade as ordinary power0 attacks.
function BattleEffects:forewarn(mon,target)
    if not self:livingAbility(mon,108) or not self:active(target) or not alive(target)
        or mon==target then return false end
    local choices,best={},1
    for _,key in ipairs(target.moves) do
        local move=moveData[key]
        if not move or type(move.power)~="number" or not move.category then
            self.battle:recordAbilityGap(108,"forewarn-move-definition",mon)
            self.battle:say("But it failed!")
            return false
        end
        local power=move.power
        if move.ohko then power=150
        elseif key=="counter" or key=="metalBurst" or key=="mirrorCoat" then power=120
        elseif power==1 or (power==0 and move.category~="status") then power=80 end
        if power>best then choices,best={move},power
        elseif power==best then choices[#choices+1]=move end
    end
    if #choices==0 then return false end
    -- PS sample consumes one trial even for a unique maximum.
    local selected=choices[RulesRNG.random(1,#choices)]
    self.battle:say(mon.name.."'s Forewarn alerted it to "..target.name.."'s "..selected.name.."!")
    return true
end
-- Only actual Start callbacks compete in entry ordering. Ordinary abilities do
-- not invent a speed-tie draw when there is no second Start event to order.
function BattleEffects:initialEntries()
    local first,second=self.battle.player,self.battle.enemy
    local a,d=self:effectiveAbility(first),self:effectiveAbility(second)
    if self:active(first) and self:active(second) and alive(first) and alive(second)
        and (a==22 or a==108) and (d==22 or d==108) then
        local x,y=self.battle:effectiveSpeed(first),self.battle:effectiveSpeed(second)
        if y>x or (x==y and RulesRNG.random(1,2)==2) then first,second=second,first end
    end
    self:entry(first)
    self:entry(second)
end
function BattleEffects:entry(mon)
    if not self:active(mon) or not alive(mon) then return false end
    local other=mon==self.battle.player and self.battle.enemy or self.battle.player
    if self:active(other) and alive(other) then
        if self:effectiveAbility(mon)==22 then
            -- Gen5 Inner Focus does NOT block Intimidate. Commit before yielding.
            local old=other.statStages.atk
            other.statStages.atk=math.max(-6,old-1)
            self.battle:say(mon.name.."'s Intimidate!")
            self.battle:say(other.name..(old>-6 and "'s ATTACK fell!" or "'s ATTACK won't go any lower!"))
            return true
        elseif self:effectiveAbility(mon)==108 then return self:forewarn(mon,other) end
    end
    local immunity=self:statusImmunity(mon,mon.status)
    if mon.status=="burn" and immunity=="Water Veil" then
        mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0
        self.battle:say(mon.name.."'s Water Veil cured its burn!")
        return true
    end
    if mon.status=="sleep" and (immunity=="Insomnia" or immunity=="Vital Spirit") then
        mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0
        self.battle:say(mon.name.." woke up with "..immunity.."!")
        return true
    end
    if self:statusImmunity(mon,mon.status)=="Immunity" then
        mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0
        self.battle.conditions:of(mon).toxic=nil
        self.battle:say(mon.name.."'s Immunity cured its poison!")
        return true
    end
    if mon.confusion~=nil and self:statusImmunity(mon,"confuse")=="Own Tempo" then
        mon.confusion=nil
        self.battle:say(mon.name.."'s Own Tempo cured its confusion!")
        return true
    end
    return false
end
function BattleEffects:weatherHeal(mon)
    local weather=self:weatherId()
    local ratio=weather=="sunnyday" and 2732 or (weather=="none" and 2048 or 1024)
    return math.max(1,round(mon.maxHP,ratio))
end
function BattleEffects:attackStat(attacker,move,value)
    local h=handlers[self:effectiveAbility(attacker)]
    value=h and h.attack and h.attack(self,attacker,move,value) or value
    -- B2W2 item attack modifier, after stat stages; never durable stats/power.
    if attacker.species=="pikachu" and attacker.heldItem=="lightBall"
        and (move.category=="physical" or move.category=="special") then return value*2 end
    return value
end
function BattleEffects:defenseStat(defender,move,value)
    if self:weatherId()=="sandstorm" and move.category=="special" and has(self,defender,"rock") then return round(value,6144) end
    return value
end
function BattleEffects:ignoresBurn(mon) return self:effectiveAbility(mon)==62 end
function BattleEffects:canDropStat(source,target,stat,delta)
    return not (source~=target and stat=="acc" and delta<0 and self:effectiveAbility(target)==51)
end
function BattleEffects:allowsSecondary(source,target,kind)
    assert(kind==nil or kind=="condition" or kind=="flinch" or kind=="stat","unsupported-secondary-kind")
    if source~=target and self:effectiveAbility(target)==19 then return false end
    -- Native condition/flinch chance precedes the dead-recipient payload gate;
    -- native stat chance follows its live-recipient gate. No entropy-equivalence
    -- claim with PS's generic lethal-stat draw; nil preserves old2arg behavior.
    return kind=="condition" or kind=="flinch" or alive(target)
end
function BattleEffects:recoilBlocked(mon,move) return self:effectiveAbility(mon)==69 and not move.struggleRecoil end
function BattleEffects:grounded(mon) return not has(self,mon,"flying") end
function BattleEffects:withdrawBlocked(mon)
    local other=mon==self.battle.player and self.battle.enemy or self.battle.player
    return alive(other) and self:effectiveAbility(other)==71 and self:grounded(mon)
end
function BattleEffects:sureEscape(mon) return self:effectiveAbility(mon)==50 end
function BattleEffects:limitDirectHit(source,target,move,amount)
    local endure=self:effectiveAbility(target)==5 and target.hp==target.maxHP and amount>=target.hp and source~=target
    return endure and math.max(0,target.hp-1) or amount,endure
end
-- Each receipt is made immediately around the direct HP commit and resolved once.
function BattleEffects:hit(source,target,move,amount,hitNumber)
    local before=target.hp
    local limited,endured=self:limitDirectHit(source,target,move,amount)
    self:damage(target,limited,"hit")
    local cause="fixed"
    if move then cause=move.ohko and "ohko" or (move.power==0 and not move.powerRule and "fixed" or "move") end
    local receipt={source=source,target=target,move=move,before=before,removed=before-target.hp,endured=endured,
        cause=cause,contact=move~=nil and move.contact==true,hit=hitNumber or 1}
    if move and move.category~="status" then self.battle.conditions:bideHit(target,source,receipt.removed) end
    self.receipts[receipt]=true
    return receipt
end
function BattleEffects:afterHit(receipt)
    if not self.receipts[receipt] or not self:active(receipt.source) or not self:active(receipt.target) then return false,"stale-hit" end
    self.receipts[receipt]=nil
    if receipt.before<=0 then return false,"target-was-fainted" end
    local b,source,target,move=self.battle,receipt.source,receipt.target,receipt.move
    local id=self:effectiveAbility(target)
    if (id==9 or id==38) and receipt.contact and receipt.before>0 and RulesRNG.random(0,99)<30 then
        -- Preserve native/Static chance-before-eligibility order, including KO.
        local status=id==9 and "paralyze" or "poison"
        local eligible=status~="poison" or (not has(self,source,"poison") and not has(self,source,"steel")
            and not self:statusImmunity(source,status))
        if alive(source) and not source.status and eligible then
            b:say(target.name .. (id==9 and "'s Static!" or "'s Poison Point!"))
            ApplyStatus({resolve=function() return source end},status,{source={resolve=function() return target end},cause="ability"}):apply(b)
        end
    end
    return true
end
function BattleEffects:announceEndure(receipt)
    if receipt.endured then self.battle:say(receipt.target.name .. " held on with Sturdy!") end
end
function BattleEffects:ohko(attacker,defender,move)
    if attacker.level<defender.level then return false,"level" end
    if self.battle:typeMatchup(move.type,defender)==0 then return false,"immune" end
    if self:effectiveAbility(defender)==5 then return false,"sturdy" end
    if self:accuracyBypassesCheck(move,attacker,defender) then return true,"accuracy" end
    return RulesRNG.random(0,99)<move.accuracy+attacker.level-defender.level,"accuracy"
end
-- Weather is a field lifetime, not owned by either current active Pokemon.
-- Existing sand-only entry points delegate here; no Sun/Hail producer exists.
function BattleEffects:setWeather(id)
    if self.closed then return false,"closed-battle" end
    if id~="sandstorm" and id~="raindance" then return false,"unsupported-weather" end
    if self:weatherId()==id then self.battle:say("But it failed!");return false,"same-weather" end
    self.weather={id=id,turns=5}
    self.battle:say(id=="sandstorm" and "A sandstorm kicked up!" or "It started to rain!")
    return true
end
function BattleEffects:setSandstorm() return self:setWeather("sandstorm") end
-- This hook is after base damage+2, before crit/random/STAB; never a base-power
-- modifier. Fixed damage doesn't enter calcDamage and is unaffected.
function BattleEffects:weatherDamage(move,damage)
    if self:weatherId()~="raindance" then return damage end
    if move.type=="water" then return round(damage,6144) end
    if move.type=="fire" then return round(damage,2048) end
    return damage
end
function BattleEffects:events()
    local events={}
    if self.weather then events[#events+1]={kind="weatherTick",order=0,side="field",owner="effects"} end
    for _,side in ipairs({"player","enemy"}) do
        local mon=self.battle[side]
        if alive(mon) then
            if self:weatherId()=="sandstorm" then events[#events+1]={kind="sand",order=1,side=side,pokemon=mon,owner="effects"} end
            if self:effectiveAbility(mon)==87 and self:weatherId()=="raindance" then
                events[#events+1]={kind="drySkin",order=1,side=side,pokemon=mon,owner="effects"}
            end
            if self:effectiveAbility(mon)==61 and mon.status then events[#events+1]={kind="shedSkin",order=5,side=side,pokemon=mon,owner="effects"} end
        end
    end
    return events
end
function BattleEffects:residual(event)
    local b,mon=self.battle,event.pokemon
    if event.kind=="weatherTick" then
        if self.weather then
            self.weather.turns=self.weather.turns-1
            if self.weather.turns==0 then
                local id=self:weatherId();self.weather=nil
                b:say(id=="sandstorm" and "The sandstorm subsided." or "The rain stopped.")
            elseif self:weatherId()=="raindance" then b:say("Rain continues to fall.") end
        end
    elseif event.kind=="drySkin" and self:weatherId()=="raindance" and self:active(mon) and alive(mon)
        and self:effectiveAbility(mon)==87 then
        local before=mon.hp
        mon:heal(math.max(1,mon.maxHP//8))
        if mon.hp>before then b:say(mon.name.." was healed by Dry Skin!") end
    elseif event.kind=="sand" and self:weatherId()=="sandstorm" and self:active(mon) and alive(mon) then
        if not has(self,mon,"rock") and not has(self,mon,"ground") and not has(self,mon,"steel") and self:effectiveAbility(mon)~=8 then
            self:damage(mon,math.max(1,mon.maxHP//16),"weather");b:say(mon.name .. " is buffeted by the sandstorm!")
        end
    elseif event.kind=="shedSkin" and self:active(mon) and alive(mon) and mon.status and self:effectiveAbility(mon)==61 then
        if RulesRNG.random(0,99)<33 then
            mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0
            b.conditions:of(mon).toxic=nil
            b:say(mon.name .. " shed its status with Shed Skin!")
        end
    end
end
function BattleEffects:clear(mon)
    self.abilityOverrides[mon]=nil
    if self.round then self.round.pending[mon]=nil;self.round.damaged[mon]=nil end
    for receipt in pairs(self.receipts) do if receipt.source==mon or receipt.target==mon then self.receipts[receipt]=nil end end
end
function BattleEffects:close() self.abilityOverrides={};self:endRound();self.closed=true;self.weather=nil;self.receipts=setmetatable({},{__mode="k"}) end
function BattleEffects:snapshot() return {weather=self:weatherId(),turns=self.weather and self.weather.turns or 0} end
