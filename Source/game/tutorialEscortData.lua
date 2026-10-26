-- Candidate data stays separate from the protected shared event/map registries.
TutorialEscortData = {}
local cached
local function record()
    if not cached then
        cached = assert(json.decodeFile("data/tutorialEscort/scenes.json"))
        assert(cached.schema == 1 and cached.source_revision == "af519899719f0754965776faac0e836a3b906e6d")
    end
    return cached
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
function TutorialEscortData.get() return copy(record()) end
function TutorialEscortData.text(label) return copy(assert(record().texts[label], "missing pinned scene text")) end
function TutorialEscortData.actorPositions(id)
    local data = record()
    if id ~= data.actors.escort.id then return {} end
    local x, y = data.actors.escort.x, data.actors.escort.y
    local positions, seen = {}, {}
    local delta = { up={0,-1}, down={0,1}, left={-1,0}, right={1,0} }
    local function append(route)
        for _, direction in ipairs(route) do
            local d = assert(delta[direction])
            x, y = x + d[1], y + d[2]
            local key = x .. "," .. y
            if not seen[key] then
                seen[key] = true
                positions[#positions + 1] = { x=x, y=y }
            end
        end
    end
    append(data.escort.npc_route)
    append(data.escort.departure)
    return SourceEvents.validateActorPositions(id, positions)
end
-- Source departure crosses the arrival cell below the Gym door. This is an
-- explicit leased-transit exception only; never an autonomous/warp exemption.
function TutorialEscortData.transitAllowed(id, x, y)
    return id == "pokered:PEWTER_CITY:objects:5" and x == 16 and y == 18
end
