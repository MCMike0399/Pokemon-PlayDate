import "CoreLibs/object"
import "CoreLibs/graphics"
import "game/bootstrap"
GameBootstrap.showLoading()
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/frameTimer"

import "lib/oop"
import "lib/rng"
import "lib/shade"
import "lib/statemachine"
import "world/tilefactory"
import "world/tileRegistry"
import "world/spritefactory"
import "world/zone"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "data/pokemonArt"
import "domain/party"
import "domain/storage"
import "domain/inventory"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "data/fieldMoveBattleData"
import "domain/pokemonCodec"
import "domain/saveStore"
import "data/items"
import "data/lightBall"
import "data/pickupData"
import "domain/items"
import "domain/worldMotion"
import "domain/itemStorage"
import "domain/pcItems"
import "domain/pickup"
import "domain/coinWallet"
import "domain/safariGame"
import "domain/fieldTravel"
import "domain/fieldCycling"
import "domain/fieldFishing"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/teaching"
import "domain/sessionCodec"
import "game/daycare"
import "domain/fieldMoves"
import "game/fieldMoveWorld"
import "domain/fieldWorld"
import "data/captureData"
import "domain/capture"
import "game/sourceText"
import "ui/sourceTextFont"
import "ui/dialog"
import "ui/menu"
import "ui/debug"
import "world/camera"
import "world/npc"
import "world/player"
import "world/overworld"
import "battle/battle"
import "battle/battleScene"
import "game/story"
import "data/maps"
import "game/fieldTravelWorld"
import "game/context"
import "game/overworldState"
import "game/dialogState"
import "game/battleState"
import "game/debugState"
import "game/learningState"
import "game/saves"
import "game/titleState"
import "game/pauseState"
import "game/partyState"
import "game/fieldMoveState"
import "game/bagState"
import "game/shopState"
import "data/pilotWorld"
import "world/sliceEvents"
import "world/sliceSprites"
import "world/mapBindings"
import "data/viridianSlice"
import "data/pewterSlice"
import "world/importedMaps"
import "world/pewterSprites"
import "game/trainerEvents"
import "game/pewterEvents"
import "world/pewterBindings"
import "game/pewterWorld"
import "world/sourceActors"
import "world/npcMotion"
import "game/kantoWorld"
import "game/eventText"
import "game/eventArt"
import "game/healingComposition"
import "game/eventState"
import "data/ceruleanContent"
import "game/ceruleanStory"
import "game/ceruleanRoutes"
import "game/ceruleanRoutesState"
import "game/tutorialEscort"
import "game/kantoScenes"
import "game/kantoServices"
import "game/vermilionGifts"
import "game/vermilionShip"
import "game/vermilionStory"
import "game/vermilionStoryTerrain"
import "game/vermilionStoryIntent"
import "game/vermilionStoryHooks"
import "game/vermilionStoryState"
import "game/daycareState"
import "game/npcTradeState"
import "game/saffronGuards"
import "game/pokedexState"
import "game/pcState"
import "game/evolutionState"
import "world/pcTerminals"
-- @harness imports-1
import "game/townMapState"
import "game/fieldItems"
-- @harness imports-2

local harness = nil
-- @harness runtime

playdate.display.setRefreshRate(30)
if not harness then
    RulesRNG.seed(playdate.getSecondsSinceEpoch())
end

-- Shared context: root machine, camera, npc manager, player, player pokemon.
-- Global so dev tooling (autopilot, debug) can reach it.
import "game/fieldBattle"
import "game/homeRest"
-- @harness imports-3

import "game/itemPCState"
-- @harness imports-4

import "domain/fieldEncounters"
-- @harness imports-5

-- @harness imports-6

-- @harness imports-7

import "game/rocketHideoutStory"
import "game/rocketHideoutStoryWorld"
import "game/rocketHideoutStoryController"
import "game/midgameGymStory"
import "game/midgameStoryWarps"
import "game/celadonServices"
import "game/celadonServicesController"
import "game/hideoutTowerContent"
import "game/hideoutTowerController"

