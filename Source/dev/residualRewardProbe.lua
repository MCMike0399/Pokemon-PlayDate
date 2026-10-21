-- Deliberately strict diagnostic. Current immediate per-member XP is expected
-- originally FAILED these witnesses. Expected fields remain unchanged; only
-- observation identities were separated and valid controlled records preflighted.
ResidualRewardProbe={}
local function own(mon,moves)mon.moves,mon.pp={},{};for i,key in ipairs(moves)do mon.moves[i]=key;mon.pp[key]=moveData[key].maxPP end end
local function settle(b)
    local n=0
    while b:phase()=="script"do
        n=n+1;assert(n<300,"diagnostic script timeout")
        if b:getLearningSnapshot().pending then
            local receipt,mon=b:takeLearningRequest();assert(receipt)
            while #mon:getPendingMoveChoices()>0 do assert(mon:resolveMoveChoice(mon:getPendingMoveChoices()[1].id,"decline"))end
            assert(b:resumeLearning(receipt))
        else assert(b.machine:get("script"):advance())end
    end
end
function ResidualRewardProbe.run()
    local report={ok=true,passed=0,failed=0,tests={},diagnostic="native-condition-exp-boundary",observation_version=2,observations={}}
    local before=RulesRNG.snapshot()
    for _,level in ipairs({6,50})do
        local p,q=Pokemon("squirtle",level),Pokemon("charmander",5)
        if level==6 then p.xp=p:xpForLevel(7)-1 end
        local e,z=Pokemon("pidgey",level),Pokemon("rattata",5)
        own(p,{"tailWhip"});own(e,{"growl"});own(z,{"growl"})
        local party,foes=Party(),Party();assert(party:add(p));assert(party:add(q));assert(foes:add(e));assert(foes:add(z))
        local b=Battle(p,e,"RESIDUAL DIAGNOSTIC",{party=party,enemyParty=foes});settle(b)
        p.hp,e.hp,p.status,e.status=1,1,"poison","poison"
        local xp=p.xp;local start={level=p.level,xp=xp,hp=p.hp,maxHP=p.maxHP,speed=p.spe,enemy_speed=e.spe,enemy_maxHP=e.maxHP}
        assert(e.spe>p.spe,"witness requires naturally faster enemy")
        for _,mon in ipairs({p,q,e,z})do assert(PokemonCodec.encode(mon))end
        local ok,why=pcall(function()b:runScript(function()return b:finishRound()end);settle(b)end)
        local observed={input=start,player_hp=p.hp,player_level=p.level,player_xp=p.xp,player_evs=p:individuals().evs,
            defeated_enemy={species=e.species,hp=e.hp},active_enemy={species=b.enemy.species,hp=b.enemy.hp},
            reserves={player={species=q.species,hp=q.hp},enemy={species=z.species,hp=z.hp}},phase=b:phase(),outcome=b.outcome or "none",
            expected={player_hp=0,player_level=level,player_xp=xp,player_evs=IndividualStats.zero(),phase="forcedSwitch"}}
        report.observations[#report.observations+1]=observed
        local match=ok and p.hp==0 and p.level==level and p.xp==xp and b:phase()=="forcedSwitch"
        for _,key in ipairs({"hp","atk","def","spa","spd","spe"})do match=match and p.evs[key]==0 end
        local name=level==6 and "native condition boundary: no early level-heal before later poisoned member"or "native condition boundary: no early XP/EV to later-fainted no-level participant"
        report.tests[#report.tests+1]={name=name,ok=match,error=not match and ("observed="..json.encode(observed)..(not ok and " runtime="..tostring(why)or ""))or nil}
        if match then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
        b:clearVolatiles()
    end
    RulesRNG.restore(before);return report
end
