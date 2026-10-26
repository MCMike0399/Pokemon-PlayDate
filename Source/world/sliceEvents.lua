-- Compatibility surface for authored/Kanto callers. Planning is shared.
import "game/sourceEvents"
SliceEvents = {}
function SliceEvents.has(id) return SourceEvents.has(id, "viridian") end
function SliceEvents.plan(id, state)
    assert(SliceEvents.has(id), "unimplemented source event: " .. tostring(id))
    return SourceEvents.plan(id, state)
end
