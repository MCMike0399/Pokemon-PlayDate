-- Read-only, JSON-safe semantic state. Never retain sprites or callbacks.
HarnessDiagnostics = {}

local function pokemon(mon)
    if not mon then return { present = false } end
    local pp, maxPP, moves = {}, {}, {}
    for i, key in ipairs(mon.moves or {}) do
        moves[i] = key
        maxPP[key] = moveData[key].maxPP
    end
    for key, value in pairs(mon.pp or {}) do pp[key] = value end
    return { present = true, species = mon.species, level = mon.level,
        nature_id=mon.natureId, ability_slot=mon.abilitySlot, ability_id=mon:ability(), held_item=mon.heldItem,
        hp = mon.hp, maxHP = mon.maxHP, xp = mon.xp, status = mon.status or "none",
        types={mon.type,mon.type2},
        statusTurns = mon.statusTurns, sleepDuration = mon.sleepDuration or 0, confusion = mon.confusion or 0,
        flinched = mon.flinched or false, pp = pp, maxPP = maxPP, moves = moves,
        pending_evolution = mon.pendingEvolution ~= nil,
        pending_evolution_level = mon.pendingEvolution and mon.pendingEvolution.level or 0,
        pending_moves = #mon:getPendingMoveChoices(), pending_choices = mon:getPendingMoveChoices() }
end
local function moveInfo(key,index,mon,enemy)
    local move=assert(moveData[key],"unknown observed move")
    local result={key=key,index=index,type=move.type,category=move.category,power=move.power,
        accuracy=move.accuracy,priority=move.priority,pp=mon and mon.pp[key] or nil}
    if mon and enemy then
        local offense,defense=move.category=="special" and "spa" or "atk",move.category=="special" and "spd" or "def"
        result.attack=applyStageMod(mon[offense],mon.statStages[offense])
        result.defense=applyStageMod(enemy[defense],enemy.statStages[defense])
        if move.category=="physical" and mon.status=="burn" then result.attack=result.attack/2 end
        result.effectiveness=move.typeless and 1 or TypeChart.getMatchup(move.type,enemy.type,enemy.type2)
        result.stab=not move.typeless and (mon.type==move.type or mon.type2==move.type) and 1.5 or 1
    end
    return result
end
local function legalMoves(battle)
    local result={}
    for _,choice in ipairs(battle:availableMoves(battle.player)) do result[#result+1]=moveInfo(choice.key,choice.index,battle.player,battle.enemy) end
    return result
end
local function learningSnapshot(state)
    if not state then return {phase="closed"} end
    local result=state:getSnapshot()
    if state.active and state.pokemon then
        if state.pendingMove then result.move_info=moveInfo(state.pendingMove) end
        result.known_moves={}
        for index,key in ipairs(state.pokemon.moves) do result.known_moves[index]=moveInfo(key,index,state.pokemon) end
    end
    return result
end
local function menu(value)
    return value and {active = value.isActive, selected = value.selectedIndex, options = value.options, columns = value.columns} or nil
end
local function ui(state)
    return state and {phase = state.phase or "closed", selected = state.selected or (state.menu and state.menu.selectedIndex),
        menu = menu(state.menu), lastSave = state.lastSave, message = state.message} or {phase = "closed"}
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
        npcs[#npcs + 1] = { name = npc.name, x = npc.gridX, y = npc.gridY,
            source_event_id = npc.def and npc.def.source_event_id,
            pixel_x=npc.x,pixel_y=npc.y,facing=npc.facing,
            interacted = npc.hasInteracted and npc:hasInteracted() or npc.interacted,
            motion=game.npcManager.motion:actor(npc) }
    end
    local party = {count = game.session:party():count(), active = game.session:party():activeIndex(), members = {}}
    for i, mon in ipairs(game.session:party():members()) do party.members[i] = pokemon(mon) end
    local inventory = {slots = game.session:inventory():slots(), money = game.session:inventory():money(), quantities = {}}
    for id in pairs(ItemData.definitions) do inventory.quantities[id] = game.session:inventory():quantity(id) end
    return {
        display = HarnessCapture.display(),
        performance={heap_kib=collectgarbage("count"),elapsed_ms=playdate.getCurrentTimeMilliseconds()},
        world_motion={rng=game.session:worldRngData(),live=game.npcManager.motion:snapshot(),captured=game.session:actorData(),
            paused=root:getCurrent()~="overworld"or root:depth()~=1 or world.sub:getCurrent()~="explore"},
        pc = root:get("pc"):getSnapshot(),
        evolution = root:get("evolution"):getSnapshot(),
        frame = { tick = HarnessCapture.tick, phase = HarnessCapture.phase },
        root = root:getCurrent(), stack = root:stackNames(),
        overworld = world.sub:getCurrent(), zone = getCurrentZoneKey(),
        zone_id = currentZone and currentZone.stableID,
        session = {party = party, inventory = inventory, flags = game.session:flags(), checkpoint = game.session:checkpoint()},
        party = party, inventory = inventory,
        pause = ui(root:get("pause")), title = ui(root:get("title")),
        party_ui = ui(root:get("party")), bag = ui(root:get("bag")),
        party_info = root:get("party"):getInfoSnapshot(),bag_held = root:get("bag"):getHeldSnapshot(),
        shop = root:get("shop") and root:get("shop"):getSnapshot() or {phase="closed"},
        event = root:get("event") and root:get("event"):getSnapshot() or {phase="closed"},
        pokedex = root:get("pokedex") and root:get("pokedex"):getSnapshot() or {phase="closed"},
        story = { stage = Story.get(game).stage, starter = Story.get(game).starter or "none",
            rivalStarter = Story.get(game).rivalStarter or "none", rivalOutcome = Story.get(game).rivalOutcome },
        player = player and { x = player.gridX, y = player.gridY, pixelX = player.x, pixelY = player.y,
            facing = player.facing, moving = player.isMoving, settled = not player.isMoving,
            isJumping = player.isJumping, jumpOffset = player.jumpOffset, moveFrames = player.moveFrames,
            groundPixelX = player.groundPixelX, groundPixelY = player.groundPixelY,
            lastTraversalBlock = player.lastTraversalBlock,
            pendingEdgeDoor = player.pendingEdgeDoor ~= nil, tile = tile and tile[player.gridX + 1] } or { present = false },
        pokemon = pokemon(game:getPlayerPokemon()),
        battle = battle and { phase = battle:phase(), message = battle.message, lastDamage = battle.lastDamage,
            conditions = battle:getConditionsSnapshot(),
            effects = battle.effects:snapshot(),
            learning = battle:getLearningSnapshot(),
            forced_switch = battle:needsForcedSwitch(), selection_kind = battle.selectionKind or "none",
            capture_result = battle.captureResult or {caught = false, checks = 0},
            capture_animation = battleState.scene:getCaptureSnapshot(),
            attackerSide = battle.attackerSide, trainerName = battle.trainerName,
            outcome = battle.outcome or "ongoing",
            current_move = battle.currentMoveKey or "none",
            available_player_moves = #battle:availableMoves(battle.player),
            legal_moves=legalMoves(battle),
            needs_struggle = battle:needsStruggle(),
            introPhase = battleState.scene.introPhase, introTimer = battleState.scene.introTimer,
            introDrawing = battleState.scene.introDrawing, irisRadius = battleState.scene.irisRadius,
            flashTimer = battle.flashTimer, isFlashing = battle.isFlashing, flashHide = battleState.scene.flashHide,
            shakeTimer = battle.shakeTimer, shakeIntensity = battle.shakeIntensity,
            shakeX = battleState.scene.shakeX or 0, shakeY = battleState.scene.shakeY or 0,
            inMoveSelect = battleState.scene.inMoveSelect,
            enemy = pokemon(battle.enemy), player = pokemon(battle.player),
            waiting = battle.machine:current().waiting, runAttempts = battle.runAttempts,
            menu = menu(battleState.scene.mainMenu),
            moveMenu = menu(battleState.scene.moveMenu) } or { present = false },
        dialog = { active = root:is("dialog") and dialog.isActive, line = dialog.currentLine,
            instance = dialogState.generation,
            ready = root:is("dialog") and dialog.isActive and dialog.charIndex >= #(dialog.lines[dialog.currentLine] or "") },
        camera = { x = game.camera.x, y = game.camera.y }, npcs = npcs,
        learning = learningSnapshot(root:get("learning")),
        last_battle_outcome = game.lastBattleOutcome and {
            kind = game.lastBattleOutcome.kind, won = game.lastBattleOutcome.won,
            blackout = game.lastBattleOutcome.blackout, player_hp = game.lastBattleOutcome.player_hp,
            enemy_hp = game.lastBattleOutcome.enemy_hp,
            payout=game.lastBattleOutcome.payout or 0,money_delta=game.lastBattleOutcome.money_delta or 0,
        } or {kind = "none"},
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
