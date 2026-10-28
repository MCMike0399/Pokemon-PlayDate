-- Delegation only: root composes these methods into its NPCTradeState subclass.
-- Never registers a state, imports a parent controller or owns progression.
RocketHideoutStoryController = {}
local gfx <const> = playdate.graphics
local turns <const> = {down = "left", left = "up", up = "right", right = "down"}
function RocketHideoutStoryController.enter(state)
    state.hideoutScene = nil
end
function RocketHideoutStoryController.advance(state)
    if not state.plan or state.plan.scene ~= "rocket-hideout" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    local script <const> = state.plan.scene_script
    if not state.hideoutScene then
        state.hideoutScene = {index = 1, ticks = 0}
        if script == "spinner" then
            local origin <const> = state.plan.origin
            if state.player.gridX ~= origin.x + RocketHideoutStory.padding(state.zone.stableID)
                or state.player.gridY ~= origin.y then
                state:fail("outside-source-spinner")
                return true
            end
        elseif script == "poster" then
            state:source({"_GameCornerPosterSwitchBehindPosterText"}, function()
                local ok, reason = RocketHideoutStory.integration().openEntrance(state.game)
                if not ok then
                    state:fail(reason)
                    return
                end
                state:finish()
            end)
            return true
        elseif script == "elevator" then
            -- Inventory ownership is checked again at selection, after dialogue.
            state:source({"_WhichFloorText"}, function()
                state.phase, state.waiting = "hideout-floor", "floor"
                local entries <const> = RocketHideoutStory.scenes().elevator
                local labels = {}
                for _, entry in ipairs(entries) do
                    labels[#labels + 1] = entry.floor
                end
                state.menu:show(labels, state:guard(function(index)
                    state.menu:hide()
                    local ok, reason = RocketHideoutStory.selectFloor(state.session, entries[index].floor)
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
            return true
        else
            state:fail("unsupported-Hideout-scene")
            return true
        end
    end
    if script == "spinner" then
        local index <const> = state.hideoutScene.index
        local direction <const> = state.plan.path[index]
        if direction then
            state.hideoutScene.index = index + 1
            state:startMove(direction)
        else
            state:finish()
        end
    end
    return true
end
function RocketHideoutStoryController.update(state)
    if not state.hideoutScene or not state.plan or state.plan.scene_script ~= "spinner"
        or not state:valid() or not state:isTop() or state.phase ~= "move" then
        return
    end
    -- Native 8-frame cell interpolation stays in Player. Rotate reviewed stand
    -- images without modifying grids, movement reservations or collision policy.
    local scene <const> = state.hideoutScene
    scene.ticks = scene.ticks + 1
    if scene.ticks % 2 == 0 then
        scene.facing = turns[scene.facing or state.player.facing]
    end
    state.player:setImage(SpriteFactory.playerStand[scene.facing or state.player.facing])
end
function RocketHideoutStoryController.handleButton(state, button)
    if state.phase ~= "hideout-floor" or not state:valid() or not state:isTop() then
        return false
    end
    if button == "up" then
        state.menu.selectedIndex = (state.menu.selectedIndex - 2) % 3 + 1
    elseif button == "down" then
        state.menu.selectedIndex = state.menu.selectedIndex % 3 + 1
    elseif button == "a" then
        state.menu.onSelect(state.menu.selectedIndex)
    elseif button == "b" then
        state.menu.onCancel()
    end
    return true
end
function RocketHideoutStoryController.draw(state)
    if state.phase ~= "hideout-floor" or not state:valid() then
        return
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    state.menu:draw(244, 96, 140, 84)
    gfx.popContext()
end
function RocketHideoutStoryController.exit(state)
    state.hideoutScene = nil
end
