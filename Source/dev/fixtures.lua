-- Whole-session fixture reset. Capture mutable definitions before first play.
HarnessFixtures = {}
if not playdate.isSimulator or not HarnessBuild.enabled then return end
local baseline = {}
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = copy(item) end
    return result
end
for key, zone in pairs(zoneRegistry) do
    baseline[key] = { npcDefs = copy(zone.npcDefs) }
end
local flagBaseline = copy(DEBUG_FLAGS)

local function integer(value, low, high)
    return type(value) == "number" and value % 1 == 0 and value >= low and value <= high
end
local function fields(value, allowed)
    assert(type(value) == "table", "fixture object required")
    for key in pairs(value) do assert(allowed[key], "unknown fixture field: " .. tostring(key)) end
end
local function prepare(options)
    fields(options, {seed=true,intro=true,zone=true,entry=true,opening=true,player_pokemon=true,
        party_pokemon=true,inventory=true,quest_flags=true,grant_xp=true,adjust_battle=true})
    assert(options.opening == nil or type(options.opening) == "boolean", "invalid opening fixture flag")
    assert(options.grant_xp == nil or type(options.grant_xp) == "table", "invalid XP fixture")
    assert(options.adjust_battle == nil or type(options.adjust_battle) == "table", "invalid battle fixture")
    assert(not (options.party_pokemon ~= nil and options.player_pokemon ~= nil), "choose a single Pokemon or party fixture")
    local prepared = {}
    local roster = options.party_pokemon
    if options.player_pokemon ~= nil then roster = {options.player_pokemon} end
    if roster ~= nil then
        assert(options.intro == "skip", "owned Pokemon fixture requires skipped intro")
        assert(Party._array(roster, 6) and #roster >= 1, "fixture party requires one to six members")
        prepared.party = {version=1, active=1, members={}}
        for i, spec in ipairs(roster) do
            fields(spec, {species=true,level=true,hp=true,status=true,status_turns=true,sleep_duration=true,pp=true})
            assert(pokemonData[spec.species] and integer(spec.level,1,100), "invalid fixture Pokemon")
            local mon = Pokemon(spec.species, spec.level)
            if spec.hp ~= nil then assert(integer(spec.hp,0,mon.maxHP), "invalid fixture HP"); mon.hp = spec.hp end
            if spec.status ~= nil then
                assert(spec.status=="none" or spec.status=="sleep" or spec.status=="freeze"
                    or spec.status=="poison" or spec.status=="burn" or spec.status=="paralyze", "invalid fixture status")
                mon.status = spec.status ~= "none" and spec.status or nil
            end
            mon.statusTurns = spec.status_turns == nil and 0 or spec.status_turns
            mon.sleepDuration = spec.sleep_duration == nil and (mon.status == "sleep" and mon.statusTurns or 0) or spec.sleep_duration
            if spec.pp ~= nil then
                assert(type(spec.pp) == "table", "fixture PP must be an object")
                for key, amount in pairs(spec.pp) do
                    assert(mon:hasMove(key) and integer(amount,0,moveData[key].maxPP), "invalid fixture PP")
                    mon.pp[key] = amount
                end
            end
            prepared.party.members[i] = SessionCodec.encodePokemon(mon)
        end
    end
    if options.inventory ~= nil then
        fields(options.inventory, {money=true,slots=true})
        local bag = assert(Inventory.fromData(ItemData.definitions,
            {version=1,money=options.inventory.money == nil and 3000 or options.inventory.money,
                slots=options.inventory.slots == nil and {} or options.inventory.slots}))
        prepared.inventory = bag:toData()
    end
    if options.quest_flags ~= nil then prepared.questFlags = GameSession._flags(options.quest_flags,4096) end
    return prepared
end
function HarnessFixtures.validate(options) prepare(options); return true end

function HarnessFixtures.reset(game, options)
    options = options or {}
    local prepared = prepare(options) -- Invalid setup cannot partially reset a live session.
    -- Exit top-down WITHOUT pop/resume: closing a dialog must not invoke a
    -- story callback or resume an obsolete battle coroutine.
    local machine = game.machine
    for i = #machine.stack, 1, -1 do
        machine.stack[i]:exit()
        machine.stack[i] = nil
    end
    WorldDeltas.reset()
    for _, timer in ipairs(playdate.timer.allTimers()) do timer:remove() end
    for _, timer in ipairs(playdate.frameTimer.allTimers()) do timer:remove() end
    playdate.graphics.sprite.removeAll()
    playdate.display.setOffset(0, 0)
    playdate.graphics.setDrawOffset(0, 0)
    game.npcManager:clear()
    for key, stored in pairs(baseline) do
        local zone = zoneRegistry[key]
        zone.npcDefs = copy(stored.npcDefs)
    end
    for key in pairs(DEBUG_FLAGS) do DEBUG_FLAGS[key] = nil end
    for key, value in pairs(flagBaseline) do DEBUG_FLAGS[key] = value end
    game.player = nil
    game.lastBattleOutcome = nil
    game.transitionLog = {}
    game.debugMenu = DebugMenu()
    local world = machine:get("overworld")
    world.savedPos = nil
    world.builtZone = nil
    world.sub:get("irisOut").callback = nil
    world.sub:get("doorWarp").door = nil
    math.randomseed(options.seed or 0)
    assert(Story.begin(game,options.seed or 0))
    if options.intro == "skip" then Story.skipIntro(game) end
    if prepared.party or prepared.inventory or prepared.questFlags then
        local data = assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        data.world = WorldDeltas.export()
        if prepared.party then
            data.party = prepared.party
            for _, mon in ipairs(data.party.members) do data.pokedex.seen[mon.species], data.pokedex.owned[mon.species] = true, true end
        end
        if prepared.inventory then data.inventory = prepared.inventory end
        if prepared.questFlags then data.questFlags = prepared.questFlags end
        assert(game:installSession(assert(SessionCodec.decode(data,game:getSessionDependencies()))))
    end
    if options.grant_xp then
        local mon = assert(game:getPlayerPokemon(), "XP fixture requires a player Pokemon")
        local xp = options.grant_xp
        assert(not xp.to_level or xp.to_level >= mon.level, "XP fixture cannot lower a level")
        mon:gainXP(xp.amount or math.max(0, mon:xpForLevel(xp.to_level) - mon.xp))
    end
    if options.zone then
        assert(zoneRegistry[options.zone], "unknown fixture zone")
        switchZone(options.zone)
    end
    machine:change("overworld", { respawn = true, entry = options.entry })
    if options.intro ~= "skip" and options.opening ~= false then
        machine:push("dialog", Story.openingLines)
    end
    if options.grant_xp then game:offerLearning(game:getPlayerPokemon()) end
end
