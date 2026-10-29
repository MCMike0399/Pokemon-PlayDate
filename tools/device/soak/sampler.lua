-- Private staged overlay. No per-frame recorder, mailbox, or retained history.
local clock <const> = playdate.getCurrentTimeMilliseconds
local serialInput <const> = playdate.serialMessageReceived
local originalMark <const> = BootTrace.mark
local originalGuard <const> = BootTrace.checkGuard
local elapsed <const> = function() return playdate.getElapsedTime()*1000 end
local guardChecks, observedHeap, maximumSlice, segments = 0, BootTrace.observedPeakKiB(), 0, 0
local guardTotal, guardMax, scalarTotal, scalarMax = 0, 0, 0, 0
local segmentStart, updateThread
local phaseSamples = 60
local profile = "hardware-60+60"
-- Read once, only on Simulator; the compiled PDX is identical on hardware.
if playdate.isSimulator and playdate.file.exists("soak-simulator-profile.json") then
    local config = assert(json.decodeFile("soak-simulator-profile.json"))
    assert(config.profile == "simulator-short-v1", "unknown soak profile")
    phaseSamples, profile = 1, "simulator-short-v1"
end
local function observeSegment()
    if segmentStart then
        maximumSlice = math.max(maximumSlice, elapsed()-segmentStart)
        segments = segments+1
    end
end
local function counters(row)
    row.profile = profile
    row.guard_checks, row.observed_heap_kib = guardChecks, observedHeap
    row.maximum_slice_ms, row.segments = maximumSlice, segments
    row.guard_total_ms, row.guard_max_ms = guardTotal, guardMax
    row.scalar_total_ms, row.scalar_max_ms = scalarTotal, scalarMax
    return row
end
local minute <const> = 60000
local phase, phaseStart, nextSample, armed = "setup", 0, 0, false
local count, totalMS, maxMS, previousMS = 0, 0, 0, 0
local suppressedCollections = 0
local anchorZone, anchorX, anchorY, anchorFacing

local function emit(row)
    counters(row)
    row.build = DEVICE_TEST_ID
    row.clock_ms = clock()
    row.wall_seconds = tostring(playdate.getSecondsSinceEpoch())
    local encoded = json.encode(row)
    local file = assert(playdate.file.open("soak-minute.jsonl", playdate.file.kFileAppend))
    assert(file:write(encoded .. "\n"))
    file:close()
    print("SOAK1 " .. encoded)
end

-- Keep production's startup full collection and ordinary GC steps/generational
-- mode. Suppress only DEVICE_TEST diagnostic full collections, including Continue.
BootTrace.collect = function() suppressedCollections = suppressedCollections + 1 end
BootTrace.requestCollect = function() suppressedCollections = suppressedCollections + 1 end

-- Preserve the ordinary guard, including its every-frame and loading checks.
-- These scalar count reads are guards, never snapshots or recorded history.
BootTrace.checkGuard = function()
    local start = elapsed()
    guardChecks = guardChecks+1
    -- Also cover guarded top-level imports before installSoak wraps SDK updates.
    maximumSlice = math.max(maximumSlice, BootTrace.sinceYield())
    observedHeap = math.max(observedHeap, collectgarbage("count"))
    originalGuard()
    local cost = elapsed()-start
    guardTotal, guardMax = guardTotal+cost, math.max(guardMax, cost)
end
BootTrace.mark = function(name, errorScreen)
    if not armed then return originalMark(name, errorScreen) end
    BootTrace.phase = tostring(name)
    BootTrace.sequence = (BootTrace.sequence or 0) + 1
    if not errorScreen then BootTrace.checkGuard() end
end

-- The sole synthetic command uses the original DS1 parser and four SDK button
-- query functions. No outside command can move the player during this packet.
function playdate.serialMessageReceived() end

local function sample(state, index, start)
    local heap = collectgarbage("count") -- recorded heap sample, once/minute; guards remain per frame
    emit({kind="minute", phase=phase, minute=index, heap_kib=heap,
        elapsed_ms=clock()-phaseStart, state=state.state, zone=state.zone,
        player=state.player, loaded=state.loaded, saved=state.saved,
        previous_sampler_ms=previousMS})
    previousMS = clock()-start
    totalMS, maxMS, count = totalMS+previousMS, math.max(maxMS, previousMS), count+1
    assert(heap <= 9*1024, "soak sampled heap exceeded 9 MiB")
end

