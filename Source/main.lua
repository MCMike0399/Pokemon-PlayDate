import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/statemachine"
import "data/maps"
import "data/pokemon"
import "battle/moves"
import "ui/dialog"
import "ui/menu"
import "world/camera"
import "world/npc"
import "world/player"
import "world/overworld"
import "battle/battle"
import "battle/battleScene"

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
local rival = nil

-- ============================================================
-- OVERWORLD STATE
-- ============================================================
gameStateMachine:register("overworld", {
    enter = function()
        gfx.sprite.removeAll()
        npcManager:clear()
        setupOverworld()

        player = Player(6, 7, palletTownCollision)

        -- Prof. Oak (dialogue NPC)
        local oak = NPC(10, 7, "Prof. Oak",
            {"Welcome to Pallet Town!", "The world of Pokemon awaits!", "Take care out there!"}, nil, "oak")
        npcManager:addNPC(oak)

        -- Rival (battle NPC)
        rival = NPC(13, 9, "Rival",
            {"Hey! Let's battle!"}, { species = "charmander", level = 5 }, "rival")
        rival.postBattleLines = {"Good battle!"}
        npcManager:addNPC(rival)

        -- Create player pokemon
        playerPokemon = Pokemon("squirtle", 5)
    end,

    exit = function()
    end,

    update = function()
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

        gfx.sprite.update()
        playdate.frameTimer.updateTimers()

        -- Camera follow
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()
    end,

    draw = function()
        -- sprites are drawn by gfx.sprite.update() in update
    end
})

-- ============================================================
-- DIALOG STATE
-- ============================================================
gameStateMachine:register("dialog", {
    enter = function(lines, onComplete)
        dialog = Dialog()
        dialog:show(lines, onComplete)
    end,

    exit = function()
        dialog = nil
    end,

    update = function()
        -- Keep overworld visible
        gfx.sprite.update()
        playdate.frameTimer.updateTimers()

        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()

        -- Draw dialog on top (in screen coords)
        camera:reset()
        dialog:update()
        dialog:draw()
        dialog:handleInput()
    end,

    draw = function()
    end
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

        currentBattle = Battle(playerPkmn, enemyPkmn)
        battleScene = BattleScene(currentBattle)

        currentBattle:on("battleEnd", function(won)
            if won and battleNPC then
                battleNPC.interacted = true
            end
            -- Restore player HP for PoC
            playerPokemon:fullRestore()
            gameStateMachine:change("overworld")
        end)
    end,

    exit = function()
        currentBattle = nil
        battleScene = nil
        battleNPC = nil
    end,

    update = function()
        battleScene:draw()
        battleScene:handleInput()
    end,

    draw = function()
    end
})

-- ============================================================
-- GAME LOOP
-- ============================================================
gameStateMachine:change("overworld")

function playdate.update()
    gameStateMachine:update()
    gameStateMachine:draw()
    playdate.timer.updateTimers()
end
