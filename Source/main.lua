import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/shade"
import "lib/statemachine"
import "world/zone"
import "data/pokemon"
import "data/typechart"
import "battle/moves"
import "ui/dialog"
import "ui/menu"
import "ui/debug"
import "world/camera"
import "world/npc"
import "world/player"
import "world/tilefactory"
import "world/overworld"
import "battle/battle"
import "battle/battleScene"
import "data/maps"

local gfx <const> = playdate.graphics

playdate.display.setRefreshRate(30)

-- Game objects
local gameStateMachine = StateMachine()
npcManager = NPCManager()
local camera = Camera()
local player = nil
local dialog = nil
local currentBattle = nil
local battleScene = nil
local playerPokemon = nil
local debugMenu = DebugMenu()

-- Iris-out transition state
local irisOut = { active = false, timer = 0, duration = 15, cx = 0, cy = 0, callback = nil }

local function startIrisOut(cx, cy, callback)
    irisOut.active = true
    irisOut.timer = 0
    irisOut.cx = cx
    irisOut.cy = cy
    irisOut.callback = callback
end

-- Add debug menu to Playdate system menu
local sysMenu = playdate.getSystemMenu()
sysMenu:addMenuItem("Debug", function()
    if gameStateMachine:getCurrent() == "overworld" then
        gameStateMachine:change("debug")
    end
end)

-- ============================================================
-- OVERWORLD STATE
-- ============================================================
gameStateMachine:register("overworld", {
    enter = function()
        gfx.sprite.removeAll()
        setupOverworld()

        local spawn = currentZone.spawn
        player = Player(spawn.x, spawn.y, currentZone.collision)

        -- Zone spawns its own NPCs
        currentZone:spawnNPCs(npcManager)

        -- Create player pokemon (only if not already created)
        if not playerPokemon then
            playerPokemon = Pokemon("squirtle", 5)
        end

        -- Snap camera to player immediately
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:snapTo(px, py, mw, mh)
    end,

    exit = function() end,

    update = function()
        -- Iris-out transition
        if irisOut.active then
            irisOut.timer = irisOut.timer + 1
            playdate.frameTimer.updateTimers()
            local px, py = player:getPixelCenter()
            local mw, mh = getMapPixelSize()
            camera:follow(px, py, mw, mh)
            camera:apply()
            gfx.sprite.update()

            camera:reset()
            local maxRadius = 260
            local progress = irisOut.timer / irisOut.duration
            local radius = math.floor(maxRadius * (1 - progress))

            if radius > 0 then
                local stencilImg = gfx.image.new(400, 240, gfx.kColorWhite)
                gfx.pushContext(stencilImg)
                    gfx.setColor(gfx.kColorBlack)
                    gfx.fillCircleAtPoint(irisOut.cx, irisOut.cy, radius)
                gfx.popContext()
                gfx.setStencilImage(stencilImg)
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(0, 0, 400, 240)
                gfx.clearStencil()
            else
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(0, 0, 400, 240)
            end
            camera:apply()

            if irisOut.timer >= irisOut.duration then
                irisOut.active = false
                if irisOut.callback then irisOut.callback() end
            end
            return
        end

        -- Handle input
        if not player.isMoving then
            if playdate.buttonIsPressed(playdate.kButtonUp) then
                player:tryMove(0, -1)
            elseif playdate.buttonIsPressed(playdate.kButtonDown) then
                player:tryMove(0, 1)
            elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
                player:tryMove(-1, 0)
            elseif playdate.buttonIsPressed(playdate.kButtonRight) then
                player:tryMove(1, 0)
            end

            -- A button: interact with NPC
            if playdate.buttonJustPressed(playdate.kButtonA) then
                local fx, fy = player:getFacingTile()
                local npc = npcManager:getNPCAt(fx, fy)
                if npc then
                    local lines = npc:getDialogLines()
                    if npc.battleData and not npc.interacted then
                        gameStateMachine:change("dialog", lines, function()
                            local enemyPokemon = Pokemon(npc.battleData.species, npc.battleData.level)
                            gameStateMachine:change("battle", playerPokemon, enemyPokemon, npc)
                        end)
                    else
                        gameStateMachine:change("dialog", lines, function()
                            gameStateMachine:change("overworld")
                        end)
                    end
                    return
                end
            end
        end

        -- Wild encounter check (delegated to Zone)
        if player.stepJustFinished then
            if currentZone:checkEncounter(player.gridX, player.gridY) then
                local px, py = player:getPixelCenter()
                local ox, oy = gfx.getDrawOffset()
                startIrisOut(px + ox, py + oy, function()
                    gameStateMachine:change("battle", playerPokemon, currentZone:rollEncounter(), nil)
                end)
            end
        end

        playdate.frameTimer.updateTimers()

        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()

        gfx.sprite.update()
    end,

    draw = function() end
})

