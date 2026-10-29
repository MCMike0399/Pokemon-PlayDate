-- Private device builds only. Simulator transport calls the unchanged DS1 callback.
if DEVICE_TEST_BUILD ~= true then
    return
end

DeviceSmoke = {}
local gfx <const> = playdate.graphics
local buttons <const> = {
    a = playdate.kButtonA,
    b = playdate.kButtonB,
    up = playdate.kButtonUp,
    down = playdate.kButtonDown,
    left = playdate.kButtonLeft,
    right = playdate.kButtonRight,
}
local originalPressed <const> = playdate.buttonIsPressed
local originalJustPressed <const> = playdate.buttonJustPressed
local originalJustReleased <const> = playdate.buttonJustReleased
local originalButtonState <const> = playdate.getButtonState
local physicalControls = false
local active, failure, runtimeGame
local tick, lastSequence = 0, 0
local held, pressed, released = 0, 0, 0
local observedSaves, loaded, saved = nil, 0, 0

-- Same button-query seam as dev/autopilot.lua; never invoke gameplay actions.
function playdate.buttonIsPressed(button)
    return (held & button) ~= 0
end

function playdate.buttonJustPressed(button)
    return (pressed & button) ~= 0
end

function playdate.buttonJustReleased(button)
    return (released & button) ~= 0
end

function playdate.getButtonState()
    return held, pressed, released
end

local function reply(sequence, status, value)
    local paused = DeviceSmoke.pauseTiming and DeviceSmoke.pauseTiming()
    local encoded = json.encode({
        build = DEVICE_TEST_ID,
        seq = sequence,
        status = status,
        tick = tick,
        value = value,
    })
    print("DS1 " .. encoded)
    if playdate.isSimulator then
        local file = assert(playdate.file.open("device-smoke-replies.jsonl", playdate.file.kFileAppend))
        assert(file:write(encoded .. "\n"))
        file:close()
    end
    if paused then
        DeviceSmoke.resumeTiming()
    end
end

