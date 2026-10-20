import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/rng"
import "lib/shade"
import "lib/statemachine"
import "world/tilefactory"
import "world/spritefactory"
import "world/zone"
import "data/pokemon"
import "data/pokemonArt"
import "domain/party"
import "domain/storage"
import "domain/inventory"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/pokemonCodec"
import "domain/saveStore"
import "ui/dialog"
import "ui/menu"
import "ui/debug"
import "world/camera"
import "world/npc"
import "world/player"
import "world/overworld"
import "battle/battle"
import "battle/battleScene"
import "game/story"
import "data/maps"
import "game/context"
import "game/overworldState"
import "game/dialogState"
import "game/battleState"
import "game/debugState"
import "game/learningState"
import "dev/contracts"
import "dev/learnsetContracts"
import "dev/partyContracts"
import "dev/learningContracts"
import "dev/saveContracts"
import "dev/combatContracts"
import "dev/rngPersistenceContracts"
Contracts.register("learnsets", LearnsetContracts.run)
Contracts.register("collections", PartyContracts.run)
Contracts.register("learning", LearningContracts.run)
Contracts.register("persistence", SaveContracts.run)
Contracts.register("combat", CombatContracts.run)
Contracts.register("rng-persistence", RNGPersistenceContracts.run)
import "dev/catalog"
import "dev/harness_build"
import "dev/harness_capture"
import "dev/diagnostics"
import "dev/fixtures"
import "dev/autopilot"
import "dev/harness"

playdate.display.setRefreshRate(30)
if not HarnessBuild.enabled then
    RulesRNG.seed(playdate.getSecondsSinceEpoch())
end

-- Shared context: root machine, camera, npc manager, player, player pokemon.
-- Global so dev tooling (autopilot, debug) can reach it.
game = GameContext()

local machine <const> = game.machine
machine:register("overworld", OverworldState(game))
machine:register("dialog", DialogState(game))
machine:register("battle", BattleState(game))
machine:register("debug", DebugState(game))
machine:register("learning", LearningState(game))

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
-- New game: the intro questline starts in Red's bedroom with Oak's
-- monologue (debug menu "Skip Intro" jumps straight to free play)
Story.begin()
machine:change("overworld")
machine:push("dialog", Story.openingLines)

---@diagnostic disable-next-line: duplicate-set-field
local function updateGame()
    Harness.beforeFrame(game)

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

-- Harness failures are evidence rather than an unacknowledged mailbox hang.
function playdate.update()
    if Harness.isQuiescent then return end
    if HarnessBuild.enabled and playdate.isSimulator then
        local ok, message = pcall(updateGame)
        Harness.afterFrame(game, not ok and tostring(message) or nil)
    else
        updateGame()
    end
end
