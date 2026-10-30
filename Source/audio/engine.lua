-- Four physical synth voices, musical clock in source ticks; no gameplay state.
import "audio/cries"

KantoSynth = {}

local sound <const> = playdate.sound
local tickSeconds <const> = 70224 / 4194304
local voices = {}
local layers = {}
local rendered = {}
local waveSamples = {}
local currentWave = nil
local master = nil
local serial = 0
local priorities <const> = {
    menu = 3,
    hit = 2,
    faint = 1,
}

local function init()
    if master then
        return
    end

    master = sound.channel.new()
    master:setVolume(0.22)

    for i = 1, 4 do
        local waveform = sound.kWaveSquare
        if i == 4 and sound.kWaveNoise then
            waveform = sound.kWaveNoise
        end
        voices[i] = sound.synth.new(waveform)
        master:addSource(voices[i])
    end
end

local function layer(name, now, score)
    score = score or assert(KantoScores[name], "unknown Kanto score")
    serial = serial + 1
    local firstLoop = 1

    if score.loop then
        while firstLoop <= #score.notes and score.notes[firstLoop][1] < score.loop do
            firstLoop = firstLoop + 1
        end
        assert(firstLoop <= #score.notes, "empty score loop")
    end

    return {
        name = name,
        score = score,
        start = now,
        offset = 0,
        cursor = 1,
        active = {},
        firstLoop = firstLoop,
        serial = serial,
    }
end

local function advance(track, now)
    if not track then
        return
    end

    local score = track.score
    local tick = (now - track.start) / tickSeconds

    -- Fast-forward whole musical laps after sleep without replaying stale notes.
    if score.loop and tick - track.offset > score.ticks * 2 then
        local laps = math.floor(
            (tick - track.offset - score.ticks) / (score.ticks - score.loop)
        )
        track.offset = track.offset + laps * (score.ticks - score.loop)
        track.cursor = track.firstLoop
        track.active = {}
    end

    while true do
        local note = score.notes[track.cursor]
        if note and note[1] + track.offset <= tick then
            track.active[note[2]] = {
                note = note,
                finish = track.start + (track.offset + note[1] + note[3]) * tickSeconds,
                id = track.serial .. ":" .. track.offset .. ":" .. track.cursor,
                cry = score.holds ~= nil,
            }
            track.cursor = track.cursor + 1
        elseif tick >= score.ticks + track.offset then
            if not score.loop then
                return nil
            end
            track.offset = track.offset + score.ticks - score.loop
            track.cursor = track.firstLoop
        else
            break
        end
    end

    for i, active in pairs(track.active) do
        if now >= active.finish then
            track.active[i] = nil
        end
    end

    return track
end

local function choose(i, now)
    local cry = layers.cry
    if cry and now < cry.start + cry.score.holds[i] * tickSeconds then
        -- An owned rest suppresses the bed too, including the source wave mute.
        return cry.active[i]
    end
    if layers.sfx and layers.sfx.active[i] then
        return layers.sfx.active[i]
    end
    if i == 1 and layers.alarm and layers.alarm.active[i] then
        return layers.alarm.active[i]
    end

    local bed = layers.jingle or layers.music
    return bed and bed.active[i]
end

function KantoSynth.update(now)
    if not master then
        return
    end

    now = now or sound.getCurrentTime()
    for key, track in pairs(layers) do
        layers[key] = advance(track, now)
    end

    for i = 1, 4 do
        local active = choose(i, now)
        local id = active and active.id
        if rendered[i] ~= id then
            local synth = voices[i]
            synth:noteOff()
            rendered[i] = id

            if active then
                local note = active.note
                if i <= 2 then
                    synth:setParameter(1, note[6])
                elseif i == 3 then
                    local key = assert(note[8], "wave note has no source waveform")
                    if currentWave ~= key then
                        local sample = waveSamples[key]
                        if not sample then
                            local path = assert(KantoWaveforms[key], "unknown source waveform")
                            sample = assert(sound.sample.new(path), "source waveform could not load")
                            assert(sample:getFormat() == sound.kFormat16bitMono, "waveform must be PCM16 mono")
                            waveSamples[key] = sample
                        end
                        -- One cell is one complete source wave RAM cycle. The
                        -- wavetable oscillator takes Hz directly in playNote.
                        synth:setWavetable(sample, 32, 1)
                        synth:setParameter(1, 0)
                        currentWave = key
                    end
                end

                -- Source envelope pace is 64 Hz; SDK ADSR is the audible approximation.
                local pace = note[7] & 7
                local rising = (note[7] & 8) ~= 0
                local envelopeTime = 0
                if pace > 0 then
                    local envelopeSteps = note[7] >> 4
                    if rising then
                        envelopeSteps = 15 - envelopeSteps
                    end
                    envelopeTime = pace * envelopeSteps / 64
                end

                if i == 3 then
                    synth:setADSR(0, 0, 1, 0.002)
                elseif pace == 0 then
                    synth:setADSR(0, 0, 1, 0.002)
                elseif rising then
                    synth:setADSR(envelopeTime, 0, 1, 0.002)
                else
                    synth:setADSR(0, envelopeTime, 0, 0.002)
                end

                local pitch = note[4]
                if not active.cry then
                    pitch = math.max(20, math.min(16000, pitch))
                end
                assert(
                    synth:playNote(pitch, note[5], math.max(.001, active.finish - now)),
                    "Kanto synth note rejected"
                )
            end
        end
    end
end

function KantoSynth.music(name)
    init()
    if layers.music and layers.music.name == name then
        return
    end

    layers.jingle = nil
    layers.music = name and layer(name, sound.getCurrentTime()) or nil
    KantoSynth.update()
end

function KantoSynth.sfx(name)
    init()
    local now = sound.getCurrentTime()
    layers.sfx = advance(layers.sfx, now)

    if name == "heal" then
        layers.jingle = layer(name, now)
    else
        local priority = assert(priorities[name], "unknown Kanto SFX")
        if layers.sfx and priorities[layers.sfx.name] < priority then
            return false
        end
        layers.sfx = layer(name, now)
    end

    KantoSynth.update(now)
    return true
end

function KantoSynth.cry(species)
    local bed = layers.jingle or layers.music
    local family = bed and KantoCryMusicBanks[bed.name] or 1
    local score, reason = KantoCries.score(species, family)
    if not score then
        return false, reason
    end
    init()
    local now = sound.getCurrentTime()
    layers.cry = layer("cry:" .. species, now, score)
    KantoSynth.update(now)
    return true
end

function KantoSynth.lowHP(flag)
    init()
    if flag and not layers.alarm then
        layers.alarm = layer("alarm", sound.getCurrentTime())
    elseif not flag then
        layers.alarm = nil
    end
    KantoSynth.update()
end

function KantoSynth.stop()
    layers = {}
    rendered = {}
    for _, synth in ipairs(voices) do
        synth:stop()
    end
end
