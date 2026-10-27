-- Pinned Showdown Gen V callbacks. BattleEffects owns hit tokens, effective
-- abilities and HP accounting; BattleConditions owns all attraction lifetimes.
ContactAbilities = {}

local function active(effects, mon)
    return effects:active(mon) and mon:isAlive()
end

local function selector(mon)
    return {resolve=function() return mon end}
end

local function status(effects, source, target, kind)
    ApplyStatus(selector(target), kind, {
        source=selector(source), cause="ability",
    }):apply(effects.battle)
end

-- Called only by BattleEffects after it validates and consumes the actual hit
-- receipt. Contact eligibility comes from that receipt, never move-name lists.
function ContactAbilities.damagingHit(effects, hit)
    local source, target = hit.source, hit.target
    if not effects:active(source) or not effects:active(target)
        or hit.before <= 0 or not hit.contact then return end
    local ability = effects:effectiveAbility(target)
    if ability == 27 then
        -- Gen V has no Grass/powder immunity. Draw before major-status/type
        -- eligibility, including a holder KO; ApplyStatus owns those gates.
        if not source:isAlive() then return end
        local roll = RulesRNG.random(0, 99)
        if roll < 11 then status(effects, target, source, "sleep")
        elseif roll < 21 then status(effects, target, source, "paralyze")
        elseif roll < 30 then status(effects, target, source, "poison") end
    elseif ability == 56 then
        -- Chance precedes incompatible sex, Oblivious and existing attraction.
        if RulesRNG.random(0, 9) < 3 then
            effects.battle.conditions:infatuate(source, target)
        end
    end
end

-- Hit, before move secondaries and DamagingHit. The actual calculation supplies
-- its critical flag; a fixed hit never invents one or consumes critical RNG.
function ContactAbilities.onHit(effects, hit, critical)
    if not effects.receipts[hit] or hit.abilityHitResolved then return false end
    hit.abilityHitResolved = true
    local target = hit.target
    if not critical or not effects:active(hit.source) or not active(effects, target)
        or effects:effectiveAbility(target) ~= 83 then return false end
    local old = target.statStages.atk
    target.statStages.atk = 6
    if old ~= 6 then effects.battle:say(target.name .. "'s Anger Point maximized its ATTACK!") end
    return true
end

-- Append a typed flinch secondary without modifying shared move definitions.
-- Shield Dust and Inner Focus stay at their real secondary/payload gates.
function ContactAbilities.secondaries(effects, source, target, move)
    if not effects:active(source) or not effects:active(target)
        or not move or move.category == "status" then return end
    if effects:effectiveAbility(source) ~= 1
        and not PickupHeld.has(effects, source, "kingsRock") then return end
    for _, secondary in ipairs(move.secondaries or {}) do
        if secondary.kind == "flinch" then return end
    end
    local recipient = selector(target)
    SecondaryEffect(recipient, When(Chance(10), ApplyStatus(recipient, "flinch"))):apply(effects.battle)
end

-- Only the successful major-status commit calls this, with captured provenance.
-- The reflected attempt goes through the same type/ability/Safeguard owner.
-- Recursion terminates at the already-statused original holder.
function ContactAbilities.afterStatus(effects, target, source, kind, cause)
    if source == target or not active(effects, target) or not active(effects, source)
        or effects:effectiveAbility(target) ~= 28 or cause == "toxicSpikes"
        or (kind ~= "burn" and kind ~= "paralyze" and kind ~= "poison" and kind ~= "badPoison") then return end
    status(effects, target, source, kind)
end

-- Non-yielding, inside the existing replacement commit and BEFORE override
-- cleanup. Faint/close cleanup is deliberately not a withdrawal callback.
function ContactAbilities.withdraw(effects, mon)
    if not active(effects, mon) or effects:effectiveAbility(mon) ~= 30 or not mon.status then return false end
    mon.status, mon.statusTurns, mon.sleepDuration = nil, 0, 0
    local state = effects.battle.conditions.members[mon]
    if state then state.toxic = nil end
    return true
end

-- Actual producer provenance, before HP loss or the hurt-this-round ledger.
-- Gen V confusion is Move damage; Struggle and HP costs bypass onDamage.
local indirect = {status=true, weather=true, recoil=true, condition=true}
function ContactAbilities.preventDamage(effects, mon, cause)
    return indirect[cause] == true and active(effects, mon)
        and effects:effectiveAbility(mon) == 98
end