-- ============================================================
-- DIALOG STATE
-- ============================================================
gameStateMachine:register("dialog", {
    enter = function(lines, onComplete)
        dialog = Dialog()
        dialog:show(lines, onComplete)
    end,

    exit = function() dialog = nil end,

    update = function()
        playdate.frameTimer.updateTimers()
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()
        gfx.sprite.update()

        camera:reset()
        dialog:update()
        dialog:draw()
        dialog:handleInput()
        camera:apply()
    end,

    draw = function() end
})

-- ============================================================
-- BATTLE STATE
-- ============================================================
local battleNPC = nil

gameStateMachine:register("battle", {
    enter = function(playerPkmn, enemyPkmn, npc)
        battleNPC = npc
        gfx.sprite.removeAll()
        camera:reset()
        playerPkmn:resetStages()

        currentBattle = Battle(playerPkmn, enemyPkmn)
        battleScene = BattleScene(currentBattle)

        currentBattle:on("battleEnd", function(won)
            if won and battleNPC then battleNPC.interacted = true end
            playerPokemon.status = nil
            playerPokemon.statusTurns = 0
            gameStateMachine:change("overworld")
        end)
    end,

    exit = function()
        playdate.display.setOffset(0, 0)
        currentBattle = nil
        battleScene = nil
        battleNPC = nil
    end,

    update = function()
        camera:reset()
        battleScene:draw()
        battleScene:handleInput()
    end,

    draw = function() end
})

-- ============================================================
-- DEBUG STATE
-- ============================================================
gameStateMachine:register("debug", {
    enter = function()
        camera:reset()
        debugMenu:open(function()
            local action = debugMenu:consumeAction()
            if action and action.type == "wildBattle" then
                gameStateMachine:change("battle", playerPokemon, Pokemon(action.species, action.level), nil)
                return
            end
            if action and action.type == "zoneSwitch" then
                switchZone(action.zone)
                gameStateMachine:change("overworld")
                return
            end
            gameStateMachine:change("overworld")
        end)
    end,

    exit = function() end,

    update = function()
        playdate.frameTimer.updateTimers()
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()
        gfx.sprite.update()

        local action = debugMenu:consumeAction()
        if action then
            if action.type == "heal" and playerPokemon then
                playerPokemon:fullRestore()
            elseif action.type == "resetNPCs" then
                for _, npc in ipairs(npcManager.npcs) do npc.interacted = false end
            elseif action.type == "setLevel" and playerPokemon then
                playerPokemon = Pokemon(playerPokemon.species, action.level)
            elseif action.type == "warp" and player then
                player.gridX = action.x
                player.gridY = action.y
                player:moveTo(action.x * TILE_SIZE, action.y * TILE_SIZE)
            elseif action.type == "zoneSwitch" then
                switchZone(action.zone)
                gameStateMachine:change("overworld")
                return
            end
        end

        camera:reset()
        debugMenu:handleInput()
        debugMenu:draw()
        camera:apply()
    end,

    draw = function() end
})

-- ============================================================
-- GAME LOOP
-- ============================================================
gameStateMachine:change("overworld")

function playdate.update()
    gameStateMachine:update()
    gameStateMachine:draw()
    playdate.timer.updateTimers()
    collectgarbage("step", 1)

    local currentState = gameStateMachine:getCurrent()
    if currentState == "overworld" or currentState == "dialog" then
        if DEBUG_FLAGS.showGrid then DebugMenu.drawOverlays() end
        if DEBUG_FLAGS.showFPS then
            camera:reset()
            playdate.drawFPS(4, 4)
            camera:apply()
        end
    end
end
