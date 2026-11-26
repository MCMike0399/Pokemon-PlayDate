-- Four physical synth voices, musical clock in source ticks; no gameplay state.
-- Scores and cries load on first play so importing this module stays small.
-- Pitch slides, vibrato, and envelope curves live in audio/shape.lua so the
-- host renderer and this synth share one implementation.

KantoSynth = {}
import "audio/shape"

local sound <const> = playdate.sound
local tickSeconds <const> = 70224 / 4194304
local voices = {}
local layers = {}
local rendered = {}
local waveSamples = {}
local currentWave = nil
local master = nil
local serial = 0
-- A playing sound rejects a new one when its number is lower.
-- faint (1) therefore blocks menu (3); equal numbers replace.
local priorities <const> = {
    faint = 1,
    faint_fall = 1,
    faint_fall_agility = 1,
    faint_fall_kinesis = 1,
    faint_fall_transform = 1,
    faint_fall_dizzy_punch = 1,
    flute = 1,
    hit = 2,
    arrow_tiles = 2,
    denied = 2,
    boulder = 2,
    text = 2,
    ledge = 2,
    healing_machine = 2,
    intro_crash = 3,
    intro_whoosh = 3,
    intro_lunge = 3,
    shooting_star = 3,
    teleport_exit_1 = 3,
    teleport_enter_1 = 3,
    teleport_exit_2 = 3,
    teleport_enter_2 = 3,
    ball_poof = 2,
    ball_toss = 2,
    run = 2,
    collision = 2,
    swap = 2,
    heal_hp = 2,
    heal_ailment = 2,
    save = 2,
    purchase = 2,
    pokedex_rating = 2,
    dex_page = 2,
    poisoned = 2,
    switch = 2,
    shrink = 2,
    safari_pa = 3,
    fly = 3,
    anne_horn = 3,
    menu = 3,
    start_menu = 3,
    go_inside = 3,
    go_outside = 3,
    cut = 3,
    pc_on = 3,
    pc_off = 3,
    pc_enter = 3,
    pc_withdraw = 3,
    tink = 3,
}

local function liveScoreNames()
    local names = {}
    for _, entry in pairs(layers) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name:sub(1, 4) ~= "cry:" then
            names[entry.name] = true
        end
    end
    return names
end

-- file.run builds one packed score on first play and KantoScores keeps it.
-- A map bed used to be hundreds of KiB of note tables. Main kept every score
-- in one import. Head loads them while zones are built, and the old beds were
-- still live at the next map, which is the out-of-memory on the cerulean and
-- vermilion suites. Drop every score the synth is not playing before the next
-- file.run, and drop wave samples that score no longer uses.
local function scoreWaves(score, into)
    if type(score) ~= "table" then
        return
    end
    if type(score.waves) == "table" then
        for _, key in ipairs(score.waves) do
            into[key] = true
        end
    end
    if score.parts then
        for _, part in ipairs(score.parts) do
            scoreWaves(part, into)
        end
    end
    if score.notes then
        for _, note in ipairs(score.notes) do
            if type(note) == "table" then
                for index = #note, 8, -1 do
                    if type(note[index]) == "string" then
                        into[note[index]] = true
                        break
                    end
                end
            end
        end
    end
end

local function releaseUnusedWaves()
    local needed = {}
    if type(KantoScores) == "table" then
        for _, score in pairs(KantoScores) do
            scoreWaves(score, needed)
        end
    end
    local cry = layers.cry
    if type(cry) == "table" and cry.score then
        scoreWaves(cry.score, needed)
    end
    for key in pairs(waveSamples) do
        if not needed[key] then
            waveSamples[key] = nil
        end
    end
    if currentWave and not needed[currentWave] then
        currentWave = nil
    end
end

local function releaseCryCatalogs()
    KantoCryPrograms = nil
    KantoCryHeaders = nil
    KantoCryBases = nil
    KantoCrySpecies = nil
    KantoCryMusicBanks = nil
end

local function releaseIdleScores(keep)
    if type(KantoScores) ~= "table" then
        return
    end
    local live = liveScoreNames()
    if keep then
        live[keep] = true
    end
    for name in pairs(KantoScores) do
        if not live[name] then
            KantoScores[name] = nil
        end
    end
    releaseUnusedWaves()
    collectgarbage("collect")
