import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/shade"
import "lib/colormapper"
import "lib/statemachine"
import "world/zone"
import "data/pokemon"
import "data/typechart"
import "battle/dsl"
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
import "game/context"
import "game/overworldState"
import "game/dialogState"
import "game/battleState"
import "game/debugState"
import "dev/autopilot"

playdate.display.setRefreshRate(30)

-- Shared context: root machine, camera, npc manager, player, player pokemon.
-- Global so dev tooling (autopilot, debug) can reach it.
game = GameContext()
npcManager = game.npcManager   -- legacy global read by world/player.lua

local machine <const> = game.machine
machine:register("overworld", OverworldState(game))
machine:register("dialog", DialogState(game))
machine:register("battle", BattleState(game))
machine:register("debug", DebugState(game))

-- Debug menu rides on top of the overworld via the system menu
local sysMenu = playdate.getSystemMenu()
sysMenu:addMenuItem("Debug", function()
    if machine:is("overworld") then
        machine:push("debug")
    end
end)

-- ============================================================
-- GAME LOOP
-- ============================================================
machine:change("overworld")

function playdate.update()
    Autopilot.update(game)

    machine:update()
    machine:handleInput()
    machine:draw()

    playdate.timer.updateTimers()
    collectgarbage("step", 1)

    local top = machine:getCurrent()
    if top ~= "battle" then
        if DEBUG_FLAGS.showGrid then DebugMenu.drawOverlays() end
        if DEBUG_FLAGS.showFPS then
            game.camera:reset()
            playdate.drawFPS(4, 4)
            game.camera:apply()
        end
    end
end
