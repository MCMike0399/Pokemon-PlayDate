-- Session-composed Blue Day Care. Only immutable content and ephemeral intents
-- live here. The held Pokemon and earned XP belong to GameSession._state.
Daycare = {}
Class("DaycareRequest")
local intents <const> = setmetatable({}, {__mode="k"})
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local policyData
local hmMoves <const> = {cut=true, fly=true, surf=true, strength=true, flash=true}
local function copy(value)
    return GameSession._copy(value)
end
local function same(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not same(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end
function Daycare.policy()
    if not policyData then
        local value = assert(json.decodeFile("data/daycare/policy.json"))
        assert(value.schema == 1 and value.source_revision == REVISION, "unverified Day Care policy")
        policyData = value
    end
    return copy(policyData)
end
function Daycare.empty()
    return {version=1, earned=0}
end
-- Save normalization never constructs/claims a Pokemon or consumes RNG. The
-- existing wire encoder owns decimal XP and move-choice counters.
function Daycare.normalize(value, checkPokemon)
    GameSession._object(value, {version=true, earned=true, pokemon=true})
    assert(value.version == 1, "unsupported-daycare-version")
    local earned = assert(DecimalInteger.decode(value.earned, 0, 1250000))
    assert(value.pokemon == nil or type(value.pokemon) == "table", "invalid-daycare-pokemon")
    if not value.pokemon then
        assert(earned == 0, "empty-daycare-xp")
    else
        local mon = checkPokemon(value.pokemon)
        assert(#mon.pendingMoveChoices == 0 and not mon.pendingEvolution, "unsettled-daycare-pokemon")
        assert(earned <= xpForLevel(100, mon.species) - mon.xp, "daycare-xp-overflow")
    end
    return {version=1, earned=earned, pokemon=value.pokemon and copy(value.pokemon) or nil}
end
function Daycare.toData(session, encodePokemon)
    local held = assert(GameSession._state(session).daycare, "Day Care session seam required")
    local value = {version=1, earned=assert(DecimalInteger.encode(held.earned, 0, 1250000))}
    if held.mon then
        assert(Party._owner(held.mon) == session, "daycare-ownership")
        value.pokemon = encodePokemon(held.mon)
    end
    return value
end
function Daycare.restore(session, normalized, decodePokemon)
    local held = {version=1, earned=normalized.earned}
    if normalized.pokemon then
        held.mon = decodePokemon(normalized.pokemon)
        assert(Party._claimMany({held.mon}, session))
    end
    return held
end
function Daycare.observe(session)
    local current = assert(GameSession._state(session))
    local held = assert(current.daycare, "Day Care session seam required")
    return {intro=session:getIntro().stage, party=assert(current.party:toData(PokemonCodec.encode)),
        money=current.inventory:money(), earned=held.earned,
        pokemon=held.mon and assert(PokemonCodec.encode(held.mon)) or nil}
end
local function depositFailure(observation, index)
    if observation.pokemon then
        return "occupied"
    end
    local members = observation.party.members
    local mon = members[index]
    if not mon then
        return "invalid-index"
    end
    if #members <= 1 then
        return "last-member"
    end
    for _, move in ipairs(mon.moves) do
        if hmMoves[move] then
            return "hm-move"
        end
    end
    -- Retain the domain party's last-usable guard, an explicit softlock policy.
    local usable = 0
    for i, other in ipairs(members) do
        if i ~= index and other.hp > 0 then
            usable = usable + 1
        end
    end
    if usable == 0 then
        return "last-usable"
    end
    if #mon.pendingMoveChoices > 0 or mon.pendingEvolution then
        return "pending-progression"
    end
end
-- Detached, read-only quote. No construction, ownership mutation or RNG draws.
function Daycare.plan(observation, operation, index)
    local s = copy(observation)
    assert(s.intro == "done", "settled intro required")
    assert(operation == "deposit" or operation == "withdraw", "unknown-daycare-operation")
    local result = {operation=operation, status="ready", expected=s, index=index}
    if operation == "deposit" then
        result.status = depositFailure(s, index) or "ready"
        result.pokemon = s.party.members[index]
    elseif not s.pokemon then
        result.status = "empty"
    else
        local level = s.pokemon.level
        local total = s.pokemon.xp + s.earned
        while level < 100 and total >= xpForLevel(level + 1, s.pokemon.species) do
            level = level + 1
        end
        result.level = level
        result.grown = level - s.pokemon.level
        result.fee = math.min(9999, 100 * (result.grown + 1))
        result.pokemon = s.pokemon
        if #s.party.members >= Party.CAPACITY then
            result.status = "party-full"
        elseif s.money < result.fee then
            result.status = "insufficient-money"
        end
    end
    return result
end
-- Request records are private ephemeral guards, like TeachingRequest. Keeping a
-- caller's detached preview cannot alter the chosen member, fee or snapshot.
function Daycare.prepare(session, operation, index)
    local plan = Daycare.plan(Daycare.observe(session), operation, index)
    local request = DaycareRequest()
    local current = GameSession._state(session)
    intents[request] = {session=session, plan=copy(plan), held=current.daycare,
        members=current.party:members(), fieldEpoch=session:fieldWorldEpoch(), status="pending"}
    return request, copy(plan)
end
local function grownPokemon(plan)
    local record = copy(plan.expected.pokemon)
    record.xp = record.xp + plan.expected.earned
    record.level = plan.level
    record.hp = IndividualStats.calculate(pokemonData[record.species], record.level,
        record.natureId, record.ivs, record.evs).maxHP
    -- Blue WriteMonMoves: only crossed levels, skip currently known moves,
    -- append to free slots, otherwise discard oldest; retained PP stays intact.
    for _, entry in ipairs(Pokemon.learnsetEntriesFor(record.species,
        plan.expected.pokemon.level + 1, record.level)) do
        local known = false
        for _, key in ipairs(record.moves) do
            if key == entry.move then
                known = true
            end
        end
        if not known then
            local definition = assert(moveData[entry.move], "missing-daycare-move")
            assert(not definition.noPP, "invalid-daycare-move")
            if #record.moves == 4 then
                local forgotten = table.remove(record.moves, 1)
                record.pp[forgotten] = nil
            end
            record.moves[#record.moves + 1] = entry.move
            record.pp[entry.move] = definition.maxPP
        end
    end
    -- No gainXP call: battle choice queues and evolution are deliberately absent.
    return assert(PokemonCodec.decode(record))
end
-- Called only by the small GameSession API seam. All validation/candidate work
-- precedes the first durable mutation. Failure consumes the intent, not money.
function Daycare._resolve(session, request, decision)
    local intent = intents[request]
    if not intent or intent.session ~= session or intent.status ~= "pending" then
        return false, "stale-daycare-request"
    end
    if type(decision) ~= "boolean" then
        return false, "explicit-daycare-decision-required"
    end
    intent.status = "complete"
    if not decision then
        return true, {kind="cancelled"}
    end
    local current = GameSession._state(session)
    local plan = intent.plan
    if session:fieldWorldEpoch() ~= intent.fieldEpoch then
        return false, "stale-daycare-context"
    end
    if current.daycare ~= intent.held or not same(plan.expected, Daycare.observe(session)) then
        return false, "stale-daycare-state"
    end
    for i, mon in ipairs(intent.members) do
        if current.party:get(i) ~= mon then
            return false, "stale-daycare-member"
        end
    end
    if plan.status ~= "ready" then
        return false, plan.status
    end
    if plan.operation == "deposit" then
        local mon, reason = current.party:_take(plan.index, session)
        if not mon then
            return false, reason
        end
        current.daycare = {version=1, earned=0, mon=mon}
        return true, {kind="deposited", name=mon.name, index=plan.index}
    end
    local ok, candidate = pcall(grownPokemon, plan)
    if not ok then
        return false, tostring(candidate)
    end
    local bag = assert(Inventory.fromData(current.deps.itemDefinitions, current.inventory:toData()))
    local paid, reason = bag:spend(plan.fee)
    if not paid then
        return false, reason
    end
    local mon = current.daycare.mon
    if Party._owner(mon) ~= session then
        return false, "daycare-ownership"
    end
    local accepted, problem = current.party:_receive(mon, session)
    if not accepted then
        return false, problem
    end
    -- Retain the actual Pokemon, Party and Inventory objects. Prepared values
    -- and existing same-owner transfer primitives cannot yield to a callback.
    assert(current.inventory:_replaceData(bag:toData()))
    for key in pairs(mon) do
        mon[key] = nil
    end
    for key, value in pairs(candidate) do
        mon[key] = value
    end
    current.daycare = Daycare.empty()
    return true, {kind="withdrawn", name=mon.name, fee=plan.fee, grown=plan.grown}
end
-- Exactly one call per completed ordinary player step. No idle/frame/dialog,
-- scripted movement, warp arrival, NPC movement, or attempted blocked step XP.
function Daycare._step(session)
    local held = assert(GameSession._state(session).daycare, "Day Care session seam required")
    if not held.mon then
        return false
    end
    local room = held.mon:xpForLevel(100) - held.mon.xp
    held.earned = math.min(room, held.earned + 1)
    return true
end
