-- First-import phase recorder. Each line is flushed to survive a watchdog.
BootTrace = {}
local clock <const> = playdate.getCurrentTimeMilliseconds
local filename <const> = "boot-trace.tsv"
local lastYield = clock()
local previous = lastYield
local sequence = 0
local peakHeap = 0
local buildID = DEVICE_TEST_ID or "unbound"
local pendingCollection
local traceFile

if json and playdate.file.exists("boot-profile-build.json") then
    local identity = json.decodeFile("boot-profile-build.json")
    if type(identity) == "table" and type(identity.build_id) == "string" then
        buildID = identity.build_id
    end
end

local function write(line, mode)
    if not traceFile then
        traceFile = assert(playdate.file.open(filename, mode), "cannot open boot trace")
    end
    assert(traceFile:write(line .. "\n"), "cannot write boot trace")
    traceFile:flush()
    print("BOOTTRACE\t" .. line)
end

write(
    "schema\t1\tbuild\t" .. buildID .. "\tplatform\t" .. (playdate.isSimulator and "simulator" or "device"),
    playdate.file.kFileWrite
)
write(
    "sequence\tphase\tclock_ms\tsince_yield_ms\tphase_ms\theap_kib\tobserved_peak_kib",
    playdate.file.kFileAppend
)

function BootTrace.mark(phase, errorScreen)
    local now = clock()
    local heap = collectgarbage("count")
    peakHeap = math.max(peakHeap, heap)
    sequence = sequence + 1
    phase = tostring(phase):gsub("[\t\r\n]", " ")
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
        playdate.file.kFileAppend
    )
    previous = clock()
    BootTrace.phase = phase
    BootTrace.sequence = sequence
    if not errorScreen then
        BootTrace.checkGuard()
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

function BootTrace.finishFrame()
    local phase = pendingCollection
    if phase then
        pendingCollection = nil
        BootTrace.collect(phase)
    end
end

-- These are crash-avoidance ceilings, not a calibrated performance pass.
function BootTrace.checkGuard()
    if not DEVICE_TEST_BUILD then
        return
    end
    local heap = collectgarbage("count")
    if heap > 9 * 1024 then
        error("device-test memory guard: " .. tostring(heap) .. " KiB at " .. tostring(BootTrace.phase))
    end
    if BootTrace.sinceYield() > 5000 then
        error("device-test slice guard at " .. tostring(BootTrace.phase))
    end
end

BootTrace.mark("boot.begin")
