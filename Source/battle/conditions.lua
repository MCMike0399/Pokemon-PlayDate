-- Concrete Gen V transient owner for early-route moves. No durable Pokemon fields.
Class("BattleConditions")
local function has(owner,mon,t) return owner.battle:hasType(mon,t) end
local function alive(mon) return mon and mon:isAlive() end
local function damage(owner,mon,n,cause)
    local amount=math.max(1,math.floor(n))
    if owner.battle.effects then return owner.battle.effects:damage(mon,amount,cause or "condition") end
    local hp=mon.hp;mon:takeDamage(amount);return hp-mon.hp
end
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
-- Read-only battle typing; durable Pokemon species types never change.
function BattleConditions:types(mon)
    local first,second=mon.type,mon.type2
    local state=self.members[mon]
    if state and state.changedType then first,second=state.changedType,nil end
    if state and state.roost then
        if first=="flying" then first=nil end
        if second=="flying" then second=nil end
        if not first then first=second;second=nil end
        if not first then first="normal" end -- GenV fallback, not GenIV ???.
    end
    return first,second
end
-- Disable inherits the pinned base condition in the Gen5 mod chain.
function BattleConditions:disabled(mon,key)
    local state=self.members[mon]
    return key~=nil and state and state.disable and state.disable.key==key or false
end
function BattleConditions:canDisable(mon)
    local state=self.members[mon];local key=state and state.lastMove
    if not key or key=="struggle" or state.disable then return false end
    for _,move in ipairs(mon.moves) do
        if move==key then return mon:hasPP(key) end
    end
    return false
end
function BattleConditions:disable()
    local b=self.battle;local mon=b.defender
    if not self:canDisable(mon) then b:say("But it failed!");return false end
    local state=self:of(mon);local key=state.lastMove
    -- Four residual ticks if the target still has its action; otherwise five.
    state.disable={key=key,turns=b.effects:pendingMove(mon) and 4 or 5}
    b:say(mon.name.."'s "..moveData[key].name.." was disabled!")
    return true
end
function BattleConditions:camouflage()
    local b=self.battle;local mon=b.attacker
    -- Campaign policy: Normal without a game-field environment. The pinned
    -- PS base callback defaults to Normal; its Gen5 override instead uses
    -- Ground. Do not infer a field environment from the overworld map art.
    local first,second=self:types(mon)
    if first=="normal" and not second then b:say("But it failed!");return false end
    self:of(mon).changedType="normal"
    b:say(mon.name.." transformed into the NORMAL type!")
    return true
