-- Blue Safari lifecycle values. The session owns the sole durable tuple.
SafariGame = {}
local cached
local function copy(value)
    return Party._primitive(value)
end
local function readData()
    if not cached then
        cached = assert(json.decodeFile("data/safariServices.json"))
        assert(cached.schema == 1 and cached.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified Safari source data")
    end
    return cached
end
function SafariGame.data()
    return copy(readData())
end
function SafariGame.empty()
    return {version = 1, active = false, steps = 0, balls = 0, ending = "none"}
end
function SafariGame.normalize(value)
    GameSession._object(value, {version = true, active = true, steps = true, balls = true, ending = true})
    local data = readData()
    assert(value.version == 1 and type(value.active) == "boolean", "invalid Safari version/status")
    assert(Party._integer(value.steps, 0, data.steps) and Party._integer(value.balls, 0, data.balls),
        "invalid Safari counters")
    assert(value.ending == "none" or value.ending == "steps" or value.ending == "balls", "invalid Safari return reason")
    assert(value.active or value.ending == "none", "inactive Safari game cannot await return")
    assert(value.ending ~= "steps" or value.steps == 0, "step return without expired counter")
    assert(value.ending ~= "balls" or value.balls == 0, "ball return without empty supply")
    return copy(value)
end
function SafariGame.isBattleMap(zoneID)
    for _, id in ipairs(readData().battle_maps) do
        if id == zoneID then
            return true
        end
    end
    return false
end
function SafariGame.flags(value)
    local state = SafariGame.normalize(value)
    return {EVENT_IN_SAFARI_ZONE = state.active, EVENT_SAFARI_GAME_OVER = state.ending ~= "none"}
end
function SafariGame.admit(value, money)
    local state = SafariGame.normalize(value)
    if state.active then
        return nil, "safari-already-active"
    end
    if not Party._integer(money, 0, Inventory.MONEY_LIMIT) then
        return nil, "invalid-safari-money"
    end
    local data = readData()
    if money < data.fee then
        return nil, "insufficient-money"
    end
    return {kind = "admission", before = state, money = money, debit = data.fee,
        after = {version = 1, active = true, steps = data.steps, balls = data.balls, ending = "none"}}
end
-- Source checks zero BEFORE decrement. Do not silently rewrite raw 502 to 500.
-- Root calls exactly once per completed logical cell, including counted scripted
-- entrance/rest-house cells. Idle, overlays and partial interpolation never call.
function SafariGame.step(value)
    local state = SafariGame.normalize(value)
    if not state.active or state.ending ~= "none" then
        return nil, "safari-not-counting"
    end
    local after = copy(state)
    if after.steps == 0 then
        after.ending = "steps"
    else
        after.steps = after.steps - 1
    end
    return {kind = "step", before = state, after = after}
end
function SafariGame.ball(value)
    local state = SafariGame.normalize(value)
    if not state.active or state.ending ~= "none" or state.balls == 0 then
        return nil, "safari-no-balls"
    end
    local after = copy(state)
    after.balls = after.balls - 1
    return {kind = "ball", before = state, after = after}
end
-- Source checks remaining balls after returning from battle/menu. A catch on
-- the last ball still recruits successfully before the return announcement.
function SafariGame.check(value)
    local state = SafariGame.normalize(value)
    local after = copy(state)
    if state.active and state.ending == "none" and state.balls == 0 then
        after.ending = "balls"
    end
    return {kind = "check", before = state, after = after}
end
function SafariGame.leave(value, confirmed)
    local state = SafariGame.normalize(value)
    if not state.active then
        return nil, "safari-not-active"
    end
    if state.ending == "none" and confirmed ~= true then
        return nil, "leave-not-confirmed"
    end
    local after = copy(state)
    after.active = false
    after.ending = "none"
    if state.ending ~= "none" then
        after.balls = 0
    end
    return {kind = "leave", before = state, after = after}
end
-- ItemUseEscapeRope clears Safari admission and balls, without an entrance
-- fee refund or a gate dialogue. Root composes this with its EXISTING guarded
-- Escape Rope inventory/world commit; never run it as an independent callback.
function SafariGame.escape(value)
    local state = SafariGame.normalize(value)
    if state.ending ~= "none" then
        return nil, "safari-return-pending"
    end
    local after = copy(state)
    after.active = false
    after.balls = 0
    return {kind = "escape", before = state, after = after}
end
-- Validate all session mutation plans centrally; callers cannot use the service
-- seam as an arbitrary counter/currency write API.
function SafariGame.validatePlan(value)
    GameSession._object(value, {kind = true, before = true, after = true, money = true, debit = true})
    local before = SafariGame.normalize(value.before)
    local after = SafariGame.normalize(value.after)
    local canonical, reason
    if value.kind == "admission" then
        canonical, reason = SafariGame.admit(before, value.money)
    elseif value.kind == "step" then
        canonical, reason = SafariGame.step(before)
    elseif value.kind == "ball" then
        canonical, reason = SafariGame.ball(before)
    elseif value.kind == "check" then
        canonical = SafariGame.check(before)
    elseif value.kind == "escape" then
        canonical, reason = SafariGame.escape(before)
    elseif value.kind == "leave" then
        canonical, reason = SafariGame.leave(before, true)
    end
    assert(canonical, reason or "unknown Safari operation")
    assert(FieldMoves.same(canonical, value) and FieldMoves.same(canonical.after, after), "changed Safari mutation plan")
    return copy(canonical)
end

-- Read-only projection for journeys. It never initializes missing model state
-- or infers completion from map availability, inventory alone or a menu phase.
function SafariGame.observe(game)
    if type(game.session.safariData) ~= "function" then
        return {sessionInstalled = false, battleRegistered = false}
    end
    local state = game.session:safariData()
    return {sessionInstalled = true, battleRegistered = game.machine:get("safariBattle") ~= nil,
        active = state.active, steps = state.steps, balls = state.balls, ending = state.ending,
        surfReceived = game.session:questFlag("EVENT_GOT_HM03"),
        teethFound = game.session:questFlag("PICKUP:pokered:SAFARI_ZONE_WEST:objects:4"),
        teethReturned = game.session:questFlag("EVENT_GAVE_GOLD_TEETH"),
        strengthReceived = game.session:questFlag("EVENT_GOT_HM04")}
end
