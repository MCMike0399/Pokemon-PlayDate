-- Imported only by the private production stage. No campaign registration,
-- resources, session owners, save writes, collision bypasses or second loader.
DoorCensus = {}
function DoorCensus.install()
    assert(playdate.isSimulator, "door census is Simulator-only")
    local cfg <const> = assert(json.decodeFile("census/config.json"))
    local clock <const> = function()
        return playdate.getElapsedTime() * 1000
    end
    local wallClock <const> = playdate.getCurrentTimeMilliseconds
    local clockOffset <const> = wallClock() - clock()
    local callback <const> = playdate.update
    local directions <const> = {up=playdate.kButtonUp, down=playdate.kButtonDown,
        left=playdate.kButtonLeft, right=playdate.kButtonRight}
    local held, pressed, released = 0, 0, 0
    local caseIndex, trial, written = 1, 1, 0
    local item, row, approach
    local phase, age = "next", 0
    local measured, started, updateThread = false, nil, nil
    local segmentNumber = 0
    local stream = assert(playdate.file.open("door-census.jsonl", playdate.file.kFileWrite))
    local segments = assert(playdate.file.open("door-census-segments.tsv", playdate.file.kFileWrite))
    local oldPressed <const> = playdate.buttonIsPressed
    local oldJustPressed <const> = playdate.buttonJustPressed
    local oldJustReleased <const> = playdate.buttonJustReleased
    local oldState <const> = playdate.getButtonState
    local oldYield <const> = coroutine.yield
    local oldDoorEnter <const> = DoorWarpSubstate.enter

    -- Same four SDK query seams used by the existing autopilot/device observer.
    -- One directional input, then release; Player and Explore perform all work.
    function playdate.buttonIsPressed(button)
        return (held & button) ~= 0
    end
    function playdate.buttonJustPressed(button)
        return (pressed & button) ~= 0
    end
    function playdate.buttonJustReleased(button)
        return (released & button) ~= 0
    end
    function playdate.getButtonState()
        return held, pressed, released
    end

    local function settled()
        local world = game.machine:get("overworld")
        local p = game.player
        return not GameBootstrap.isLoading() and game.machine:getCurrent() == "overworld"
            and game.machine:depth() == 1 and world.sub:getCurrent() == "explore"
            and p and not p.isMoving and not p.fieldStep and not p.pendingEdgeDoor
            and not p.pendingConnection
    end

    local function location()
        return {zone_id=currentZone and currentZone.stableID,
            x=game.player and game.player.gridX, y=game.player and game.player.gridY,
            facing=game.player and game.player.facing}
    end

    -- Observe the real production entry. Never call it ourselves or change its
    -- argument, resolution, collision, field/script guards or lifecycle.
    function DoorWarpSubstate:enter(door)
        if measured then
            row.door_entries = row.door_entries + 1
            row.trigger = {source_event_id=door.source_event_id, x=door.x, y=door.y,
                edge=door.edge, connection=door.connection == true, scripted=door.scripted == true}
        end
        oldDoorEnter(self, door)
        if measured and self.door then
            local d = self.door
            row.resolved = {to=d.to, x=d.toX, y=d.toY, facing=d.facing,
                connection=d.connection == true, source_event_id=d.source_event_id}
        end
    end

    local function segment(kind)
        if not measured or not started then
            return
        end
        local duration = clock() - started
        segmentNumber = segmentNumber + 1
        row.active_ms = row.active_ms + duration
        row.max_segment_ms = math.max(row.max_segment_ms, duration)
        assert(segments:write(string.format("%s\t%d\t%d\t%d\t%s\t%.3f\t%d\t%.3f\t%d\n",
            cfg.build_id, caseIndex, trial, segmentNumber, kind, duration, BootTrace.sequence,
            started + clockOffset, GameBootstrap.isLoading() and 1 or 0)))
        segments:flush()
        started = nil
    end

    -- SDK update coroutine spans are cut at the actual yield. Suspension,
    -- inter-frame waits and observer file writes never become active CPU time.
    coroutine.yield = function(...)
        local observing = measured and coroutine.running() == updateThread
        if observing then
            segment("yield")
        end
        -- The 64-bit census observer is larger than the shipped device game.
        -- Collect only at an actual loading suspension, outside active spans;
        -- retain the production 9 MiB guard and the native 16 MiB pool.
        if coroutine.running() == updateThread and collectgarbage("count") >= 8 * 1024 then
            local before = clock()
            collectgarbage("collect")
            if row then
                row.observer_gc_count = (row.observer_gc_count or 0) + 1
                row.observer_gc_ms = (row.observer_gc_ms or 0) + clock() - before
                if observing then
                    row.traversal_observer_gc_count = (row.traversal_observer_gc_count or 0) + 1
                    row.traversal_observer_gc_ms = (row.traversal_observer_gc_ms or 0) + clock() - before
                end
            end
        end
        local values = table.pack(oldYield(...))
        if observing then
            started = clock()
        end
        return table.unpack(values, 1, values.n)
    end

    local function finish(status, problem)
        measured, started = false, nil
        held, pressed, released = 0, 0, 0
        row.status, row.gap = status, problem and tostring(problem):sub(1, 1024) or nil
        row.wall_ms = row.wall_start_ms and wallClock() - row.wall_start_ms or nil
        row.trace_end = BootTrace.sequence
        row.arrived = location()
        row.last_block = game.player and game.player.lastTraversalBlock
        row.root_state = game.machine:getCurrent()
        -- Safe boundary after the update/loading operation returns. Do not
        -- reset provider/view internals or retain old Zones, players or frames.
        local begin = clock()
        collectgarbage("collect")
        row.gc_ms = clock() - begin
        row.post_gc_lua_heap_kib = collectgarbage("count")
        BootTrace.flush()
        assert(stream:write(json.encode(row) .. "\n"))
        stream:flush()
        written = written + 1
        row, approach = nil, nil
        if trial == 1 then
            trial = 2
            phase = "setup"
        else
            trial = 1
            caseIndex = caseIndex + 1
            item = nil
            phase = "next"
        end
        age = 0
    end

    local function resolve()
        if item.kind == "warp" then
            local descriptor = SourceMaps.descriptor(item.source_name)
            local event = assert(descriptor.warps[item.source_index], "source warp missing")
            assert(event.id == item.id and event.x == item.x and event.y == item.y,
                "source-owned warp identity/geometry differs")
            row.source_resolution = SourceMaps.warpSpec(item.source_name, event)
        elseif item.kind == "connection" then
            row.source_resolution = SourceMaps.connection(item.source_name, item.x, item.y, item.direction)
            if item.target_class == "authored_seam" then
                local ok, value = pcall(KantoSlice.connection, item.source_name,
                    item.x, item.y, item.direction, game.session:getIntro().stage)
                row.authored_resolution = ok and value or nil
                row.authored_gap = not ok and tostring(value) or nil
            end
        elseif item.kind == "authored_connection" then
            local ok, value = pcall(KantoSlice.connection, item.source_name,
                item.x, item.y, item.direction, game.session:getIntro().stage)
            row.authored_resolution = ok and value or nil
            row.authored_gap = not ok and tostring(value) or nil
        end
    end

    local function setup()
        row = {schema=1, build_id=cfg.build_id, id=item.id, case_index=caseIndex, trial=trial,
            classification=cfg.classification, source={name=item.source_name, key=item.source_key,
                zone_id=item.source_id, x=item.x, y=item.y}, door_entries=0,
            active_ms=0, max_segment_ms=0, step_completion_observed=false,
            pending_edge_observed=false, input_frames=0, trace_setup_begin=BootTrace.sequence}
        -- A missing earned input is explicit. Never manufacture badges, actors,
        -- field requirements, starter resources or story flags for the census.
        resolve()
        if not cfg.earned then
            finish("gap", "optional earned-save input absent; traversal not attempted")
            return
        end
        if row.source_resolution and row.source_resolution.status == "blocked" then
            finish("gap", row.source_resolution.reason or "source warp blocked")
            return
        end
        for _, candidate in ipairs(item.approaches) do
            if not candidate.geometry_gap then
                approach = candidate
                break
            end
        end
        if not approach then
            finish("gap", "no source-owned land approach; field or terrain requirement unsupported")
            return
        end
        -- Fixture placement is outside the measured interval. It uses normal
        -- switchZone/Overworld/WorldView/Player/provider ownership and real actors.
        -- No movement or collision flag is changed; overlays are never dismissed.
        GameBootstrap.withLoading("census.fixture", function()
            switchZone(item.source_key)
            game.machine:change("overworld", {entry={x=approach.x, y=approach.y,
                facing=approach.direction}})
        end)
        phase, age = "arm", 0
    end

    local function arm()
        if not settled() then
            finish("gap", "source fixture requires actor, field or script completion; root=" .. game.machine:getCurrent())
            return
        end
        assert(currentZone.stableID == item.source_id, "fixture entered another map")
        local p = game.player
        assert(p.gridX == approach.x and p.gridY == approach.y, "fixture approach differs")
        if currentZone.collision[p.gridY+1][p.gridX+1] ~= 0
            or game.npcManager:getNPCAt(p.gridX, p.gridY) then
            finish("gap", "solid or occupied actual source approach")
            return
        end
        if item.kind == "warp" or item.kind == "authored_door" then
            local door = item.edge and currentZone:getEdgeDoorAt(item.x, item.y, item.edge)
                or currentZone:getDoorAt(item.x, item.y)
            if not door or (item.kind == "warp" and door.source_event_id ~= item.id) then
                finish("gap", "source portal has no matching active Zone door")
                return
            end
            if item.kind == "authored_door" then
                local d = item.declaration
                assert(door.to == d.to and door.toX == d.toX and door.toY == d.toY,
                    "authored Zone target differs from literal inventory")
            end
        end
        assert(not DEBUG_FLAGS.noclip and not DEBUG_FLAGS.noEncounters, "census requires ordinary movement flags")
        local provider = WorldDeltas.definitionProvider()
        local snapshot = provider:snapshot()
        local expected = row.authored_resolution or row.source_resolution or item.declaration
        local target = expected and expected.to
        local cached = false
        for _, key in ipairs(snapshot.cached) do
            if key == target then
                cached = true
            end
        end
        row.cache_before = snapshot
        row.target_cache = target and (cached and "warm" or "cold") or "unresolved until real script"
        row.cache_definition = "provider target Zone residency immediately before input; not OS or content-cache cold"
        row.approach = {x=approach.x, y=approach.y, direction=approach.direction}
        row.input_origin = location()
        row.trace_begin = BootTrace.sequence
        collectgarbage("collect")
        row.pre_entry_post_gc_lua_heap_kib = collectgarbage("count")
        phase, age, segmentNumber = "measure", 0, 0
        row.wall_start_ms = wallClock()
        held, pressed, released = directions[approach.direction], directions[approach.direction], 0
        row.input_frames = 1
        measured = true
    end

    local function afterFrame()
        if phase ~= "measure" then
            return
        end
        local p = game.player
        row.step_completion_observed = row.step_completion_observed or p.stepJustFinished == true
        row.pending_edge_observed = row.pending_edge_observed or p.pendingEdgeDoor ~= nil
        released, held, pressed = held, 0, 0
        age = age + 1
        if row.door_entries > 0 and settled() then
            local d = row.resolved
            local targetID = d and (WorldDeltas.definitionProvider():hasKey(d.to)
                and WorldDeltas.definitionProvider():descriptor(d.to).id or d.to)
            local triggerOK = row.trigger and ((item.kind == "warp" and row.trigger.source_event_id == item.id)
                or (item.kind == "authored_door" and row.trigger.x == item.x and row.trigger.y == item.y)
                or ((item.kind == "connection" or item.kind == "authored_connection") and row.trigger.connection))
            local boundary = item.edge ~= nil or item.kind == "connection" or item.kind == "authored_connection"
            local movementOK = boundary and row.pending_edge_observed or (not boundary and row.step_completion_observed)
            if not d or not triggerOK or not movementOK or row.door_entries ~= 1
                or currentZone.stableID ~= targetID or p.gridX ~= d.x or p.gridY ~= d.y then
                finish("gap", "real portal did not complete the identified collision/input arrival")
            else
                row.input_completion_verified = true
                finish("measured")
            end
        elseif not GameBootstrap.isLoading() and game.machine:getCurrent() ~= "overworld" then
            finish("gap", "actor/field/script overlay interrupts traversal: " .. game.machine:getCurrent())
        elseif age >= cfg.max_frames or (age > 30 and settled() and row.door_entries == 0) then
            finish("gap", "input did not complete portal before frame bound")
        end
    end

    local function nextCase()
        if caseIndex > cfg.count then
            measured, started = false, nil
            BootTrace.flush()
            stream:close()
            segments:close()
            playdate.buttonIsPressed = oldPressed
            playdate.buttonJustPressed = oldJustPressed
            playdate.buttonJustReleased = oldJustReleased
            playdate.getButtonState = oldState
            coroutine.yield = oldYield
            DoorWarpSubstate.enter = oldDoorEnter
            playdate.update = function() end
            local f = assert(playdate.file.open("door-census-done.tmp", playdate.file.kFileWrite))
            assert(f:write(json.encode({build_id=cfg.build_id, rows=written})))
            f:close()
            assert(playdate.file.rename("door-census-done.tmp", "door-census-done.json"))
            phase = "done"
            return
        end
        item = assert(json.decodeFile("census/" .. caseIndex .. ".json"))
        -- Restore only through the existing save/session authority, once per
        -- cold/warm pair. The second traversal observes any real first-entry
        -- side effects; its cache label is measured, never assumed warm.
        if cfg.earned then
            local ok, problem = game.saves:continueGame()
            assert(ok, type(problem) == "table" and problem.error or problem)
        end
        phase = "setup"
    end

    function playdate.update()
        if phase == "done" then
            return
        end
        updateThread = coroutine.running()
        local ok, problem = pcall(function()
            if phase == "next" then
                nextCase()
            elseif phase == "setup" then
                setup()
            elseif phase == "arm" then
                arm()
            end
        end)
        if not ok then
            if not row then
                row = {schema=1, build_id=cfg.build_id, id=item and item.id,
                    case_index=caseIndex, trial=trial, classification=cfg.classification}
            end
            finish("gap", "fixture or resolution failure: " .. tostring(problem))
            updateThread = nil
            return
        end
        if phase == "done" then
            return
        end
        if measured then
            started = clock()
        end
        local accepted, failure = pcall(callback)
        segment(accepted and "return" or "error")
        started, updateThread = nil, nil
        if not accepted then
            if row then
                finish("failure", failure)
            end
            GameBootstrap.fail(failure)
            return
        end
        -- A production safe error replaces update; do not mask or recover it.
        if BootTrace.phase and BootTrace.phase:match("^error%.") then
            return
        end
        afterFrame()
    end
end
