-- Imported only by the outside-Git calibration builder; never by the game.
local pd <const> = playdate
local gfx <const> = pd.graphics
local clock <const> = pd.getElapsedTime
local BLOCK <const> = 8
local BLOCKS <const> = 8192
local SLICE_MS <const> = 2
local MAX_BLOCKS_PER_FRAME <const> = 32
local phase, current, failure, pending
local lastExit, heartbeat = nil, 0
local records = {}
local state = "starting"
local build <const> = CALIBRATION_BUILD
local platform <const> = pd.isSimulator and "simulator" or "device"

local function emit(kind, value)
    print("CAL1 " .. json.encode({kind = kind, build_id = build.id, value = value}))
end

local function persist()
    local payload = {
        schema = 1, build_id = build.id, source_sha256 = build.source_sha256,
        sdk_version = build.sdk_version, platform = platform, status = state,
        error = failure, phases = records,
        timer = "getElapsedTime; seconds, documented microsecond accuracy; active game time",
        timing_scope = "active Lua spans including GC/preemption; excludes between-update delay; not OS CPU time",
        slice_target_ms = SLICE_MS, block_work = BLOCK, blocks_per_phase = BLOCKS,
        frame_block_cap = MAX_BLOCKS_PER_FRAME,
        timer_accuracy_us = 1,
        timer_elapsed_s = clock(),
        timer_limits = "game time pauses while inactive; float precision degrades with uptime; no hard real-time/OS CPU guarantee",
    }
    local text = json.encode(payload)
    local file = assert(pd.file.open("calibration.json", pd.file.kFileWrite))
    local count = file:write(text)
    file:flush()
    file:close()
    assert(count == #text, "short calibration write")
end

local function startPhase()
    phase = (phase or 0) + 1
    if phase > 2 then
        state = "complete"
        current = nil
        BootTrace.mark("calibration.complete")
        persist()
        emit("complete", {platform = platform})
        return
    end
    current = {
        name = phase == 1 and "lua_compute" or "small_tables",
        blocks = 0, work_count = 0, checksum = 1,
        active_work_ms = 0, inter_frame_ms = 0,
        max_block_ms = 0, max_work_slice_ms = 0, frames = 0, zero_blocks = 0,
    }
    records[phase] = current
    state = current.name
    BootTrace.mark("calibration." .. state .. ".begin")
    persist()
end

local function block()
    local value = current.checksum
    for _ = 1, BLOCK do
        -- Values remain small exact integers on both SDK targets.
        if phase == 1 then
            for _ = 1, 16 do
                value = (value * 17 + 31) % 65521
            end
        else
            -- One eight-element table at a time; no retained allocation corpus.
            local cells = {value, 3, 5, 7, 11, 13, 17, 19}
            for i = 1, 8 do
                value = (value + cells[i] * i) % 65521
            end
        end
    end
    current.checksum = value
    current.blocks = current.blocks + 1
    current.work_count = current.work_count + BLOCK
end

local function step()
    local entry = clock()
    if pending then
        pending = nil
        startPhase()
        return
    end
    if not current then
        return
    end
    local count = 0
    repeat
        local before = clock()
        block()
        local duration = (clock() - before) * 1000
        current.max_block_ms = math.max(current.max_block_ms, duration)
        if duration == 0 then
            current.zero_blocks = current.zero_blocks + 1
        end
        count = count + 1
    until current.blocks == BLOCKS or count == MAX_BLOCKS_PER_FRAME or (clock() - entry) * 1000 >= SLICE_MS
    local duration = (clock() - entry) * 1000
    current.active_work_ms = current.active_work_ms + duration
    current.frames = current.frames + 1
    current.max_work_slice_ms = math.max(current.max_work_slice_ms, duration)
    current.heap_kib = collectgarbage("count")
    if current.blocks == BLOCKS then
        current.complete = true
        pending = true
        BootTrace.mark("calibration." .. current.name .. ".done")
        persist()
        emit("phase", current)
    end
end

local function fail(problem)
    if failure then
        return
    end
    failure = tostring(problem):sub(1, 320)
    state = "error"
    current = nil
    pending = nil
    pcall(persist)
    pcall(function() BootTrace.mark("calibration.error", true) end)
    pcall(emit, "error", failure)
end

local function draw()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("CALIBRATION / USB KEEPER", 8, 8)
    gfx.drawText("Synthetic only. No gameplay gate.", 8, 38)
    gfx.drawText("State: " .. state, 8, 68)
    gfx.drawText("Alive: " .. tostring(heartbeat), 8, 98)
    if failure then
        gfx.drawTextInRect(failure, 8, 128, 384, 104)
    end
end

function pd.update()
    heartbeat = (heartbeat + 1) % 1000000
    local entry = clock()
    if current and lastExit and not pending then
        current.inter_frame_ms = current.inter_frame_ms + (entry - lastExit) * 1000
    end
    local ok, problem = pcall(step)
    if not ok then
        fail(problem)
    end
    local drawn, drawProblem = pcall(draw)
    if not drawn then
        fail(drawProblem)
    end
    BootTrace.yielded()
    lastExit = clock()
end

-- Exact read-only commands. No evaluation, input injection, restart or mutation.
function pd.serialMessageReceived(message)
    if message ~= "CAL1 ping" and message ~= "CAL1 status" then
        return
    end
    local ok, problem = pcall(emit, "status", {
        state = state, platform = platform, heartbeat = heartbeat, error = failure,
        phase = phase, blocks = current and current.blocks,
    })
    if not ok then
        fail(problem)
    end
end

local ok, problem = pcall(function()
    pd.setAutoLockDisabled(true)
    pd.display.setRefreshRate(30)
    pd.resetElapsedTime()
    pending = true
    emit("ready", {platform = platform, source_sha256 = build.source_sha256})
end)
if not ok then
    fail(problem)
end
