-- Imports stay in PDZ loading; context setup runs in the SDK update coroutine.
GameBootstrap = {}
local gfx <const> = playdate.graphics
local pending = {}
local started, loading, ready = false, false, false

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
    gfx.drawText("Loading...", 160, 124)
    playdate.display.flush()
end

function GameBootstrap.checkpoint()
    if not loading then
        return
    end
    GameBootstrap.showLoading()
    coroutine.yield()
end

function GameBootstrap.start(initialize)
    assert(not started and type(initialize) == "function", "one startup initializer required")
    started = true
    playdate.update = function()
        loading = true
        initialize()
        loading, ready = false, true
        local callbacks = pending
        pending = {}
        for _, callback in ipairs(callbacks) do
            callback()
        end
    end
end