end

function KantoSynth.unloadAll()
    layers.music, layers.jingle, layers.sfx, layers.cry, layers.alarm = nil, nil, nil, nil, nil
    rendered = {}
    waveSamples = {}
    currentWave = nil
    if type(KantoScores) == "table" then
        for name in pairs(KantoScores) do
            KantoScores[name] = nil
        end
    end
    releaseCryCatalogs()
    -- Imported stubs stay in the main chunk. The tables are file.run targets.
    KantoMoveSfx = nil
    KantoPacked = nil
    if type(KantoEvents) == "table" then
        KantoEvents.fieldReceipts = nil
        KantoEvents.maps = nil
        KantoEvents.aliases = nil
    end
    collectgarbage("collect")
end

-- The record decoder lives in audio/packed.lua so unloadAll can drop it
-- before the next city inflates. Cries and the host stub still use note tables.
local function packedApi()
    if not KantoPacked then
        playdate.file.run("audio/packed")
    end
    return KantoPacked
end

local function bindPacked(score)
    return packedApi().bind(score)
end

local function noteCount(score)
    return packedApi().count(score)
end

local function noteAt(score, index)
    return packedApi().noteAt(score, index)
end

local function nowSeconds(now)
    if now ~= nil then
        return now
    end
    local current = sound.getCurrentTime()
    if current == nil then
        return 0
    end
    return current
end

local function runScoreFile(scorePath)
    playdate.file.run(scorePath)
end

local function ensureScore(name)
    if KantoScores and KantoScores[name] then
        return bindPacked(KantoScores[name])
    end
    KantoScores = KantoScores or {}
    releaseIdleScores(name)
    -- import() is only legal while a pdz is loading, and pdc 3.1.2 treats a
    -- literal "audio/score/" prefix as a file request. file.run loads the
    -- compiled score pdz the first time that score plays.
    local scorePath = "audio/score/" .. name
    -- The score file calls KantoPacked.words while it loads.
    packedApi()
    local ok, err = pcall(runScoreFile, scorePath)
    local score = KantoScores[name]
    if not score then
        -- A failed constructor can throw nil once the pool cannot hold the
        -- error string. Always surface a string so the harness can record it.
        if not ok and type(err) == "string" and err ~= "" then
            error(err, 0)
        end
        error("unknown Kanto score " .. tostring(name), 0)
    end
    return bindPacked(score)
end

local function init()
    if not KantoWaveforms then
        playdate.file.run("audio/routes")
    end
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

local function track(name, now, score)
    serial = serial + 1
    local firstLoop = 1

    if score.loop then
        local count = noteCount(score)
        while firstLoop <= count do
            local note = noteAt(score, firstLoop)
            if not note or note[1] >= score.loop then
                break
            end
            firstLoop = firstLoop + 1
        end
        assert(firstLoop <= count, "empty score loop")
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

local function layer(name, now, score)
    score = bindPacked(score or ensureScore(name))
    -- Channels whose pokered labels do not share a joint period.
    if score.parts then
        local parts = {}
        for index, part in ipairs(score.parts) do
            parts[index] = track(name, now, part)
        end
        return {name = name, parts = parts}
    end
    return track(name, now, score)
end

local function voiced(playing, i)
    if not playing then
        return nil
    end
    if playing.parts then
        for _, part in ipairs(playing.parts) do
            if part and part.active[i] then
                return part.active[i]
            end
        end
        return nil
    end
    return playing.active[i]
end

