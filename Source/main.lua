import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/statemachine"
import "data/maps"
import "data/pokemon"
import "data/typechart"
import "battle/moves"
import "ui/dialog"
import "ui/menu"
import "ui/debug"
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

-- Wild encounter config: tall grass tile ID = 8
local TALL_GRASS_TILE_ID <const> = 8
local ENCOUNTER_RATE <const> = 0.15 -- 15% per step on tall grass

local function checkWildEncounter(tileX, tileY)
    local tiles = currentZone.tiles
    if tileY + 1 > #tiles or tileX + 1 > #tiles[1] then return false end
    local tileId = tiles[tileY + 1][tileX + 1]
    if tileId == TALL_GRASS_TILE_ID and math.random() < ENCOUNTER_RATE then
        return true
    end
    return false
end

-- Zone-specific encounter tables
local zoneEncounters = {
    pallet_town = {
        { species = "rattata", minLevel = 2, maxLevel = 4, weight = 40 },
        { species = "pidgey", minLevel = 2, maxLevel = 5, weight = 35 },
        { species = "caterpie", minLevel = 3, maxLevel = 5, weight = 15 },
        { species = "weedle", minLevel = 3, maxLevel = 5, weight = 10 },
    },
    test_zone = {
        { species = "rattata", minLevel = 2, maxLevel = 4, weight = 40 },
        { species = "pidgey", minLevel = 2, maxLevel = 5, weight = 35 },
        { species = "caterpie", minLevel = 3, maxLevel = 5, weight = 15 },
        { species = "weedle", minLevel = 3, maxLevel = 5, weight = 10 },
    },
}

local function rollWildPokemon()
    -- Find current zone key for encounter lookup
    local encounters = nil
    for key, zone in pairs(zones) do
        if zone == currentZone then
            encounters = zoneEncounters[key]
            break
        end
    end
    if not encounters then encounters = zoneEncounters.pallet_town end

    local totalWeight = 0
    for _, e in ipairs(encounters) do
        totalWeight = totalWeight + e.weight
    end
    local roll = math.random(1, totalWeight)
    local cumulative = 0
    for _, e in ipairs(encounters) do
        cumulative = cumulative + e.weight
        if roll <= cumulative then
            local level = math.random(e.minLevel, e.maxLevel)
            return Pokemon(e.species, level)
        end
    end
    return Pokemon("rattata", 3)
end

-- Zone-specific NPC setup
local function setupZoneNPCs(zoneKey)
    npcManager:clear()

    if zoneKey == "pallet_town" then
        -- Prof. Oak outside his lab
        local oak = NPC(10, 12, "Prof. Oak",
            {"Welcome to Pallet Town!", "The world of Pokemon awaits!", "Take care out there!"}, nil, "oak")
        npcManager:addNPC(oak)

        -- Rival near Blue's house
        rival = NPC(13, 6, "Rival",
            {"Hey! Let's battle!"}, { species = "charmander", level = 5 }, "rival")
        rival.postBattleLines = {"Good battle!"}
        npcManager:addNPC(rival)

    elseif zoneKey == "test_zone" then
        -- Prof. Oak
        local oak = NPC(10, 7, "Prof. Oak",
            {"Welcome to the Test Zone!", "This is the original map.", "Explore freely!"}, nil, "oak")
        npcManager:addNPC(oak)

        -- Rival
        rival = NPC(13, 9, "Rival",
            {"Hey! Let's battle!"}, { species = "charmander", level = 5 }, "rival")
        rival.postBattleLines = {"Good battle!"}
        npcManager:addNPC(rival)
    end
end

-- Get current zone key from the currentZone reference
local function getCurrentZoneKey()
    for key, zone in pairs(zones) do
        if zone == currentZone then
            return key
        end
    end
    return "pallet_town"
end

