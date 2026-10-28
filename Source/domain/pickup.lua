-- Field Pickup only. Battle recycling has no current item-consumption producer.
-- GameSession commits the prepared held slots and rules continuation together.
Pickup = {}
local battles <const> = setmetatable({}, {__mode = "k"})
local cutoffs <const> = {30, 40, 50, 60, 70, 80, 90, 94, 98}

function Pickup.select(level, roll)
    assert(Party._integer(level, 1, 100), "invalid Pickup level")
    assert(Party._integer(roll, 0, 99), "invalid Pickup roll")
    local band <const> = math.min(9, (level - 1) // 10)
    local column
    if roll >= 98 then
        column = roll == 99 and 10 or 11
    else
        for index, cutoff in ipairs(cutoffs) do
            if roll < cutoff then
                column = index
                break
            end
        end
    end
    local native <const> = PickupData.rows[band + 1][column]
    return assert(PickupData.items[native]), native, band, column
end

-- Only BattleState's admitted field entry creates a receipt. Rebinding a used
-- Battle cannot forge another attempt; receipts are disposable, never saved.
function Pickup._bind(session, battle, fieldType)
    if battles[battle] then
        return false, "already-bound-pickup-battle"
    end
    if type(battle) ~= "table" or type(battle.is) ~= "function" or not battle:is("Battle")
        or battle.session ~= session
        or battle.party ~= session:party() or battle.endEmitted then
        return false, "invalid-pickup-battle-owner"
    end
    if fieldType ~= 0 and fieldType ~= 1 then
        return false, "invalid-pickup-field-type"
    end
    battles[battle] = {session = session, party = session:party(), fieldType = fieldType, attempted = false}
    return true
end

function Pickup._plan(session, battle, won, kind)
    local receipt <const> = battles[battle]
    assert(receipt and receipt.session == session and receipt.party == session:party(), "foreign-pickup-receipt")
    assert(battle.session == session and battle.party == receipt.party, "stale-pickup-owner")
    assert(battle.emittingEnd and battle.endEmitted and battle.outcome == kind
        and won == (kind == "victory"), "unconfirmed-pickup-result")
    assert(not receipt.attempted, "already-attempted-pickup")
    -- Consume the actual receipt even on preparation failure. A failed attempt
    -- leaves gameplay and both RNGs untouched, and cannot be rerolled.
    receipt.attempted = true
    local stream
    local plan <const> = {awards = {}, report = {
        version = 1, fieldType = receipt.fieldType, result = kind,
        eligible = {}, awards = {}, recycling = "no-item-consumption-producer",
    }}
    if kind ~= "victory" then
        return plan
    end
    for slot, mon in ipairs(receipt.party:members()) do
        -- Codec validation rejects unknown/egg species and invalid held IDs.
        -- HP and participation deliberately do not affect eligibility.
        if mon:ability() == 53 and mon.heldItem == "none" then
            assert(PokemonCodec.encode(mon))
            assert(GameSession.activeRNGSession() == session, "inactive-pickup-session")
            if not stream then
                stream = RulesRNG.new(1)
                stream:restore(RulesRNG.snapshot())
            end
            local attempt <const> = {slot = slot, level = mon.level, gate = stream:random(0, 9)}
            plan.report.eligible[#plan.report.eligible + 1] = attempt
            if attempt.gate == 0 then
                attempt.roll = stream:random(0, 99)
                local item, native, band = Pickup.select(mon.level, attempt.roll)
                assert(ItemData.definitions[item] and SpecimenData.holdable[item], "undefined Pickup item")
                plan.awards[#plan.awards + 1] = {mon = mon, item = item}
                plan.report.awards[#plan.report.awards + 1] = {slot = slot, item = item, gen5Id = native, band = band}
            end
        end
    end
    plan.rng = stream and stream:snapshot() or nil
    return plan
end
