-- Root's one final event controller delegates here, then to its existing chain.
-- These are temporary event actions, not a saved scene phase or dispatcher.
TowerStoryController = {}
local function queue(state, action)
    assert(#state.towerScene.actions < 32, "bounded Tower scene required")
    state.towerScene.actions[#state.towerScene.actions + 1] = action
end
local function text(state, labels)
    queue(state, function()
        state:source(labels, function()
            state:advance()
        end)
    end)
end
local function launch(state, request, reason)
    if not request then
        state:fail(reason)
        return
    end
    -- This API belongs in root's existing FieldBattle owner. Missing integration
    -- is an explicit failure, never a fabricated win or ordinary wild fallback.
    if not FieldBattle.startSourceEncounter then
        state:fail("missing-root-scripted-wild-api")
        return
    end
    local ok
    ok, reason = FieldBattle.startSourceEncounter(state.game, request)
    if not ok then
        state:fail(reason)
    end
end
function TowerStoryController.enter(state)
    state.towerScene = nil
end
local function rocketExit(state)
    local id <const> = state.id
    local descriptor <const> = assert(SourceEvents.descriptor(id))
    local receipt <const> = state.plan.confirmed_receipt
    if receipt then
        assert(receipt.id == id and receipt.won and state.session:trainerDefeated(id), "unconfirmed Tower trainer receipt")
        text(state, descriptor.won)
        text(state, {"_MoneyForWinningText"})
    end
    text(state, descriptor.after)
    local variant <const> = TowerStory.variant(id, state.player.gridX - TowerStory.padding(state.zone.stableID), state.player.gridY)
    if not variant then
        queue(state, function()
            state:fail("outside-source-Tower-Rocket-coordinate-table")
        end)
        return
    end
    -- TrainerEvents has already restored its actual completed approach pose.
    -- Never teleport it to a guessed start or create an untracked temporary NPC.
    queue(state, function()
        for _, actor in ipairs(state.game.npcManager.npcs) do
            if actor.def and actor.def.source_event_id == id then
                if actor.gridX ~= variant.origin.x + TowerStory.padding(state.zone.stableID)
                    or actor.gridY ~= variant.origin.y then
                    state:fail("source-Tower-Rocket-return-pose-mismatch")
                    return
                end
                state:advance()
                return
            end
        end
        state:fail("absent-source-Tower-Rocket")
    end)
    for _, direction in ipairs(variant.path) do
        local facing <const> = direction
        queue(state, function()
            state:startNPCMove({id = id, direction = facing})
        end)
    end
    queue(state, function()
        local flag <const> = TowerStory.departureFlag(id)
        local ok, reason = state.session:transact({flags = {[flag] = false}, trainers = {[id] = true}, items = {}},
            {flags = {[flag] = true}, items = {}})
        if not ok then
            state:fail(reason)
            return
        end
        state.towerScene.departed = true
        state:cancelNPCMove()
        TowerStory.integration().reconcileActors(state.game)
        state:advance()
    end)
end
local function rival(state, returning)
    local spec = TowerStory.scenes().rival
    local trigger
    for _, point in ipairs(spec.triggers) do
        if state.player.gridX == point.x + TowerStory.padding(state.zone.stableID) and state.player.gridY == point.y then
            trigger = point
        end
    end
    if not returning then
        queue(state, function()
            if trigger then
                local flag = "EVENT_POKEMON_TOWER_RIVAL_ON_LEFT"
                local ok, reason = state.session:transactSourceEffects({flags = {[flag] = state.session:questFlag(flag)}},
                    {flags = {[flag] = trigger.left}})
                if not ok then
                    state:fail(reason)
                    return
                end
                state.player.facing = trigger.player_facing
                state.player:updateSprite()
            end
            local npc
            for _, candidate in ipairs(state.game.npcManager.npcs) do
                if candidate.def and candidate.def.source_event_id == state.id then
                    npc = candidate
                end
            end
            if not npc then
                state:fail("absent-source-Tower-rival")
                return
            end
            local owner = state.game.npcManager.motion
            local lease, reason = owner:claimScript(npc, state)
            if not lease then
                state:fail(reason)
                return
            end
            local facing = trigger and trigger.actor_facing or npc.facing
            local faced = owner:faceScript(lease, facing)
            owner:releaseScript(lease)
            if not faced then
                state:fail("invalid-source-Tower-rival-facing")
                return
            end
            state:startTrainer({id = state.id, mode = "talk", before = {"_PokemonTower2FRivalWhatBringsYouHereText"}})
        end)
        return
    end
    if state.plan.confirmed_receipt then
        assert(state.plan.confirmed_receipt.id == state.id and state.plan.confirmed_receipt.won,
            "confirmed Tower rival receipt required")
        text(state, {"_PokemonTower2FRivalDefeatedText", "_MoneyForWinningText"})
    end
    text(state, {"_PokemonTower2FRivalHowsYourDexText"})
    local path = state.session:questFlag("EVENT_POKEMON_TOWER_RIVAL_ON_LEFT") and spec.paths.left or spec.paths.below
    for _, direction in ipairs(path) do
        local facing = direction
        queue(state, function()
            state:startNPCMove({id = state.id, direction = facing})
        end)
    end
    queue(state, function()
        local ok, reason = state.session:transact({flags = {[TowerStory.RIVAL_LEFT] = false},
            trainers = {[state.id] = true}, items = {}}, {flags = {[TowerStory.RIVAL_LEFT] = true}, items = {}})
        if not ok then
            state:fail(reason)
            return
        end
        state.towerScene.departed = true
        state:cancelNPCMove()
        TowerStory.integration().reconcileActors(state.game)
        state:advance()
    end)
end
local function prepare(state)
    local script <const> = state.plan.scene_script
    if script == "tower-rival" or script == "tower-rival-exit" then
        rival(state, script == "tower-rival-exit")
    elseif script == "rocket-exit" then
        rocketExit(state)
    elseif script == "ghost" then
        text(state, {"_PokemonTower6FBeGoneText"})
        queue(state, function()
            launch(state, TowerStory.ghostRequest(state.session))
        end)
    elseif script == "ghost-return" then
        local receipt <const> = state.plan.source_receipt
        assert(receipt.id == TowerStory.GHOST and receipt.confirmed, "confirmed ghost result required")
        if receipt.kind == "victory" and receipt.completed then
            assert(state.session:questFlag("EVENT_BEAT_GHOST_MAROWAK"), "uncommitted ghost result")
            text(state, {"_PokemonTower6FGhostWasCubonesMotherText", "_PokemonTower6FSoulWasCalmedText"})
        elseif receipt.kind == "run" or not receipt.completed then
            queue(state, function()
                state:startMove("right")
            end)
        else
            queue(state, function()
                state:fail("unexpected-source-ghost-return")
            end)
        end
    elseif script == "snorlax" then
        local definition <const> = assert(SnorlaxStory.definition(state.id))
        text(state, {"_PlayedFluteHadEffectText", definition.woke_text})
        queue(state, function()
            launch(state, SnorlaxStory.request(state.session, state.id))
        end)
    elseif script == "snorlax-return" then
        local receipt <const> = state.plan.source_receipt
        local definition <const> = assert(SnorlaxStory.definition(state.id))
        assert(receipt.id == state.id and receipt.confirmed and receipt.kind ~= "defeat", "confirmed Snorlax result required")
        assert(state.session:questFlag(definition.defeated_flag), "uncommitted Snorlax removal")
        if receipt.kind ~= "caught" then
            text(state, {definition.after_text})
        end
        queue(state, function()
            TowerStory.integration().reconcileActors(state.game)
            state:advance()
        end)
    else
        queue(state, function()
            state:fail("unsupported-Tower-source-scene")
        end)
    end
end
function TowerStoryController.advance(state)
    if not state.plan or state.plan.scene ~= "tower-story" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if not state.towerScene then
        state.towerScene = {actions = {}, index = 1}
        prepare(state)
    end
    local scene <const> = state.towerScene
    local action <const> = scene.actions[scene.index]
    scene.index = scene.index + 1
    if action then
        action()
    else
        state:finish()
    end
    return true
end
function TowerStoryController.exit(state)
    if state.towerScene and not state.towerScene.departed then
        -- A failed/cancelled source departure must be replayable from its source
        -- approach pose. Trainer victory remains in its atomic durable owner.
        for _, lease in pairs(state.npcLeases or {}) do
            state.game.npcManager.motion:releaseScript(lease, true)
        end
        state.npcLeases, state.npcMove = {}, nil
    end
    state.towerScene = nil
end
