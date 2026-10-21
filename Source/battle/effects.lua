-- Gen V ability hooks owned by one actual Battle. No persistent volatile state.
Class("BattleEffects")
local function has(mon,t) return mon.type==t or mon.type2==t end
local function ability(mon) return mon and mon.ability and mon:ability() or 0 end
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
handlers[8]={evasion=function(owner) return owner.weather and 3277 or 4096 end}
handlers[5],handlers[9],handlers[19],handlers[50],handlers[51],handlers[61],handlers[69],handlers[71]={},{},{},{},{},{},{},{}
function BattleEffects:init(battle)
    self.battle=battle;self.weather=nil;self.receipts=setmetatable({},{__mode="k"});self.closed=false
end
function BattleEffects:supported(id) return handlers[id]~=nil end
function BattleEffects:active(mon) return not self.closed and (self.battle.player==mon or self.battle.enemy==mon) end
function BattleEffects:accuracy(attacker,defender,move)
    local ratio=4096;local a,d=handlers[ability(attacker)],handlers[ability(defender)]
    if a and a.accuracy then ratio=chain(ratio,a.accuracy(self,attacker)) end
    if d and d.evasion then ratio=chain(ratio,d.evasion(self,defender)) end
    return round(move.accuracy,ratio)
end
function BattleEffects:basePower(move,power)
    if self.weather and move.sandWeakened then return math.max(1,round(power,2048)) end
    return power
end
function BattleEffects:weatherHeal(mon)
    return math.max(1,round(mon.maxHP,self.weather and 1024 or 2048))
end
function BattleEffects:attackStat(attacker,move,value)
    local h=handlers[ability(attacker)];return h and h.attack and h.attack(self,attacker,move,value) or value
end
function BattleEffects:defenseStat(defender,move,value)
    if self.weather and move.category=="special" and has(defender,"rock") then return round(value,6144) end
    return value
end
function BattleEffects:ignoresBurn(mon) return ability(mon)==62 end
function BattleEffects:canDropStat(source,target,stat,delta)
    return not (source~=target and stat=="acc" and delta<0 and ability(target)==51)
end
function BattleEffects:allowsSecondary(source,target)
    return alive(target) and (source==target or ability(target)~=19)
end
function BattleEffects:recoilBlocked(mon,move) return ability(mon)==69 and not move.struggleRecoil end
function BattleEffects:grounded(mon) return not has(mon,"flying") end
function BattleEffects:withdrawBlocked(mon)
    local other=mon==self.battle.player and self.battle.enemy or self.battle.player
    return alive(other) and ability(other)==71 and self:grounded(mon)
end
function BattleEffects:sureEscape(mon) return ability(mon)==50 end
function BattleEffects:limitDirectHit(source,target,move,amount)
    local endure=ability(target)==5 and target.hp==target.maxHP and amount>=target.hp and source~=target
    return endure and math.max(0,target.hp-1) or amount,endure
end
-- Each receipt is made immediately around the direct HP commit and resolved once.
function BattleEffects:hit(source,target,move,amount,hitNumber)
    local before=target.hp
    local limited,endured=self:limitDirectHit(source,target,move,amount)
    target:takeDamage(limited)
    local cause="fixed"
    if move then cause=move.ohko and "ohko" or (move.power==0 and "fixed" or "move") end
    local receipt={source=source,target=target,move=move,before=before,removed=before-target.hp,endured=endured,
        cause=cause,contact=move~=nil and move.contact==true,hit=hitNumber or 1}
    self.receipts[receipt]=true
    return receipt
end
function BattleEffects:afterHit(receipt)
    if not self.receipts[receipt] or not self:active(receipt.source) or not self:active(receipt.target) then return false,"stale-hit" end
    self.receipts[receipt]=nil
    local b,source,target,move=self.battle,receipt.source,receipt.target,receipt.move
    if ability(target)==9 and receipt.contact and receipt.removed>0 and RulesRNG.random(0,99)<30 then
        if alive(source) and not source.status then
            b:say(target.name .. "'s Static!")
            ApplyStatus({resolve=function() return source end},"paralyze"):apply(b)
        end
    end
    return true
end
function BattleEffects:announceEndure(receipt)
    if receipt.endured then self.battle:say(receipt.target.name .. " held on with Sturdy!") end
end
function BattleEffects:ohko(attacker,defender,move)
    if attacker.level<defender.level then return false,"level" end
    if TypeChart.getMatchup(move.type,defender.type,defender.type2)==0 then return false,"immune" end
    if ability(defender)==5 then return false,"sturdy" end
    return RulesRNG.random(0,99)<move.accuracy+attacker.level-defender.level,"accuracy"
end
function BattleEffects:setSandstorm()
    if self.weather then self.battle:say("But it failed!");return false end
    self.weather={turns=5};self.battle:say("A sandstorm kicked up!");return true
end
function BattleEffects:events()
    local events={}
    if self.weather then events[#events+1]={kind="weatherTick",order=0,side="field",owner="effects"} end
    for _,side in ipairs({"player","enemy"}) do
        local mon=self.battle[side]
        if alive(mon) then
            if self.weather then events[#events+1]={kind="sand",order=1,side=side,pokemon=mon,owner="effects"} end
            if ability(mon)==61 and mon.status then events[#events+1]={kind="shedSkin",order=5,side=side,pokemon=mon,owner="effects"} end
        end
    end
    return events
end
function BattleEffects:residual(event)
    local b,mon=self.battle,event.pokemon
    if event.kind=="weatherTick" then
        if self.weather then
            self.weather.turns=self.weather.turns-1
            if self.weather.turns==0 then self.weather=nil;b:say("The sandstorm subsided.") end
        end
    elseif event.kind=="sand" and self.weather and self:active(mon) and alive(mon) then
        if not has(mon,"rock") and not has(mon,"ground") and not has(mon,"steel") and ability(mon)~=8 then
            mon:takeDamage(math.max(1,mon.maxHP//16));b:say(mon.name .. " is buffeted by the sandstorm!")
        end
    elseif event.kind=="shedSkin" and self:active(mon) and alive(mon) and mon.status and ability(mon)==61 then
        if RulesRNG.random(0,99)<33 then
            mon.status,mon.statusTurns,mon.sleepDuration=nil,0,0
            b.conditions:of(mon).toxic=nil
            b:say(mon.name .. " shed its status with Shed Skin!")
        end
    end
end
function BattleEffects:clear(mon)
    for receipt in pairs(self.receipts) do if receipt.source==mon or receipt.target==mon then self.receipts[receipt]=nil end end
end
function BattleEffects:close() self.closed=true;self.weather=nil;self.receipts=setmetatable({},{__mode="k"}) end
function BattleEffects:snapshot() return {weather=self.weather and "sandstorm" or "none",turns=self.weather and self.weather.turns or 0} end
