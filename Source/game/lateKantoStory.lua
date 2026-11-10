-- Source plan for late Kanto and the original postgame.
-- The league maps are installed by the endgame packet. This module only
-- reads the pinned plan. It does not register world hooks, write quest
-- flags, or place Mew. PowerPlant and CeruleanCaveB1F stay uninstalled.
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
