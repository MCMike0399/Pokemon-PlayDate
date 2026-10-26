-- Bounded Gen V callbacks. BattleEffects owns effective identity and receipts;
-- this object owns only Flash Fire's per-active-member volatile lifetime.
Class("OrdinaryAbilities")

local floor <const> = math.floor
local max <const> = math.max

function OrdinaryAbilities:init(effects)
    self.effects = effects
    self.flashFire = {}
end

function OrdinaryAbilities:clear(mon)
    self.flashFire[mon] = nil
end

function OrdinaryAbilities:close()
    self.flashFire = {}
end

-- Technician runs at priority19, after Rivalry24 and before Dry Skin17.
-- The threshold observes the accumulated modifier, not just declared power.
function OrdinaryAbilities:technicianRatio(source, power, ratio)
    local effects = self.effects
    if power > 0 and effects:livingAbility(source, 101)
        and BattleEffects.fixedRound(power, ratio) <= 60 then
        return BattleEffects.chain(ratio, 6144)
    end
    return ratio
end

function OrdinaryAbilities:attackStat(source, move, value)
    if move.type == "fire" and self.flashFire[source]
        and self.effects:livingAbility(source, 18) then
        return BattleEffects.fixedRound(value, 6144)
    end
    return value
end

function OrdinaryAbilities:speed(mon, value)
    if self.effects:weatherId() == "raindance"
        and self.effects:livingAbility(mon, 33) then
        return value * 2
    end
    return value
end

-- TryHit follows type immunity and Protect, and precedes accuracy/damage RNG.
-- The immutable shared move record is never rewritten to force accuracy.
function OrdinaryAbilities:absorb(source, target, move)
    local effects = self.effects
    if source == target or not effects:active(source) or not effects:active(target)
        or not source:isAlive() or not target:isAlive() then
        return false
    end
    local ability = effects:effectiveAbility(target)
    if move.type == "water" and (ability == 11 or ability == 87) then
        target:heal(max(1, target.maxHP // 4))
        local name = ability == 11 and "Water Absorb" or "Dry Skin"
        effects.battle:say(target.name .. " absorbed the water with " .. name .. "!")
        return true
    end
    if move.type == "fire" and ability == 18 then
        -- Commit before narration yields; repeated hits never stack the boost.
        self.flashFire[target] = true
        effects.battle:say(target.name .. " absorbed the fire with Flash Fire!")
        return true
    end
    return false
end

-- SourceTryHeal provenance: drained is the HP donor, receiver gets the heal.
-- A donor KO on the actual hit/tick still invokes Liquid Ooze before faint
-- cleanup. A withdrawn donor, dead receiver or closed battle cannot do so.
function OrdinaryAbilities:drain(drained, receiver, amount, cause)
    local effects = self.effects
    assert(cause == "drain" or cause == "leechSeed", "invalid-drain-provenance")
    if amount <= 0 or not effects:active(drained) or not effects:active(receiver)
        or not receiver:isAlive() then
        return false
    end
    if effects:effectiveAbility(drained) == 64 then
        -- The existing condition damage category is indirect damage, including
        -- Magic Guard prevention and the actual hurt-this-round ledger.
        local removed = effects:damage(receiver, amount, "condition")
        if removed > 0 then
            effects.battle:say(receiver.name .. " was hurt by Liquid Ooze!")
        end
    else
        receiver:heal(amount)
    end
    return true
end

-- Only an actual unconsumed hit receipt can authorize direct drain. Mark it
-- before yielding so a replay cannot heal or hurt twice, even after a KO.
function OrdinaryAbilities:drainHit(receipt)
    local effects = self.effects
    if not effects.receipts[receipt] or receipt.drainResolved
        or not effects:active(receipt.source) or not effects:active(receipt.target)
        or receipt.removed <= 0 then
        return false
    end
    local percent = receipt.move and receipt.move.drain
    if type(percent) ~= "number" or percent <= 0 then
        return false
    end
    receipt.drainResolved = true
    local amount = max(1, floor(receipt.removed * percent / 100 + 0.5))
    return self:drain(receipt.target, receipt.source, amount, "drain")
end