local function menuState(menu)
    if not menu or not menu.isActive then
        return nil
    end
    local options = {}
    for index = 1, math.min(#menu.options, 12) do
        options[index] = tostring(menu.options[index]):sub(1, 120)
    end
    return { selected = menu.selectedIndex, options = options }
end

local function dialogState(dialog)
    if not dialog or not dialog.isActive then
        return nil
    end
    return {
        page = dialog.currentLine,
        chars = dialog.charIndex,
        text = (dialog.lines[dialog.currentLine] or ""):sub(1, 512),
    }
end

local function snapshot()
    if GameBootstrap and GameBootstrap.isLoading() then
        return {root = "loading", phase = BootTrace and BootTrace.phase}
    end
    local result = { ready = runtimeGame ~= nil, error = failure, loaded = loaded, saved = saved,
        physical_controls = physicalControls }
    if not runtimeGame then
        return result
    end
    local machine = runtimeGame.machine
    local name = machine:getCurrent()
    local state = machine:get(name)
    result.state = name
    result.phase = state and state.phase
    result.menu = state and menuState(state.menu)
    result.dialog = state and dialogState(state.dialog)
    result.zone = currentZone and currentZone.stableID
    local player = runtimeGame.player
    if player then
        result.player =
            { x = player.gridX, y = player.gridY, facing = player.facing, moving = player.isMoving }
    end
    if name == "title" then
        result.continue_available = state.candidate ~= nil
    end
    local overworld = machine:get("overworld")
    result.overworld = overworld.sub and overworld.sub:getCurrent()
    local battleState = machine:get("battle")
    local battle, scene = battleState.battle, battleState.scene
    if battle then
        result.battle = {
            phase = battle.machine:getCurrent(),
            message = (battle.message or ""):sub(1, 512),
            player_hp = battle.player.hp,
            enemy_hp = battle.enemy.hp,
            command = scene and menuState(scene.mainMenu),
            moves = scene and menuState(scene.moveMenu),
            dialog = scene and dialogState(scene.messageDialog),
        }
    end
    local lastSave = machine:get("pause").lastSave
    if lastSave then
        result.last_save = { ok = lastSave.ok, reason = lastSave.reason }
    end
    return result
end

function DeviceSmoke.drawError()
    playdate.display.setOffset(0, 0)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawTextInRect("DEVICE TEST STOPPED\n" .. (failure or "unknown error"), 8, 8, 384, 224)
end

-- Root's guarded bootstrap can use this for startup failures too.
function DeviceSmoke.fail(message)
    if not failure then
        failure = tostring(message):sub(1, 2048)
        if BootTrace then
            pcall(BootTrace.mark, "error." .. failure:sub(1, 160), true)
        end
        held, pressed, released = 0, 0, 0
        local sequence = active and active.seq or 0
        active = nil
        reply(sequence, "error", failure)
    end
    playdate.update = DeviceSmoke.drawError
end

local function integer(text, maximum)
    if not text or not text:match("^%d+$") or #text > 8 then
        return nil
    end
    local value = tonumber(text)
    if value < 1 or value > maximum then
        return nil
    end
    return value
end

local function receive(message)
    if type(message) ~= "string" or #message > 96 then
        reply(0, "error", "message-length")
        return
    end
    local words = {}
    for word in message:gmatch("%S+") do
        words[#words + 1] = word
    end
    local sequence = integer(words[2], 16777215)
    if words[1] ~= "DS1" or not sequence then
        reply(0, "error", "envelope")
        return
    end
    if sequence <= lastSequence then
        reply(sequence, "error", "stale-sequence")
        return
    end
    lastSequence = sequence
    local op, button, frames = words[3], nil, nil
    if op == "state" and #words == 3 then
        reply(sequence, "done", snapshot())
        return
    elseif op == "manual" and #words == 3 then
        frames = 0
    elseif op == "press" and #words == 5 then
        button, frames = buttons[words[4]], integer(words[5], 120)
        if not button or not frames then
            op = nil
        end
    elseif op == "release" and #words == 4 then
        button = words[4] == "all" and 0 or buttons[words[4]]
        frames = 1
        if not button then
            op = nil
        end
    elseif op == "wait" and #words == 4 then
        frames = integer(words[4], 300)
        if not frames then
            op = nil
        end
    else
        op = nil
    end
    if not op then
        reply(sequence, "error", "command")
    elseif failure then
        reply(sequence, "error", "stopped")
    elseif not runtimeGame then
        reply(sequence, "error", "not-ready")
    elseif active then
        reply(sequence, "error", "busy")
    elseif physicalControls then
        reply(sequence, "error", "physical-controls-active")
    elseif op == "manual" then
        -- One-way handoff for user play after the recorded smoke. State reads
        -- remain available; serial inputs cannot compete with physical buttons.
        held, pressed, released = 0, 0, 0
        playdate.buttonIsPressed = originalPressed
        playdate.buttonJustPressed = originalJustPressed
        playdate.buttonJustReleased = originalJustReleased
        playdate.getButtonState = originalButtonState
        physicalControls = true
        reply(sequence, "done", snapshot())
    else
        active = { seq = sequence, op = op, button = button, frames = frames, elapsed = 0 }
        reply(sequence, "accepted", op)
    end
end

function playdate.serialMessageReceived(message)
    local ok, problem = pcall(receive, message)
    if not ok then
        DeviceSmoke.fail(problem)
    end
end

local function frame(updateGame)
    -- Observe the existing verified save boundary without recapturing or writing.
    if observedSaves ~= runtimeGame.saves then
        observedSaves = runtimeGame.saves
        local previous = observedSaves.observeBoundary
        observedSaves.observeBoundary = function(session, kind, payload, metadata)
            if kind == "loaded" then
                loaded = loaded + 1
            end
            if kind == "saved" then
                saved = saved + 1
            end
            if previous then
                previous(session, kind, payload, metadata)
            end
        end
    end
    pressed, released = 0, 0
    local request = active
    if request and request.op == "press" then
        if request.elapsed < request.frames then
            held = request.button
            if request.elapsed == 0 then
                pressed = held
            end
        else
            released, held = held, 0
        end
    elseif request and request.op == "release" then
        released = request.button == 0 and held or (held & request.button)
        held = held & ~released
    end
    updateGame()
    tick = tick + 1
    if request then
        request.elapsed = request.elapsed + 1
        local length = request.frames + (request.op == "press" and 1 or 0)
        if request.elapsed >= length then
            active = nil
            reply(request.seq, "done", snapshot())
        end
    end
    pressed, released = 0, 0
end

function DeviceSmoke.runFrame(game, updateGame)
    if failure then
        DeviceSmoke.drawError()
        return
    end
    runtimeGame = game
    local ok, problem = pcall(frame, updateGame)
    if not ok then
        DeviceSmoke.fail(problem)
        DeviceSmoke.drawError()
    end
end

playdate.setAutoLockDisabled(true)
reply(0, "ready", "serial-installed; gameplay pending")

-- Installed by private staging after main. Hardware returns before any mailbox IO.
-- Active elapsed spans exclude coroutine suspension, polling and observer writes.
-- Each yield/return row is one SDK update segment, not an entire yielding task.
DeviceSmoke.simulatorTransportVersion = 1
function DeviceSmoke.installSimulatorObserver()
    -- Root-only optional device metrics hook. Keep mailbox IO Simulator-only.
    local function poll()
        if not playdate.isSimulator then
            return
        end
        local name = "device-smoke-command.txt"
        if not playdate.file.exists(name) then
            return
        end
        local file = assert(playdate.file.open(name, playdate.file.kFileRead))
        local message = file:read(97)
        file:close()
        assert(playdate.file.delete(name))
        playdate.serialMessageReceived(message)
    end
    local elapsed <const> = playdate.getElapsedTime
    local function clock()
        return elapsed() * 1000
    end
    local clockOffset <const> = playdate.getCurrentTimeMilliseconds() - clock()
    local started, updateID, segmentID = nil, 0, 0
    local loadingSegment = false
    local segmentTrace = 0
    local excluded, pauseDepth, pauseStarted = 0, 0, nil
    local updateThread
    function DeviceSmoke.pauseTiming()
        if not started then
            return false
        end
        if pauseDepth == 0 then
            pauseStarted = clock()
        end
        pauseDepth = pauseDepth + 1
        return true
    end
    function DeviceSmoke.resumeTiming()
        pauseDepth = pauseDepth - 1
        if pauseDepth == 0 then
            excluded = excluded + clock() - pauseStarted
            pauseStarted = nil
        end
    end
    local function record(kind)
        local elapsed = clock() - started - excluded
        if pauseStarted then
            elapsed = elapsed - clock() + pauseStarted
        end
        local transition = loadingSegment or GameBootstrap.isLoading()
        if (BootTrace.sequence or 0) > segmentTrace
            and (BootTrace.phase == "battle.start.end" or BootTrace.phase == "battle.live.after_gc") then
            transition = true
        end
        segmentID = segmentID + 1
        local file = assert(playdate.file.open("device-smoke-frames.tsv", playdate.file.kFileAppend))
        assert(file:write(string.format("%s\t%d\t%d\t%s\t%.3f\t%.3f\t%d\t%.3f\n",
            DEVICE_TEST_ID, updateID, segmentID, kind, elapsed, collectgarbage("count"),
            transition and 1 or 0, started + clockOffset)))
        file:close()
    end
    local yield <const> = coroutine.yield
    coroutine.yield = function(...)
        if not started or coroutine.running() ~= updateThread then
            return yield(...)
        end
        record("yield")
        started = nil
        local values = table.pack(yield(...))
        poll()
        started = clock()
        excluded, pauseDepth, pauseStarted = 0, 0, nil
        loadingSegment = GameBootstrap.isLoading()
        segmentTrace = BootTrace.sequence or 0
        return table.unpack(values, 1, values.n)
    end
    local callback = playdate.update
    local wrapper
    wrapper = function()
        poll()
        updateID = updateID + 1
        segmentID = 0
        started = clock()
        excluded, pauseDepth, pauseStarted = 0, 0, nil
        loadingSegment = GameBootstrap.isLoading()
        segmentTrace = BootTrace.sequence or 0
        updateThread = coroutine.running()
        local ok, problem = pcall(callback)
        record(ok and "return" or "error")
        started = nil
        updateThread = nil
        if not ok then
            DeviceSmoke.fail(problem)
        end
        if playdate.update ~= wrapper then
            callback = playdate.update
            playdate.update = wrapper
        end
    end
    playdate.update = wrapper
end
