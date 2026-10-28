-- Pinned Showdown Gen V item callbacks, using the existing battle/HP owners.
-- No suppression or item-consumption producers are introduced here.
PickupHeld = {}

function PickupHeld.has(effects, mon, item)
    return effects:active(mon) and mon:isAlive() and mon.heldItem == item
end

function PickupHeld.speed(effects, mon, value)
    if PickupHeld.has(effects, mon, "ironBall") then
        return BattleEffects.fixedRound(value, 2048)
    end
    return value
end

-- The pinned Iron Ball onEffectiveness makes Ground neutral against a Flying
-- holder, including its other type. Levitate bypass is a separate immunity gate.
function PickupHeld.matchup(effects, kind, mon)
    if kind == "ground" and PickupHeld.has(effects, mon, "ironBall")
        and effects.battle:hasType(mon, "flying") then
        return 1
    end
    return nil
end

function PickupHeld.event(effects, mon, side)
    if PickupHeld.has(effects, mon, "leftovers") then
        return {kind = "leftovers", order = 5, suborder = 4,
            owner = "effects", side = side, pokemon = mon}
    end
end

function PickupHeld.residual(effects, event)
    if event.consumed then
        return
    end
    event.consumed = true
    local mon <const> = event.pokemon
    if not PickupHeld.has(effects, mon, "leftovers") then
        return
    end
    local before <const> = mon.hp
    mon:heal(math.max(1, mon.maxHP // 16))
    if mon.hp > before then
        effects.battle:say(mon.name .. " restored HP with Leftovers!")
    end
end
