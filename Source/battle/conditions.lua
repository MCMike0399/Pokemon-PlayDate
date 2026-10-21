-- Concrete Gen V transient owner for early-route moves. No durable Pokemon fields.
Class("BattleConditions")
local function has(mon,t) return mon.type==t or mon.type2==t end
local function alive(mon) return mon and mon:isAlive() end
local function damage(mon,n) local hp=mon.hp;mon:takeDamage(math.max(1,math.floor(n)));return hp-mon.hp end
function BattleConditions:init(battle)
    self.battle=battle;self:clearAll()
end
function BattleConditions:clearAll()
    self.members={};self.sides={player={},enemy={}}
end
function BattleConditions:of(mon)
    if not self.members[mon] then self.members[mon]={} end
    return self.members[mon]
end
function BattleConditions:side(mon) return mon==self.battle.player and "player" or "enemy" end
function BattleConditions:clear(mon)
    self.members[mon]=nil
    for _,state in pairs(self.members) do if state.trap and state.trap.source==mon then state.trap=nil end end
end
function BattleConditions:locked(mon) return self.members[mon] and self.members[mon].rollout end
function BattleConditions:trapped(mon)
    local trap=self.members[mon] and self.members[mon].trap
    return trap and alive(trap.source) and (trap.source==self.battle.player or trap.source==self.battle.enemy) or false
end
function BattleConditions:basePower(mon,move)
    local power=move.power;local state=self:of(mon)
    if move.rollout then power=power*2^((state.rollout and state.rollout.hits) or 0)*(state.defenseCurl and 2 or 1) end
    if move.type=="electric" then
        local modifier=4096
        for _,active in ipairs({self.battle.player,self.battle.enemy}) do
            if alive(active) and self:of(active).mudSport then modifier=(modifier*1352+2048)//4096 end
        end
        power=math.max(1,math.floor((power*modifier+2047)/4096))
    end
    return power
end
function BattleConditions:mudSport()
    local b=self.battle;local state=self:of(b.attacker)
    if state.mudSport then b:say("But it failed!");return end
    state.mudSport=true;b:say("Electricity's power was weakened!")
end
function BattleConditions:curse()
    local b=self.battle;local user,target=b.attacker,b.defender
    if not has(user,"ghost") then
        ModifyStat(ATTACKER,"spe",-1):apply(b);ModifyStat(ATTACKER,"atk",1):apply(b);ModifyStat(ATTACKER,"def",1):apply(b);return
    end
    local state=self:of(target)
    if state.curse then b:say("But it failed!");return end
    state.curse=true;damage(user,user.maxHP/2)
    b:say(user.name.." cut its own HP and laid a curse on "..target.name.."!")
end
function BattleConditions:rageHit(target)
    if alive(target) and self:of(target).rage then
        local old=target.statStages.atk;target.statStages.atk=math.min(6,old+1)
        if target.statStages.atk>old then self.battle:say(target.name.."'s rage is building!") end
    end
end
function BattleConditions:rapidSpin()
    local b=self.battle;local user=b.attacker;local state=self:of(user)
    local side=self.sides[self:side(user)]
    local removed=state.seed or state.trap or side.spikes or side.toxicSpikes or side.stealthRock
    state.seed,state.trap=nil,nil;self.sides[self:side(user)]={}
    if removed then b:say(user.name.." blew away the obstacles!") end
end
function BattleConditions:leechSeed()
    local b=self.battle;local state=self:of(b.defender)
    if has(b.defender,"grass") or state.seed then b:say("But it failed!");return end
    state.seed=b.attackerSide;b:say(b.defender.name.." was seeded!")
end
function BattleConditions:trap()
    local b=self.battle;local state=self:of(b.defender)
    if state.trap or not alive(b.defender) then return end
    state.trap={source=b.attacker,remaining=RulesRNG.random(4,5)}
    b:say(b.defender.name.." was trapped!")
end
function BattleConditions:hazard(kind)
    local b=self.battle;local side=self.sides[b.attackerSide=="player" and "enemy" or "player"]
    local limit=kind=="spikes" and 3 or (kind=="toxicSpikes" and 2 or 1)
    if (side[kind] or 0)>=limit then b:say("But it failed!");return end
    if not side[kind] then
        side.order=side.order or {};local recorded=false
        for _,name in ipairs(side.order) do if name==kind then recorded=true end end
        if not recorded then side.order[#side.order+1]=kind end
    end
    side[kind]=(side[kind] or 0)+1;b:say("Hazards were scattered on the opposing side!")
end
function BattleConditions:entry(mon,side)
    local b=self.battle;local hazards=self.sides[side]
    self:clear(mon)
    -- Preserve side-condition insertion order, as the pinned event owner does.
    for _,kind in ipairs(hazards.order or {}) do
        if alive(mon) then
            if kind=="stealthRock" and hazards.stealthRock then
                damage(mon,mon.maxHP*TypeChart.getMatchup("rock",mon.type,mon.type2)/8)
                b:say("Pointed stones dug into "..mon.name.."!")
            elseif not has(mon,"flying") then
                if kind=="spikes" and hazards.spikes then
                    local divisor=({8,6,4})[hazards.spikes];damage(mon,mon.maxHP/divisor);b:say(mon.name.." was hurt by Spikes!")
                elseif kind=="toxicSpikes" and hazards.toxicSpikes then
                    if has(mon,"poison") then hazards.toxicSpikes=nil;b:say(mon.name.." absorbed the poison spikes!")
                    elseif not has(mon,"steel") and not mon.status then
                        mon.status=hazards.toxicSpikes==2 and "badPoison" or "poison";mon.statusTurns,mon.sleepDuration=0,0
                        b:say(mon.name.." was poisoned!")
                    end
                end
            end
        end
    end
end
function BattleConditions:events()
    local events={}
    for _,side in ipairs({"player","enemy"}) do
        local mon=self.battle[side];local state=self:of(mon)
        local function add(kind,order) events[#events+1]={side=side,pokemon=mon,kind=kind,order=order} end
        if alive(mon) then
            if state.seed then add("seed",8) end
            if mon.status=="poison" or mon.status=="badPoison" then add("status",9) end
            if mon.status=="burn" then add("status",10) end
            if state.curse then add("curse",12) end
            if state.trap then add("trap",13) end
        end
    end
    return events
end
function BattleConditions:residual(event)
    local b=self.battle;local mon=event.pokemon;local state=self:of(mon)
    if not alive(mon) then return end
    if event.kind=="seed" and state.seed then
        local receiver=b[state.seed]
        if alive(receiver) then receiver:heal(damage(mon,mon.maxHP/8));b:say(mon.name.."'s health was sapped by Leech Seed!") end
    elseif event.kind=="curse" and state.curse then damage(mon,mon.maxHP/4);b:say(mon.name.." is afflicted by the curse!")
    elseif event.kind=="trap" and state.trap then
        if not self:trapped(mon) then state.trap=nil;return end
        damage(mon,mon.maxHP/16);state.trap.remaining=state.trap.remaining-1
        b:say(mon.name.." is hurt by the binding!")
        if state.trap.remaining==0 then state.trap=nil;b:say(mon.name.." was freed!") end
    elseif event.kind=="status" then
        if mon.status=="badPoison" then
            state.toxic=math.min(15,(state.toxic or 0)+1);damage(mon,math.max(1,mon.maxHP//16)*state.toxic)
            b:say(mon.name.." is hurt by poison!")
        else state.toxic=nil;b:applyStatusDamage(mon) end
    end
end
