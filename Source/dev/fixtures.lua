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
local function preparePokemon(spec)
    fields(spec, {species=true,level=true,hp=true,status=true,status_turns=true,sleep_duration=true,pp=true,nature_id=true,ability_slot=true,held_item=true})
    assert(pokemonData[spec.species] and integer(spec.level,1,100), "invalid fixture Pokemon")
    local mon = Pokemon(spec.species, spec.level, {natureId=spec.nature_id==nil and 0 or spec.nature_id,
        abilitySlot=spec.ability_slot==nil and "first" or spec.ability_slot,
        heldItem=spec.held_item==nil and "none" or spec.held_item})
    if spec.hp ~= nil then assert(integer(spec.hp,0,mon.maxHP), "invalid fixture HP"); mon.hp = spec.hp end
    if spec.status ~= nil then
        assert(spec.status=="none" or spec.status=="sleep" or spec.status=="freeze"
            or spec.status=="poison" or spec.status=="badPoison" or spec.status=="burn" or spec.status=="paralyze", "invalid fixture status")
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
    assert(PokemonCodec.encode(mon))
    return mon
end
local function prepare(options)
    fields(options, {seed=true,intro=true,zone=true,entry=true,opening=true,player_pokemon=true,
        party_pokemon=true,inventory=true,quest_flags=true,grant_xp=true,adjust_battle=true,pokedex_seen=true,trainer_name=true,enemy_party=true,vermilion_aide_capacity=true})
    assert(options.opening == nil or type(options.opening) == "boolean", "invalid opening fixture flag")
    assert(options.grant_xp == nil or type(options.grant_xp) == "table", "invalid XP fixture")
    assert(options.adjust_battle == nil or type(options.adjust_battle) == "table", "invalid battle fixture")
    assert(not (options.party_pokemon ~= nil and options.player_pokemon ~= nil), "choose a single Pokemon or party fixture")
    local descriptor=assert(WorldDeltas.describeZone(options.zone or "reds_house_2f"),"unknown fixture zone")
    if options.entry~=nil then
        fields(options.entry,{x=true,y=true,facing=true})
        assert(integer(options.entry.x,0,descriptor.width-1) and integer(options.entry.y,0,descriptor.height-1),"invalid fixture entry")
        local facing=options.entry.facing
        assert(facing==nil or facing=="up" or facing=="down" or facing=="left" or facing=="right","invalid fixture facing")
    end
    local prepared = {}
    if options.vermilion_aide_capacity ~= nil then
        local key = options.vermilion_aide_capacity
        local zones = {hm05="kanto_route_2_gate",itemfinder="kanto_route_11_gate_2f"}
        assert((key=="hm05" or key=="itemfinder") and options.intro=="skip"
            and options.zone==zones[key], "aide capacity is a supplementary two-case fixture")
        assert(options.party_pokemon==nil and options.player_pokemon==nil
            and options.quest_flags==nil and options.grant_xp==nil and options.enemy_party==nil
            and options.adjust_battle==nil and options.pokedex_seen==nil,
            "aide capacity fixture cannot mix with unrelated state edits")
        prepared.aideKey, prepared.aideThreshold = key, key=="hm05" and 10 or 30
        prepared.aideCandidates = {}
        local species = {"bulbasaur","ivysaur","venusaur","charmander","charmeleon","charizard",
            "squirtle","wartortle","blastoise","caterpie","metapod","butterfree","weedle","kakuna",
            "beedrill","pidgey","pidgeotto","pidgeot","rattata","raticate","spearow","fearow",
            "ekans","arbok","pikachu","raichu","sandshrew","sandslash","nidoranF","nidorina"}
        for _, id in ipairs(species) do
            prepared.aideCandidates[#prepared.aideCandidates+1] = preparePokemon({species=id,level=5})
        end
    end
    if options.pokedex_seen ~= nil then
        assert(Party._array(options.pokedex_seen,151), "Pokedex seen fixture requires a dense array")
        prepared.pokedexSeen = {}
        local seen = {}
        for i, species in ipairs(options.pokedex_seen) do
            assert(type(species)=="string" and pokemonData[species], "unknown Pokedex fixture species")
            assert(not seen[species], "duplicate Pokedex fixture species")
            seen[species] = true
            prepared.pokedexSeen[i] = species
        end
    end
    local roster = options.party_pokemon
    if options.player_pokemon ~= nil then roster = {options.player_pokemon} end
    if roster ~= nil then
        assert(options.intro == "skip", "owned Pokemon fixture requires skipped intro")
        assert(Party._array(roster, 6) and #roster >= 1, "fixture party requires one to six members")
        prepared.party = {version=1, active=1, members={}}
        for i, spec in ipairs(roster) do
            local mon=preparePokemon(spec)
            prepared.party.members[i] = SessionCodec.encodePokemon(mon)
            if i==1 then prepared.playerCandidate=mon end
        end
    end
    assert((options.trainer_name == nil) == (options.enemy_party == nil), "trainer team requires name and party")
    if options.enemy_party ~= nil then
        assert(options.intro == "skip" and prepared.party, "trainer team requires explicit owned party and skipped intro")
        assert(type(options.trainer_name) == "string" and #options.trainer_name >= 1 and #options.trainer_name <= 30
            and not options.trainer_name:find("[^ -~]"), "invalid synthetic trainer name")
        assert(Party._array(options.enemy_party,6) and #options.enemy_party >= 1, "trainer team requires one to six members")
        prepared.enemyParty = {version=1, active=1, members={}}
        for i,spec in ipairs(options.enemy_party) do
            local data=assert(PokemonCodec.encode(preparePokemon(spec)))
            assert(data.hp>0,"trainer fixture member must be conscious")
            prepared.enemyParty.members[i]=data
        end
        -- Party schema/ownership capacity preflight occurs before any live reset.
        assert(Party.fromData(prepared.enemyParty,PokemonCodec.decode))
        prepared.trainerName = options.trainer_name
    end
    if options.grant_xp then
        fields(options.grant_xp,{amount=true,to_level=true})
        local xp=options.grant_xp
        assert((xp.amount==nil) ~= (xp.to_level==nil),"XP fixture requires amount or target")
        assert(xp.amount==nil or integer(xp.amount,0,1000000),"invalid XP fixture amount")
        assert(xp.to_level==nil or integer(xp.to_level,1,100),"invalid XP target level")
        if prepared.party then
            local mon=assert(PokemonCodec.decode(assert(PokemonCodec.encode(prepared.playerCandidate))))
            assert(not xp.to_level or xp.to_level>=mon.level,"XP fixture cannot lower level")
            mon:gainXP(xp.amount or mon:xpForLevel(xp.to_level)-mon.xp)
            if prepared.enemyParty then
                assert(#mon:getPendingMoveChoices()==0 and mon.pendingEvolution==nil,
                    "trainer fixture XP must settle before battle without a learning/evolution overlay")
            end
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
    game.player=nil
    WorldDeltas.disposeImportedCache()
    for key, stored in pairs(baseline) do
        local zone = zoneRegistry[key]
        zone.npcDefs = copy(stored.npcDefs)
    end
    for key in pairs(DEBUG_FLAGS) do DEBUG_FLAGS[key] = nil end
    for key, value in pairs(flagBaseline) do DEBUG_FLAGS[key] = value end
    game.player = nil
    game.lastBattleOutcome = nil
    game.lastVermilionAideFixture = nil
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
    if prepared.aideCandidates then
        local session, receipts = game.session, {}
        local function ownedCount()
            local count = 0
            for _, owned in pairs(session:pokedex().owned) do
                if owned then
                    count = count + 1
                end
            end
            return count
        end
        for _, mon in ipairs(prepared.aideCandidates) do
            if ownedCount() >= prepared.aideThreshold then
                break
            end
            if not session:pokedex().owned[mon.species] then
                local storage = session:storage()
                if session:party():count() >= Party.CAPACITY and storage:count() >= Storage.BOX_CAPACITY then
                    assert(storage:selectBox(storage:activeBox()+1))
                end
                local ok, receipt = session:recruit(mon)
                assert(ok, receipt)
                receipts[#receipts+1] = {species=mon.species,destination=receipt}
            end
        end
        assert(ownedCount()==prepared.aideThreshold, "aide fixture distinct recruitment threshold")
        game.lastVermilionAideFixture = {classification="supplementary",case=prepared.aideKey,
            threshold=prepared.aideThreshold,owned=ownedCount(),recruits=receipts}
    end
    for _, species in ipairs(prepared.pokedexSeen or {}) do assert(game.session:markSeen(species)) end
    if options.grant_xp then
        local mon = assert(game:getPlayerPokemon(), "XP fixture requires a player Pokemon")
        local xp = options.grant_xp
        assert(not xp.to_level or xp.to_level >= mon.level, "XP fixture cannot lower a level")
        mon:gainXP(xp.amount or math.max(0, mon:xpForLevel(xp.to_level) - mon.xp))
    end
    if options.zone then
        assert(WorldDeltas.describeZone(options.zone), "unknown fixture zone")
        switchZone(options.zone)
    end
    machine:change("overworld", { respawn = true, entry = options.entry })
    if options.intro ~= "skip" and options.opening ~= false then
        machine:push("dialog", Story.openingLines)
    end
    if prepared.enemyParty then
        local enemies=assert(Party.fromData(prepared.enemyParty,PokemonCodec.decode))
        -- Synthetic harness identity never aliases a source trainer flag/reward.
        local npc={name=prepared.trainerName,trainerID="fixture:trainer-team",fixtureDefeated=false,
            markInteracted=function(self) self.fixtureDefeated=true end}
        machine:change("battle",assert(game:getPlayerPokemon()),enemies:active(),npc,enemies)
    elseif options.grant_xp then game:offerPartyLearning() end
end
