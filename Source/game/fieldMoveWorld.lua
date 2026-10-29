-- Adapter to existing owners; root explicitly exposes this through GameContext.
-- No terrain, save schema, ledger, flags, RNG or inventory owner is introduced.
FieldMoveWorld = {}
function FieldMoveWorld.commit(game, before, after, position, actors)
    if game.machine._transitioning or not FieldMoves.same(WorldDeltas.export(),before) then
        return false, "stale-world"
    end
    if FieldMoves.same(before,after) then return false, "no-terrain-change" end
    local session = game.session
    local deps = game:getSessionDependencies()
    local checked, candidate = pcall(function()
        local world = deps.validateWorld(after)
        local resolvePlayer = deps.resolvePlayerLocation or deps.resolveLocation
        resolvePlayer(position, world, session:fieldTravelData())
        deps.resolveLocation(session:checkpoint(),world)
        -- captureTraversal validates actors again after native application.
        if deps.validateActors then deps.validateActors(actors,world,position,session:flags()) end
        return world
    end)
    if not checked then return false, tostring(candidate) end
    local undoRuntime = WorldDeltas.checkpointRuntime()
    local applied, undoWorld = pcall(WorldDeltas.apply,candidate)
    if not applied then undoRuntime(); return false, tostring(undoWorld) end
    local called, accepted, reason = pcall(session.captureTraversal,session,
        {world=candidate, location=position, actors=actors})
    if not called or not accepted then
        undoWorld()
        undoRuntime()
        return false, tostring(called and reason or accepted)
    end
    return true, {kind="cut", zone_id=position.zone_id}
end
