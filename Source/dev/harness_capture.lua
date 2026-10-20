-- Raw buffers omit display transforms. Explicit captures are retained by name;
-- recent frames live in a bounded, tick-named ring in private runtime Data.
HarnessCapture = { tick = 0, phase = "before-first-frame" }
if not playdate.isSimulator or not HarnessBuild.enabled then return end
local gfx <const> = playdate.graphics
local retained, recentFrames = {}, {}
playdate.file.mkdir("recent")

function HarnessCapture.display()
    local x, y = playdate.display.getOffset()
    local mx, my = playdate.display.getMosaic()
    return { offsetX = x, offsetY = y, scale = playdate.display.getScale(),
        inverted = playdate.display.getInverted(), mosaicX = mx, mosaicY = my,
        backgroundColor = gfx.getBackgroundColor() }
end

local function writePair(name, root, storage)
    local display = HarnessCapture.display()
    assert(display.scale == 1 and not display.inverted and display.mosaicX == 0 and display.mosaicY == 0,
        "capture supports display offset only; unsupported display transform")
    local raw = gfx.getWorkingImage()
    local presentation = gfx.image.new(400, 240, display.backgroundColor)
    gfx.pushContext(presentation)
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    raw:draw(display.offsetX, display.offsetY)
    gfx.popContext()
    local rawName, displayName = name .. ".png", name .. "-display.png"
    playdate.simulator.writeToFile(raw, root .. rawName)
    playdate.simulator.writeToFile(presentation, root .. displayName)
    return { tick = HarnessCapture.tick, phase = HarnessCapture.phase,
        raw = rawName, presentation = displayName, storage = storage, display = display,
        presentation_transform = "offset-on-background-v1", time_ms = playdate.getCurrentTimeMilliseconds() }
end

function HarnessCapture.write(name)
    local capture = writePair(name, HarnessBuild.output_dir, "frames")
    retained[name] = capture
    local file = assert(playdate.file.open("captures.jsonl", playdate.file.kFileAppend))
    file:write(json.encode(capture) .. "\n")
    file:close()
end

function HarnessCapture.recent()
    local name = string.format("recent/frame-%08d", HarnessCapture.tick)
    local capture = writePair(name, HarnessBuild.data_dir .. "/", "runtime-data")
    recentFrames[#recentFrames + 1] = capture
    if #recentFrames > 8 then
        local old = table.remove(recentFrames, 1)
        assert(playdate.file.delete(old.raw))
        assert(playdate.file.delete(old.presentation))
    end
end

function HarnessCapture.manifest()
    local captures = {}
    local names = {}
    for name in pairs(retained) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do captures[#captures + 1] = retained[name] end
    return { schema = 1, quiescent = true, capture_tick = HarnessCapture.tick,
        captures = captures, capture_count = #captures,
        recent_frames = recentFrames, recent_count = #recentFrames, recent_limit = 8 }
end
