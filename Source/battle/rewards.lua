-- One actual battle owns per-foe durable EV/XP and deferred stat refresh.
-- No RNG/item acquisition, UI callbacks, trainer money or global game owner.
BattleRewards={}
local states=setmetatable({},{__mode="k"})
local plans=setmetatable({},{__mode="k"})
local growthFields={"xp","level","xpToNext","nextMoveChoiceId","pendingMoveChoices"}
local statFields={"maxHP","atk","def","spa","spd","spe"}
local function copy(v)if type(v)~="table"then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
local function same(a,b)
    if type(a)~=type(b)then return false end;if type(a)~="table"then return a==b end
    for k,v in pairs(a)do if not same(v,b[k])then return false end end
    for k in pairs(b)do if a[k]==nil then return false end end;return true
end
local function stats(mon)
    local out={hp=mon.hp}
    for _,key in ipairs(statFields)do
        local n=type(mon[key])=="number"and math.tointeger(mon[key])or nil
        assert(n and n>=1 and n<=1000000,"invalid-live-reward-stat:"..key);out[key]=n
    end
    assert(type(out.hp)=="number"and math.tointeger(out.hp)and out.hp>=0 and out.hp<=out.maxHP,"invalid-live-reward-hp")
    return out
end
local function record(mon)return assert(PokemonCodec.encode(mon))end
local function members(battle)
    if battle.party then return battle.party:members()end
    return {battle.player}
end
local function participants(battle,roster)
    local allowed={};for _,mon in ipairs(roster)do allowed[mon]=true end
    local set={};assert(type(battle.participants)=="table","invalid-reward-participants")
    for mon,value in pairs(battle.participants)do assert(allowed[mon]and value==true,"invalid-reward-participant");set[mon]=true end
    return set
end
function BattleRewards.attach(battle)
    assert(not states[battle],"reward-owner-already-attached")
    states[battle]={party=battle.party,session=battle.session,enemyParty=battle.enemyParty,count=0,deferred={},holds={},closed=false}
end
local function current(battle,foe)
    local state=assert(states[battle],"missing-reward-owner")
    assert(not state.closed and not battle.endEmitted and battle.outcome==nil,"closed-reward-owner")
    assert(battle.party==state.party and battle.session==state.session and battle.enemyParty==state.enemyParty,"stale-reward-owner")
    if state.session then assert(state.session:party()==state.party,"stale-reward-session-party")end
    assert(battle.enemy==foe and foe~=battle.player and not foe:isAlive(),"reward-requires-current-fainted-foe")
    assert(not battle.awardedEnemies[foe],"foe-already-awarded")
    assert(state.count<6,"reward-foe-capacity")
    return state
