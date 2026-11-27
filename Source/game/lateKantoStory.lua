-- Source plan for late Kanto and the original postgame.
-- Power Plant, Cerulean Cave and the other remainder maps are installed.
-- This module reads the pinned plan. It does not write badges, write a
-- save, or place Mew.
-- pdc 3.1.2 treats a literal import name as a file request, even inside type().
-- postgameStory is left unreferenced so it stays a standalone pdz.
local importer = import
LateKantoStory = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached

function LateKantoStory.scenes()
    if not cached then
        local data <const> = assert(json.decodeFile("data/lateKanto/scenes.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified late Kanto scenes")
        cached = data.scenes
    end
    return cached
end

function LateKantoStory.championAce(rivalStarter)
    local row <const> = LateKantoStory.scenes().champion.by_rival_starter[rivalStarter]
    assert(row, "unknown rival starter")
    return row.ace
end

function LateKantoStory.staticEncounter(name)
    local row <const> = LateKantoStory.scenes().statics[name]
    assert(row and row.kind == "static", "missing static encounter")
    return row
end

-- The battle request is the static object: species and level from the
-- object_event, not a wild slot and not a trainer roster.
function LateKantoStory.staticBattle(name)
    local row <const> = LateKantoStory.staticEncounter(name)
    local species <const> = row.species:lower()
    assert(pokemonData[species], "unknown static species")
    assert(type(row.level) == "number" and row.level >= 1 and row.level <= 100, "static level required")
    return {
        id = row.id,
        map_id = "pokered:" .. row.map_constant,
        species = species,
        level = row.level,
        x = row.x,
        y = row.y,
        source = "object_event",
    }
end

-- The guard starts ON, on the only tile south of the cave warp. Hall of
-- Fame hides him. Until that flag is set the cave stays closed.
function LateKantoStory.caveEntry(flags)
    local rule <const> = LateKantoStory.scenes().cerulean_cave
    if flags[rule.hide] then
        return "open"
    end
    return "blocked"
end

-- PostgameStory.visibility is the hide rule for these statics, and that
-- chunk is not loaded when title inspect validates a save. scripts/CeruleanCaveB1F.asm
-- object 1 uses EVENT_BEAT_MEWTWO. scripts/PowerPlant.asm objects 1-9 use the
-- voltorb flags and EVENT_BEAT_ZAPDOS. The same rules are returned by
-- PostgameStory.visibility once a Hall-team continue has loaded the chunk.
local POSTGAME_STATIC_HIDE <const> = {
    ["pokered:CERULEAN_CAVE_B1F:objects:1"] = "EVENT_BEAT_MEWTWO",
    ["pokered:POWER_PLANT:objects:1"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_0",
    ["pokered:POWER_PLANT:objects:2"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_1",
    ["pokered:POWER_PLANT:objects:3"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_2",
    ["pokered:POWER_PLANT:objects:4"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_3",
    ["pokered:POWER_PLANT:objects:5"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_4",
    ["pokered:POWER_PLANT:objects:6"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_5",
    ["pokered:POWER_PLANT:objects:7"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_6",
    ["pokered:POWER_PLANT:objects:8"] = "EVENT_BEAT_POWER_PLANT_VOLTORB_7",
    ["pokered:POWER_PLANT:objects:9"] = "EVENT_BEAT_ZAPDOS",
}

-- PostgameStory.installEvents registers these pickups. Until that chunk
-- loads, SourceEvents.descriptor is nil, so a taken ball is omitted from
-- the save and title inspect still treats it as visible.
local POSTGAME_PICKUP_HIDE <const> = {
    ["pokered:CERULEAN_CAVE_1F:objects:1"] = "PICKUP:pokered:CERULEAN_CAVE_1F:objects:1",
    ["pokered:CERULEAN_CAVE_1F:objects:2"] = "PICKUP:pokered:CERULEAN_CAVE_1F:objects:2",
    ["pokered:CERULEAN_CAVE_1F:objects:3"] = "PICKUP:pokered:CERULEAN_CAVE_1F:objects:3",
    ["pokered:CERULEAN_CAVE_2F:objects:1"] = "PICKUP:pokered:CERULEAN_CAVE_2F:objects:1",
    ["pokered:CERULEAN_CAVE_2F:objects:2"] = "PICKUP:pokered:CERULEAN_CAVE_2F:objects:2",
    ["pokered:CERULEAN_CAVE_2F:objects:3"] = "PICKUP:pokered:CERULEAN_CAVE_2F:objects:3",
    ["pokered:CERULEAN_CAVE_B1F:objects:2"] = "PICKUP:pokered:CERULEAN_CAVE_B1F:objects:2",
    ["pokered:CERULEAN_CAVE_B1F:objects:3"] = "PICKUP:pokered:CERULEAN_CAVE_B1F:objects:3",
    ["pokered:POWER_PLANT:objects:10"] = "PICKUP:pokered:POWER_PLANT:objects:10",
    ["pokered:POWER_PLANT:objects:11"] = "PICKUP:pokered:POWER_PLANT:objects:11",
    ["pokered:POWER_PLANT:objects:12"] = "PICKUP:pokered:POWER_PLANT:objects:12",
    ["pokered:POWER_PLANT:objects:13"] = "PICKUP:pokered:POWER_PLANT:objects:13",
    ["pokered:POWER_PLANT:objects:14"] = "PICKUP:pokered:POWER_PLANT:objects:14",
}

function LateKantoStory.actorMetadata(id)
    -- A field install has not loaded the postgame chunk. Continue validates
    -- the saved actor list before that chunk is installed, so these hide
    -- rules have to live in the boot chunk.
    if PostgameStory and PostgameStory.visibility then
        local extra <const> = PostgameStory.visibility(id)
        if extra then
            return extra
        end
    end
    local hidden <const> = POSTGAME_STATIC_HIDE[id]
    if hidden then
        return {visibility = {{group = "quest", id = hidden, equals = false}}}
    end
    local pickup <const> = POSTGAME_PICKUP_HIDE[id]
    if pickup then
        return {visibility = {{group = "quest", id = pickup, equals = false}}}
    end
    local rule <const> = LateKantoStory.scenes().cerulean_cave
    if id == rule.guard_id then
        return {visibility = {{group = "quest", id = rule.hide, equals = false}}}
    end
    return {}
end

if type(importer) == "function" then
    importer "game/fossilRevival"
end
