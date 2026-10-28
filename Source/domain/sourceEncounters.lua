-- Source encounter definitions and detached plans. GameSession alone retains
-- pending/bound identities, capture intents and one-shot return receipts.
SourceEncounters = {}
local ghostID <const> = "pokered:POKEMON_TOWER_6F:hidden_events:1"
local function copy(value)
    return Party._primitive(value)
end
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do
        if not equal(value, b[key]) then return false end
    end
    for key in pairs(b) do
        if a[key] == nil then return false end
    end
    return true
end
SourceEncounters.equal = equal
local definitions <const> = {
    [ghostID] = {zone_id = "pokered:POKEMON_TOWER_6F", species = "marowak", level = 30,
        flag = "EVENT_BEAT_GHOST_MAROWAK", positions = {{10, 16}}},
    ["pokered:ROUTE_12:objects:1"] = {zone_id = "pokered:ROUTE_12", species = "snorlax", level = 30,
        flag = "EVENT_BEAT_ROUTE12_SNORLAX", fight = "EVENT_FIGHT_ROUTE12_SNORLAX",
        positions = {{9,62}, {10,61}, {10,63}, {11,62}}},
    ["pokered:ROUTE_16:objects:7"] = {zone_id = "pokered:ROUTE_16", species = "snorlax", level = 30,
        flag = "EVENT_BEAT_ROUTE16_SNORLAX", fight = "EVENT_FIGHT_ROUTE16_SNORLAX",
        positions = {{27,10}, {25,10}}},
}
function SourceEncounters.policy(session, zoneID, definition)
    local identified <const> = session:inventory():quantity("silphScope") > 0
    local restless <const> = definition and definition.species == "marowak"
    if restless or zoneID:match("^pokered:POKEMON_TOWER_[1-7]F$") and not identified then
        return {capture = not restless and identified, unidentified = not identified,
            restless_soul = restless == true, text_event_id = ghostID,
            intro_labels = identified and {"_EnemyAppearedText", "_UnveiledGhostText"}
                or {"_EnemyAppearedText", "_GhostCantBeIDdText"},
            player_block_label = "_ScaredText", enemy_block_label = "_GetOutText"}
    end
end
function SourceEncounters.prepare(session, request, location)
    assert(type(request) == "table" and type(request.id) == "string", "source encounter request required")
    local d <const> = assert(definitions[request.id], "unsupported source encounter")
    assert(request.zone_id == d.zone_id and request.species == d.species and request.level == d.level,
        "request differs from pinned source encounter")
    assert(location.zone_id == d.zone_id, "wrong-source-encounter-zone")
    local atSource = false
    for _, position in ipairs(d.positions) do
        atSource = atSource or location.x == position[1] and location.y == position[2]
    end
    assert(atSource, "outside-source-encounter-trigger")
    assert(not session:questFlag(d.flag), "already-complete")
    local expected <const> = {flags = {[d.flag] = false}, items = {}}
    local outcomes
    local policy <const> = SourceEncounters.policy(session, d.zone_id, d)
    if d.fight then
        assert(session:questFlag(d.fight), "unarmed-source-snorlax")
        assert(session:inventory():quantity("pokeFlute") > 0, "no-flute")
        expected.flags[d.fight] = true
        expected.items.pokeFlute = session:inventory():quantity("pokeFlute")
        outcomes = {victory = {flags = {[d.flag] = true, [d.fight] = false}},
            caught = {flags = {[d.flag] = true, [d.fight] = false}},
            run = {flags = {[d.flag] = true, [d.fight] = false}},
            defeat = {flags = {[d.fight] = false}}}
        assert(equal(request.rules, {capture = true, unidentified = false}), "forged source battle rules")
    else
        expected.items.silphScope = session:inventory():quantity("silphScope")
        outcomes = {victory = {flags = {[d.flag] = true}}, run = {flags = {}}, defeat = {flags = {}}}
        local declared = copy(policy)
        declared.text_event_id = nil
        assert(equal(request.rules, declared), "forged source ghost rules")
    end
    assert(equal(request.guards, expected) and equal(request.outcomes, outcomes), "forged source outcome/guards")
    assert(session:party():firstUsable(), "no-usable-pokemon")
    assert(GameSession.activeRNGSession() == session, "inactive-source-session")
    local before <const> = RulesRNG.snapshot()
    local stream <const> = RulesRNG.new(1)
    stream:restore(before)
    local enemy, reason = Specimen.create(d.species, d.level, "wild", stream)
    assert(enemy, reason)
    return {token = {}, definition = copy(d), id = request.id, party = session:party(),
        zone_id = d.zone_id, enemy = enemy, policy = policy or {capture = true, unidentified = false},
        guards = expected, beforeRng = before, rng = stream:snapshot(), phase = "prepared"}
end
function SourceEncounters.current(session, record, battle)
    assert(record and record.phase == "active" and record.battle == battle, "unbound-source-battle")
    assert(GameSession.activeRNGSession() == session and battle.session == session
        and session:fieldWorldEpoch() == record.fieldEpoch
        and battle.party == session:party() and record.party == battle.party
        and battle.party:active() == battle.player
        and battle.enemy == record.enemy and not battle.trainerName, "stale-source-battle-owner")
    for flag, expected in pairs(record.guards and record.guards.flags or {}) do
        local launchConsumed <const> = record.definition and flag == record.definition.fight
        assert(session:questFlag(flag) == (not launchConsumed and expected or false), "stale-source-flag")
    end
    for item, expected in pairs(record.guards and record.guards.items or {}) do
        assert(session:inventory():quantity(item) == expected, "stale-source-key-item")
    end
    return record
end
function SourceEncounters.terminal(session, record, battle, won, kind)
    SourceEncounters.current(session, record, battle)
    assert(battle.emittingEnd and battle.endEmitted and battle.outcome == kind
        and won == (kind == "victory"), "unconfirmed-source-result")
    assert(kind == "victory" or kind == "caught" or kind == "run" or kind == "defeat", "unsupported-source-result")
    if kind == "victory" then
        assert(not battle.enemy:isAlive(), "source-victory-with-live-enemy")
    elseif kind == "caught" then
        assert(record.capture and record.capture.caught and record.capture.enemy == battle.enemy
            and battle.caughtPokemon == battle.enemy and battle.captureResult == record.capture.result,
            "unconfirmed-source-capture")
    elseif kind == "defeat" then
        assert(not battle.player:isAlive() and not battle:hasUsablePlayer(), "source-loss-with-usable-party")
    end
    local d <const> = record.definition
    if not d then return {flags = {}, completed = false} end
    local completed <const> = d.fight and kind ~= "defeat"
        or not d.fight and kind == "victory" and not record.policy.unidentified
    local changes = {}
    if completed then changes[d.flag] = true end
    if d.fight then changes[d.fight] = false end
    return {flags = changes, completed = completed == true}
end
