-- Wallet state shares private codec v4; actual services publish through later
-- root-owned economy transactions, never an inventory stack or boolean flags.
function GameSession:coins()
    return state[self].coins
end
-- Root composes these methods inside GameSession, where `state` is private.
-- No shared owner is modified by the worker.
function GameSession:safariData()
    return copy(state[self].safari)
end
function GameSession:commitSafari(plan, expectedEpoch)
    local current = state[self]
    if current.fieldEpoch ~= expectedEpoch then
        return false, "stale-safari-context"
    end
    local called, prepared = pcall(function()
        local candidate = SafariGame.validatePlan(plan)
        assert(FieldMoves.same(current.safari, candidate.before), "stale-safari-state")
        local expectedFlags = SafariGame.flags(candidate.before)
        for id, value in pairs(expectedFlags) do
            assert(self:questFlag(id) == value, "inconsistent-safari-source-flags")
        end
        local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
        if candidate.kind == "admission" then
            assert(current.location.zone_id == SafariGame.data().gate, "Safari admission belongs at gate")
            assert(bag:money() == candidate.money, "stale-safari-money")
            assert(bag:spend(candidate.debit))
        end
        local combined = copy(current.questFlags)
        for id, value in pairs(SafariGame.flags(candidate.after)) do
            combined[id] = value
        end
        return {after = candidate.after, flags = flags(combined, 4096), bag = bag:toData()}
    end)
    if not called then
        return false, tostring(prepared)
    end
    local accepted, reason = Inventory._replaceData(current.inventory, prepared.bag)
    if not accepted then
        return false, reason
    end
    current.safari, current.questFlags = prepared.after, prepared.flags
    self:invalidateFieldWorldContext()
    return true
end
function GameSession:commitSafariBattle(token)
    local prepared, reason = SafariBattle._commitPlan(self, token)
    if not prepared then
        return false, reason
    end
    local destination
    if prepared.caught then
        local accepted
        accepted, destination = self:recruit(prepared.caught)
        if not accepted then
            return false, destination
        end
    end
    -- The plan prevalidated these exact primitive values and the active stream.
    -- No fallible callback, allocation or capacity decision follows recruitment.
    state[self].safari = prepared.after
    RulesRNG.restore(prepared.rulesAfter)
    self:invalidateFieldWorldContext()
    return true, {battle = prepared.battle, receipt = prepared.receipt, destination = destination}
end