end
local function prepare(battle,foe)
    local owner=current(battle,foe)
    local roster=members(battle);assert(#roster>=1 and #roster<=6,"invalid-reward-roster")
    for _,mon in ipairs(roster)do assert(mon~=foe,"reward-foe-is-owned-member")end
    if battle.enemyParty then assert(battle.enemyParty:active()==foe,"stale-reward-foe-party")end
    local set=participants(battle,roster);local snapshots,alive={},0
    for index,mon in ipairs(roster)do
        if battle.party then assert(Party._owner(mon)==battle.party,"stale-reward-member-owner")end
        snapshots[index]={mon=mon,record=record(mon),stats=stats(mon)}
        if set[mon]and mon:isAlive()then alive=alive+1 end
    end
    local foeRecord=record(foe);local yield=IndividualStats.yieldFor(pokemonData[foe.species].dex)
    local receipt={version=1,id=owner.count+1,foe={species=foe.species,level=foe.level},trainer=battle.trainerName~=nil,
        eligible=alive,yield=copy(yield),rows={}}
    local entries,holds={},{}
    for index,value in ipairs(snapshots)do
        local mon=value.mon
        if set[mon]and mon:isAlive()then
            local ev,delta,wasted=IndividualStats.addEffort(mon.evs,yield)
            local candidateRecord=copy(value.record);candidateRecord.evs=ev
            local candidate=assert(PokemonCodec.decode(candidateRecord))
            -- Codec reconstructs canonical field stats. Actual no-level battle
            -- stats must remain the source snapshot until return/level gain.
            candidate.hp=value.stats.hp
            for _,key in ipairs(statFields)do candidate[key]=value.stats[key]end
            local amount=mon:calcExpGain(foe,battle.trainerName~=nil,alive)
            local leveled,result=candidate:gainXP(amount) -- actual production bounds/choices, detached only.
            record(candidate) -- No fallible candidate validation follows commit.
            local changed=false;for _,n in pairs(delta)do if n~=0 then changed=true end end
            local deferred=not leveled and (changed or owner.deferred[mon]~=nil)
            local row={index=index,species=mon.species,xp=result.gained,fromLevel=result.fromLevel,toLevel=result.toLevel,
                levels=copy(result.levels),moveChoices=copy(result.moveChoices),yield=copy(yield),evDelta=delta,evWasted=wasted,
                evsBefore=copy(mon.evs),evsAfter=copy(ev),before=copy(value.stats),after=stats(candidate),leveled=leveled,deferred=deferred}
            if result.gained>0 then holds[mon]={level=mon.level,hp=value.stats.hp,maxHP=value.stats.maxHP,id=receipt.id,index=index}end
            receipt.rows[#receipt.rows+1]=row
            entries[#entries+1]={mon=mon,candidate=candidate,evs=ev,deferred=deferred,index=index}
        end
    end
    local token={};plans[token]={owner=battle,foe=foe,state=owner,count=owner.count,roster=roster,participants=set,
        player=battle.player,active=battle.party and battle.party:activeIndex() or 1,trainerName=battle.trainerName,
        phase=battle.machine:getCurrent(),co=battle.machine:get("script").co,
        snapshots=snapshots,foeRecord=foeRecord,foeStats=stats(foe),rng=RulesRNG.snapshot(),marker=battle.awardedEnemies[foe],
        entries=entries,holds=holds,receipt=receipt,status="prepared"}
    return token
end
function BattleRewards.prepare(battle,foe)
    local ok,result=pcall(prepare,battle,foe);if not ok then return nil,tostring(result)end;return result
end
local function validate(battle,plan)
    assert(plan and plan.owner==battle and plan.status=="prepared","invalid-reward-plan")
    local state=current(battle,plan.foe)
    assert(state==plan.state and state.count==plan.count and battle.awardedEnemies[plan.foe]==plan.marker,"stale-reward-generation")
    assert(same(RulesRNG.snapshot(),plan.rng),"stale-reward-rng")
    assert(battle.player==plan.player and (not battle.party or battle.party:activeIndex()==plan.active)
        and battle.trainerName==plan.trainerName and battle.machine:getCurrent()==plan.phase
        and battle.machine:get("script").co==plan.co,"stale-reward-script-owner")
    local roster=members(battle);assert(#roster==#plan.roster,"stale-reward-roster")
    for index,mon in ipairs(roster)do
        local old=plan.snapshots[index]
        assert(mon==old.mon and (not battle.party or Party._owner(mon)==battle.party),"stale-reward-member")
        assert(same(record(mon),old.record)and same(stats(mon),old.stats),"stale-reward-member-record")
    end
    local set=participants(battle,roster)
    for mon in pairs(set)do assert(plan.participants[mon],"stale-reward-participants")end
    for mon in pairs(plan.participants)do assert(set[mon],"stale-reward-participants")end
    assert(same(record(plan.foe),plan.foeRecord)and same(stats(plan.foe),plan.foeStats),"stale-reward-foe")
    return state
end
function BattleRewards.commit(battle,token)
    local plan=plans[token]
    local ok,state=pcall(validate,battle,plan);if not ok then
        if plan and plan.owner==battle then plan.status="rejected"end
        return false,tostring(state)
    end
    -- All recipients and final records were prepared and revalidated. The
    -- retained objects receive plain assignments only; no yields/callback/RNG.
    for _,entry in ipairs(plan.entries)do entry.mon.evs=entry.evs end -- ALL EVs precede any XP.
    for _,entry in ipairs(plan.entries)do
        local mon,candidate=entry.mon,entry.candidate
        for _,key in ipairs(growthFields)do mon[key]=candidate[key]end
        mon.pendingEvolution=candidate.pendingEvolution
        mon.hp=candidate.hp
        for _,key in ipairs(statFields)do mon[key]=candidate[key]end
        state.deferred[mon]=entry.deferred and entry.index or nil
    end
    battle.awardedEnemies[plan.foe]=true;battle.xpAwarded=true
    state.count=state.count+1;state.latest=plan.receipt;state.latestRoster=plan.roster;state.holds=plan.holds;plan.status="complete"
    return true,copy(plan.receipt)
end
function BattleRewards.flush(battle)
    local owner=states[battle];if not owner then return true end
    local ok,prepared=pcall(function()
        local out={}
        for mon in pairs(owner.deferred)do
            record(mon)
            local value=mon:calculatedStats();value.hp=IndividualStats.hpAfterRecalc(mon.hp,mon.maxHP,value.maxHP)
            out[#out+1]={mon=mon,value=value}
        end
        return out
    end)
    if not ok then return false,tostring(prepared)end
    for _,entry in ipairs(prepared)do
        entry.mon.hp=entry.value.hp
        for _,key in ipairs(statFields)do entry.mon[key]=entry.value[key]end
        owner.deferred[entry.mon]=nil
    end
    owner.holds={}
    return true
end
function BattleRewards.close(battle)
    local ok,why=BattleRewards.flush(battle);if not ok then return false,why end
    local owner=states[battle];if owner then owner.closed=true end;return true
end
-- HUD-only scalar reads. No allocation/RNG/update/authoritative model override.
function BattleRewards.presentationVitals(battle,mon)
    local owner=states[battle];local held=owner and not owner.closed and owner.holds[mon]
    if held then return held.level,held.hp,held.maxHP end
    return mon.level,mon.hp,mon.maxHP
end
function BattleRewards.acknowledge(battle,id,index)
    local owner=states[battle]
    if not owner or owner.closed or not owner.latest or owner.latest.id~=id then return false,"stale-reward-presentation"end
    local mon=owner.latestRoster[index];local held=mon and owner.holds[mon]
    if not held or held.id~=id or held.index~=index or (battle.party and battle.party:get(index)~=mon)then return false,"stale-reward-presentation"end
    owner.holds[mon]=nil;return true
end
function BattleRewards.snapshot(battle)
    local owner=states[battle];if not owner then return {version=1,present=false}end
    local deferred,holds={},{}
    for index,mon in ipairs(members(battle))do
        if owner.deferred[mon]then deferred[#deferred+1]={index=owner.deferred[mon],species=mon.species}end
        local held=owner.holds[mon];if held then holds[#holds+1]={index=index,level=held.level,hp=held.hp,maxHP=held.maxHP}end
    end
    return {version=1,present=true,closed=owner.closed,awards=owner.count,deferred=deferred,holds=holds,latest=owner.latest and copy(owner.latest)or nil}
end
