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

    function synth:setADSR(attack, decay, sustain, release)
        self.adsr = {attack or 0, decay or 0, sustain or 1, release or 0.002}
    end

    function synth:setLegato(flag)
        self.legato = flag and true or false
    end

    function synth:noteOff()
        local ev = sounding[self.index]
        if ev then
            ev.dur = math.max(0, hostNow - ev.t)
            sounding[self.index] = nil
        end
    end

    function synth:playNote(hz, amp, dur)
        -- A legato playNote is a pitch change on the sounding note. The
        -- envelope clock stays at the original attack, matching setLegato.
        if self.legato and sounding[self.index] then
            local ev = sounding[self.index]
            ev.points[#ev.points + 1] = {t = hostNow, hz = hz}
            return true
        end
        local ev = {
            t = hostNow,
            voice = self.index,
            hz = hz,
            amp = amp or 0,
            dur = dur or 0,
            kind = self.kind,
            duty = self.duty or 0.5,
            wave = self.wave or "-",
            adsr = self.adsr or {0, 0, 1, 0.002},
            points = {{t = hostNow, hz = hz}},
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
    -- One row per audio tick. Pitch points come from the engine's legato
    -- updates; amplitude is KantoShape.gain of the ADSR the engine set.
    for _, ev in ipairs(events) do
        if ev.dur > 0 then
            local ticks = math.max(1, math.floor(ev.dur / TICK + 1e-6))
            local adsr = ev.adsr or {0, 0, 1, 0.002}
            for i = 0, ticks - 1 do
                local t = ev.t + i * TICK
                if t >= ev.t + ev.dur - 1e-8 then
                    break
                end
                local hz = ev.hz
                for _, point in ipairs(ev.points) do
                    if point.t <= t + 1e-8 then
                        hz = point.hz
                    end
                end
                local dur = math.min(TICK, ev.t + ev.dur - t)
                local g0 = ev.amp * KantoShape.gain(adsr[1], adsr[2], adsr[3], adsr[4], i * TICK)
                local g1 = ev.amp * KantoShape.gain(adsr[1], adsr[2], adsr[3], adsr[4], i * TICK + dur)
                io.write(string.format(
                    "note\t%.8f\t%d\t%.6f\t%.6f\t%.8f\t%s\t%.6f\t%s\t%d\t%.6f\n",
                    t, ev.voice, hz, g0, dur, ev.kind, ev.duty, ev.wave, i == 0 and 0 or 1, g1
                ))
            end
        end
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
    elseif kind == "oak-arrival" then
        local dialog = {name = "dialog", lines = {"OAK: RED!"}}
        local game = gameWith({{name = "overworld"}, dialog})
        currentZone = {stableID = "pokered:CHAMPIONS_ROOM"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "route22-walk" then
        local event = {name = "event", id = "pokered:ROUTE_22:objects:2", phase = "move-npc"}
        local game = gameWith({{name = "overworld"}, event})
        currentZone = {stableID = "pokered:ROUTE_22"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "route22-league" then
        local dialog = {name = "dialog", lines = {"That loosened me up! I'm ready for"}}
        local game = gameWith({{name = "overworld"}, dialog})
        currentZone = {stableID = "pokered:ROUTE_22"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "faint-trainer" then
        local enemy = {hp = 20, maxHP = 20, species = "dewgong"}
        local player = {hp = 40, maxHP = 40, species = "bulbasaur", level = 50}
        local battle = {trainerName = "LORELEI", trainerClass = "OPP_LORELEI", enemy = enemy, player = player}
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:LORELEIS_ROOM"}
        KantoAudio.updateGame(game)
        enemy.hp = 0
        for _ = 1, 12 do
            KantoAudio.updateGame(game)
        end
    elseif kind == "faint-wild" then
        local enemy = {hp = 12, maxHP = 12, species = "rattata"}
        local player = {hp = 20, maxHP = 20, species = "pikachu", level = 5}
        local battle = {enemy = enemy, player = player}
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        enemy.hp = 0
        KantoAudio.updateGame(game)
    elseif kind == "rival-exits" then
        local pages = {lines = {""}, currentLine = 1, isActive = true}
        local dialog = {name = "dialog", dialog = pages}
        local game = gameWith({{name = "overworld"}, dialog})
        local cases = {
            {"pokered:OAKS_LAB", "RED! Gramps! Smell you later!"},
            {"Oak's Lab", "BLUE: Gramps!"},
            {"pokered:OAKS_LAB", "BLUE: Alright Gramps! Leave it all to me!"},
            {"pokered:ROUTE_22", "I heard POKEMON LEAGUE has many"},
            {"pokered:CERULEAN_CITY", "BLUE: I went to BILL's"},
            {"pokered:POKEMON_TOWER_2F", "How's your POKEDEX coming, pal?"},
            {"pokered:SS_ANNE_2F", "BLUE: I heard there was a CUT master"},
            {"pokered:SILPH_CO_7F", "RED, well good luck to you!"},
            {"pokered:OAKS_LAB", "BLUE: Gramps! I'm fed up with waiting!"},
        }
        for _, row in ipairs(cases) do
            currentZone = {stableID = row[1], name = row[1]}
            pages.lines[1] = row[2]
            KantoAudio.updateGame(game)
        end
    elseif kind == "pitched-fall" then
        local battle = {
            trainerName = "BLUE",
            enemy = {hp = 20, maxHP = 20, species = "abra"},
            player = {hp = 20, maxHP = 20, species = "rattata", level = 5},
        }
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:ROUTE_22"}
        for _, key in ipairs({"agility", "kinesis", "transform", "dizzyPunch"}) do
            battle.currentMoveKey = nil
            KantoAudio.updateGame(game)
            battle.currentMoveKey = key
            KantoAudio.updateGame(game)
        end
    elseif kind == "ball-poof" then
        local capture = {phase = "throw"}
        local battle = {
            enemy = {hp = 10, maxHP = 10, species = "pidgey"},
            player = {hp = 10, maxHP = 10, species = "pikachu", level = 5},
        }
        local game = gameWith({{name = "battle", battle = battle, scene = {captureAnimation = capture}}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        capture.phase = "absorb"
        KantoAudio.updateGame(game)
        capture.phase = "drop"
        KantoAudio.updateGame(game)
        capture.phase = "breakout"
        KantoAudio.updateGame(game)
    elseif kind == "teleport" then
        local warp = {name = "doorWarp", door = {connection = true}}
        local sub = {
            current = "doorWarp",
            getCurrent = function(self) return self.current end,
            get = function(self, name)
                if name == self.current then return warp end
            end,
        }
        local overworld = {name = "overworld", sub = sub}
        local game = gameWith({overworld})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        warp.door = {edge = "down"}
        KantoAudio.updateGame(game)
        warp.door = {preserveFacing = true}
        for _ = 1, 180 do
            KantoAudio.updateGame(game)
        end
        game.lastFieldItem = {kind = "escape-rope"}
        for _ = 1, 180 do
            KantoAudio.updateGame(game)
        end
    elseif kind == "nidorina" then
        local title = {name = "title", phase = "menu"}
        local pages = {
            lines = {
                "This world is inhabited by creatures called POKEMON!",
                "For some people, POKEMON are pets. Others use them for fights.",
            },
            currentLine = 1,
            isActive = true,
        }
        local dialog = {name = "dialog", dialog = pages}
        local game = gameWith({title, dialog})
        currentZone = nil
        KantoAudio.updateGame(game)
        pages.currentLine = 2
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "pidgeot" then
        local dialog = {name = "dialog", lines = {"PIDGEOT: Bi bibii!"}}
        local game = gameWith({{name = "overworld"}, dialog})
        currentZone = {stableID = "pokered:SAFFRON_CITY"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "fly" then
        local travel = {name = "fieldTravel", key = "fly", phase = "announce"}
        local game = gameWith({{name = "overworld"}, travel})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        travel.phase = "fade"
        KantoAudio.updateGame(game)
        game.lastFieldTravel = {key = "fly", kind = "complete"}
        travel.phase = "closed"
        KantoAudio.updateGame(game)
    elseif kind == "collision" then
        local player = {}
        local game = gameWith({{name = "overworld"}})
        game.player = player
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        player.lastTraversalBlock = {kind = "terrain", id = "wall"}
        KantoAudio.updateGame(game)
        player.lastTraversalBlock = {kind = "terrain", id = "wall-again"}
        KantoAudio.updateGame(game)
    elseif kind == "run" then
        local battle = {
            enemy = {hp = 10, maxHP = 10, species = "rattata"},
            player = {hp = 10, maxHP = 10, species = "pikachu", level = 5},
        }
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        battle.outcome = "run"
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "pound" then
        local battle = {
            enemy = {hp = 20, maxHP = 20, species = "rattata"},
            player = {hp = 20, maxHP = 20, species = "pikachu", level = 5},
            currentMoveKey = "pound",
        }
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
    elseif kind == "ship-horn" then
        local ship = {cues = {
            {symbol = "SFX_STOP_ALL_MUSIC"},
            {symbol = "MUSIC_SURFING"},
            {symbol = "SFX_SS_ANNE_HORN"},
        }}
        local event = {name = "event", vermilionShip = ship}
        local game = gameWith({{name = "overworld"}, event})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "party-swap" then
        local party = {name = "party", phase = "swap", swapFrom = 1}
        local game = gameWith({{name = "overworld"}, party})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        party.phase = "list"
        party.swapFrom = nil
        KantoAudio.updateGame(game)
        party.swapReceipt = {from = 1, to = 2}
        KantoAudio.updateGame(game)
    elseif kind == "purchase" then
        local shop = {name = "shop", phase = "browse", trade = "buy", result = nil}
        local game = gameWith({{name = "overworld"}, shop})
        currentZone = {stableID = "pokered:VIRIDIAN_MART"}
        KantoAudio.updateGame(game)
        shop.phase = "result"
        shop.result = {ok = true, kind = "purchase"}
        KantoAudio.updateGame(game)
        shop.trade = "sell"
        shop.result = {ok = true, kind = "sale"}
        KantoAudio.updateGame(game)
    elseif kind == "menu-save" then
        local game = gameWith({{name = "overworld"}})
        currentZone = {stableID = "pokered:PALLET_TOWN"}
        KantoAudio.updateGame(game)
        game.lastSave = {ok = true}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "potion" then
        local game = gameWith({{name = "overworld"}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        game.lastItemUse = {effect = "heal", hpRestored = 20}
        KantoAudio.updateGame(game)
        game.lastItemUse = {effect = "cure", statusCured = "poison"}
        KantoAudio.updateGame(game)
        game.lastItemUse = {effect = "fullRestore", hpRestored = 5, statusCured = "burn"}
        KantoAudio.updateGame(game)
    elseif kind == "dex-page" then
        local battle = {
            enemy = {hp = 0, maxHP = 10, species = "pidgey"},
            player = {hp = 10, maxHP = 10, species = "pikachu", level = 5},
            outcome = "caught",
            dexPageAdded = "pidgey",
        }
        local game = gameWith({{name = "battle", battle = battle}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
    elseif kind == "poison-tick" then
        local game = gameWith({{name = "overworld"}})
        currentZone = {stableID = "pokered:ROUTE_1"}
        KantoAudio.updateGame(game)
        game.lastFieldPoison = {step = 4}
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    elseif kind == "dex-rating" then
        local game = gameWith({{name = "overworld"}})
        currentZone = {stableID = "pokered:OAKS_LAB"}
        KantoAudio.updateGame(game)
        game.lastDexRating = {owned = 20}
        KantoAudio.updateGame(game)
    elseif kind == "switch-can" then
        local event = {name = "event", phase = "dialog", waiting = "none"}
        local game = gameWith({{name = "overworld"}, event})
        currentZone = {stableID = "pokered:VERMILION_GYM"}
        KantoAudio.updateGame(game)
        event.waiting = "_VermilionGymTrashSuccessText1"
        KantoAudio.updateGame(game)
    elseif kind == "bill-shrink" then
        local event = {name = "event", phase = "dialog", waiting = "_BillsHouseInitiatedText"}
        local game = gameWith({{name = "overworld"}, event})
        currentZone = {stableID = "pokered:BILLS_HOUSE"}
        KantoAudio.updateGame(game)
        event.phase = "story-machine"
        event.waiting = "cell-separator"
        KantoAudio.updateGame(game)
    elseif kind == "safari-over" then
        local passage = {name = "safariPassage", phase = "announcement"}
        local game = gameWith({{name = "overworld"}, passage})
        currentZone = {stableID = "pokered:SAFARI_ZONE_EAST"}
        KantoAudio.updateGame(game)
    elseif kind == "ceremony" then
        local event = {name = "event", phase = "hall-photo"}
        local game = gameWith({{name = "overworld"}, event})
        currentZone = {stableID = "pokered:HALL_OF_FAME"}
        KantoAudio.updateGame(game)
        event.phase = "credits"
        KantoAudio.updateGame(game)
        KantoAudio.updateGame(game)
    else
        error("unknown observe " .. tostring(kind))
    end
end

local function shapeProbe()
    -- Fixed cases. The slide numbers are Music_PkmnHealed channel 1's first
    -- pitch_slide after Audio1_InitPitchSlideVars (current 2039, target 1915).
    -- The envelope is note_type 12, 12, 1 (byte 0xC1). The vibrato is extent
    -- 4, rate 0, delay 0, note-on low byte 100, direction clear.
    local function line(fmt, ...)
        io.write(string.format(fmt, ...))
    end
    local slide = {0, 1, 14, 16384, 0.5333, 0.5, 129, {p = 2040, s = {2039, 1915, 9, 12, 1}}}
    for _, elapsed in ipairs({0, 1, 5, 13}) do
        line("direct\tslide\t%d\t%d\t%.4f\n", elapsed, KantoShape.periodAt(slide, elapsed), KantoShape.hz(slide, elapsed))
    end
    local attack, decay, sustain, release = KantoShape.adsr(193, 1)
    line("direct\tadsr\t%.6f\t%.6f\t%.6f\t%.6f\n", attack, decay, sustain, release)
    for _, t in ipairs({0, 6 / 64, 12 / 64}) do
        line("direct\tgain\t%.6f\t%.6f\n", t, KantoShape.gain(attack, decay, sustain, release, t))
    end
    local vib = {0, 1, 8, 1000, 1, 0, 0, {p = 100, v = {0, 4, 0, 100, 0}}}
    for _, elapsed in ipairs({0, 1, 2}) do
        line("direct\tvibrato\t%d\t%d\t%.4f\n", elapsed, KantoShape.periodAt(vib, elapsed), KantoShape.hz(vib, elapsed))
    end

    local function play(name, note, steps)
        KantoSynth.stop()
        resetClock()
        KantoScores = KantoScores or {}
        KantoScores[name] = {ticks = 32, loop = nil, notes = {note}}
        KantoSynth.music(name)
        for _ = 1, steps do
            step(1)
        end
        for _, ev in ipairs(events) do
            for _, point in ipairs(ev.points) do
                local elapsed = math.floor((point.t - ev.t) / TICK + 1e-6)
                line(
                    "engine\t%s\t%d\t%.4f\t%.6f\t%.6f\t%.6f\t%.6f\n",
                    name, elapsed, point.hz, ev.adsr[1], ev.adsr[2], ev.adsr[3], ev.adsr[4]
                )
            end
        end
    end
    play("probe_slide", slide, 13)
    play("probe_vib", vib, 2)
    play("probe_env", {0, 1, 16, 440, 12 / 15, 0.5, 193}, 0)
end

local command = arg[1]
local name = arg[2]
if command == "clip" then
    clip(name)
elseif command == "observe" then
    observe(name)
elseif command == "shape" then
    shapeProbe()
else
    error("usage: host_engine.lua clip|observe|shape name")
end
