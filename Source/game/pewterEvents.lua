-- Compatibility surface for existing map bindings and SDK contracts.
PewterEvents = {}
function PewterEvents.has(id) return SourceEvents.has(id, "pewter") end
function PewterEvents.isPickup(id) return SourceEvents.isPickup(id) end
function PewterEvents.pickupFlag(id) return SourceEvents.pickupFlag(id) end
function PewterEvents.plan(id, state)
    assert(PewterEvents.has(id), "unsupported Pewter source event")
    return SourceEvents.plan(id, state)
end
function PewterEvents.pages(labels, ram) return EventText.pagesFrom(labels, PewterSlice.text, ram) end
function PewterEvents.afterCommit(game, plan) return SourceEvents.afterCommit(game, plan) end
