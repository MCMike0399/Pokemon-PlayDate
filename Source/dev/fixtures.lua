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
    baseline[key] = { tiles = copy(zone.tiles), collision = copy(zone.collision), npcDefs = copy(zone.npcDefs) }
end
local flagBaseline = copy(DEBUG_FLAGS)

function HarnessFixtures.reset(game, options)
    options = options or {}
    -- Exit top-down WITHOUT pop/resume: closing a dialog must not invoke a
    -- story callback or resume an obsolete battle coroutine.
    local machine = game.machine
    for i = #machine.stack, 1, -1 do
        machine.stack[i]:exit()
        machine.stack[i] = nil
    end
    for _, timer in ipairs(playdate.timer.allTimers()) do timer:remove() end
    for _, timer in ipairs(playdate.frameTimer.allTimers()) do timer:remove() end
    playdate.graphics.sprite.removeAll()
    playdate.display.setOffset(0, 0)
    playdate.graphics.setDrawOffset(0, 0)
    game.npcManager:clear()
    for key, stored in pairs(baseline) do
        local zone = zoneRegistry[key]
        zone.tiles = copy(stored.tiles)
        zone.collision = copy(stored.collision)
        zone.npcDefs = copy(stored.npcDefs)
    end
    for key in pairs(DEBUG_FLAGS) do DEBUG_FLAGS[key] = nil end
    for key, value in pairs(flagBaseline) do DEBUG_FLAGS[key] = value end
    game.player = nil
    game.playerPokemon = nil
    game.lastBattleOutcome = nil
    game.transitionLog = {}
    game.debugMenu = DebugMenu()
    local world = machine:get("overworld")
    world.savedPos = nil
    world.builtZone = nil
    world.sub:get("irisOut").callback = nil
    world.sub:get("doorWarp").door = nil
    Story.stage = "pre_oak"
    Story.starter = nil
    Story.rivalStarter = nil
    Story.rivalOutcome = nil
    if RulesRNG then RulesRNG.seed(options.seed or 0) end
    math.randomseed(options.seed or 0)
    Story.begin()
    if options.intro == "skip" then Story.skipIntro(game) end
    if options.player_pokemon then
        game.playerPokemon = Pokemon(options.player_pokemon.species, options.player_pokemon.level)
    end
    if options.grant_xp then
        local mon = assert(game.playerPokemon, "XP fixture requires a player Pokemon")
        local xp = options.grant_xp
        assert(not xp.to_level or xp.to_level >= mon.level, "XP fixture cannot lower a level")
        mon:gainXP(xp.amount or math.max(0, xpForLevel(xp.to_level) - mon.xp))
    end
    if options.zone then
        assert(zoneRegistry[options.zone], "unknown fixture zone")
        switchZone(options.zone)
    end
    machine:change("overworld", { respawn = true, entry = options.entry })
    if options.intro ~= "skip" and options.opening ~= false then
        machine:push("dialog", Story.openingLines)
    end
    if options.grant_xp then game:offerLearning(game.playerPokemon) end
end
