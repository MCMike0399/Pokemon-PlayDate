import "game/bootTrace"
BootTrace.mark("import.game/bootstrap.begin")
import "game/bootstrap"
import "game/shippedDataPolicy"
BootTrace.mark("import.game/bootstrap.end")
GameBootstrap.showLoading()
local bootAccepted, bootProblem = pcall(function()
    BootTrace.mark("import.coreLibs.begin")
    import "CoreLibs/object"
    import "CoreLibs/graphics"
    import "CoreLibs/sprites"
    import "CoreLibs/timer"
    import "CoreLibs/frameTimer"
    BootTrace.mark("import.coreLibs.end")

    BootTrace.mark("import.foundations.begin")
    import "lib/oop"
    import "lib/rng"
    import "lib/shade"
    import "lib/statemachine"
    import "world/tilefactory"
    import "world/tileRegistry"
    import "world/spritefactory"
    import "world/zone"
    BootTrace.mark("import.foundations.end")
    BootTrace.mark("import.pokemonRules.begin")
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
    BootTrace.mark("import.pokemonRules.end")
    BootTrace.mark("import.sessionAndTransactions.begin")
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
    BootTrace.mark("import.sessionAndTransactions.end")
    BootTrace.mark("import.presentation.begin")
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
    BootTrace.mark("import.presentation.end")
    BootTrace.mark("import.authoredWorld.begin")
    import "game/story"
    import "data/maps"
    BootTrace.mark("import.authoredWorld.end")
    BootTrace.mark("import.gameStates.begin")
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
    BootTrace.mark("import.gameStates.end")
    BootTrace.mark("import.importedWorld.begin")
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
    BootTrace.mark("import.importedWorld.end")
    BootTrace.mark("import.campaignAndServices.begin")
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
    BootTrace.mark("import.campaignAndServices.end")
    -- @harness imports-2

    local harness = nil
    -- @harness runtime


    -- Shared context: root machine, camera, npc manager, player, player pokemon.
    -- Global so dev tooling (autopilot, debug) can reach it.
    BootTrace.mark("import.fieldServices.begin")
    import "game/fieldBattle"
    import "game/homeRest"
    -- @harness imports-3

    import "game/itemPCState"
    -- @harness imports-4

    import "domain/fieldEncounters"
    BootTrace.mark("import.fieldServices.end")
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

    local function initialize()
        BootTrace.mark("initialize.begin")
        playdate.display.setRefreshRate(30)
        if not harness then
            RulesRNG.seed(playdate.getSecondsSinceEpoch())
        end

        BootTrace.mark("SpriteFactory.initialize.begin")
        SpriteFactory.initialize()
        BootTrace.mark("SpriteFactory.initialize.end")
        GameBootstrap.checkpoint()
        BootTrace.mark("AuthoredMaps.initialize.begin")
        AuthoredMaps.initialize()
        BootTrace.mark("AuthoredMaps.initialize.end")
        GameBootstrap.checkpoint()

        local function installContent()
            BootTrace.mark("CeruleanContent.registerPackage.begin")
            CeruleanContent.registerPackage("vermilion", "data/vermilionPreparation/")
            CeruleanContent.registerPackage("midgameEast", "data/midgameEast/", function(events, trainers)
                return HideoutTowerContent.package("midgameEast", events, trainers)
            end)
            BootTrace.mark("CeruleanContent.registerPackage.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("CeruleanContent.install.begin")
            CeruleanContent.install(campaignActorMetadata)
            BootTrace.mark("CeruleanContent.install.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("CeruleanContent.installSigns.begin")
            CeruleanContent.installSigns()
            BootTrace.mark("CeruleanContent.installSigns.end")
            GameBootstrap.yieldIfDue()

            -- @harness content-ready
            BootTrace.mark("KantoScenes.install.begin")
            KantoScenes.install()
            BootTrace.mark("KantoScenes.install.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("KantoServices.install.begin")
            KantoServices.install()
            BootTrace.mark("KantoServices.install.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("VermilionGifts.install.begin")
            VermilionGifts.install()
            BootTrace.mark("VermilionGifts.install.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("VermilionStory.install.begin")
            VermilionStory.install({reconcileActors=KantoScenes.reconcileActors})
            BootTrace.mark("VermilionStory.install.end")
            GameBootstrap.yieldIfDue()
            BootTrace.mark("Daycare.install.begin")
            Daycare.install()
            -- NPC trades and Saffron guards remain parked.
            HideoutTowerContent.install()
            CeladonServices.install({reconcileActors=KantoScenes.reconcileActors})
            MidgameStoryWarps.install()
            BootTrace.mark("Daycare.install.end")
            GameBootstrap.yieldIfDue()
            SourceEvents.registerWorldHooks("pokered:MUSEUM_1F:objects:1", {explore=KantoServices.check})
            SourceEvents.registerWorldHooks("pokered:PEWTER_CITY:script:default", {
                beforeSpawn=function(context)
                    assert(KantoServices.onMapEnter(context.session, currentZone.stableID))
                end,
            })
        end
        BootTrace.mark("GameContext.begin")
        game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        BootTrace.mark("GameContext.end")
        GameBootstrap.yieldIfDue()

        GameBootstrap.checkpoint()

        local machine <const> = game.machine
        BootTrace.mark("state.title.begin")
        local title = machine:register("title", TitleState(game))
        BootTrace.mark("state.title.end")
        BootTrace.mark("title.start.begin")
        machine:change("title", {preparing=true})
        BootTrace.mark("title.start.end")
        GameBootstrap.presentStartup(function()
            machine:draw()
            return true
        end)
        BootTrace.mark("title.visible")

        -- Keep the real title on screen while immutable content is installed.
        -- No gameplay input is dispatched until all owners are ready.
        installContent()
        collectgarbage("collect")
        GameBootstrap.checkpoint()

        BootTrace.mark("state.overworld.begin")
        machine:register("overworld", OverworldState(game))
        BootTrace.mark("state.overworld.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.dialog.begin")
        machine:register("dialog", DialogState(game))
        BootTrace.mark("state.dialog.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.battle.begin")
        machine:register("battle", BattleState(game))
        BootTrace.mark("state.battle.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.debug.begin")
        machine:register("debug", DebugState(game))
        BootTrace.mark("state.debug.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.learning.begin")
        machine:register("learning", LearningState(game))
        BootTrace.mark("state.learning.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.evolution.begin")
        machine:register("evolution", EvolutionState(game))
        BootTrace.mark("state.evolution.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.pause.begin")
        machine:register("pause", PauseState(game))
        BootTrace.mark("state.pause.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.options.begin")
        machine:register("options", OptionsState(game))
        BootTrace.mark("state.options.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.party.begin")
        machine:register("party", PartyState(game))
        BootTrace.mark("state.party.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.fieldMove.begin")
        machine:register("fieldMove", FieldMoveState(game))
        BootTrace.mark("state.fieldMove.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.bag.begin")
        machine:register("bag", BagState(game))
        BootTrace.mark("state.bag.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.shop.begin")
        machine:register("shop", ShopState(game))
        BootTrace.mark("state.shop.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.event.begin")
        machine:register("event", NPCTradeState(game))
        BootTrace.mark("state.event.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.tutorial-escort.begin")
        machine:register("tutorial-escort", TutorialEscortState(game))
        BootTrace.mark("state.tutorial-escort.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.pokedex.begin")
        machine:register("pokedex", PokedexState(game))
        BootTrace.mark("state.pokedex.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.pc.begin")
        machine:register("pc", PCState(game))
        BootTrace.mark("state.pc.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.itemPC.begin")
        machine:register("itemPC",ItemPCState(game))
        BootTrace.mark("state.itemPC.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.townMap.begin")
        machine:register("townMap",TownMapState(game))
        BootTrace.mark("state.townMap.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("state.homeRest.begin")
        machine:register("homeRest",HomeRestState(game))
        BootTrace.mark("state.homeRest.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("KantoWorld.install.begin")
        KantoWorld.install(game)
        BootTrace.mark("KantoWorld.install.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("PewterWorld.install.begin")
        PewterWorld.install(game)
        BootTrace.mark("PewterWorld.install.end")
        GameBootstrap.yieldIfDue()
        BootTrace.mark("GameSaves.begin")
        game.saves = GameSaves(game)
        BootTrace.mark("GameSaves.end")
        GameBootstrap.yieldIfDue()

        -- Debug menu rides on top of the overworld via the system menu
        local sysMenu = playdate.getSystemMenu()
        sysMenu:addMenuItem("Debug", function()
            if machine:is("overworld") and not GameBootstrap.isLoading() then
                machine:push("debug")
            end
        end)

        -- ============================================================
        -- GAME LOOP
        -- ============================================================
        BootTrace.mark("title.prepare.begin")
        title:finishStartup()
        BootTrace.mark("title.prepare.end")
        GameBootstrap.checkpoint()
        if DEVICE_TEST_BUILD then
            BootTrace.collect("title.live")
        end

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
                GameBootstrap.runFrame(updateGame, game)
            end
        end
    end

    GameBootstrap.start(initialize)
end)
if not bootAccepted then
    GameBootstrap.fail(bootProblem)
end
