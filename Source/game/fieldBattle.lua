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
    return {game=game,session=session,party=party,index=index,lead=party:get(index),requested=requested,enemy=enemy,npc=npc,enemyParty=enemyParty,
        sourceToken=session:sourceEncounterToken(enemy), zoneID=currentZone and currentZone.stableID}
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
    assert(fresh and fresh.session==plan.session and fresh.lead==plan.lead and fresh.index==plan.index and fresh.sourceToken==plan.sourceToken and fresh.zoneID==plan.zoneID,reason or "stale-field-entry")
    local state=GameSession._state(plan.session)
    local oldDex=state.dex;state.dex=Party._primitive(oldDex)
    local stages=plan.lead.statStages
    local battle,scene
    local ok,problem=pcall(function()
        plan.party:_withActiveForEntry(plan.index,function(lead)
            lead:resetStages()
            battle=Battle(lead,plan.enemy,plan.npc and plan.npc.name,{party=plan.party,session=plan.session,enemyParty=plan.enemyParty,
                sourceFieldContext=not plan.npc and {token=plan.sourceToken, zone_id=plan.zoneID} or nil})
            scene=BattleScene(battle)
        end)
    end)
    if not ok then
        state.dex=oldDex;plan.lead.statStages=stages
        if battle then
            plan.session:abortSourceBattle(battle, true)
            battle:clearListeners()
        elseif state.sourceBattle then
            plan.session:abortSourceBattle(state.sourceBattle.battle, true)
        end
        state.dex = oldDex
        error(problem,0)
    end
    return battle,scene
end

function FieldBattle.startSourceEncounter(game, request)
    if type(request) ~= "table" then return false, "source-request-required" end
    local event = game and game.machine and game.machine:get("event")
    if not event or game.machine:getCurrent() ~= "event" or event.id ~= request.id
        or not event:valid() or not event:isTop() then
        return false, "source-encounter-requires-owning-event"
    end
    local player = game.player
    if not player or player.isMoving or player.pendingEdgeDoor or player.pendingConnection
        or not game.machine:get("battle") then
        return false, "unsettled-source-encounter"
    end
    local token, enemy = game.session:prepareSourceEncounter(request,
        {zone_id=currentZone.stableID, x=player.gridX, y=player.gridY})
    if not token then return false, enemy end
    local ready, reason = FieldBattle.prepare(game, game:getPlayerPokemon(), enemy)
    if not ready then
        game.session:cancelSourceEncounter(token)
        return false, reason
    end
    local called, accepted, problem = pcall(FieldBattle.start, game, game:getPlayerPokemon(), enemy)
    if not called or not accepted then
        local current = GameSession._state(game.session).sourceBattle
        if current then game.session:abortSourceBattle(current.battle, true) end
        game.session:cancelSourceEncounter(token)
        return false, called and problem or tostring(accepted)
    end
    return true
end
function FieldBattle.attachSourceEncounter(game, battle)
    -- Construction already installed policy before the immediate intro. This
    -- compatibility seam only verifies the live binding, never applies it late.
    game.session:sourceBattlePolicy(battle)
    return true
end
function FieldBattle.resolveSourceEncounter(game, battle, won, kind)
    return game.session:resolveSourceEncounter(battle, won, kind)
end
function FieldBattle.takeSourceReceipt(game, id)
    return game.session:takeSourceReceipt(id)
end
