-- pret/pokered af519899 engine/overworld/field_move_messages.asm
-- IsSurfingAllowed, lines 21-50. dbmapcoord stores y then x, so the
-- stairs coordinate is x=7, y=11. CheckBothEventsSet sets Z when both
-- events are set, and that path returns with Surf still allowed.
-- Lane B's coast module owns the rest of the Seafoam story. Keep this
-- predicate when that module is the one loaded.
CoastStory = CoastStory or {}

local function both(flags, left, right)
    return flags[left] == true and flags[right] == true
end

if CoastStory.currentTooFast == nil then
    function CoastStory.currentTooFast(map, x, y, flags)
        if map ~= "pokered:SEAFOAM_ISLANDS_B4F" then
            return false
        end
        if both(flags or {}, "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE", "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE") then
            return false
        end
        return x == 7 and y == 11
    end
end
