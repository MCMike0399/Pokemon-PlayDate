-- Host stand-in for playdate.sound. Loads the game's engine and steps it.
-- This is not a Simulator capture. The oscillators are written by host_render.py.

local script = debug.getinfo(1, "S").source:sub(2)
local toolsAudio = script:match("(.*/)") or "./"
local repo = toolsAudio .. "../.."
local sourceRoot = repo .. "/Source"

local hostNow = 0
local events = {}
local sounding = {}

local function noop() end

playdate = {
    kButtonA = 1,
    buttonJustPressed = function()
        return false
    end,
    sound = {
        kWaveSquare = "square",
        kWaveNoise = "noise",
        kFormat16bitMono = "pcm16",
        getCurrentTime = function()
            return hostNow
        end,
    },
}

local sound = playdate.sound
sound.channel = {}
sound.synth = {}
sound.sample = {}

function sound.channel.new()
    return {setVolume = noop, addSource = noop}
end

function sound.sample.new(path)
    return {
        path = path,
        getFormat = function()
            return sound.kFormat16bitMono
        end,
    }
end

local voiceCount = 0

function sound.synth.new(kind)
    voiceCount = voiceCount + 1
    local synth = {
        index = voiceCount,
        kind = kind == sound.kWaveNoise and "noise" or "square",
        duty = 0.5,
        wave = "-",
    }

    function synth:setParameter(id, value)
        if id == 1 then
            self.duty = value
        end
    end

    function synth:setWavetable(sample)
        self.wave = sample and sample.path or "-"
        self.kind = "wave"
    end

    function synth:setADSR() end

    function synth:noteOff()
        local ev = sounding[self.index]
        if ev then
            ev.dur = math.max(0, hostNow - ev.t)
            sounding[self.index] = nil
        end
    end

    function synth:playNote(hz, amp, dur)
        local ev = {
            t = hostNow,
            voice = self.index,
            hz = hz,
            amp = amp or 0,
            dur = dur or 0,
            kind = self.kind,
            duty = self.duty or 0.5,
            wave = self.wave or "-",
        }
        events[#events + 1] = ev
        sounding[self.index] = ev
        return true
    end

    function synth:stop()
        self:noteOff()
    end

    return synth
end

function import(name)
    local path = sourceRoot .. "/" .. name .. ".lua"
    local chunk, err = loadfile(path)
    if not chunk then
        error(err)
    end
    chunk()
end

dofile(sourceRoot .. "/audio/engine.lua")

local TICK = 70224 / 4194304

local function step(count)
    for _ = 1, count do
        hostNow = hostNow + TICK
        KantoSynth.update()
    end
end

local function ticksFor(seconds)
    return math.floor(seconds / TICK + 0.5)
end

local function emitNotes()
    for _, ev in ipairs(events) do
        io.write(string.format(
            "note\t%.8f\t%d\t%.6f\t%.6f\t%.8f\t%s\t%.6f\t%s\n",
            ev.t, ev.voice, ev.hz, ev.amp, ev.dur, ev.kind, ev.duty, ev.wave
        ))
    end
end

local function resetClock()
    hostNow = 0
    events = {}
    sounding = {}
end

local function clip(kind)
    resetClock()
    if kind == "title" then
        KantoSynth.music("title")
        step(ticksFor(8))
    elseif kind == "route1" then
        KantoSynth.music("route1")
        step(ticksFor(8))
    elseif kind == "champion" then
        KantoSynth.music("final")
        step(ticksFor(8))
    elseif kind == "heal" then
        KantoSynth.sfx("healing_machine")
        KantoSynth.sfx("heal")
        step(ticksFor(4))
    elseif kind == "trainer" then
        -- The jingle replaces the bed while it loops, so the clip plays the
        -- jingle and then restarts the trainer bed.
        KantoSynth.music("trainer")
        KantoSynth.jingle("meet_male")
        step(ticksFor(3.5))
        KantoSynth.stop()
        KantoSynth.music("trainer")
        step(ticksFor(6))
    elseif kind == "mansion" then
        KantoSynth.music("mansion")
        events = {}
        sounding = {}
        hostNow = 9000 * TICK
        KantoSynth.update()
        step(700)
    else
        error("unknown clip " .. tostring(kind))
    end
    emitNotes()
end

local function logCall(name, arg)
    io.write(string.format("call\t%s\t%s\n", name, tostring(arg)))
end

local function wrapSynth()
    for _, name in ipairs({"music", "jingle", "sfx", "cry", "stop"}) do
        local fn = KantoSynth[name]
        KantoSynth[name] = function(arg, ...)
            logCall(name, arg)
            return fn(arg, ...)
        end
    end
end

local function gameWith(stack)
    return {
        session = {},
        machine = {
            stack = stack,
            get = function(self, name)
                for index = #self.stack, 1, -1 do
                    local state = self.stack[index]
                    if state.name == name then
                        return state
                    end
                end
            end,
        },
    }
end

local function observe(kind)
    dofile(sourceRoot .. "/game/kantoAudio.lua")
    wrapSynth()
    if kind == "title" then
        local title = {name = "title", phase = "menu", idle = {species = "squirtle"}}
        local game = gameWith({title})
        currentZone = nil
        for _ = 1, 102 do
            KantoAudio.updateGame(game)
        end
        title.phase = "confirm-new"
        KantoAudio.updateGame(game)
    elseif kind == "leave-title" then
        local title = {name = "title", phase = "menu", idle = {species = "squirtle"}}
        local game = gameWith({title})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        game.machine.stack = {{name = "overworld"}}
        KantoAudio.updateGame(game)
    elseif kind == "cancel-evolution" then
        local sub = {
            current = "announce",
            getCurrent = function(self)
                return self.current
            end,
        }
        local evo = {
            name = "evolution",
            active = true,
            sub = sub,
            info = {from = "pidgey", to = "pidgeotto", species = "pidgeotto"},
        }
        local game = gameWith({{name = "overworld"}, evo})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        sub.current = "animate"
        KantoAudio.updateGame(game)
        sub.current = "result"
        evo.result = {kind = "cancelled"}
        KantoAudio.updateGame(game)
    elseif kind == "complete-evolution" then
        local sub = {
            current = "animate",
            getCurrent = function(self)
                return self.current
            end,
        }
        local evo = {
            name = "evolution",
            active = true,
            sub = sub,
            info = {from = "pidgey", to = "pidgeotto", species = "pidgeotto"},
        }
        local game = gameWith({{name = "overworld"}, evo})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        sub.current = "result"
        evo.result = {kind = "complete"}
        KantoAudio.updateGame(game)
    elseif kind == "receipt" then
        local event = {
            name = "event",
            phase = "receipt",
            waiting = "_VermilionOldRodHouseFishingGuruTakeThisText",
        }
        local dialog = {name = "dialog", lines = {"RED got an OLD ROD!"}}
        local game = gameWith({{name = "overworld"}, event, dialog})
        currentZone = {stableID = "pokered:VERMILION_CITY"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "meet-oak" then
        local dialog = {name = "dialog", lines = {"OAK: Hey! Wait! Don't go out!"}}
        local game = gameWith({{name = "overworld"}, dialog})
        currentZone = {stableID = "pallet_town"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    else
        error("unknown observe " .. tostring(kind))
    end
end

local command = arg[1]
local name = arg[2]
if command == "clip" then
    clip(name)
elseif command == "observe" then
    observe(name)
else
    error("usage: host_engine.lua clip|observe name")
end
