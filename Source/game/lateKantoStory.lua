-- Source plan for late Kanto and the original postgame.
-- Power Plant, Cerulean Cave and the other remainder maps are installed.
-- This module reads the pinned plan. It does not write badges, write a
-- save, or place Mew.
if type(import) == "function" then
    import "game/postgameStory"
end
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

function LateKantoStory.actorMetadata(id)
    if PostgameStory and PostgameStory.ensureRuntime then
        PostgameStory.ensureRuntime()
    end
    local rule <const> = LateKantoStory.scenes().cerulean_cave
    if PostgameStory and PostgameStory.visibility then
        local extra <const> = PostgameStory.visibility(id)
        if extra then
            return extra
        end
    end
    if id == rule.guard_id then
        return {visibility = {{group = "quest", id = rule.hide, equals = false}}}
    end
    return {}
end

if type(import) == "function" then
    import "game/fossilRevival"
end
