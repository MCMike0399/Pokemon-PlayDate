-- Private capture overlay only. No game, input, RNG, flags, audio or clock changes.
local preflightStart = nil
local previousRecent = HarnessCapture.recent
function HarnessCapture.recent()
    previousRecent()
    if HarnessCapture.phase ~= "completed" then return end
    local f = playdate.file.open("showcase-control.txt", playdate.file.kFileRead)
    if not f then return end
    local label = f:read(64)
    f:close()
    if not label or not label:match("^[a-z]+$") then return end
    if label == "preflight" then
        local now = playdate.getCurrentTimeMilliseconds()
        preflightStart = preflightStart or now
        if now - preflightStart > 3000 then return end
    end
    local gfx = playdate.graphics
    local d = HarnessCapture.display()
    assert(d.scale == 1 and not d.inverted and d.mosaicX == 0 and d.mosaicY == 0)
    local raw = gfx.getWorkingImage()
    local image = gfx.image.new(400, 240, d.backgroundColor)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    raw:draw(d.offsetX, d.offsetY)
    gfx.popContext()
    local name = string.format("showcase-%s-%08d.png", label, HarnessCapture.tick)
    local now = playdate.getCurrentTimeMilliseconds()
    playdate.simulator.writeToFile(image, HarnessBuild.output_dir .. name)
    local log = assert(playdate.file.open("showcase-frames.jsonl", playdate.file.kFileAppend))
    log:write(json.encode({label=label, file=name, tick=HarnessCapture.tick,
        time_ms=now, phase=HarnessCapture.phase, display=d}) .. "\n")
    log:close()
end
