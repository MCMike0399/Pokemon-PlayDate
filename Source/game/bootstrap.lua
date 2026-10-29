-- Imports stay in PDZ loading; context setup runs in the SDK update coroutine.
GameBootstrap = {}
local gfx <const> = playdate.graphics
local pending = {}
local started, loading, ready = false, false, false
local failure
local sliceStart = playdate.getCurrentTimeMilliseconds()
local sliceBudget = 8
local errorFrames = 0

if DEVICE_TEST_BUILD then
    playdate.setAutoLockDisabled(true)
end

function GameBootstrap.afterReady(callback)
    assert(type(callback) == "function", "startup callback required")
    if ready then
        callback()
    else
        pending[#pending + 1] = callback
    end
end

function GameBootstrap.showLoading()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("Pokemon Blue", 146, 96)
    gfx.drawText("Loading...", 160, 112)
    gfx.drawText(tostring(BootTrace.phase or "starting"):sub(1, 48), 8, 144)
    gfx.drawText("Phase " .. tostring(BootTrace.sequence or 0), 8, 168)
    local progress = math.min((BootTrace.sequence or 0) / 340, 0.95)
    gfx.drawRect(20, 202, 360, 10)
    gfx.fillRect(22, 204, math.floor(356 * progress), 6)
end

function GameBootstrap.drawError()
    errorFrames = errorFrames + 1
    if errorFrames == 1 or errorFrames % 30 == 0 then
        BootTrace.mark("error.alive." .. tostring(errorFrames), true)
    end
    collectgarbage("step", 1)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("Game stopped safely", 12, 20)
    gfx.drawText(tostring(BootTrace.phase or "unknown phase"):sub(1, 48), 12, 52)
    local text = tostring(failure or "unknown error")
    for line = 0, 5 do
        gfx.drawText(text:sub(line * 46 + 1, (line + 1) * 46), 12, 84 + line * 20)
    end
end

function GameBootstrap.fail(message)
    failure = tostring(message)
    loading = false
    pcall(BootTrace.mark, "error." .. failure:sub(1, 160))
    print("BOOTERROR\t" .. failure)
    if DEVICE_TEST_BUILD then
        playdate.setAutoLockDisabled(true)
        if DeviceSmoke then
            DeviceSmoke.fail(failure)
        end
    end
    playdate.update = GameBootstrap.drawError
end

function GameBootstrap.checkpoint()
    if not loading then
        return
    end
    BootTrace.checkGuard()
    collectgarbage("step", 32)
    GameBootstrap.showLoading()
    BootTrace.mark("initialize.yield")
    BootTrace.yielded()
    coroutine.yield()
    BootTrace.yielded()
    sliceStart = playdate.getCurrentTimeMilliseconds()
end

function GameBootstrap.isLoading()
    return loading
end

function GameBootstrap.withLoading(phase, callback)
    local previous = loading
    loading = true
    local pause = collectgarbage("setpause", 110)
    local ok, first, second = pcall(function()
        BootTrace.mark(phase .. ".task.begin")
        if not previous then
            GameBootstrap.checkpoint()
        end
        if SourceMaps and SourceMaps._withRuntimeDefinitions then
            return SourceMaps._withRuntimeDefinitions(callback)
        end
        return callback()
    end)
    collectgarbage("setpause", pause)
    loading = previous
    if not ok then
        error(first, 0)
    end
    return first, second
end

function GameBootstrap.yieldIfDue()
    BootTrace.checkGuard()
    if loading and playdate.getCurrentTimeMilliseconds() - sliceStart >= sliceBudget then
        GameBootstrap.checkpoint()
    end
end

function GameBootstrap.runFrame(callback, game)
    if failure then
        GameBootstrap.drawError()
        return
    end
    BootTrace.yielded()
    local ok, message = pcall(function()
        BootTrace.checkGuard()
        if DEVICE_TEST_BUILD and DeviceSmoke then
            DeviceSmoke.runFrame(game, callback)
        else
            callback()
        end
        BootTrace.checkGuard()
        BootTrace.finishFrame()
    end)
    if not ok then
        GameBootstrap.fail(message)
        GameBootstrap.drawError()
    end
end

function GameBootstrap.start(initialize)
    assert(not started and type(initialize) == "function", "one startup initializer required")
    started = true
    playdate.update = function()
        loading = true
        sliceStart = playdate.getCurrentTimeMilliseconds()
        BootTrace.yielded()
        local ok, message = pcall(initialize)
        if not ok then
            GameBootstrap.fail(message)
            GameBootstrap.drawError()
            return
        end
        loading, ready = false, true
        BootTrace.mark("initialize.ready")
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do
            local accepted, problem = pcall(callback)
            if not accepted then
                GameBootstrap.fail(problem)
                return
            end
        end
    end
end
