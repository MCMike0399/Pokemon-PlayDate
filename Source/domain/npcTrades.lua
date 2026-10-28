-- Nine English Blue exchanges. Requests are opaque, ephemeral and single use.
-- All allocations/validation occur before GameSession publishes a prepared swap.
NPCTrades = {}
Class("NPCTradeRequest")
local requests <const> = setmetatable({}, {__mode="k"})
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached
local function copy(value)
    return GameSession._copy(value)
end
local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not same(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end
NPCTrades.same = same
function NPCTrades.policy()
    if not cached then
        cached = assert(json.decodeFile("data/npcTrades/policy.json"))
        assert(cached.schema == 1 and cached.source_revision == REVISION, "unverified-npc-trades")
    end
    return copy(cached)
end
function NPCTrades.offer(id)
    return NPCTrades.policy().trades[id]
end
-- Provenance describes acquisition, so ordinary original151 evolutions retain
-- the same receipt. The pinned evolution graph supplies the allowed descendants.
local function descendant(origin, species, visited)
    if origin == species then return true end
    visited = visited or {}
    if visited[origin] then return false end
    visited[origin] = true
    for _, rule in ipairs(EvolutionData.rules[origin] or {}) do
        if pokemonData[rule.to] and descendant(rule.to, species, visited) then return true end
    end
    return false
end
-- Neutral migration carries no invented OT, source history or outsider status.
function NPCTrades.provenance(value, species)
    if value == nil then return {version=1, kind="neutral"} end
    GameSession._object(value, {version=true, kind=true, sourceId=true, tradeIndex=true,
        sourceRevision=true, otName=true, otId=true, language=true})
    assert(value.version == 1, "unsupported-acquisition-provenance")
    if value.kind == "neutral" then
        for key in pairs(value) do
            assert(key == "version" or key == "kind", "fabricated-neutral-history")
        end
        return {version=1, kind="neutral"}
    end
    assert(value.kind == "npc-trade", "invalid-acquisition-kind")
    local offer <const> = assert(NPCTrades.offer(value.sourceId), "unknown-trade-provenance")
    assert(descendant(offer.offered, species) and value.tradeIndex == offer.index
        and value.sourceRevision == REVISION and value.otName == "TRAINER"
        and value.language == "local" and Party._integer(value.otId, 0, 65535), "invalid-trade-provenance")
    return copy(value)
end
function NPCTrades.isOutsider(mon)
    local value <const> = NPCTrades.provenance(mon.acquisition, mon.species)
    return value.kind == "npc-trade" and value.language == "local"
end
local function eligible(session, id, mon)
    assert(Specimen.isActiveSession(session), "inactive-trade-session")
    local offer <const> = assert(NPCTrades.offer(id), "unknown-trade")
    assert(not session:questFlag(offer.flag), "already-complete")
    assert(Party._owner(mon) == session:party(), "not-party-member")
    assert(mon.species == offer.wanted, "wrong-species")
    assert(mon.heldItem == "none", "take-held-item-first")
    assert(#mon:getPendingMoveChoices() == 0 and not mon.pendingEvolution, "pending-progression")
    return offer
end
local function roster(party)
    local records <const> = {}
    for index, mon in ipairs(party:members()) do
        records[index] = assert(PokemonCodec.encode(mon))
    end
    return records
end
-- Context is supplied by the existing guarded event controller. The owner also
-- binds the authoritative traversal epoch/location; direct callers must return
-- the exact context token on resolution, never a reconstructed species search.
function NPCTrades.prepare(session, id, mon, context)
    local ok, result = pcall(function()
        local offer <const> = eligible(session, id, mon)
        assert(type(context) == "table" and context.session == session and context.machine, "trade-context-required")
        local party <const> = session:party()
        local members <const> = party:members()
        local index
        for slot, member in ipairs(members) do
            if member == mon then index = slot end
        end
        assert(index, "not-party-member")
        local request <const> = NPCTradeRequest()
        requests[request] = {status="prepared", session=session, offer=offer, mon=mon,
            context=context, party=party, members=members, index=index, active=party:activeIndex(),
            records=roster(party), rng=session:rngData(), epoch=session:fieldWorldEpoch(),
            sceneEpoch=GameSession._state(session).sceneEpoch or 0,
            player=context.player, zone=currentZone, top=context.machine:current(),
            x=context.player and context.player.gridX, y=context.player and context.player.gridY,
            facing=context.player and context.player.facing}
        return request
    end)
    if not ok then return nil, tostring(result):match("([^:]+)$"):gsub("^%s+", "") end
    return result
end
function NPCTrades.cancel(request)
    local value <const> = requests[request]
    if not value or value.status ~= "prepared" then return false, "not-prepared" end
    value.status = "cancelled"
    return true
end
function NPCTrades._plan(session, request, context)
    local value <const> = requests[request]
    assert(value and value.status == "prepared", "not-prepared")
    -- A failed confirmation is terminal, including stale context or changed HP.
    value.status = "rejected"
    assert(value.session == session and context == value.context and context.session == session
        and context.player == value.player and currentZone == value.zone
        and context.machine:current() == value.top
        and (GameSession._state(session).sceneEpoch or 0) == value.sceneEpoch, "stale-context")
    if value.player then
        assert(value.player.gridX == value.x and value.player.gridY == value.y
            and value.player.facing == value.facing and not value.player.isMoving, "stale-field-position")
    end
    local offer <const> = eligible(session, value.offer.sourceId, value.mon)
    local party <const> = session:party()
    assert(party == value.party and party:activeIndex() == value.active
        and party:count() == #value.members and session:fieldWorldEpoch() == value.epoch
        and same(session:rngData(), value.rng), "stale-request")
    for index, mon in ipairs(value.members) do
        assert(party:get(index) == mon, "stale-roster")
    end
    assert(same(roster(party), value.records), "stale-pokemon")
    local stream <const> = RulesRNG.new(1)
    stream:restoreData(value.rng)
    -- One bounded 16-bit source OTID sample PRECEDES the nine normal trait draws.
    local otId <const> = stream:random(0, 65535)
    local incoming, receipt = Specimen.create(offer.offered, value.mon.level, "npc-trade", stream)
    assert(incoming, receipt)
    incoming.name = offer.nickname
    incoming.acquisition = NPCTrades.provenance({version=1, kind="npc-trade", sourceId=offer.sourceId,
        tradeIndex=offer.index, sourceRevision=REVISION, otName="TRAINER", otId=otId, language="local"}, incoming.species)
    assert(PokemonCodec.encode(incoming), "invalid-incoming-trade")
    local swap <const> = assert(party:_prepareExchange(value.index, value.mon, incoming))
    return {request=value, incoming=incoming, outgoing=value.mon, offer=offer,
        swap=swap, rng=stream:snapshot(), receipt=receipt}
end
