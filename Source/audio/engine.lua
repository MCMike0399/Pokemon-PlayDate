-- Four physical synth voices, musical clock in source ticks; no gameplay state.
KantoSynth = {}
local sound <const> = playdate.sound
local tickSeconds <const> = 70224 / 4194304
local voices, layers, rendered = {}, {}, {}
local master = nil
local serial = 0
local priorities <const> = {menu=3, hit=2, faint=1}

local function init()
    if master then return end
    master = sound.channel.new()
    master:setVolume(0.22)
    for i=1,4 do
        local waveform = i==4 and sound.kWaveNoise or (i==3 and sound.kWaveTriangle or sound.kWaveSquare)
        voices[i] = sound.synth.new(waveform)
        master:addSource(voices[i])
    end
end

local function layer(name, now)
    local score = assert(KantoScores[name], "unknown Kanto score")
    serial = serial+1
    local firstLoop = 1
    if score.loop then
        while firstLoop<=#score.notes and score.notes[firstLoop][1]<score.loop do firstLoop=firstLoop+1 end
        assert(firstLoop<=#score.notes, "empty score loop")
    end
    return {name=name, score=score, start=now, offset=0, cursor=1, active={},
        firstLoop=firstLoop, serial=serial}
end

local function advance(track, now)
    if not track then return end
    local score = track.score
    local tick = (now-track.start)/tickSeconds
    -- Fast-forward whole musical laps after sleep without replaying stale notes.
    if score.loop and tick-track.offset>score.ticks*2 then
        local laps = math.floor((tick-track.offset-score.ticks)/(score.ticks-score.loop))
        track.offset=track.offset+laps*(score.ticks-score.loop)
        track.cursor=track.firstLoop
        track.active={}
    end
    while true do
        local note=score.notes[track.cursor]
        if note and note[1]+track.offset<=tick then
            track.active[note[2]]={note=note, finish=track.start+(track.offset+note[1]+note[3])*tickSeconds,
                id=track.serial..":"..track.offset..":"..track.cursor}
            track.cursor=track.cursor+1
        elseif tick>=score.ticks+track.offset then
            if not score.loop then return nil end
            track.offset=track.offset+score.ticks-score.loop
            track.cursor=track.firstLoop
        else break end
    end
    for i,active in pairs(track.active) do
        if now>=active.finish then track.active[i]=nil end
    end
    return track
end

local function choose(i)
    if layers.sfx and layers.sfx.active[i] then return layers.sfx.active[i] end
    if i==1 and layers.alarm and layers.alarm.active[i] then return layers.alarm.active[i] end
    local bed=layers.jingle or layers.music
    return bed and bed.active[i]
end

function KantoSynth.update(now)
    if not master then return end
    now=now or sound.getCurrentTime()
    for key,track in pairs(layers) do layers[key]=advance(track,now) end
    for i=1,4 do
        local active=choose(i)
        local id=active and active.id
        if rendered[i]~=id then
            local synth=voices[i]
            synth:noteOff()
            rendered[i]=id
            if active then
                local n=active.note
                if i<=2 then synth:setParameter(1,n[6]) end
                -- Source envelope pace is 64 Hz; SDK ADSR is the audible approximation.
                local pace=n[7]&7
                local rising=(n[7]&8)~=0
                local envelopeTime=pace>0 and pace*(rising and (15-(n[7]>>4)) or (n[7]>>4))/64 or 0
                if i==3 then synth:setADSR(0,0,1,0.002)
                elseif pace==0 then synth:setADSR(0,0,1,0.002)
                elseif rising then synth:setADSR(envelopeTime,0,1,0.002)
                else synth:setADSR(0,envelopeTime,0,0.002) end
                local pitch=math.max(20,math.min(16000,n[4]))
                assert(synth:playNote(pitch,n[5],math.max(.001,active.finish-now)), "Kanto synth note rejected")
            end
        end
    end
end

function KantoSynth.music(name)
    init()
    if layers.music and layers.music.name==name then return end
    layers.jingle=nil
    layers.music=name and layer(name,sound.getCurrentTime()) or nil
    KantoSynth.update()
end
function KantoSynth.sfx(name)
    init()
    local now=sound.getCurrentTime()
    layers.sfx=advance(layers.sfx,now)
    if name=="heal" then
        layers.jingle=layer(name,now)
    else
        local priority=assert(priorities[name],"unknown Kanto SFX")
        if layers.sfx and priorities[layers.sfx.name]<priority then return false end
        layers.sfx=layer(name,now)
    end
    KantoSynth.update(now)
    return true
end
function KantoSynth.lowHP(flag)
    init()
    if flag and not layers.alarm then layers.alarm=layer("alarm",sound.getCurrentTime())
    elseif not flag then layers.alarm=nil end
    KantoSynth.update()
end
function KantoSynth.stop()
    layers={};rendered={}
    for _,synth in ipairs(voices) do synth:stop() end
end
