-- Elevator cells belong to the shared map pipeline. The existing scene flags
-- choose a floor only when an actual door transition asks for its destination.
MidgameStoryWarps = {}
function MidgameStoryWarps.install()
    local function register(owner, cabin)
        local ids = owner.elevatorBindings(nil)
        for index = 1, 2 do
            ids[cabin .. ":warps:" .. index] = true
        end
        for id in pairs(ids) do
            SourceMaps.registerScriptedWarp(id, function(session, sourceID)
                return owner.elevatorBindings(session)[sourceID]
            end)
        end
    end
    register(RocketHideoutStory, "pokered:ROCKET_HIDEOUT_ELEVATOR")
    if SilphStoryWorld and SourceMaps.nameForID("pokered:SILPH_CO_ELEVATOR") then
        register(SilphStoryWorld, "pokered:SILPH_CO_ELEVATOR")
    end
end
