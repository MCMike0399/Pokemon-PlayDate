-- Private SDK overlay. The original capture implementation is imported intact.
import "dev/capture_stress_config"
import "dev/harness_capture_base"

local gfx <const> = playdate.graphics
local config <const> = CaptureStressConfig
local workingImage <const> = gfx.getWorkingImage
local exportImage <const> = playdate.simulator.writeToFile
local recent <const> = HarnessCapture.recent
local count, frames = 0, 0

local function mark(phase, path)
    local player = game and game.player
    local data = {
        synthetic_stress = true,
        phase = phase,
        path = path,
        tick = HarnessCapture.tick,
        captures = count,
        stress_frames = frames,
        explicit_gc = config.explicit_gc,
        heap_kib = collectgarbage("count"),
        time_ms = playdate.getCurrentTimeMilliseconds(),
        player = player and {
            x = player.gridX, y = player.gridY,
            moving = player.isMoving, move_frames = player.moveFrames,
        } or nil,
    }
    local file = assert(playdate.file.open("capture-stress.json.tmp", playdate.file.kFileWrite))
    file:write(json.encode(data))
    file:close()
    assert(playdate.file.rename("capture-stress.json.tmp", "capture-stress.json"))
end

function gfx.getWorkingImage()
    mark("working-image-enter")
    local image = workingImage()
    mark("working-image-return")
    return image
end

function playdate.simulator.writeToFile(image, path)
    mark("export-enter", path)
    local result = exportImage(image, path)
    mark("export-return", path)
    return result
end

function HarnessCapture.recent()
    -- Preserve the real ring and its real frame ticks. Additional captures use
    -- one retained explicit name: stress allocations/export, not file retention.
    recent()
    if not game or currentZone ~= zoneRegistry.kanto_pewter_city or frames >= config.frames then
        return
    end
    frames = frames + 1
    for _ = 1, config.batch do
        if config.explicit_gc then
            mark("gc-enter")
            collectgarbage("collect")
            mark("gc-return")
        end
        HarnessCapture.write("synthetic-stress")
        count = count + 1
    end
    mark(frames == config.frames and "stress-complete" or "batch-complete")
end
