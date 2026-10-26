PewterBindings = {}
import "world/sourceBindings"

-- NPC text, trainer identity, source art and bespoke visibility remain content.
function PewterBindings.object(d, event, spec, options)
    local dispatch, quest, sourceFlag = options.dispatch, options.questFlag, options.sourceFlag
    local key = PewterSprites.key(event.sprite)
    if not options.isolatedCatalog then assert(SpriteFactory.npc[key], "original source sprite must be installed") end
    local id, canInteract = event.id, spec.status == "bound"
    if canInteract then assert(PewterEvents.has(id), "missing implemented source object handler") end
    local trainer = PewterSlice.trainer(id)
    local def = {
        gridX = event.x, gridY = event.y, name = trainer and trainer.name or event.text_id,
        sprite = key, source_event_id = id, source_sprite = event.sprite,
        source_movement = { kind = event.movement, range = event.range_or_facing },
        dialog = function()
            assert(canInteract, "unimplemented source interaction")
            return dispatch(id)
        end,
    }
    local facing = { DOWN = "down", UP = "up", LEFT = "left", RIGHT = "right", NONE = "down",
        UP_DOWN = "down", LEFT_RIGHT = "left" }
    def.facing = facing[event.range_or_facing] or "down"
    if PewterEvents.isPickup(id) then
        local flag = PewterEvents.pickupFlag(id)
        def.appearsIf = function() return not quest(flag) end
    elseif d.name == "PewterCity" and event.source_index == 5 then
        def.appearsIf = function() return not sourceFlag("EVENT_BEAT_BROCK") end
    end
    return def
end

function PewterBindings.prepare(d, specs, options)
    return SourceBindings.prepare(d, specs, SourceBindings.options("pewter", options))
end
