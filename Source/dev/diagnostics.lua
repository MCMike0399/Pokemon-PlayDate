-- Read-only, JSON-safe semantic state. Never retain sprites or callbacks.
HarnessDiagnostics = {}

local function pokemon(mon)
    if not mon then return { present = false } end
    local pp, moves = {}, {}
    for i, key in ipairs(mon.moves or {}) do moves[i] = key end
    for key, value in pairs(mon.pp or {}) do pp[key] = value end
    return { present = true, species = mon.species, level = mon.level,
        hp = mon.hp, maxHP = mon.maxHP, xp = mon.xp, status = mon.status or "none",
        statusTurns = mon.statusTurns, confusion = mon.confusion or 0,
        flinched = mon.flinched or false, pp = pp, moves = moves }
end

function HarnessDiagnostics.snapshot(game)
    local root = game.machine
    local top = root:current()
    local world = root:get("overworld")
    local battleState = root:get("battle")
    local battle = battleState.battle
    local player = game.player
    local dialogState = root:get("dialog")
    local dialog = dialogState.dialog
    local tile = player and currentZone.tiles[player.gridY + 1]
    local npcs = {}
    for _, npc in ipairs(game.npcManager.npcs) do
        npcs[#npcs + 1] = { name = npc.name, x = npc.gridX, y = npc.gridY, interacted = npc.interacted }
    end
    return {
        display = HarnessCapture.display(),
        frame = { tick = HarnessCapture.tick, phase = HarnessCapture.phase },
        root = root:getCurrent(), stack = root:stackNames(),
        overworld = world.sub:getCurrent(), zone = getCurrentZoneKey(),
        story = { stage = Story.stage, starter = Story.starter or "none",
            rivalStarter = Story.rivalStarter or "none", rivalOutcome = Story.rivalOutcome },
        player = player and { x = player.gridX, y = player.gridY, pixelX = player.x, pixelY = player.y,
            facing = player.facing, moving = player.isMoving, settled = not player.isMoving,
            pendingEdgeDoor = player.pendingEdgeDoor ~= nil, tile = tile and tile[player.gridX + 1] } or { present = false },
        pokemon = pokemon(game.playerPokemon),
        battle = battle and { phase = battle:phase(), message = battle.message, lastDamage = battle.lastDamage,
            attackerSide = battle.attackerSide, trainerName = battle.trainerName,
            outcome = battle:phase() == "ended" and (battle.machine:current().won and "victory" or "defeat") or "ongoing",
            introPhase = battleState.scene.introPhase, introTimer = battleState.scene.introTimer,
            introDrawing = battleState.scene.introDrawing, irisRadius = battleState.scene.irisRadius,
            flashTimer = battle.flashTimer, isFlashing = battle.isFlashing, flashHide = battleState.scene.flashHide,
            shakeTimer = battle.shakeTimer, shakeIntensity = battle.shakeIntensity,
            shakeX = battleState.scene.shakeX or 0, shakeY = battleState.scene.shakeY or 0,
            inMoveSelect = battleState.scene.inMoveSelect,
            enemy = pokemon(battle.enemy), player = pokemon(battle.player),
            waiting = battle.machine:current().waiting, runAttempts = battle.runAttempts,
            menu = battleState.scene.mainMenu and { active = battleState.scene.mainMenu.isActive,
                selected = battleState.scene.mainMenu.selectedIndex } or nil,
            moveMenu = battleState.scene.moveMenu and { active = battleState.scene.moveMenu.isActive,
                selected = battleState.scene.moveMenu.selectedIndex } or nil } or { present = false },
        dialog = { active = root:is("dialog") and dialog.isActive, line = dialog.currentLine,
            ready = root:is("dialog") and dialog.isActive and dialog.charIndex >= #(dialog.lines[dialog.currentLine] or "") },
        camera = { x = game.camera.x, y = game.camera.y }, npcs = npcs,
        flags = { noEncounters = DEBUG_FLAGS.noEncounters, showGrid = DEBUG_FLAGS.showGrid, showFPS = DEBUG_FLAGS.showFPS },
        rng = RulesRNG and RulesRNG.snapshot() or {}, transitions = game:recentTransitions(),
    }
end

function HarnessDiagnostics.lookup(snapshot, path)
    local value = snapshot
    for key in path:gmatch("[^.]+") do
        if type(value) ~= "table" then return nil end
        value = value[tonumber(key) or key]
    end
    return value
end
