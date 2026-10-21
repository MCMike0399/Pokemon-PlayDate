-- Admission policy for NEW field battles only. Rules/forced replacement/learning
-- keep the existing active battler; no roster sorting or random sampling here.
FieldBattle={}
function FieldBattle.prepare(game,requested,enemy,npc,enemyParty)
    if not game or not game.session then return nil,"missing-session" end
    local session=game.session;local party=session:party()
    if requested~=party:active() then return nil,"stale-player" end
    local index=party:firstUsable()
    if not index then return nil,"no-usable-pokemon" end
    if not Party._validPokemon(enemy)or not enemy:isAlive()then return nil,"invalid-enemy"end
    if npc and(type(npc)~="table"or type(npc.name)~="string")then return nil,"invalid-trainer"end
    if enemyParty and(not npc or type(enemyParty.is)~="function"or not enemyParty:is("Party")or enemyParty:active()~=enemy)then return nil,"invalid-enemy-party"end
    return {game=game,session=session,party=party,index=index,lead=party:get(index),requested=requested,enemy=enemy,npc=npc,enemyParty=enemyParty}
end
function FieldBattle.start(game,requested,enemy,npc,enemyParty)
    local plan,reason=FieldBattle.prepare(game,requested,enemy,npc,enemyParty)
    if not plan then return false,reason end
    if not game.machine:get("battle")then return false,"battle-state-not-registered"end
    game.machine:change("battle",requested,enemy,npc,enemyParty)
    return true
end
function FieldBattle.construct(plan)
    local fresh,reason=FieldBattle.prepare(plan.game,plan.requested,plan.enemy,plan.npc,plan.enemyParty)
    assert(fresh and fresh.session==plan.session and fresh.lead==plan.lead and fresh.index==plan.index,reason or "stale-field-entry")
    local state=GameSession._state(plan.session)
    local oldDex=state.dex;state.dex=Party._primitive(oldDex)
    local stages=plan.lead.statStages
    local battle,scene
    local ok,problem=pcall(function()
        plan.party:_withActiveForEntry(plan.index,function(lead)
            lead:resetStages()
            battle=Battle(lead,plan.enemy,plan.npc and plan.npc.name,{party=plan.party,session=plan.session,enemyParty=plan.enemyParty})
            scene=BattleScene(battle)
        end)
    end)
    if not ok then
        state.dex=oldDex;plan.lead.statStages=stages
        if battle then battle:clearListeners()end
        error(problem,0)
    end
    return battle,scene
end