local function advance(playing, now)
    if not playing then
        return
    end
    if playing.parts then
        for index, part in ipairs(playing.parts) do
            playing.parts[index] = advance(part, now)
        end
        return playing
    end

    local track = playing
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
        local note = noteAt(score, track.cursor)
        if note and note[1] + track.offset <= tick then
            track.active[note[2]] = {
                note = note,
                born = track.start + (track.offset + note[1]) * tickSeconds,
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
    return voiced(bed, i)
end

local function waveKey(note)
    for index = #note, 8, -1 do
        if type(note[index]) == "string" then
            return note[index]
        end
    end
end

local function elapsedTicks(active, now)
    return math.max(0, math.floor((now - active.born) / tickSeconds + 1e-6))
end

local function pitched(active, now)
    local pitch = KantoShape.hz(active.note, elapsedTicks(active, now))
    if not active.cry then
        pitch = math.max(20, math.min(16000, pitch))
    end
    return pitch
end

function KantoSynth.update(now)
    if not master then
        return
    end

    now = nowSeconds(now)
    for key, track in pairs(layers) do
        layers[key] = advance(track, now)
    end

    for i = 1, 4 do
        local active = choose(i, now)
        local id = active and active.id
        local synth = voices[i]
        if rendered[i] ~= id then
            synth:noteOff()
            rendered[i] = id

            if active then
                local note = active.note
                if i <= 2 then
                    synth:setParameter(1, note[6])
                elseif i == 3 then
                    local key = assert(waveKey(note), "wave note has no source waveform")
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
                local attack, decay, sustain, release = KantoShape.adsr(note[7], i)
                synth:setADSR(attack, decay, sustain, release)
                synth:setLegato(false)

                local pitch = pitched(active, now)
                active.pitch = pitch
                assert(
                    synth:playNote(pitch, note[5], math.max(.001, active.finish - now)),
                    "Kanto synth note rejected"
                )
            end
        elseif active then
            -- Same note. setLegato keeps the envelope running while the pitch
            -- follows Audio1_ApplyPitchSlide / the vibrato block.
            local pitch = pitched(active, now)
            if math.abs(pitch - active.pitch) >= 0.00005 then
                active.pitch = pitch
                synth:setLegato(true)
                assert(
                    synth:playNote(pitch, active.note[5], math.max(.001, active.finish - now)),
                    "Kanto synth pitch update rejected"
                )
                synth:setLegato(false)
            end
        end
    end
end

function KantoSynth.music(name, keepJingle)
    init()
    -- Same bed: leave an in-progress jingle alone.
    if layers.music and layers.music.name == name then
        return
    end
    if not keepJingle then
        layers.jingle = nil
    end
    -- Drop the old bed before ensureScore so its note tables can be collected
    -- before the next score is built.
    layers.music = nil
    layers.music = name and layer(name, nowSeconds()) or nil
    KantoSynth.update()
end

function KantoSynth.jingle(name)
    init()
    local now = nowSeconds()
    layers.jingle = layer(name, now)
    KantoSynth.update(now)
    return true
end

function KantoSynth.jingling()
    return layers.jingle ~= nil
end

function KantoSynth.scoreTicks(name)
    return ensureScore(name).ticks
end

-- Move rows share priority 2. Their names are move_<key>, not cue names.
local function sfxPriority(name)
    local known = priorities[name]
    if known then
        return known
    end
    if type(name) == "string" and name:sub(1, 5) == "move_" then
        return 2
    end
    return nil
end

function KantoSynth.sfx(name)
    init()
    local now = nowSeconds()
    layers.sfx = advance(layers.sfx, now)

    if name == "heal" then
        layers.jingle = layer(name, now)
    else
        local priority = assert(sfxPriority(name), "unknown Kanto SFX")
        local playing = layers.sfx and sfxPriority(layers.sfx.name)
        if playing and playing < priority then
            return false
        end
        layers.sfx = layer(name, now)
    end

    KantoSynth.update(now)
    return true
end

function KantoSynth.cry(species)
    if not KantoCries then
        playdate.file.run("audio/cries")
    end
    -- The bank table is only needed to pick the family. score() drops it.
    KantoCries.ensureData()
    local bed = layers.jingle or layers.music
    local banks = KantoCryMusicBanks
    local family = bed and banks and banks[bed.name] or 1
    local score, reason = KantoCries.score(species, family)
    if not score then
        return false, reason
    end
    init()
    local now = nowSeconds()
    layers.cry = layer("cry:" .. species, now, score)
    KantoSynth.update(now)
    return true
end

function KantoSynth.lowHP(flag)
    init()
    if flag and not layers.alarm then
        layers.alarm = layer("alarm", nowSeconds())
    elseif not flag then
        layers.alarm = nil
    end
    KantoSynth.update()
end

function KantoSynth.stop()
    KantoSynth.unloadAll()
    layers = {}
    rendered = {}
    for _, synth in ipairs(voices) do
        synth:stop()
    end
end
