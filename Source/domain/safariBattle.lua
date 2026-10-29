-- Safari has its own command loop. Never instantiate Battle/normal Bag phases.
-- Gen V capture math stays in Capture; Blue bait/rock/flee/ball rules stay here.
SafariBattle = {}
local function copy(value)
    return Party._primitive(value)
end
function SafariBattle.begin(safari, enemy)
    safari = SafariGame.normalize(safari)
    if not safari.active or safari.ending ~= "none" or safari.balls == 0 then
        return nil, "safari-not-active"
    end
    if not Party._validPokemon(enemy) or Party._owner(enemy) or enemy.hp ~= enemy.maxHP or enemy.status then
        return nil, "invalid-safari-enemy"
    end
    local rate = assert(CaptureData[enemy.dex], "missing Gen V capture rate")
    return {version = 1, catchRate = rate, baseRate = rate, bait = 0, anger = 0, outcome = "command"}
end
local function normalize(value, enemy)
    GameSession._object(value, {version = true, catchRate = true, baseRate = true, bait = true, anger = true, outcome = true})
    assert(value.version == 1 and value.baseRate == CaptureData[enemy.dex], "wrong Safari battle provenance")
    assert(Party._integer(value.catchRate, 0, 255) and Party._integer(value.bait, 0, 255)
        and Party._integer(value.anger, 0, 255), "invalid Safari battle counters")
    assert(value.bait == 0 or value.anger == 0, "simultaneous Safari bait and anger")
    assert(value.outcome == "command", "Safari battle already ended")
    return copy(value)
end
local function duration(rng)
    for _ = 1, 1024 do
        local value = rng:random(0, 255) % 8
        if value < 5 then
            return value + 1
        end
    end
    error("Safari duration rejection limit", 0)
end
-- Stream must be detached. A failed rule/capture calculation cannot consume the
-- active RNG or a Safari Ball. Root publishes only a revalidated completed plan.
function SafariBattle.plan(safari, battle, enemy, command, caughtCount, rng, captureAttempt)
    assert(rng ~= RulesRNG, "detached Safari stream required")
    assert(Party._integer(caughtCount, 0, 151), "invalid Safari caught count")
    local before = SafariGame.normalize(safari)
    assert(before.active and before.ending == "none" and before.balls > 0, "Safari battle supply unavailable")
    assert(Party._validPokemon(enemy) and not Party._owner(enemy), "foreign Safari target")
    local nextBattle = normalize(battle, enemy)
    local after = copy(before)
    local stream = RulesRNG.new(1)
    stream:restore(rng:snapshot())
    local receipt = {command = command}
    if command == "run" then
        nextBattle.outcome = "run"
    elseif command == "ball" then
        if type(captureAttempt) ~= "function" then
            return nil, "safari-capture-policy-not-installed"
        end
        local capture, reason = captureAttempt(enemy, nextBattle.catchRate, caughtCount, stream)
        assert(capture and type(capture.caught) == "boolean", reason or "invalid Safari capture result")
        receipt.capture = capture
        after = assert(SafariGame.ball(before)).after
        if capture.caught then
            nextBattle.outcome = "caught"
        elseif after.balls == 0 then
            nextBattle.outcome = "out-of-balls"
        end
    elseif command == "bait" then
        nextBattle.catchRate = nextBattle.catchRate // 2
        nextBattle.anger = 0
        nextBattle.bait = math.min(255, nextBattle.bait + duration(stream))
    elseif command == "rock" then
        nextBattle.catchRate = math.min(255, nextBattle.catchRate * 2)
        nextBattle.bait = 0
        nextBattle.anger = math.min(255, nextBattle.anger + duration(stream))
    else
        return nil, "unsupported-safari-command"
    end
    if nextBattle.outcome == "command" then
        if nextBattle.bait > 0 then
            nextBattle.bait = nextBattle.bait - 1
            receipt.message = "eating"
        elseif nextBattle.anger > 0 then
            nextBattle.anger = nextBattle.anger - 1
            receipt.message = "angry"
            if nextBattle.anger == 0 then
                nextBattle.catchRate = nextBattle.baseRate
            end
        end
        -- Blue reads the speed low byte; an initial doubling overflow flees
        -- before bait can divide it. Subsequent anger multiplication saturates.
        local speed = enemy.spe % 256
        local threshold = speed * 2
        if threshold >= 256 then
            receipt.forcedFlee = true
            nextBattle.outcome = "fled"
        else
            if nextBattle.bait > 0 then
                threshold = threshold // 4
            end
            if nextBattle.anger > 0 then
                threshold = math.min(255, threshold * 2)
            end
            receipt.fleeThreshold = threshold
            receipt.fleeRoll = stream:random(0, 255)
            if receipt.fleeRoll < threshold then
                nextBattle.outcome = "fled"
            end
        end
    end
    -- Publish into the caller's DETACHED stream only after every check succeeds.
    rng:restore(stream:snapshot())
    return {before = before, after = SafariGame.normalize(after), battle = nextBattle,
        receipt = receipt, rulesAfter = stream:snapshot()}