end
function BattleConditions:roost()
    local b=self.battle;local mon=b.attacker
    if not self:activeSide(mon) or mon~=b[b.attackerSide] or not alive(mon) then return false,"invalid-roost-user" end
    if mon.hp>=mon.maxHP then b:say("But it failed!");return false,"full-hp" end
    mon:heal((mon.maxHP+1)//2)
    self:of(mon).roost={} -- Install after real healing, before narration yields.
    b:say(mon.name .. " regained health!")
    return true
end
local sideDurations <const> ={lightScreen=5,safeguard=5,tailwind=4}
local sideSuborders <const> ={lightScreen=2,safeguard=3,tailwind=5}
local sideNames <const> ={lightScreen="Light Screen",safeguard="Safeguard",tailwind="Tailwind"}
function BattleConditions:activeSide(mon)
    if mon==self.battle.player then return "player" end
    if mon==self.battle.enemy then return "enemy" end
end
function BattleConditions:setSideCondition(kind)
    if not sideDurations[kind] then return false,"unsupported-side-condition" end
    local b=self.battle;local side=b.attackerSide;local state=self.sides[side]
    if not state or b.attacker~=b[side] then return false,"invalid-side-source" end
    if state[kind] then b:say("But it failed!");return false,"already-active" end
    state[kind]={turns=sideDurations[kind]}
    local team=side=="player" and "your team" or "the opposing team"
    if kind=="tailwind" then b:say("A tailwind blew behind "..team.."!")
    else b:say(sideNames[kind].." protected "..team.."!") end
    return true
end
-- Pure current side queries: no member/side allocation, and no bench identity
-- silently inheriting the current opposing side through legacy side().
function BattleConditions:sideTurns(mon,kind)
    if not sideDurations[kind] then return 0 end
    local side=self:activeSide(mon);local state=side and self.sides[side][kind]
    return state and state.turns or 0
end
function BattleConditions:speed(mon,speed)
    return self:sideTurns(mon,"tailwind")>0 and speed*2 or speed
end
function BattleConditions:screenDamage(source,target,move,damage,critical)
    if move.power==0 and not move.powerRule then return damage end
    if source~=target and not critical and move.category=="special" and self:sideTurns(target,"lightScreen")>0 then
        return BattleEffects.fixedRound(damage,2048)
    end
    return damage
end
-- Concrete provenance is captured at application/placement, not guessed later
-- from whichever attacker happens to own a residual or entry callback.
function BattleConditions:statusOrigin(source,cause)
    return {source=source,side=self:activeSide(source),cause=cause or "move"}
end
local guardedStatuses <const> ={poison=true,badPoison=true,burn=true,paralyze=true,sleep=true,freeze=true,confuse=true}
function BattleConditions:preventsStatus(mon,status,origin)
    if not guardedStatuses[status] or self:sideTurns(mon,"safeguard")==0 then return false end
    if not origin or not origin.source or origin.source==mon then return false end
    return origin.cause=="move" or origin.cause=="ability" or origin.cause=="toxicSpikes"
end
function BattleConditions:clear(mon)
    self.members[mon]=nil
    for _,state in pairs(self.members) do
        if state.trap and state.trap.source==mon then state.trap=nil end
        if state.infatuation and state.infatuation.source==mon then state.infatuation=nil end
    end
end
function BattleConditions:locked(mon)
    local state=self.members[mon]
    return state and (state.bide or state.charge or state.rampage or state.rollout)
end
function BattleConditions:lockedKey(mon)
    local state=self.members[mon]
    return state and (state.bide and "bide" or state.charge and state.charge.key
        or state.rampage and state.rampage.key or state.rollout and "rollout") or nil
end
function BattleConditions:abortMove(mon)
    local state=self.members[mon]
    if state then
        state.rollout,state.bide,state.charge=nil,nil,nil
        -- A blocked rampage finishes at residual expiry. On its final turn
        -- fatigue still occurs; an early interrupted chain calms without it.
        if state.rampage then state.rampage.interrupted=true end
    end
end
-- Persistent across logical rounds, disposable on interruption/withdraw/faint.
-- Two-turn moves are anchored to the opposing slot in singles, not to a
-- stale Pokemon identity. Replacement/learning cannot forge a learned slot.
function BattleConditions:charge(move)
    local b=self.battle;local user=b.attacker;local state=self:of(user)
    if state.charge then
        assert(state.charge.key==b.currentMoveKey,"wrong-charge-continuation")
        state.charge=nil;return false
    end
    assert(move.chargeRule=="solarBeam" or move.chargeRule=="skullBash","unsupported-charge-rule")
    local skip=move.chargeRule=="solarBeam" and BattleEffects.solarPolicy(b.effects:weatherId())
    if not skip then state.charge={key=assert(b.currentMoveKey,"missing charge identity")} end
    if move.chargeRule=="skullBash" then
        b:say(user.name .. " lowered its head!")
        ModifyStat(ATTACKER,"def",1):apply(b)
    else b:say(user.name .. " took in sunlight!") end
    return not skip
end
-- Successful self-effect precedes contact reactions, as the pinned dispatcher
-- does. First miss/immune/absent target never creates a lock or duration draw.
function BattleConditions:landedMove(move)
    if move.lockRule~="rampage" then return end
    local b=self.battle;local state=self:of(b.attacker)
    if not state.rampage then
        local duration=RulesRNG.random(2,3)
        state.rampage={key=assert(b.currentMoveKey,"missing rampage identity"),remaining=duration,total=duration,interrupted=false}
    end
end
function BattleConditions:endRampage(mon,confuse)
    local state=self.members[mon]
    if not state or not state.rampage then return end
    state.rampage=nil
    if confuse and alive(mon) then
        local itself={resolve=function()return mon end}
        ApplyStatus(itself,"confuse",{source=itself,cause="fatigue"}):apply(self.battle)
    end
end
function BattleConditions:moveFinished(move,success)
    if move.lockRule~="rampage" then return end
    local b=self.battle;local state=self.members[b.attacker];local rampage=state and state.rampage
    if not rampage then return end
    if not alive(b.attacker) then self:endRampage(b.attacker,false);return end
    if not success then self:endRampage(b.attacker,rampage.remaining==1);return end
    rampage.remaining=rampage.remaining-1;rampage.interrupted=false
    if rampage.remaining==0 then self:endRampage(b.attacker,true) end
end
-- GenV stall counter1 is guaranteed, then halves to1/128. Its saturated
-- native-style branch nominally selects one of2^32 outcomes. Our two uniform
-- 16bit values are deterministic/correlated Park-Miller outputs, not native
-- independent32bit entropy; choosing both maxima has a reproducible real seed.
function BattleConditions.protectSucceeds(counter)
    assert(counter==1 or counter==2 or counter==4 or counter==8 or counter==16
        or counter==32 or counter==64 or counter==128 or counter==256,"invalid-protect-counter")
    if counter==1 then return true end
    if counter>=256 then
        local planned=RulesRNG.new(1);planned:restore(RulesRNG.snapshot())
        local first=planned:random(0,65535)
        local second=planned:random(0,65535)
        RulesRNG.restore(planned:snapshot())
        return first==65535 and second==65535
    end
    return RulesRNG.random(1,counter)==1
end
function BattleConditions:protect()
    local b=self.battle;local mon=b.attacker;local state=self.members[mon]
    -- The real opposing selected action remains queued even if its status may
    -- later block it; already-consumed/no-action response paths cannot protect.
    if not b.effects:pendingMove(b.defender) then b:say("But it failed!");return false end
    local counter=state and state.stall and state.stall.counter or 1
    if not BattleConditions.protectSucceeds(counter) then b:say("But it failed!");return false end
    state=self:of(mon);state.protect=true
    state.stall={counter=math.min(256,counter*2),remaining=2}
    b:say(mon.name .. " protected itself!");return true
end
function BattleConditions:blocks(move,source,target)
    local state=self.members[target]
    if source~=target and state and state.protect and move.protectable then
        self.battle:say(target.name .. " protected itself!");return true
    end
    return false
end
function BattleConditions:breakProtection(move,target)
    local state=self.members[target]
    if move.breaksProtect and state and state.protect then
        state.protect=nil -- GenV Feint deliberately preserves the stall counter.
        self.battle:say(target.name .. "'s protection was broken!");return true
    end
    return false
end
function BattleConditions:endRound()
    for _,state in pairs(self.members) do
        state.protect=nil
        if state.stall then
            state.stall.remaining=state.stall.remaining-1
            if state.stall.remaining==0 then state.stall=nil end
        end
    end
end
function BattleConditions:bideHit(target,source,removed)
    local state=self.members[target]
    if removed>0 and source and source~=target and state and state.bide then
        state.bide.total=state.bide.total+removed
        state.bide.source=source
    end
end
function BattleConditions:bide()
    local b=self.battle;local mon=b.attacker;local state=self:of(mon)
    if not state.bide then
        state.bide={turns=1,total=0}
        b:say(mon.name .. " used BIDE!")
        b:say(mon.name .. " is storing energy!")
        return nil
    end
    local stored=state.bide
    if stored.turns==1 then
        stored.turns=2;b:say(mon.name .. " is storing energy!");return nil
    end
    -- Release owns/clears its receipt before yielding/contact/faint callbacks.
    state.bide=nil
    b:say(mon.name .. " unleashed energy!")
    if stored.total==0 or not stored.source then b:say("But it failed!");return nil end
    -- Singles: if the recorded attacker left, the sole active opponent is the
    -- only eligible retarget. No random choice exists among multiple targets.
    local target=stored.source
    if target~=b.defender or not alive(target) then target=b.defender end
    if not alive(target) then b:say("But there was no target!");return nil end
    -- GenV release is a physical Normal fixed hit. Generic DirectDamage owns
    -- Ghost immunity, Sturdy, actual HP removed, Rage and contact reactions.
    if b:typeMatchup(b.currentMove.type,target)~=0
       and self:blocks(b.currentMove,mon,target) then return nil end
    DirectDamage(DEFENDER,stored.total*2):apply(b)
    if not target:isAlive() then return b:handleFaint() end
    if not mon:isAlive() then b:setDirection(b.attackerSide=="player"and "enemy"or "player");return b:handleFaint() end
    return nil
end
function BattleConditions:trapped(mon)
    local trap=self.members[mon] and self.members[mon].trap
    return trap and alive(trap.source) and (trap.source==self.battle.player or trap.source==self.battle.enemy) or false
end
-- Raw move-defined multipliers precede the single BasePower modifier chain.
function BattleConditions:rawPower(mon,move,power)
    power=power or move.power;local state=self.members[mon] or {}
    if move.rollout then power=power*2^((state.rollout and state.rollout.hits) or 0)*(state.defenseCurl and 2 or 1) end
    return power
end
-- Pure active-holder observation; withdrawal/defeat cannot contribute a modifier.
function BattleConditions:mudSportCount()
    local count=0
    for _,active in ipairs({self.battle.player,self.battle.enemy}) do
        if alive(active) and (self.members[active] or {}).mudSport then count=count+1 end
    end
    return count
end
function BattleConditions:mudSport()
    local b=self.battle;local state=self:of(b.attacker)
    if state.mudSport then b:say("But it failed!");return end
    state.mudSport=true;b:say("Electricity's power was weakened!")
end
function BattleConditions:curse()
    local b=self.battle;local user,target=b.attacker,b.defender
    if not has(self,user,"ghost") then
        ModifyStat(ATTACKER,"spe",-1):apply(b);ModifyStat(ATTACKER,"atk",1):apply(b);ModifyStat(ATTACKER,"def",1):apply(b);return
    end
    local state=self:of(target)
    if state.curse then b:say("But it failed!");return end
    state.curse=true;damage(self,user,user.maxHP/2,"cost")
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
    state.seed,state.trap=nil,nil
    side.spikes,side.toxicSpikes,side.stealthRock,side.order,side.hazardOrigins=nil,nil,nil,nil,nil
    if removed then b:say(user.name.." blew away the obstacles!") end
end
function BattleConditions:leechSeed()
    local b=self.battle;local state=self:of(b.defender)
    if has(self,b.defender,"grass") or state.seed then b:say("But it failed!");return end
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
        side.hazardOrigins=side.hazardOrigins or {}
        side.hazardOrigins[kind]=self:statusOrigin(b.attacker,kind)
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
                if damage(self,mon,mon.maxHP*b:typeMatchup("rock",mon)/8)>0 then
                    b:say("Pointed stones dug into "..mon.name.."!")
                end
            elseif b.effects:grounded(mon) then
                if kind=="spikes" and hazards.spikes then
                    local divisor=({8,6,4})[hazards.spikes]
                    if damage(self,mon,mon.maxHP/divisor)>0 then b:say(mon.name.." was hurt by Spikes!") end
                elseif kind=="toxicSpikes" and hazards.toxicSpikes then
                    if has(self,mon,"poison") then hazards.toxicSpikes=nil;if hazards.hazardOrigins then hazards.hazardOrigins.toxicSpikes=nil end;b:say(mon.name.." absorbed the poison spikes!")
                    elseif not has(self,mon,"steel") and not mon.status
                        and not (b.effects and b.effects:statusImmunity(mon,"poison")) then
                        local status=hazards.toxicSpikes==2 and "badPoison" or "poison"
                        local origin=hazards.hazardOrigins and hazards.hazardOrigins.toxicSpikes
                        if self:preventsStatus(mon,status,origin) then b:say(mon.name.." is protected by Safeguard!")
                        else mon.status=status;mon.statusTurns,mon.sleepDuration=0,0;b:say(mon.name.." was poisoned!") end
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
            if state.roost then events[#events+1]={side=side,pokemon=mon,kind="roostEnd",order=25,record=state.roost} end
            if state.disable then add("disable",17) end
            if state.seed then add("seed",8) end
            if mon.status=="poison" or mon.status=="badPoison" then add("status",9) end
            if mon.status=="burn" then add("status",10) end
            if state.curse then add("curse",12) end
            if state.trap then add("trap",13) end
            if state.rampage and (state.rampage.interrupted or mon.status=="sleep") then add("rampageEnd",1000) end
        end
    end
    for _,side in ipairs({"player","enemy"}) do
        for _,kind in ipairs({"lightScreen","safeguard","tailwind"}) do
            local state=self.sides[side][kind]
            if state then events[#events+1]={kind="sideTimer",side=side,condition=kind,record=state,order=26,suborder=sideSuborders[kind]} end
        end
    end
    return events
end
function BattleConditions:residual(event)
    local b=self.battle
    if event.kind=="sideTimer" then
        local state=self.sides[event.side][event.condition]
        if state~=event.record or event.consumed then return end
        event.consumed=true
        state.turns=state.turns-1
        if state.turns==0 then
            self.sides[event.side][event.condition]=nil
            b:say((event.side=="player" and "Your " or "The opposing ")..sideNames[event.condition].." wore off!")
        end
        return
    end
    if event.kind=="roostEnd" then
        local state=self.members[event.pokemon]
        if state and state.roost==event.record then state.roost=nil end
        return
    end
    local mon=event.pokemon;local state=self:of(mon)
    if not alive(mon) then return end
    if event.kind=="disable" and state.disable then
        state.disable.turns=state.disable.turns-1
        if state.disable.turns==0 then
            state.disable=nil;b:say(mon.name.." is no longer disabled!")
        end
    elseif event.kind=="rampageEnd" then
        local rampage=state.rampage
        if rampage then self:endRampage(mon,rampage.interrupted and rampage.remaining==1) end
    elseif event.kind=="seed" and state.seed then
        local receiverSide = state.seed
        local receiver = b[receiverSide]
        if b.effects:active(mon) and alive(receiver) then
            local removed = damage(self, mon, mon.maxHP / 8)
            if removed > 0 then
                b.effects:drainSeed(mon, receiver, removed)
                b:say(mon.name .. "'s health was sapped by Leech Seed!")
                -- Liquid Ooze may KO the recipient rather than event.pokemon.
                -- Return its actual side to the existing residual faint cohort.
                if not receiver:isAlive() then
                    return receiverSide
                end
            end
        end
    elseif event.kind=="curse" and state.curse then
        if damage(self,mon,mon.maxHP/4)>0 then b:say(mon.name.." is afflicted by the curse!") end
    elseif event.kind=="trap" and state.trap then
        if not self:trapped(mon) then state.trap=nil;return end
        local removed=damage(self,mon,mon.maxHP/16);state.trap.remaining=state.trap.remaining-1
        if removed>0 then b:say(mon.name.." is hurt by the binding!") end
        if state.trap.remaining==0 then state.trap=nil;b:say(mon.name.." was freed!") end
    elseif event.kind=="status" then
        if mon.status=="badPoison" then
            state.toxic=math.min(15,(state.toxic or 0)+1)
            if damage(self,mon,math.max(1,mon.maxHP//16)*state.toxic)>0 then b:say(mon.name.." is hurt by poison!") end
        else state.toxic=nil;b:applyStatusDamage(mon) end
    end
end

function BattleConditions:focusEnergy()
    local b=self.battle;local mon=b.attacker;local state=self:of(mon)
    if state.focusEnergy then b:say("But it failed!");return false end
    state.focusEnergy=true;b:say(mon.name .. " is getting pumped!");return true
end

-- Attraction is an identity-bound battle volatile, never a Pokemon/save field.
function BattleConditions:infatuate(target, source)
    local b = self.battle
    if not b.effects:active(target) or not b.effects:active(source)
        or target == source or not alive(target) or not alive(source) then return false end
    local a, d = target:getSex(), source:getSex()
    if a == "genderless" or d == "genderless" or a == d
        or b.effects:effectiveAbility(target) == 12 then return false end
    local state = self:of(target)
    if state.infatuation then return false end
    state.infatuation = {source=source}
    b:say(target.name .. " fell in love with " .. source.name .. "!")
    return true
end

-- BeforeMove priority2: after confusion, before paralysis and attempted PP.
function BattleConditions:infatuationBlocks(mon)
    local state = self.members[mon]
    local attraction = state and state.infatuation
    if not attraction then return false end
    local b = self.battle
    if not b.effects:active(mon) or not alive(mon)
        or not b.effects:active(attraction.source) or not alive(attraction.source)
        or b.effects:effectiveAbility(mon) == 12 then
        state.infatuation = nil
        return false
    end
    local blocked = RulesRNG.random(0, 1) == 0
    b:say(mon.name .. (blocked and " is immobilized by love!" or " is in love!"))
    return blocked
end
