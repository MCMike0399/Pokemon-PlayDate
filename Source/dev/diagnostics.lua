-- Read-only, JSON-safe semantic state. Never retain sprites or callbacks.
HarnessDiagnostics = {}

local function shownVitals(battle,mon)
    local level,hp,maxHP=battle:presentationVitals(mon)
    return {level=level,hp=hp,maxHP=maxHP}
end

local function pokemon(mon)
    if not mon then return { present = false } end
    local pp, maxPP, moves, stages = {}, {}, {}, {}
    for i, key in ipairs(mon.moves or {}) do
        moves[i] = key
        maxPP[key] = moveData[key].maxPP
    end
    for key, value in pairs(mon.pp or {}) do pp[key] = value end
    for _, stat in ipairs({"atk","def","spa","spd","spe","acc","eva"}) do
        stages[stat] = mon.statStages[stat]
    end
    return { present = true, species = mon.species, level = mon.level,
        nature_id=mon.natureId, ability_slot=mon.abilitySlot, ability_id=mon:ability(), held_item=mon.heldItem,
        sex=mon:getSex(),sex_provenance=mon:attributes().sexProvenance,
        individuals=mon:individuals(),canonical_stats=mon:calculatedStats(),
        actual_stats={maxHP=mon.maxHP,atk=mon.atk,def=mon.def,spa=mon.spa,spd=mon.spd,spe=mon.spe},
        hp = mon.hp, maxHP = mon.maxHP, xp = mon.xp, status = mon.status or "none",
        types={mon.type,mon.type2},
        statusTurns = mon.statusTurns, sleepDuration = mon.sleepDuration or 0, confusion = mon.confusion or 0,
        flinched = mon.flinched or false, pp = pp, maxPP = maxPP, moves = moves, stat_stages = stages,
        pending_evolution = mon.pendingEvolution ~= nil,
        pending_evolution_level = mon.pendingEvolution and mon.pendingEvolution.level or 0,
        pending_moves = #mon:getPendingMoveChoices(), pending_choices = mon:getPendingMoveChoices() }
end
local function moveInfo(key,index,mon,enemy,effects,battle)
    local move=assert(moveData[key],"unknown observed move")
    local result={key=key,index=index,type=move.type,category=move.category,power=move.power,
        accuracy=move.accuracy,priority=move.priority,pp=mon and mon.pp[key] or nil,
        power_rule=move.powerRule,damage_rule=move.damageRule,attempt_rule=move.attemptRule,charge_rule=move.chargeRule,lock_rule=move.lockRule}
    if mon and enemy then
        local offense,defense=move.category=="special" and "spa" or "atk",move.category=="special" and "spd" or "def"
        result.attack=applyStageMod(mon[offense],mon.statStages[offense])
        result.defense=applyStageMod(enemy[defense],enemy.statStages[defense])
        if effects then
            result.attack=effects:attackStat(mon,move,result.attack)
            result.defense=effects:defenseStat(enemy,move,result.defense)
        end
        if move.category=="physical" and mon.status=="burn" and not (effects and effects:ignoresBurn(mon)) then
            result.attack=result.attack/2
        end
        local threshold,mode=accuracyThreshold(move,mon,enemy,effects)
        result.effective_accuracy=threshold
        result.accuracy_mode=mode or (move.accuracy==0 and "always" or "ordinary")
        result.ohko=move.ohko==true
        if battle then
            result.effective_power=battle:effectiveMovePower(move,mon,enemy)
            local fixed=effects:fixedDamage(move,mon,enemy)
            if fixed then result.fixed_damage=math.max(0,fixed) end
            if result.effective_power>0 and move.category~="status" then result.crit_stage=effects:criticalStage(mon,move) end
        end
        local sameType
        if battle then
            result.effectiveness=move.typeless and 1 or battle:typeMatchup(move.type,enemy)
            sameType=battle:hasType(mon,move.type)
        else
            result.effectiveness=move.typeless and 1 or TypeChart.getMatchup(move.type,enemy.type,enemy.type2)
            sameType=mon.type==move.type or mon.type2==move.type
        end
        result.stab=not move.typeless and sameType and 1.5 or 1
    end
    return result
end
local function legalMoves(battle)
    local result={}
    for _,choice in ipairs(battle:availableMoves(battle.player)) do result[#result+1]=moveInfo(choice.key,choice.index,battle.player,battle.enemy,battle.effects,battle) end
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
        menu = menu(state.menu), lastSave = state.lastSave, message = state.message, lastResult = state.lastResult} or {phase = "closed"}
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
        field_encounter=game.lastEncounterSession==game.session and game.lastEncounterAttempt or {kind="none",reason="not-attempted"},
        performance={heap_kib=collectgarbage("count"),elapsed_ms=playdate.getCurrentTimeMilliseconds()},
        world_motion={rng=game.session:worldRngData(),live=game.npcManager.motion:snapshot(),captured=game.session:actorData(),
            paused=root:getCurrent()~="overworld"or root:depth()~=1 or world.sub:getCurrent()~="explore"},
        item_pc=root:get("itemPC") and root:get("itemPC"):getSnapshot() or {phase="closed"},
        home_rest=root:get("homeRest") and root:get("homeRest"):getSnapshot() or {phase="closed"},
        town_map=root:get("townMap") and root:get("townMap"):getSnapshot() or {phase="closed"},
        field_item=game.lastFieldItem or {kind="none"},
        pc = root:get("pc"):getSnapshot(),
        evolution = root:get("evolution"):getSnapshot(),
        frame = { tick = HarnessCapture.tick, phase = HarnessCapture.phase },
        root = root:getCurrent(), stack = root:stackNames(),
        overworld = world.sub:getCurrent(), zone = getCurrentZoneKey(),
        zone_id = currentZone and currentZone.stableID,
        session = {item_storage=game.session:itemStorage():toData(),party = party, inventory = inventory, flags = game.session:flags(), checkpoint = game.session:checkpoint(),
            pokedex = game.session:pokedex()},
        party = party, inventory = inventory,
        pause = ui(root:get("pause")), title = ui(root:get("title")),
        field_move = ui(root:get("fieldMove")),
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
        battle = battle and { presentation={player=shownVitals(battle,battle.player),enemy=shownVitals(battle,battle.enemy),xp_gauge="authoritative-model"},
            rewards=battle:getRewardSnapshot(), phase = battle:phase(), message = battle.message, lastDamage = battle.lastDamage,
            conditions = battle:getConditionsSnapshot(),
            effects = battle.effects:snapshot(),
            force_switch = battle:getForceSwitchSnapshot(), move_gaps = battle:getMoveGaps(),
            effective_abilities = {player=battle.effects:effectiveAbility(battle.player),enemy=battle.effects:effectiveAbility(battle.enemy)},
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
            shift_choice = battle.shiftChoice ~= nil,
            menu = menu(battleState.scene.mainMenu),
            moveMenu = menu(battleState.scene.moveMenu) } or { present = false },
        dialog = { active = root:is("dialog") and dialog.isActive, line = dialog.currentLine,
            instance = dialogState.generation,
            ready = root:is("dialog") and dialog.isActive and dialog.charIndex >= #(dialog.lines[dialog.currentLine] or "") },
        camera = { x = game.camera.x, y = game.camera.y }, npcs = npcs,
        learning = learningSnapshot(root:get("learning")),
        last_battle_outcome = game.lastBattleOutcome and {
            trainer_id = game.lastBattleOutcome.trainer_id,
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

-- Heavy observations are request-only. No snapshot/trace calls this code.
-- Cache only a real successful disk Save/Continue, tied to its session identity.
local boundaries = setmetatable({}, {__mode="k"})
local function equal(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end
local function armBoundary(game)
    if game.saves.observeBoundary then return end
    game.saves.observeBoundary = function(session, kind, payload, metadata)
        -- SaveStore supplies a detached primitive record. Nothing here calls
        -- captureSession/captureTraversal or samples current moving actors.
        boundaries[game.saves] = {session=session, kind=kind, payload=payload,
            sequence=metadata.sequence, reason=metadata.reason}
    end
end
local function codecObservation(game, payload)
    local deps = game:getSessionDependencies()
    local valid, problem = SessionCodec.validate(payload, deps)
    assert(valid, problem)
    local detached = assert(SessionCodec.decode(payload, deps))
    local encoded = assert(SessionCodec.encode(detached,
        {root="overworld", overworld="explore", settled=true}))
    assert(equal(payload, encoded), "noncanonical session boundary roundtrip")
    return {version=SessionCodec.VERSION, valid=true, roundtrip_equal=true, payload=payload}
end
local function observeOwners(game)
    local export = assert(json.decodeFile("dev/ceruleanJourney.json"), "missing owner projection")
    assert(export.schema == 1 and export.session_codec == SessionCodec.VERSION, "stale owner projection")
    local actual = SourceEvents.trainerDefinitions()
    local expected = GameSession._copy(export.trainers)
    for id, variants in pairs(export.rivals) do
        local registered = assert(actual[id], "unregistered rival: " .. id)
        local selected = {}
        for starter, definition in pairs(variants) do
            selected[starter] = {party=definition.party, payout=definition.payout}
            local base = GameSession._copy(registered)
            base.party, base.payout, base.rival_parties = definition.party, definition.payout, nil
            assert(equal(base, definition), "rival definition drift: " .. id)
        end
        assert(equal(registered.rival_parties, selected), "unregistered rival variants")
        expected[id] = registered
    end
    for id, definition in pairs(expected) do
        assert(equal(actual[id], definition), "registered trainer definition differs: " .. id)
    end
    for _, id in ipairs(export.events) do
        assert(SourceEvents.has(id), "unregistered projected event: " .. id)
    end
    for id, shop in pairs(export.shops) do
        local descriptor = assert(SourceEvents.descriptor(id))
        assert(descriptor.kind == "program" and #descriptor.steps == 1
            and descriptor.steps[1].op == "shop", "shop dispatch differs")
        assert(equal(ItemData.marts[descriptor.steps[1].id], shop.stock), "shop stock differs")
        for item, price in pairs(shop.prices) do
            assert(ItemData.definitions[item].price == price, "shop price differs")
        end
    end
    assert(equal(CeruleanStory.pcPlayer(), export.bill_pc_player), "Bill PC player binding differs")
    armBoundary(game)
    return {kind="owners", valid=true, version=SessionCodec.VERSION}
end
function HarnessDiagnostics.observe(game, kind)
    if kind == "midgame-owners" then
        local registered, shops, compatibility = {}, {}, {}
        for _, name in ipairs(SourceMaps.names()) do
            local definition = SourceMaps.definition(name)
            local events = {}
            for _, group in ipairs({"objects", "background_events"}) do
                for _, event in ipairs(definition.events[group]) do events[#events + 1] = event end
            end
            for _, event in ipairs(events) do
                registered[event.id] = SourceEvents.has(event.id)
                local descriptor = SourceEvents.descriptor(event.id)
                local step = descriptor and descriptor.kind == "program" and descriptor.steps[1]
                if step and step.op == "shop" then
                    local stock = assert(ItemData.marts[step.id])
                    local prices = {}
                    for _, item in ipairs(stock) do prices[item] = ItemData.definitions[item].price end
                    shops[event.id] = {stock=GameSession._copy(stock), prices=prices}
                end
            end
        end
        for _, hm in ipairs({"hm01", "hm02", "hm03", "hm04", "hm05"}) do
            compatibility[hm] = {}
            for species, moves in pairs(MachineData.compatibility) do
                if moves[hm] then table.insert(compatibility[hm], species) end
            end
            table.sort(compatibility[hm])
        end
        armBoundary(game)
        return {kind=kind, valid=true, version=SessionCodec.VERSION,
            registered_events=registered, shops=shops, hm_compatibility=compatibility,
            trainers=SourceEvents.trainerDefinitions()}
    end
    if kind == "midgame-state" then
        return {kind=kind, zone_id=currentZone and currentZone.stableID,
            fieldWorld=game.session:fieldWorldData(), fieldTravel=game.session:fieldTravelData(),
            fieldRuntime=game.getFieldTravelSnapshot and game:getFieldTravelSnapshot() or {installed=false},
            fieldUI=ui(game.machine:get("fieldTravel"))}
    end
    if kind == "purity" then
        -- Prepared real-SDK witness: repeated requests must preserve the entire
        -- canonical session, live world/actors, identities and both RNG owners.
        local session, storage, party = game.session, game.session:storage(), game.session:party()
        local gate = {root="overworld", overworld="explore", settled=true}
        local before = assert(SessionCodec.encode(session, gate))
        local actors = game.npcManager.motion:snapshot()
        local world, rng = WorldDeltas.export(), RulesRNG.snapshot()
        HarnessDiagnostics.observe(game, "validate")
        HarnessDiagnostics.observe(game, "validate")
        assert(game.session == session and session:storage() == storage and session:party() == party,
            "observation changed owner identity")
        assert(equal(before, assert(SessionCodec.encode(session, gate))), "observation changed session")
        assert(equal(actors, game.npcManager.motion:snapshot()), "observation changed live actors")
        assert(equal(world, WorldDeltas.export()), "observation changed live world")
        assert(equal(rng, RulesRNG.snapshot()), "observation consumed rules RNG")
        return {kind="purity", valid=true, version=SessionCodec.VERSION}
    end
    if kind == "vermilion-owners" then
        local export = assert(json.decodeFile("dev/vermilionJourney.json"))
        assert(export.schema == 1 and export.session_codec == SessionCodec.VERSION, "stale Vermilion projection")
        local actual = SourceEvents.trainerDefinitions()
        for id, definition in pairs(export.trainers) do
            assert(equal(actual[id], definition), "Vermilion trainer differs: " .. id)
        end
        for id in pairs(export.events) do
            assert(SourceEvents.has(id), "unregistered Vermilion event: " .. id)
        end
        assert(SourceEvents.has("pokered:DAYCARE:objects:1"), "Day Care service not registered")
        armBoundary(game)
        return {kind=kind, valid=true, version=SessionCodec.VERSION}
    end
    if kind == "vermilion-collection" then
        local session = game.session
        return {kind=kind,owned=session:pokedex().owned,
            party=assert(session:party():toData(PokemonCodec.encode)),
            storage=assert(session:storage():toData(PokemonCodec.encode))}
    end
    if kind == "vermilion-encounter-terrain" then
        local zone, cells = assert(currentZone), {}
        for y=0,zone.height-1 do
            for x=0,zone.width-1 do
                local policy = zone:encounterPolicyAt(x,y)
                if policy and policy.rate.value > 0 then cells[#cells+1]={x=x,y=y} end
            end
        end
        return {kind=kind,zone_id=zone.stableID,cells=cells}
    end
    if kind == "vermilion-aide-fixture" then
        local result = GameSession._copy(assert(game.lastVermilionAideFixture,
            "missing explicit supplementary Vermilion aide fixture"))
        result.kind = kind
        return result
    end
    if kind == "vermilion-daycare" then
        local owner = Daycare.observe(game.session)
        local quote = owner.pokemon and Daycare.plan(owner, "withdraw") or nil
        return {kind=kind,owner=owner,withdrawal=quote}
    end
    if kind == "vermilion-world" then
        local zone = assert(currentZone)
        local cells = {}
        local export = assert(json.decodeFile("dev/vermilionJourney.json"))
        if zone.stableID == "pokered:VERMILION_CITY" then
            local padding = export.maps.VermilionCity.padding
            for _, site in ipairs(export.cut_sites) do
                for _, cell in ipairs(site.cells) do
                    local x, y = cell.x+padding, cell.y
                    cells[#cells+1] = {x=x,y=y,key=zone.registry:key(zone.tiles[y+1][x+1])}
                end
            end
        end
        return {kind=kind,zone_id=zone.stableID,cells=cells,collision=GameSession._copy(zone.collision)}
    end
    if kind == "owners" then return observeOwners(game) end
    armBoundary(game)
    if kind == "validate" then
        -- Validation of existing session data only: no traversal capture/repair.
        local world = game.machine:get("overworld")
        assert(game.machine:getCurrent() == "overworld" and game.machine:depth() == 1
            and world.sub:getCurrent() == "explore" and game.player and not game.player.isMoving
            and not game.player.pendingEdgeDoor and not game.player.pendingConnection,
            "read-only validation requires settled exploration")
        local payload = assert(SessionCodec.encode(game.session,
            {root="overworld", overworld="explore", settled=true}))
        local result = codecObservation(game, payload)
        -- Fresh validation is deliberately not a Save/Continue receipt.
        result.payload, result.kind = nil, "validate"
        return result
    end
    assert(kind == "saved" or kind == "loaded", "unknown observation")
    local boundary = assert(boundaries[game.saves], "no observed Save/Continue boundary")
    assert(boundary.session == game.session and boundary.kind == kind,
        "stale or wrong Save/Continue boundary")
    local result = codecObservation(game, boundary.payload)
    result.kind, result.sequence = kind, boundary.sequence
    return result
end