local function afterFrame()
    local status, loaded, saved, inputActive = DeviceSmoke.soakStatus()
    assert(not status, status)
    assert(saved == 0, "unexpected save")
    if not armed or phase == "complete" or phase == "error" then return end
    -- Per-frame checks read existing owners without allocating snapshots.
    local machine = game.machine
    local name = machine:getCurrent()
    local world = machine:get("overworld")
    local player = game.player
    local now = clock()
    if phase == "title" then
        assert(loaded == 0 and name == "title" and machine:get("title").candidate, "title idle interrupted")
    elseif phase == "continue" then
        if name == "overworld" and world.sub:getCurrent() == "explore"
            and player and not player.isMoving then
            if inputActive then return end -- finish the ordinary release frame
            assert(loaded == 1 and saved == 0, "unverified Continue boundary")
            local state = DeviceSmoke.soakState()
            anchorZone, anchorX, anchorY, anchorFacing = state.zone,
                state.player.x, state.player.y, state.player.facing
            phase, phaseStart, nextSample = "overworld", now, now+minute
            emit({kind="overworld-start", state=state.state, zone=anchorZone, player=state.player})
        else
            assert(now-phaseStart < minute, "Continue did not settle within 60 seconds")
        end
        return
    elseif phase == "overworld" then
        assert(loaded == 1 and name == "overworld" and world.sub:getCurrent() == "explore"
            and player and not player.isMoving and currentZone.stableID == anchorZone
            and player.gridX == anchorX and player.gridY == anchorY
            and player.facing == anchorFacing,
            "earned overworld idle interrupted")
    end
    if now < nextSample then return end
    -- No catch-up loop: pauses cannot create a burst of heap reads or fake minutes.
    local index = phase == "title" and count+1 or count-phaseSamples+1
    local sampleStart = clock()
    local state = DeviceSmoke.soakState()
    assert(not state.error and state.saved == 0, state.error or "unexpected save")
    sample(state, index, sampleStart)
    nextSample = clock()+minute
    if index ~= phaseSamples then return end
    if phase == "title" then
        phase, phaseStart = "continue", clock()
        emit({kind="continue-input", command="DS1 1 press a 1"})
        serialInput("DS1 1 press a 1")
    else
        phase = "finishing"
    end
end

local function finish()
    if phase == "finishing" then
        phase = "complete"
        emit({kind="complete", samples=count, sampler_total_ms=totalMS,
            sampler_max_ms=maxMS, sampler_last_ms=previousMS,
            suppressed_test_full_collections=suppressedCollections,
            setup_full_gc="unchanged production main.lua collection before GameContext",
            idle_full_gc=0})
    end
end

function DeviceSmoke.installSoak()
    GameBootstrap.afterReady(function()
        assert(not playdate.file.exists("soak-minute.jsonl"), "fresh private soak Data required")
        local title = game.machine:get("title")
        assert(game.machine:is("title") and title.candidate and title.menu.selectedIndex == 1
            and title.actions[1] == "continue", "earned Continue must be selected at title")
        phase, phaseStart, nextSample, armed = "title", clock(), clock()+minute, true
        emit({kind="title-start", setup_full_gc="production startup only; no test full GC",
            guard="unchanged 5 s/9 MiB guard every frame and loading check", sampler_version=2,
            phase_samples=phaseSamples, sample_interval_ms=minute})
    end)
    local yield <const> = coroutine.yield
    local function resumed(...)
        segmentStart = elapsed()
        return ...
    end
    coroutine.yield = function(...)
        if not segmentStart or coroutine.running() ~= updateThread then return yield(...) end
        observeSegment()
        segmentStart = nil
        return resumed(yield(...))
    end
    local callback = playdate.update
    local wrapper
    wrapper = function()
        segmentStart, updateThread = elapsed(), coroutine.running()
        local ok, problem = pcall(callback)
        if ok then
            local start = elapsed()
            ok, problem = pcall(afterFrame)
            local cost = elapsed()-start
            scalarTotal, scalarMax = scalarTotal+cost, math.max(scalarMax, cost)
        end
        observeSegment()
        segmentStart, updateThread = nil, nil
        if ok then ok, problem = pcall(finish) end
        if not ok and phase ~= "error" then
            phase = "error"
            playdate.setAutoLockDisabled(true)
            pcall(emit, {kind="error", error=tostring(problem):sub(1, 1024), samples=count,
                sampler_total_ms=totalMS, sampler_max_ms=maxMS})
            GameBootstrap.fail(problem)
        end
        if playdate.update ~= wrapper then
            callback = playdate.update
            playdate.update = wrapper
        end
    end
    playdate.update = wrapper
end
