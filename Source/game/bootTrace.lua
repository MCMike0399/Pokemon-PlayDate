-- First-import phase recorder. Startup and device tests flush every line;
-- production after title batches bounded evidence until a phase ends or fails.
BootTrace = {}
local clock <const> = playdate.getCurrentTimeMilliseconds
local filename <const> = "boot-trace.tsv"
local lastYield = clock()
local previous = lastYield
local sequence = 0
local peakHeap = 0
local buildID = DEVICE_TEST_ID or "unbound"
local pendingCollection
local memoryCollectionRunning = false
local memoryCollections = 0
local lastMemoryBefore = 0
local lastMemoryAfter = 0
local traceFile
local titleStarted = false
local diagnosticProductionPolicy = false
local failed = false
local buffered = {}
local bufferedBytes = 0
local maxBufferedBytes <const> = 8192
local maxBufferedLines <const> = 64

if json and playdate.file.exists("boot-profile-build.json") then
    local identity = json.decodeFile("boot-profile-build.json")
    if type(identity) == "table" and type(identity.build_id) == "string" then
        buildID = identity.build_id
    end
end

function BootTrace.flush()
    if #buffered == 0 then
        return
    end
    assert(traceFile:write(table.concat(buffered, "\n") .. "\n"), "cannot write boot trace")
    traceFile:flush()
    -- Keep the existing prefix on EVERY serial line, including batched output.
    print("BOOTTRACE\t" .. table.concat(buffered, "\nBOOTTRACE\t"))
    buffered = {}
    bufferedBytes = 0
end

local function write(line, mode, flush)
    if not traceFile then
        -- The first open truncates the old run; never append a prior run's tail.
        traceFile = assert(playdate.file.open(filename, mode), "cannot open boot trace")
    end
    if bufferedBytes + #line + 1 > maxBufferedBytes or #buffered >= maxBufferedLines then
        BootTrace.flush()
    end
    buffered[#buffered + 1] = line
    bufferedBytes = bufferedBytes + #line + 1
    if flush or bufferedBytes >= maxBufferedBytes or #buffered >= maxBufferedLines then
        BootTrace.flush()
    end
end

write(
    "schema\t1\tbuild\t" .. buildID .. "\tplatform\t" .. (playdate.isSimulator and "simulator" or "device"),
    playdate.file.kFileWrite,
    true
)
write(
    "sequence\tphase\tclock_ms\tsince_yield_ms\tphase_ms\theap_kib\tobserved_peak_kib",
    playdate.file.kFileAppend,
    true
)

-- Private staged-main measurement ONLY: leaves DEVICE_TEST_BUILD and all its
-- guards/collections intact. Serial sampler builds must keep the default.
function BootTrace.useProductionTracePolicyForDiagnostic()
    assert(DEVICE_TEST_BUILD, "diagnostic trace policy requires a device-test build")
    BootTrace.flush()
    diagnosticProductionPolicy = true
    BootTrace.mark("diagnostic.trace_policy.production")
    BootTrace.flush()
end

function BootTrace.mark(phase, errorScreen)
    local now = clock()
    local heap = collectgarbage("count")
    peakHeap = math.max(peakHeap, heap)
    sequence = sequence + 1
    -- Bound individual records as well as the batch, including arbitrary errors.
    phase = tostring(phase):gsub("[\t\r\n]", " ")
    if #phase > 512 then
        local cut = 513
        while phase:byte(cut) >= 128 and phase:byte(cut) <= 191 do
            cut = cut - 1
        end
        phase = phase:sub(1, cut - 1)
    end
    if phase:match("^error%.") or errorScreen then
        failed = true
    end
    -- Error-screen heartbeats must not replace the caught diagnostic reason.
    if not errorScreen then
        BootTrace.phase = phase
    end
    BootTrace.sequence = sequence
    local flush = not titleStarted or failed
        or (DEVICE_TEST_BUILD and not diagnosticProductionPolicy)
        or phase:match("%.end$") or phase:match("%.after_gc$")
        or phase == "initialize.ready"
    write(
        string.format(
            "%d\t%s\t%d\t%d\t%d\t%.3f\t%.3f",
            sequence,
            phase,
            now,
            now - lastYield,
            now - previous,
            heap,
            peakHeap
        ),
        playdate.file.kFileAppend,
        flush
    )
    previous = clock()
    if not errorScreen then
        BootTrace.checkGuard()
    end
    if phase == "title.start.end" then
        titleStarted = true
    end
end

function BootTrace.yielded()
    lastYield = clock()
end

function BootTrace.sinceYield()
    return clock() - lastYield
end

function BootTrace.observedPeakKiB()
    return peakHeap
end

function BootTrace.collect(phase)
    BootTrace.mark(phase .. ".before_gc")
    collectgarbage("collect")
    BootTrace.mark(phase .. ".after_gc")
    if DEVICE_TEST_BUILD and (phase == "title.live" or phase == "Continue.live")
        and collectgarbage("count") > 6 * 1024 then
        error("device-test live heap guard at " .. phase)
    end
end

function BootTrace.requestCollect(phase)
    pendingCollection = phase
end

local function memoryBudgetEnabled()
    return DEVICE_TEST_BUILD or not (HarnessBuild and HarnessBuild.enabled)
end

function BootTrace.memoryCollectionStatus()
    return memoryCollections, lastMemoryBefore, lastMemoryAfter
end

-- Call only after a game frame or completed loading operation has returned.
-- This collection is part of production memory management, not a test probe.
function BootTrace.collectMemoryIfNeeded()
    if not memoryBudgetEnabled() or memoryCollectionRunning then
        return
    end
    local before = collectgarbage("count")
    if before < 8 * 1024 then
        return
    end
    memoryCollectionRunning = true
    local phase = BootTrace.phase
    BootTrace.mark("memory.soft.before_gc")
    collectgarbage("collect")
    local after = collectgarbage("count")
    memoryCollections = memoryCollections + 1
    lastMemoryBefore, lastMemoryAfter = before, after
    BootTrace.mark("memory.soft.after_gc")
    BootTrace.phase = phase
    memoryCollectionRunning = false
    if after > 6 * 1024 then
        BootTrace.flush()
        error("live memory guard: " .. tostring(after) .. " KiB after collection at " .. tostring(phase))
    end
end

function BootTrace.finishFrame()
    local phase = pendingCollection
    if phase then
        pendingCollection = nil
        BootTrace.collect(phase)
    end
    BootTrace.collectMemoryIfNeeded()
end

-- These are crash-avoidance ceilings, not a calibrated performance pass.
function BootTrace.checkGuard()
    if not memoryBudgetEnabled() then
        return
    end
    local heap = collectgarbage("count")
    if heap >= 9 * 1024 then
        BootTrace.flush()
        error("device-test memory guard: " .. tostring(heap) .. " KiB at " .. tostring(BootTrace.phase))
    end
    if BootTrace.sinceYield() > 5000 then
        BootTrace.flush()
        error("device-test slice guard at " .. tostring(BootTrace.phase))
    end
end

BootTrace.mark("boot.begin")