-- Switch to a different zone
function switchZone(zoneKey)
    if zones[zoneKey] then
        currentZone = zones[zoneKey]
        gameStateMachine:change("overworld")
    end
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

        -- Setup NPCs for current zone
        setupZoneNPCs(getCurrentZoneKey())

        -- Create player pokemon (only if not already created)
        if not playerPokemon then
            playerPokemon = Pokemon("squirtle", 5)
        end

        -- Snap camera to player immediately (no lerp on load)
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:snapTo(px, py, mw, mh)
    end,

    exit = function()
    end,

    update = function()
        -- Iris-out transition in progress
        if irisOut.active then
            irisOut.timer = irisOut.timer + 1
            -- Keep drawing world underneath
            playdate.frameTimer.updateTimers()
            local px, py = player:getPixelCenter()
            local mw, mh = getMapPixelSize()
            camera:follow(px, py, mw, mh)
            camera:apply()
            gfx.sprite.update()

            -- Draw iris-out overlay in screen space
            camera:reset()
            local maxRadius = 260
            local progress = irisOut.timer / irisOut.duration
            local radius = math.floor(maxRadius * (1 - progress))

            if radius > 0 then
                -- Draw black border outside the circle using stencil
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
                            -- Iris-out then battle
                            local screenX, screenY = player:getPixelCenter()
                            screenX = screenX + gfx.getDrawOffset()
                            screenY = screenY + gfx.getDrawOffset()
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

        -- Check for wild encounter after movement completes
        if player.stepJustFinished then
            if checkWildEncounter(player.gridX, player.gridY) then
                -- Get player screen position for iris center
                local px, py = player:getPixelCenter()
                local ox, oy = gfx.getDrawOffset()
                local screenX = px + ox
                local screenY = py + oy
                startIrisOut(screenX, screenY, function()
                    local wildPokemon = rollWildPokemon()
                    gameStateMachine:change("battle", playerPokemon, wildPokemon, nil)
                end)
            end
        end

        playdate.frameTimer.updateTimers()

        -- Camera follow (before sprite draw so offset is applied this frame)
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()

        gfx.sprite.update()
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
        playdate.frameTimer.updateTimers()

        -- Camera follow (before sprite draw)
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()

        -- Keep overworld visible
        gfx.sprite.update()

        -- Draw dialog on top (in screen coords)
        camera:reset()
        dialog:update()
        dialog:draw()
        dialog:handleInput()
        camera:apply()
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

        -- Reset stat stages for battle (but keep HP, status, XP)
        playerPkmn:resetStages()

        currentBattle = Battle(playerPkmn, enemyPkmn)
        battleScene = BattleScene(currentBattle)

        currentBattle:on("battleEnd", function(won)
            if won and battleNPC then
                battleNPC.interacted = true
            end
            -- Clear status after battle (mercy rule for PoC)
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

    draw = function()
    end
})

-- ============================================================
-- DEBUG STATE
-- ============================================================
gameStateMachine:register("debug", {
    enter = function()
        camera:reset()
        debugMenu:open(function()
            -- Wild battle action closes menu and goes straight to battle
            local action = debugMenu:consumeAction()
            if action and action.type == "wildBattle" then
                local enemyPokemon = Pokemon(action.species, action.level)
                gameStateMachine:change("battle", playerPokemon, enemyPokemon, nil)
                return
            end
            if action and action.type == "zoneSwitch" then
                switchZone(action.zone)
                return
            end
            gameStateMachine:change("overworld")
        end)
    end,

    exit = function()
    end,

    update = function()
        playdate.frameTimer.updateTimers()

        -- Camera follow (before sprite draw)
        local px, py = player:getPixelCenter()
        local mw, mh = getMapPixelSize()
        camera:follow(px, py, mw, mh)
        camera:apply()

        -- Keep overworld visible underneath
        gfx.sprite.update()

        -- Process in-menu actions (heal, set level, etc.)
        local action = debugMenu:consumeAction()
        if action then
            if action.type == "heal" and playerPokemon then
                playerPokemon:fullRestore()
            elseif action.type == "resetNPCs" then
                for _, npc in ipairs(npcManager.npcs) do
                    npc.interacted = false
                end
            elseif action.type == "setLevel" and playerPokemon then
                local species = playerPokemon.species
                playerPokemon = Pokemon(species, action.level)
            elseif action.type == "warp" and player then
                player.gridX = action.x
                player.gridY = action.y
                player:moveTo(action.x * TILE_SIZE, action.y * TILE_SIZE)
            elseif action.type == "zoneSwitch" then
                switchZone(action.zone)
                return
            end
        end

        -- Draw debug menu on top (screen coords)
        camera:reset()
        debugMenu:handleInput()
        debugMenu:draw()
        camera:apply()
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

    -- Incremental GC to avoid spikes
    collectgarbage("step", 1)

    -- Debug overlays (FPS, grid) always on top
    local currentState = gameStateMachine:getCurrent()
    if currentState == "overworld" or currentState == "dialog" then
        -- Grid draws in world space (with camera offset active)
        if DEBUG_FLAGS.showGrid then
            DebugMenu.drawOverlays()
        end
        -- Temporarily reset offset for screen-space HUD, then restore
        if DEBUG_FLAGS.showFPS then
            camera:reset()
            playdate.drawFPS(4, 4)
            camera:apply()
        end
    end
end
