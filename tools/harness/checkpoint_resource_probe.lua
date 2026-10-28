-- Supplemental production-only observer. Elapsed time and setup belong here;
-- traversal, specimens and battle construction stay in their production owners.
local cfg <const> = CheckpointResourceConfig
local clock <const> = playdate.getCurrentTimeMilliseconds
local originalUpdate <const> = playdate.update
local report = {schema=1, ok=false, session_id=cfg.session_id, build_id=cfg.build_id,
    mode="production", simulator=not not playdate.isSimulator, startup_ms=cfg.startup_ms,
    classification="supplemental performance setup; not natural-journey proof",
    timing="playdate.update CPU duration, including production draw and incremental GC; not display presentation time",
    limits="Simulator only; representative chosen traversal and battle, not whole-game worst case; observer overhead is not subtracted",
    heap_limits="collectgarbage count measures Lua heap including observer allocations, not native graphics or device RAM",
    full_gc_excluded_from_gameplay=true, windows={}}
local phase = "continue"
local age = 0
local pending
local mapOrigin
local completed = false

local function publish(problem)
    if completed then return end
    completed = true
    report.ok = problem == nil
    report.error = problem and tostring(problem) or nil
    report.ending_phase = phase
    playdate.update = function() end
    local file = assert(playdate.file.open("startup-probe.tmp", playdate.file.kFileWrite))
    assert(file:write(json.encode(report)))
    file:close()
    assert(playdate.file.rename("startup-probe.tmp", "startup-probe.json"))
end

local function settled()
    local world = game.machine:get("overworld")
    local player = game.player
    return game.machine:getCurrent() == "overworld" and game.machine:depth() == 1
        and world and world.sub:getCurrent() == "explore" and player and not player.isMoving
        and not player.fieldStep and not player.pendingEdgeDoor and not player.pendingConnection
end

local function sample(label, duration)
    local row = report.windows[label]
    if not row then
        row = {frames=0, total_update_ms=0, worst_update_ms=0, worst_frame=0}
        report.windows[label] = row
    end
    row.frames = row.frames + 1
    row.total_update_ms = row.total_update_ms + duration
    if duration > row.worst_update_ms then
        row.worst_update_ms, row.worst_frame = duration, row.frames
    end
end

local function collectCheckpoint(label)
    local start = clock()
    local before = collectgarbage("count")
    collectgarbage("collect")
    collectgarbage("collect")
    report[label] = {heap_kib_before_gc=before, heap_kib_after_gc=collectgarbage("count"),
        deliberate_full_gc_ms=clock() - start, passes=2, excluded_from_frame_windows=true}
end

local function startMap()
    mapOrigin = currentZone.stableID
    local name = SourceMaps.nameForID(mapOrigin)
    local key = name and SourceMaps.entry(name).key or mapOrigin
    local choices = {}
    for _, door in ipairs(currentZone.doors or {}) do
        if door.to and door.to ~= key and door.to ~= mapOrigin
            and type(door.toX) == "number" and type(door.toY) == "number" then
            choices[#choices + 1] = door
        end
    end
    local door = assert(choices[cfg.door_index], "requested actual current-zone door is unavailable")
    report.map_load = {from_zone=mapOrigin, from_x=game.player.gridX, from_y=game.player.gridY,
        door_index=cfg.door_index, to=door.to, x=door.toX, y=door.toY,
        trigger="direct invocation of the real DoorWarp substate; player not repositioned onto a door"}
    phase, age = "map_load", 0
    pending = function()
        game.machine:get("overworld").sub:change("doorWarp", GameSession._copy(door))
    end
end

local function startBattle()
    report.battle_start = {species=cfg.battle_species, level=cfg.battle_level,
        trigger="fixed supplemental wild specimen through Specimen and FieldBattle; no encounter-rate claim, rewards or save write"}
    phase, age = "battle_start", 0
    pending = function()
        assert(pokemonData[cfg.battle_species], "supplemental species is outside the installed original roster")
        local planned = RulesRNG.new(1)
        planned:restore(RulesRNG.snapshot())
        local specimen = Specimen.rollEncounterAbilities(assert(Specimen.planEncounter(game.session)), planned)
        local gap = Specimen.encounterGap(specimen)
        assert(not gap, "supplemental specimen acquisition gap: " .. tostring(gap))
        local enemy, reason = Specimen.create(cfg.battle_species, cfg.battle_level, "wild", planned, specimen)
        assert(enemy, reason)
        RulesRNG.restore(planned:snapshot())
        local started, problem = FieldBattle.start(game, game:getPlayerPokemon(), enemy, nil)
        assert(started, problem)
    end
end

local function afterUpdate()
    age = age + 1
    if phase == "continue" then
        if age == 1 then
            assert(game.machine:getCurrent() == "title", "earned-save probe requires the real title entry")
            local ok, problem = game.saves:continueGame()
            assert(ok, type(problem) == "table" and problem.reason or problem)
        elseif settled() then
            report.loaded = {zone_id=currentZone.stableID, x=game.player.gridX, y=game.player.gridY}
            collectCheckpoint("checkpoint")
            local start = clock()
            for _ = 1, 1000 do clock() end
            report.instrumentation = {clock_1000_calls_ms=clock() - start,
                overhead="two clock reads and optional synthetic trigger inside timed updates; statistics outside; persistent observer allocations included in Lua heap",
                timer_resolution="not independently qualified", frame_limit=cfg.battle_frames}
            startMap()
        elseif age > cfg.settle_frames then
            error("earned save did not settle in ordinary exploration")
        end
    elseif phase == "map_load" then
        if currentZone.stableID ~= mapOrigin and settled() then
            report.map_load.arrived_zone = currentZone.stableID
            report.map_load.arrived_x, report.map_load.arrived_y = game.player.gridX, game.player.gridY
            collectCheckpoint("after_map_load")
            startBattle()
        elseif age > cfg.settle_frames then
            error("real map traversal did not settle; try another actual door index")
        end
    elseif phase == "battle_start" then
        assert(game.machine:getCurrent() == "battle", "supplemental battle did not enter the real battle owner")
        if age >= cfg.battle_frames then
            collectCheckpoint("after_battle_start")
            publish()
        end
    end
end

function playdate.update()
    if completed then return end
    local measuredPhase = phase
    local start = clock()
    local ok, problem = pcall(function()
        if pending then
            local action = pending
            pending = nil
            action()
        end
        originalUpdate()
    end)
    local duration = clock() - start
    if measuredPhase == "map_load" or measuredPhase == "battle_start" then
        sample(measuredPhase, duration)
    end
    if not ok then
        publish(problem)
        return
    end
    -- Full collections, overhead calibration and publication happen OUTSIDE
    -- the measured gameplay interval. No deliberate full-GC pause is a frame.
    local advanced, failure = pcall(afterUpdate)
    if not advanced then publish(failure) end
end
