-- Oracle from exact B67e391e8; only owner identifier renamed.
-- Leader rewards compile through the existing ordinary SourceEvents trainer
-- planner. Only the source Dojo choice needs delegated controller behavior.
GameCornerMetadataBaseline = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
GameCornerMetadataBaseline.MASTER = "pokered:FIGHTING_DOJO:objects:1"
local cached
local function copy(value)
    return GameSession._copy(value)
end
function GameCornerMetadataBaseline.descriptors()
    if not cached then
        local data <const> = assert(json.decodeFile("data/midgameGymStory/events.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified gym story data")
        cached = data.events
    end
    local installed = {}
    for id, descriptor in pairs(cached) do
        local mapID = id:match("^(pokered:[^:]+):")
        if SourceMaps.nameForID(mapID) then
            installed[id] = copy(descriptor)
        end
    end
    return installed
end
function GameCornerMetadataBaseline.actorMetadata(id)
    local descriptor <const> = GameCornerMetadataBaseline.descriptors()[id]
    if descriptor and descriptor.species then
        -- Only the chosen ball vanishes. The other remains and says greedy.
        return {visibility = {{group = "quest", id = descriptor.flag, equals = false}}}
    end
    return {}
end
