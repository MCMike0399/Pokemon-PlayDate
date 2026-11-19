-- Host probe. Lua 5.4 loads the data table and select.lua; Playdate is not required.
local root = arg[1]
assert(root and root ~= "", "pass the repository root")
dofile(root .. "/Source/audio/events.lua")
dofile(root .. "/Source/audio/select.lua")

local function show(key, value)
    if value == nil then
        value = "nil"
    elseif value == true then
        value = "true"
    elseif value == false then
        value = "false"
    end
    io.write(key, "\t", tostring(value), "\n")
end

for id, score in pairs(KantoEvents.maps) do
    show("map:" .. id, score)
end
for name, _ in pairs(KantoEvents.evil) do
    show("evil:" .. name, "true")
end
for name, _ in pairs(KantoEvents.female) do
    show("female:" .. name, "true")
end
for name, _ in pairs(KantoEvents.rivalSilent) do
    show("rival:" .. name, "true")
end
for name, row in pairs(KantoEvents.legendary) do
    show("legend:" .. name, row.id)
end
for name, cue in pairs(KantoEvents.cues) do
    show("cue:" .. name, cue.score .. ":" .. cue.kind)
end

local function battle(label, info)
    show("score:" .. label, KantoEvents.battleScore(info))
    show("kind:" .. label, KantoEvents.battleKind(info))
    show("victory:" .. label, KantoEvents.victoryScore(info))
end

battle("wild", {wild = true, species = "rattata"})
battle("articuno", {wild = true, species = "articuno"})
battle("mewtwo", {wild = true, species = "mewtwo", trainerClass = "OPP_YOUNGSTER"})
battle("gym-flag", {trainerClass = "OPP_YOUNGSTER", gymLeaderNo = 1})
battle("gym-zero", {trainerClass = "OPP_YOUNGSTER", gymLeaderNo = 0})
battle("rival3", {trainerClass = "OPP_RIVAL3"})
battle("lance", {trainerClass = "OPP_LANCE", gymLeaderNo = 0})
battle("brock-nil", {trainerClass = "OPP_BROCK"})
battle("brock-zero", {trainerClass = "OPP_BROCK", gymLeaderNo = 0})
battle("giovanni-gym", {trainerClass = "OPP_GIOVANNI", zone = "pokered:VIRIDIAN_GYM"})
battle("giovanni-hideout", {trainerClass = "OPP_GIOVANNI", zone = "pokered:ROCKET_HIDEOUT_B4F"})
battle("giovanni-zero", {trainerClass = "OPP_GIOVANNI", gymLeaderNo = 0, zone = "pokered:VIRIDIAN_GYM"})
battle("youngster", {trainerClass = "OPP_YOUNGSTER", gymLeaderNo = 0})

show("jingle:lass", KantoEvents.trainerJingle("OPP_LASS", 0))
show("jingle:rocket", KantoEvents.trainerJingle("OPP_ROCKET", 0))
show("jingle:youngster", KantoEvents.trainerJingle("OPP_YOUNGSTER", nil))
show("jingle:rival", KantoEvents.trainerJingle("OPP_RIVAL1", nil))
show("jingle:brock", KantoEvents.trainerJingle("OPP_BROCK", 0))
show("jingle:gym", KantoEvents.trainerJingle("OPP_YOUNGSTER", 1))
show("jingle:empty", KantoEvents.trainerJingle(nil, nil))

show("pixels:9", KantoEvents.hpBarPixels(9, 48))
show("pixels:10", KantoEvents.hpBarPixels(10, 48))
show("pixels:0", KantoEvents.hpBarPixels(0, 48))
show("pixels:1", KantoEvents.hpBarPixels(1, 1000))
show("pixels:shift", KantoEvents.hpBarPixels(256, 512))
show("low:9", KantoEvents.lowHP(9, 48))
show("low:10", KantoEvents.lowHP(10, 48))
show("low:0", KantoEvents.lowHP(0, 48))
show("low:faint", KantoEvents.lowHP(0, 20))

show("alias:pallet", KantoEvents.mapScore("pallet_town"))
show("alias:oaks", KantoEvents.mapScore("oaks_lab"))
show("alias:route", KantoEvents.mapScore("route1"))
show("bed:surf", KantoEvents.fieldBed("surfing", "pallet"))
show("bed:bike", KantoEvents.fieldBed("bicycle", "pallet"))
show("bed:walk", KantoEvents.fieldBed("walking", "pallet"))

local menu = {}
show("menu:first", KantoEvents.menuCue("pause", nil, nil, menu, nil, 1))
show("menu:pause", KantoEvents.menuCue("pause", "overworld", nil, menu, nil, 1))
show("menu:title", KantoEvents.menuCue("title", "title", nil, menu, nil, 1))
show("menu:cursor", KantoEvents.menuCue("pause", "pause", menu, menu, 1, 2))
show("menu:battle", KantoEvents.menuCue("battle", "battle", nil, menu, nil, 1))
