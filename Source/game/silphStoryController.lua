-- Finite source actions delegated by root's existing final event controller.
SilphStoryController = {}
local gfx <const> = playdate.graphics
local function queue(state, callback)
    assert(#state.silphScene.actions < 32, "bounded Silph scene required")
    state.silphScene.actions[#state.silphScene.actions + 1] = callback
end
local function text(state, labels)
    queue(state, function()
        state:source(labels, function()
            state:advance()
        end)
    end)
end
local function actor(state, id)
    for _, npc in ipairs(state.game.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then
            return npc
        end
    end
end
local function place(state, id, point, facing)
    queue(state, function()
        local npc <const> = actor(state, id)
        if not npc then
            state:fail("absent-source-Silph-actor")
            return
        end
        local owner <const> = state.game.npcManager.motion
        local lease, reason = state.npcLeases[id]
        if not lease then
            lease, reason = owner:claimScript(npc, state)
            if not lease then
                state:fail(reason)
                return
            end
            state.npcLeases[id] = lease
        end
        local x <const> = point.x + SilphStory.padding(state.zone.stableID)
        local ok
        if npc.gridX == x and npc.gridY == point.y then
            ok = owner:faceScript(lease, facing)
        else
            ok, reason = owner:placeScript(lease, x, point.y, facing)
        end
        if not ok then
            state:fail(reason or "invalid-source-Silph-facing")
            return
        end
        state:advance()
    end)
end
local function path(state, id, directions)
    for _, direction in ipairs(directions) do
        local facing <const> = direction
        queue(state, function()
            state:startNPCMove({id = id, direction = facing})
        end)
    end
end
local function facePlayer(state, direction)
    queue(state, function()
        state.player.facing = direction
        state.player:updateSprite()
        state:advance()
    end)
end
local function beginTrainer(state)
    queue(state, function()
        -- The source already printed pre-battle text before actor motion.
        -- Use the existing trainer owner directly rather than print it twice.
        state:cancelNPCMove()
        local npc <const> = actor(state, state.id)
        if not npc then
            state:fail("absent-Silph-trainer")
            return
        end
        local token, reason = state.game.trainers:prepare(npc, "talk", state)
        if not token then
            state:fail(reason)
            return
        end
        state.trainerToken, state.trainerNPC = token, npc
        local ready
        ready, reason = state.game.trainers:updateApproach(token)
        if not ready then
            state:fail(reason)
            return
        end
        local party
        party, reason = state.game.trainers:launch(token)
        if not party then
            state:fail(reason)
            return
        end
        state.trainerLaunching = true
        local ok
        ok, reason = FieldBattle.start(state.game, state.game:getPlayerPokemon(), party:active(), npc, party)
        if not ok then
            state.trainerLaunching = false
            state:fail(reason)
        end
    end)
end
local function rival(state, returning)
    local spec <const> = SilphStory.scenes().rival
    local variant <const> = SilphStory.variant(state.id,
        state.player.gridX - SilphStory.padding(state.zone.stableID), state.player.gridY)
    if not variant then
        if returning then
            queue(state, function()
                state:fail("outside-source-Silph-rival-trigger")
            end)
        else
            text(state, {"_SilphCo7FRivalText"})
        end
        return
    end
    facePlayer(state, "down")
    if returning then
        if state.plan.confirmed_receipt then
            text(state, {"_SilphCo7FRivalDefeatedText", "_MoneyForWinningText"})
        end
        text(state, {"_SilphCo7FRivalGoodLuckToYouText"})
        place(state, state.id, variant.battle_pose, "up")
        path(state, state.id, variant.departure)
        queue(state, function()
            local ok, reason = state.session:transact({flags = {[SilphStory.RIVAL_LEFT] = false},
                trainers = {[state.id] = true}, items = {}}, {flags = {[SilphStory.RIVAL_LEFT] = true}, items = {}})
            if not ok then
                state:fail(reason)
                return
            end
            state.silphScene.departed = true
            state:cancelNPCMove()
            SilphStory.integration().reconcileActors(state.game)
            state:advance()
        end)
    else
        text(state, {"_SilphCo7FRivalText"})
        place(state, state.id, spec.origin, "up")
        path(state, state.id, variant.approach)
        text(state, {"_SilphCo7FRivalWaitedHereText"})
        beginTrainer(state)
    end
end
local function giovanni(state, returning)
    local spec <const> = SilphStory.scenes().giovanni
    local variant <const> = SilphStory.variant(state.id,
        state.player.gridX - SilphStory.padding(state.zone.stableID), state.player.gridY)
    if not variant then
        if returning then
            queue(state, function()
                state:fail("outside-source-Silph-Giovanni-trigger")
            end)
        else
            text(state, {"_SilphCo11FGiovanniText"})
        end
        return
    end
    if returning then
        if state.plan.confirmed_receipt then
            text(state, {"_SilphCo11FGiovanniILostAgainText", "_MoneyForWinningText"})
        end
        facePlayer(state, variant.player_facing)
        place(state, state.id, spec.battle_pose, variant.actor_facing)
        text(state, {"_SilphCo11FGiovanniYouRuinedOurPlansText"})
        queue(state, function()
            state.silphScene.departed = true
            state:cancelNPCMove()
            SilphStory.integration().reconcileActors(state.game)
            state:advance()
        end)
    else
        text(state, {"_SilphCo11FGiovanniText"})
        place(state, state.id, spec.origin, "down")
        path(state, state.id, spec.approach)
        facePlayer(state, variant.player_facing)
        place(state, state.id, spec.battle_pose, variant.actor_facing)
        beginTrainer(state)
    end
end
local function prepare(state)
    local script <const> = state.plan.scene_script
    if script == "rival" or script == "rival-exit" then
        rival(state, script == "rival-exit")
    elseif script == "giovanni" or script == "giovanni-exit" then
        giovanni(state, script == "giovanni-exit")
    elseif script == "door" then
        text(state, {"_CardKeySuccessText1", "_CardKeySuccessText2"})
        queue(state, function()
            local ok, reason = SilphStoryWorld.unlock(state.game, state.id)
            if not ok then
                state:fail(reason)
                return
            end
            state:advance()
        end)
    elseif script == "elevator" then
        text(state, {"_WhichFloorText"})
        queue(state, function()
            state.phase, state.waiting = "silph-floor", "floor"
            local labels = {}
            for _, entry in ipairs(SilphStory.scenes().elevator) do
                labels[#labels + 1] = tostring(entry.floor) .. "F"
            end
            state.menu:show(labels, state:guard(function(index)
                state.menu:hide()
                local ok, reason = SilphStoryWorld.selectFloor(state.session, index)
                if ok then
                    state:finish()
                else
                    state:fail(reason)
                end
            end), state:guard(function()
                state.menu:hide()
                state:finish()
            end))
        end)
    elseif script == "lapras" then
        text(state, {"_SilphCo7FSilphWorkerM1HaveThisPokemonText"})
        queue(state, function()
            local accepted, result = state.session:purchaseGiftPokemon({species = "lapras", level = 15,
                price = 0, flag = "BIT_GOT_LAPRAS"}, state.session:inventory():money())
            if not accepted then
                if result == "box-full" then
                    state:source({"_BoxIsFullText"}, function()
                        state:finish()
                    end)
                else
                    state:fail(result)
                end
                return
            end
            state.committed = true
            state.plan.ram = {wNameBuffer = "LAPRAS", wBoxMonNicks = "LAPRAS", wStringBuffer = tostring(result.box or 1)}
            state:source({result.destination == "storage" and "_SentToBoxText" or "_GotMonText",
                "_SilphCo7FSilphWorkerM1LaprasDescriptionText"}, function()
                state:advance()
            end)
        end)
    elseif script == "nurse" then
        text(state, {"SilphCo9FNurseYouLookTiredText"})
        queue(state, function()
            state.session:party():healAll()
            state:advance()
        end)
        text(state, {"SilphCo9FNurseDontGiveUpText"})
    else
        queue(state, function()
            state:fail("unsupported-source-Silph-scene")
        end)
    end
end
function SilphStoryController.enter(state)
    state.silphScene = nil
end
function SilphStoryController.advance(state)
    if not state.plan or state.plan.scene ~= "silph-story" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if not state.silphScene then
        state.silphScene = {actions = {}, index = 1}
        prepare(state)
    end
    local scene <const> = state.silphScene
    local action <const> = scene.actions[scene.index]
    scene.index = scene.index + 1
    if action then
        action()
    else
        state:finish()
    end
    return true
end
function SilphStoryController.handleButton(state, button)
    if not state:valid() or not state:isTop() or state.phase ~= "silph-floor" then
        return false
    end
    if button == "up" then
        state.menu.selectedIndex = (state.menu.selectedIndex - 2) % 11 + 1
    elseif button == "down" then
        state.menu.selectedIndex = state.menu.selectedIndex % 11 + 1
    elseif button == "a" then
        state.menu.onSelect(state.menu.selectedIndex)
    elseif button == "b" then
        state.menu.onCancel()
    end
    return true
end
function SilphStoryController.draw(state)
    if not state:valid() or state.phase ~= "silph-floor" then
        return
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    state.menu:draw(244, 60, 140, 116)
    gfx.popContext()
end
function SilphStoryController.exit(state)
    if state.silphScene and not state.silphScene.departed then
        for _, lease in pairs(state.npcLeases or {}) do
            state.game.npcManager.motion:releaseScript(lease, true)
        end
        state.npcLeases, state.npcMove = {}, nil
    end
    state.silphScene = nil
end
