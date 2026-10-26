-- Imported last, only in generated private staging trees with interval > 1.
-- Leave gameplay, named captures, recordings and the original eight-pair ring alone.
assert(HarnessBuild.enabled and playdate.isSimulator)
local interval <const> = HarnessBuild.recent_interval
assert(type(interval) == "number" and interval > 1 and interval % 1 == 0)
local recent <const> = HarnessCapture.recent
local manifest <const> = HarnessCapture.manifest
local lastSampledTick = nil

local function sampleCompleted()
    assert(HarnessCapture.phase == "completed" and HarnessCapture.tick > 0,
        "capture policy requires a completed tick")
    if lastSampledTick == HarnessCapture.tick then return end
    recent()
    lastSampledTick = HarnessCapture.tick
end

function HarnessCapture.recent()
    if HarnessCapture.tick % interval == 0 then sampleCompleted() end
end

function HarnessCapture.manifest()
    -- Quiesce calls this after drawing its final tick. Never relabel an old
    -- buffer or duplicate a periodic sample on the same tick.
    sampleCompleted()
    return manifest()
end

local afterFrame <const> = Harness.afterFrame
function Harness.afterFrame(game, runtimeError)
    local ok, problem = pcall(afterFrame, game, runtimeError)
    if ok then return end
    -- afterFrame lives outside main's updateGame pcall. Stop all future updates
    -- without claiming quiescence or asking the failing snapshot path for data.
    playdate.update = function() end
    local message = tostring(problem)
    local published, publicationError = pcall(function()
        local file = assert(playdate.file.open("runtime-error.json.tmp", playdate.file.kFileWrite))
        file:write(json.encode({ protocol = HarnessBuild.protocol,
            build_id = HarnessBuild.build_id, session_id = HarnessBuild.session_id,
            tick = HarnessCapture.tick, error = message }))
        file:close()
        assert(playdate.file.rename("runtime-error.json.tmp", "runtime-error.json"))
    end)
    if not published then print("afterFrame error publication failed: " .. tostring(publicationError)) end
    error(message, 0)
end
