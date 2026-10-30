-- Root adds this to the accepted schema-4 GameSession. No codec change.
-- Runtime token proves completed source cells and owns staged-world rollback.
function GameSession:commitSafariPassage(token)
    local current = state[self]
    local called, prepared = pcall(function()
        local passage, reason = SafariPassage._commitPlan(self, token)
        assert(passage, reason)
        local mutation = SafariGame.validatePlan(passage.mutation)
        assert(FieldMoves.same(current.safari, mutation.before), "stale Safari passage resources")
        for id, value in pairs(SafariGame.flags(current.safari)) do
            assert(self:questFlag(id) == value, "inconsistent Safari passage flags")
        end
        local after = mutation.after
        if after.active then
            for _ = 1, passage.countedSteps do
                after = assert(SafariGame.step(after)).after
            end
        end
        local combined = copy(current.questFlags)
        for id, value in pairs(SafariGame.flags(after)) do
            combined[id] = value
        end
        combined = flags(combined, 4096)
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
        if mutation.kind == "admission" then
            assert(current.location.zone_id == "pokered:SAFARI_ZONE_GATE", "Safari fee outside gate")
            assert(bag:money() == mutation.money, "changed Safari fee balance")
            assert(bag:spend(mutation.debit))
        end
        local snapshot = passage.snapshot
        object(snapshot, {world = true, location = true, actors = true, fieldTravel = true, fieldWorld = true})
        local candidate = world(current.deps, snapshot.world)
        local travel = FieldTravel.normalize(snapshot.fieldTravel)
        local position = location(current.deps, snapshot.location, candidate, true, travel)
        local checkpoint = location(current.deps, current.checkpoint, candidate)
        local actors = GameSession._validateActors(current.deps, snapshot.actors, candidate, position,
            {quest = combined, trainers = copy(current.trainerFlags)})
        return {safari = SafariGame.normalize(after), flags = combined, bag = bag:toData(),
            world = candidate, location = position, checkpoint = checkpoint, actors = actors,
            fieldTravel = travel, fieldWorld = fieldData(snapshot.fieldWorld)}
    end)
    if not called then
        return false, tostring(prepared)
    end
    local accepted, reason = Inventory._replaceData(current.inventory, prepared.bag)
    if not accepted then
        return false, reason
    end
    -- Everything was allocated/validated before this retained-owner publication.
    current.safari, current.questFlags = prepared.safari, prepared.flags
    current.world, current.location, current.checkpoint = prepared.world, prepared.location, prepared.checkpoint
    current.currentActors = prepared.actors
    current.fieldTravel, current.fieldWorld = prepared.fieldTravel, prepared.fieldWorld
    self:invalidateFieldWorldContext()
    return true
end