end

-- Typed ephemeral turn intents, consumed by the root-owned session method.
local requests = setmetatable({}, {__mode = "k"})
local function roster(session)
    return assert(session:party():toData(function(mon)
        return assert(PokemonCodec.encode(mon))
    end))
end
local function current(request)
    if not request or request.status ~= "prepared" or not Specimen.isActiveSession(request.session)
        or request.session:fieldWorldEpoch() ~= request.epoch
        or not FieldMoves.same(request.session:safariData(), request.safari)
        or not FieldMoves.same(request.session:location(), request.location)
        or not FieldMoves.same(RulesRNG.snapshot(), request.rules)
        or not FieldMoves.same(roster(request.session), request.roster)
        or not FieldMoves.same(request.session:flags(), request.flags)
        or not FieldMoves.same(request.session:inventory():toData(), request.inventory)
        or request.session:storage():activeBox() ~= request.box
        or request.session:storage():count() ~= request.boxCount
        or not FieldMoves.same(assert(PokemonCodec.encode(request.enemy)), request.enemyRecord)
        or Party._owner(request.enemy) then
        return false
    end
    return true
end
function SafariBattle.prepare(session, enemy, battle, command, captureAttempt)
    if not Specimen.isActiveSession(session) or type(session.safariData) ~= "function" then
        return nil, "safari-session-not-installed"
    end
    if not session:party():firstUsable() then
        return nil, "no-usable-party"
    end
    if not SafariGame.isBattleMap(session:location().zone_id) then
        return nil, "not-a-safari-battle-map"
    end
    if command == "ball" and session:party():count() >= Party.CAPACITY
        and session:storage():count() >= Storage.BOX_CAPACITY then
        return nil, "storage-full"
    end
    local count = 0
    for _, owned in pairs(session:pokedex().owned) do
        if owned then
            count = count + 1
        end
    end
    local token = {}
    requests[token] = {session = session, enemy = enemy, enemyRecord = assert(PokemonCodec.encode(enemy)),
        safari = session:safariData(), epoch = session:fieldWorldEpoch(), location = session:location(),
        roster = roster(session), rules = RulesRNG.snapshot(), battle = copy(battle), command = command,
        flags = session:flags(), inventory = session:inventory():toData(),
        box = session:storage():activeBox(), boxCount = session:storage():count(),
        caughtCount = count, capture = captureAttempt, status = "prepared"}
    return token
end
function SafariBattle.cancel(token)
    local request = requests[token]
    if not request or request.status ~= "prepared" then
        return false
    end
    request.status = "cancelled"
    return true
end
function SafariBattle._commitPlan(session, token)
    local request = requests[token]
    if not request or request.session ~= session or not current(request) then
        return nil, "stale-safari-turn"
    end
    local called, result, reason = pcall(function()
        if request.command == "ball" and session:party():count() >= Party.CAPACITY
            and session:storage():count() >= Storage.BOX_CAPACITY then
            return nil, "storage-full"
        end
        local stream = RulesRNG.new(1)
        stream:restore(request.rules)
        local result, why = SafariBattle.plan(request.safari, request.battle, request.enemy,
            request.command, request.caughtCount, stream, request.capture)
        if not result then
            return nil, why
        end
        assert(current(request), "changed-safari-turn")
        -- Validate final resource/RNG values before root begins any publication.
        local after = SafariGame.normalize(result.after)
        local probe = RulesRNG.new(1)
        probe:restore(result.rulesAfter)
        return {after = after, rulesAfter = probe:snapshot(), battle = result.battle,
            receipt = result.receipt, caught = result.battle.outcome == "caught" and request.enemy or nil}
    end)
    request.status = "used"
    if not called then
        return nil, tostring(result)
    end
    return result, reason
end
