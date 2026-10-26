-- Isolated probe only. Never imported by production Source.
local sound <const> = playdate.sound
local identity <const> = ProbeIdentity
local gain <const> = identity.audible and 0.03 or 0
local period <const> = 0.12
local voices = {}
local instruments = {}
local samples = {}
local sequence
local generation = 1
local stopped = false
local frame = 0
local startTime
local phase = "loops"
local phaseTime
local actionIndex = 0
local stalled = false
local previousTime
local report = {
    identity = identity,
    fixture = "synthetic PCM phase markers; no music fidelity claim",
    observations = {},
    events = {},
    errors = {},
    loops = {},
    ends = {},
    starts = {},
    controlErrors = {},
    status = "running",
    limits = {
        offset = "SDK seconds, not waveform sample proof",
        sequenceLoops = "finite SDK loop configuration; step wraps are observations, not exact loop counts",
        synthOffset = "no documented synth sample cursor",
        underruns = "fileplayer flag only; synth underrun metric unavailable",
        steal = "API and state observations only; no waveform verification",
        heap = "Lua heap KB includes this instrumentation; native memory unavailable",
        capacity = "no physical device capacity or listening claim",
    },
}

local function append(list, value, bound)
    assert(#list < bound, "probe observation bound exceeded")
    list[#list + 1] = value
end

local function event(kind, voice, extra)
    append(report.events, {
        kind = kind, voice = voice, audioTime = sound.getCurrentTime(),
        frame = frame, detail = extra,
    }, 1200)
end

local function publish(name, value)
    local temporary = name .. ".tmp"
    local file = assert(playdate.file.open(temporary, playdate.file.kFileWrite))
    local encoded = json.encode(value)
    local written, message = file:write(encoded)
    file:close()
    assert(written == #encoded, "incomplete probe publication: " .. tostring(message))
    assert(playdate.file.rename(temporary, name))
end

local function finish(status, message)
    if stopped then return end
    stopped = true
    generation = generation + 1 -- invalidate every callback before stopping SDK objects
    playdate.update = function() end -- stop snapshot producer BEFORE publication
    if message then append(report.errors, tostring(message), 32) end
    if sequence then
        local ok, errorMessage = pcall(function() sequence:stop() end)
        if not ok then append(report.errors, tostring(errorMessage), 32) end
    end
    for _, voice in ipairs(voices) do
        local ok, errorMessage = pcall(function()
            voice:setVolume(0)
            voice:stop()
        end)
        if not ok then append(report.errors, tostring(errorMessage), 32) end
    end
    if #report.errors > 0 and status == "complete" then status = "error" end
    report.status = status
    report.finishedAudioTime = sound.getCurrentTime()
    report.heapEndKB = collectgarbage("count")
    report.quiescent = true
    report.publication = "producer-stopped-v1"
    publish("RuntimeSnapshot.json", report)
    -- Last write is the host barrier. No callback/update can mutate report now.
    publish("done.json", {
        identity = identity, status = status, quiescent = true,
        publication = "producer-stopped-v1",
    })
end

local function voiceState(voice, index)
    local left, right = voice:getVolume()
    local state = {voice = index, playing = voice:isPlaying(), left = left, right = right}
    if identity.mode == "streams" then
        state.offset = voice:getOffset()
        state.underrun = voice:didUnderrun()
        state.loopCallbacks = #report.loops[index]
        if startTime then
            state.clockPhaseError = ((state.offset - (sound.getCurrentTime() - startTime)
                + period / 2) % period) - period / 2
        end
    end
    return state
end

local function observe()
    local now = sound.getCurrentTime()
    local row = {
        frame = frame, audioTime = now,
        wallMS = playdate.getCurrentTimeMilliseconds(),
        audioDelta = previousTime and now - previousTime or 0,
        phase = phase, heapKB = collectgarbage("count"), voices = {},
    }
    previousTime = now
    for index, voice in ipairs(voices) do
        row.voices[index] = voiceState(voice, index)
    end
    if sequence then
        row.step = sequence:getCurrentStep()
        row.sequencePlaying = sequence:isPlaying()
        row.expectedStepPhase = ((now - startTime) * 100) % 12
        row.stepPhaseError = ((row.step - row.expectedStepPhase + 6) % 12) - 6
    else
        local low, high = math.huge, -math.huge
        for _, state in ipairs(row.voices) do
            low = math.min(low, state.offset)
            high = math.max(high, state.offset)
        end
        row.offsetSpread = high - low -- wrap-boundary discontinuity must be considered
    end
    append(report.observations, row, 1000)
    return row
end

local function setup()
    playdate.display.setRefreshRate(30)
    report.systemVolume = playdate.getSystemVolume() -- read only; never change OS volume
    report.heapStartKB = collectgarbage("count")
    report.sampleRate = sound.getSampleRate()
    local token = generation
    if identity.mode == "sequence" then
        sequence = assert(sound.sequence.new(), "sequence allocation failed")
        sequence:setTempo(100)
        sequence:setLoops(0, 12, identity.loops)
        report.sequenceConfig = {tempo = 100, startStep = 0, endStep = 12, loopCount = identity.loops}
    end
    for index = 1, 4 do
        local voice
        report.loops[index] = {}
        report.ends[index] = {}
        if identity.mode == "streams" then
            voice = assert(sound.fileplayer.new("voice" .. index, 0.25), "fileplayer allocation failed")
            voices[index] = voice -- retain partial setup for error cleanup
            voice:setVolume(gain)
            voice:setStopOnUnderrun(true)
            voice:setLoopRange(0, period)
            voice:setLoopCallback(function(player)
                if stopped or token ~= generation then return end
                append(report.loops[index], {
                    audioTime = sound.getCurrentTime(), offset = player:getOffset(), frame = frame,
                    callbackIndex = #report.loops[index] + 1,
                    clockDrift = sound.getCurrentTime() - startTime
                        - (#report.loops[index] + 1) * period,
                }, 110)
            end)
            voice:setFinishCallback(function(player)
                if stopped or token ~= generation then return end
                append(report.ends[index], {
                    audioTime = sound.getCurrentTime(), offset = player:getOffset(),
                    underrun = player:didUnderrun(), phase = phase, frame = frame,
                }, 16)
            end)
        else
            local sample, errorMessage = sound.sample.new("voice" .. index)
            assert(sample, "PCM load failed: " .. tostring(errorMessage))
            samples[index] = sample
            -- Real documented PCM constructor. Unsupported SDK behavior FAILS.
            voice = assert(sound.synth.new(sample, 1, 5292), "PCM synth allocation failed")
            voices[index] = voice
            voice:setVolume(gain)
            voice:setADSR(0, 0, 1, 0.02)
            local instrument = assert(sound.instrument.new(voice), "instrument allocation failed")
            instruments[index] = instrument
            local track = assert(sequence:addTrack(), "track allocation failed")
            track:setInstrument(instrument)
            track:addNote(0, 60, 8, 1)
            -- Explicit zero-velocity final event makes the loop extent 12 steps.
            track:addNote(11, 60, 1, 0)
        end
    end
    startTime = sound.getCurrentTime()
    report.startAudioTime = startTime
    if sequence then
        report.starts[1] = {before = startTime}
        sequence:play(function()
            if stopped or token ~= generation then return end
            event("sequence-end", 0)
            report.sequenceEnded = true
        end)
        report.starts[1].after = sound.getCurrentTime()
        report.sequenceLength = sequence:getLength()
        assert(report.sequenceLength == 12, "unexpected sequence length")
    else
        for index, voice in ipairs(voices) do
            local before = sound.getCurrentTime()
            local ok, errorMessage = voice:play(identity.loops + 1)
            report.starts[index] = {before = before, after = sound.getCurrentTime(), ok = ok,
                                    error = errorMessage}
            assert(ok, "fileplayer play failed: " .. tostring(errorMessage))
        end
        report.startCallSkew = report.starts[4].after - report.starts[1].before
    end
end

local function summarizeLoops()
    if sequence then
        report.sequenceLoopWitness = "SDK finite loop count plus completion; no per-loop callback API"
        report.sequenceExpectedSeconds = period * identity.loops
        report.sequenceEndClockDifference = report.loopElapsed - report.sequenceExpectedSeconds
        return
    end
    local firstLow, firstHigh = math.huge, -math.huge
    report.streamLoopSummary = {}
    for index = 1, 4 do
        local loops = report.loops[index]
        assert(#loops >= identity.loops, "fewer than 100 stream loop callbacks")
        assert(not report.ends[index][1].underrun, "stream ended on underrun")
        firstLow = math.min(firstLow, loops[1].audioTime)
        firstHigh = math.max(firstHigh, loops[1].audioTime)
        report.streamLoopSummary[index] = {
            callbacks = #loops, first = loops[1], last = loops[#loops],
            firstToLastDrift = loops[#loops].audioTime - loops[1].audioTime
                - (#loops - 1) * period,
        }
    end
    report.firstLoopCallbackSkew = firstHigh - firstLow
end

local function allEnded()
    if sequence then return report.sequenceEnded == true end
    for index = 1, 4 do
        if #report.ends[index] == 0 then return false end
    end
    return true
end

-- Four serial control exercises, 400 ms each, after the loop arm ends.
-- The one-voice instruments force documented stealing on a second active note.
local function controlExercise(now)
    local wanted = math.floor((now - phaseTime) / 0.1)
    if wanted <= actionIndex then return end
    actionIndex = actionIndex + 1 -- no unbounded catch-up loop after a stall
    local index = math.floor((actionIndex - 1) / 4) + 1
    local action = (actionIndex - 1) % 4
    if index > 4 then
        if #report.controlErrors > 0 then
            finish("error", "control state errors; inspect controlErrors")
        else
            finish("complete")
        end
        return
    end
    local voice = voices[index]
    if action == 0 then
        if sequence then
            local result = instruments[index]:playMIDINote(60, 1)
            event("control-note-on", index, {result = result})
        else
            local ok, errorMessage = voice:play(1)
            event("control-play", index, {ok = ok, error = errorMessage})
            assert(ok, tostring(errorMessage))
        end
    elseif action == 1 then
        voice:setVolume(0)
        local muted = voiceState(voice, index)
        event("gate-muted", index, muted)
        if muted.left ~= 0 or (muted.right and muted.right ~= 0) then
            append(report.controlErrors, "gate readback mismatch voice " .. index, 32)
        end
        if sequence then
            local result = instruments[index]:playMIDINote(62, 1)
            event("one-voice-instrument-steal-request", index, {result = result})
        else
            -- Explicit stop/restart approximation, not a native stream voice-steal claim.
            voice:stop()
            local ok, errorMessage = voice:play(1)
            event("stream-replacement", index, {ok = ok, error = errorMessage})
            assert(ok, tostring(errorMessage))
        end
    elseif action == 2 then
        voice:setVolume(gain * 0.5, gain) -- per-side gain/readback, no acoustic claim
        if sequence then voice:noteOff() else voice:stop() end
        event("release-request", index, voiceState(voice, index))
    else
        local released = voiceState(voice, index)
        event("release-observed", index, released)
        if released.playing then
            append(report.controlErrors, "release still playing voice " .. index, 32)
        end
        voice:stop()
        voice:setVolume(gain)
    end
end

local function update()
    frame = frame + 1
    local beginMS = playdate.getCurrentTimeMilliseconds()
    local now = sound.getCurrentTime()
    if playdate.file.exists("cancel.json") then
        local cancel = json.decodeFile("cancel.json")
        if cancel and cancel.identity and cancel.identity.probe_id == identity.probe_id then
            finish("cancelled")
            return
        end
    end
    assert(frame <= 950, "frame bound exceeded")
    assert(now - startTime < 25, "audio clock deadline exceeded")
    if not stalled and now - startTime >= 2 then
        stalled = true
        local before = observe()
        local endMS = playdate.getCurrentTimeMilliseconds() + 200
        local iterations = 0
        repeat
            iterations = iterations + 1
        until playdate.getCurrentTimeMilliseconds() >= endMS or iterations >= 10000000
        local after = observe()
        report.stall = {before = before, after = after, iterations = iterations,
                        gameMS = playdate.getCurrentTimeMilliseconds() - beginMS}
    end
    if phase == "loops" and allEnded() then
        report.loopEndAudioTime = now
        report.loopElapsed = now - startTime
        summarizeLoops()
        phase = "controls"
        phaseTime = now
    elseif phase == "controls" then
        controlExercise(now)
    end
    if stopped then return end
    local row = observe()
    row.updateMS = playdate.getCurrentTimeMilliseconds() - beginMS
end

playdate.update = function()
    if stopped then return end
    local ok, message = pcall(function()
        if not startTime then setup() end
        update()
    end)
    if not ok then finish("error", message) end
end
