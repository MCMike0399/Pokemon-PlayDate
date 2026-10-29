-- Root adds this small method inside gameSession.lua, where `state` is private.
-- Import FieldCycling after FieldTravel and before the first GameSession use.
-- This changes no schema: the forced-bike source bit uses existing saved flags.
function GameSession:commitCycling(expectedEpoch, expectedTravel, expectedForced, candidate)
    local current = state[self]
    if current.fieldEpoch ~= expectedEpoch
        or not FieldMoves.same(current.fieldTravel, expectedTravel)
        or self:questFlag(FieldCycling.FLAG) ~= expectedForced then
        return false, "stale-cycling-context"
    end
    if type(candidate) ~= "table" then
        return false, "invalid-cycling-candidate"
    end
    local checked, travel = pcall(FieldTravel.normalize, candidate.travel)
    if not checked or type(candidate.forced) ~= "boolean" then
        return false, "invalid-cycling-candidate"
    end
    local modeOnly = copy(travel)
    modeOnly.mode = current.fieldTravel.mode
    if not FieldMoves.same(modeOnly, current.fieldTravel)
        or current.fieldTravel.mode == "surfing" or travel.mode == "surfing"
        or self:inventory():quantity("bicycle") ~= 1 and (travel.mode == "bicycle" or candidate.forced) then
        return false, "invalid-cycling-transition"
    end
    -- The normal source transaction clears actors for event-driven rebuilding.
    -- Gear mode changes preserve the existing settled actor value instead.
    local actors = current.currentActors
    local accepted, reason = self:transact(
        {flags = {[FieldCycling.FLAG] = expectedForced}, items = {}},
        {flags = {[FieldCycling.FLAG] = candidate.forced}, items = {}})
    if not accepted then
        return false, reason
    end
    current.currentActors = actors
    current.fieldTravel = travel
    self:invalidateFieldWorldContext()
    return true, {kind = candidate.kind, mode = travel.mode, forced = candidate.forced}
end