local function campaignActorMetadata(definition, event, runtimeGame)
    local metadata = KantoScenes.actorMetadata(definition, event, runtimeGame)
    local extra = VermilionStory.actorMetadata(event.id, runtimeGame)
    for _, condition in ipairs(extra.visibility or {}) do
        metadata.visibility[#metadata.visibility + 1] = Party._primitive(condition)
    end
    local story = HideoutTowerContent.actorMetadata(event.id, runtimeGame)
    for _, condition in ipairs(story.visibility) do
        metadata.visibility[#metadata.visibility + 1] = Party._primitive(condition)
    end
    return metadata
end

CeruleanContent.registerPackage("vermilion", "data/vermilionPreparation/")
CeruleanContent.registerPackage("midgameEast", "data/midgameEast/", function(events, trainers)
    return HideoutTowerContent.package("midgameEast", events, trainers)
end)
CeruleanContent.install(campaignActorMetadata)
CeruleanContent.installSigns()
KantoScenes.install()
KantoServices.install()
VermilionGifts.install()
VermilionStory.install({reconcileActors=KantoScenes.reconcileActors})
Daycare.install()
-- NPC trades and Saffron guards remain parked for later checkpoints.
HideoutTowerContent.install()
CeladonServices.install({reconcileActors=KantoScenes.reconcileActors})
MidgameStoryWarps.install()
-- @harness content-ready
SourceEvents.registerWorldHooks("pokered:MUSEUM_1F:objects:1", {explore=KantoServices.check})
SourceEvents.registerWorldHooks("pokered:PEWTER_CITY:script:default", {
    beforeSpawn=function(context)
        assert(KantoServices.onMapEnter(context.session, currentZone.stableID))
    end,
})

local function initialize()
    collectgarbage("collect")
    GameBootstrap.checkpoint()
    game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})

    GameBootstrap.checkpoint()

    local machine <const> = game.machine
    machine:register("overworld", OverworldState(game))
    machine:register("dialog", DialogState(game))
    machine:register("battle", BattleState(game))
    machine:register("debug", DebugState(game))
    machine:register("learning", LearningState(game))
    machine:register("evolution", EvolutionState(game))
    machine:register("title", TitleState(game))
    machine:register("pause", PauseState(game))
    machine:register("options", OptionsState(game))
    machine:register("party", PartyState(game))
    machine:register("fieldMove", FieldMoveState(game))
    machine:register("bag", BagState(game))
    machine:register("shop", ShopState(game))
    machine:register("event", NPCTradeState(game))
    machine:register("tutorial-escort", TutorialEscortState(game))
    machine:register("pokedex", PokedexState(game))
    machine:register("pc", PCState(game))
    machine:register("itemPC",ItemPCState(game))
    machine:register("townMap",TownMapState(game))
    machine:register("homeRest",HomeRestState(game))
    KantoWorld.install(game)
    PewterWorld.install(game)
    game.saves = GameSaves(game)

    -- Debug menu rides on top of the overworld via the system menu
    local sysMenu = playdate.getSystemMenu()
    sysMenu:addMenuItem("Debug", function()
        if machine:is("overworld") then
            machine:push("debug")
        end
    end)

    -- ============================================================
    -- GAME LOOP
    -- ============================================================
    -- Show the title before New Game or Continue. New Game starts Oak's opening.
    game.saves:start()

    ---@diagnostic disable-next-line: duplicate-set-field
    local function updateGame()
        if harness then harness.beforeFrame(game) end

        machine:update()
        machine:handleInput()
        machine:get("overworld"):flushPendingPresentation()
        machine:draw()

        playdate.timer.updateTimers()
        collectgarbage("step", 1)

        local top = machine:getCurrent()
        if top ~= "battle" then
            if DEBUG_FLAGS.showGrid then DebugMenu.drawOverlays() end
            if DEBUG_FLAGS.showFPS then
                game.camera:reset()
                playdate.drawFPS(4, 4)
                game.camera:apply()
            end
        end
    end

    -- Harness failures are evidence rather than an unacknowledged mailbox hang.
    function playdate.update()
        if harness and harness.isQuiescent then return end
        if harness and playdate.isSimulator then
            local ok, message = pcall(updateGame)
            harness.afterFrame(game, not ok and tostring(message) or nil)
        else
            updateGame()
        end
    end
end

GameBootstrap.start(initialize)
