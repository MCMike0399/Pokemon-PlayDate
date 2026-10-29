import "game/bootTrace"
BootTrace.mark("import.game/bootstrap.begin")
import "game/bootstrap"
BootTrace.mark("import.game/bootstrap.end")
GameBootstrap.showLoading()
local bootAccepted, bootProblem = pcall(function()
    BootTrace.mark("import.CoreLibs/object.begin")
    import "CoreLibs/object"
    BootTrace.mark("import.CoreLibs/object.end")
    BootTrace.mark("import.CoreLibs/graphics.begin")
    import "CoreLibs/graphics"
    BootTrace.mark("import.CoreLibs/graphics.end")
    BootTrace.mark("import.CoreLibs/sprites.begin")
    import "CoreLibs/sprites"
    BootTrace.mark("import.CoreLibs/sprites.end")
    BootTrace.mark("import.CoreLibs/timer.begin")
    import "CoreLibs/timer"
    BootTrace.mark("import.CoreLibs/timer.end")
    BootTrace.mark("import.CoreLibs/frameTimer.begin")
    import "CoreLibs/frameTimer"
    BootTrace.mark("import.CoreLibs/frameTimer.end")

    BootTrace.mark("import.lib/oop.begin")
    import "lib/oop"
    BootTrace.mark("import.lib/oop.end")
    BootTrace.mark("import.lib/rng.begin")
    import "lib/rng"
    BootTrace.mark("import.lib/rng.end")
    BootTrace.mark("import.lib/shade.begin")
    import "lib/shade"
    BootTrace.mark("import.lib/shade.end")
    BootTrace.mark("import.lib/statemachine.begin")
    import "lib/statemachine"
    BootTrace.mark("import.lib/statemachine.end")
    BootTrace.mark("import.world/tilefactory.begin")
    import "world/tilefactory"
    BootTrace.mark("import.world/tilefactory.end")
    BootTrace.mark("import.world/tileRegistry.begin")
    import "world/tileRegistry"
    BootTrace.mark("import.world/tileRegistry.end")
    BootTrace.mark("import.world/spritefactory.begin")
    import "world/spritefactory"
    BootTrace.mark("import.world/spritefactory.end")
    BootTrace.mark("import.world/zone.begin")
    import "world/zone"
    BootTrace.mark("import.world/zone.end")
    BootTrace.mark("import.data/individualData.begin")
    import "data/individualData"
    BootTrace.mark("import.data/individualData.end")
    BootTrace.mark("import.domain/individualStats.begin")
    import "domain/individualStats"
    BootTrace.mark("import.domain/individualStats.end")
    BootTrace.mark("import.data/pokemon.begin")
    import "data/pokemon"
    BootTrace.mark("import.data/pokemon.end")
    BootTrace.mark("import.data/pokemonArt.begin")
    import "data/pokemonArt"
    BootTrace.mark("import.data/pokemonArt.end")
    BootTrace.mark("import.domain/party.begin")
    import "domain/party"
    BootTrace.mark("import.domain/party.end")
    BootTrace.mark("import.domain/storage.begin")
    import "domain/storage"
    BootTrace.mark("import.domain/storage.end")
    BootTrace.mark("import.domain/inventory.begin")
    import "domain/inventory"
    BootTrace.mark("import.domain/inventory.end")
    BootTrace.mark("import.data/typechart.begin")
    import "data/typechart"
    BootTrace.mark("import.data/typechart.end")
    BootTrace.mark("import.battle/dsl.begin")
    import "battle/dsl"
    BootTrace.mark("import.battle/dsl.end")
    BootTrace.mark("import.battle/moves.begin")
    import "battle/moves"
    BootTrace.mark("import.battle/moves.end")
    BootTrace.mark("import.data/fieldMoveBattleData.begin")
    import "data/fieldMoveBattleData"
    BootTrace.mark("import.data/fieldMoveBattleData.end")
    BootTrace.mark("import.domain/pokemonCodec.begin")
    import "domain/pokemonCodec"
    BootTrace.mark("import.domain/pokemonCodec.end")
    BootTrace.mark("import.domain/saveStore.begin")
    import "domain/saveStore"
    BootTrace.mark("import.domain/saveStore.end")
    BootTrace.mark("import.data/items.begin")
    import "data/items"
    BootTrace.mark("import.data/items.end")
    BootTrace.mark("import.data/lightBall.begin")
    import "data/lightBall"
    BootTrace.mark("import.data/lightBall.end")
    BootTrace.mark("import.data/pickupData.begin")
    import "data/pickupData"
    BootTrace.mark("import.data/pickupData.end")
    BootTrace.mark("import.domain/items.begin")
    import "domain/items"
    BootTrace.mark("import.domain/items.end")
    BootTrace.mark("import.domain/worldMotion.begin")
    import "domain/worldMotion"
    BootTrace.mark("import.domain/worldMotion.end")
    BootTrace.mark("import.domain/itemStorage.begin")
    import "domain/itemStorage"
    BootTrace.mark("import.domain/itemStorage.end")
    BootTrace.mark("import.domain/pcItems.begin")
    import "domain/pcItems"
    BootTrace.mark("import.domain/pcItems.end")
    BootTrace.mark("import.domain/pickup.begin")
    import "domain/pickup"
    BootTrace.mark("import.domain/pickup.end")
    BootTrace.mark("import.domain/gameSession.begin")
    import "domain/gameSession"
    BootTrace.mark("import.domain/gameSession.end")
    BootTrace.mark("import.domain/teaching.begin")
    import "domain/teaching"
    BootTrace.mark("import.domain/teaching.end")
    BootTrace.mark("import.domain/sessionCodec.begin")
    import "domain/sessionCodec"
    BootTrace.mark("import.domain/sessionCodec.end")
    BootTrace.mark("import.game/daycare.begin")
    import "game/daycare"
    BootTrace.mark("import.game/daycare.end")
    BootTrace.mark("import.domain/fieldMoves.begin")
    import "domain/fieldMoves"
    BootTrace.mark("import.domain/fieldMoves.end")
    BootTrace.mark("import.game/fieldMoveWorld.begin")
    import "game/fieldMoveWorld"
    BootTrace.mark("import.game/fieldMoveWorld.end")
    BootTrace.mark("import.domain/fieldWorld.begin")
    import "domain/fieldWorld"
    BootTrace.mark("import.domain/fieldWorld.end")
    BootTrace.mark("import.data/captureData.begin")
    import "data/captureData"
    BootTrace.mark("import.data/captureData.end")
    BootTrace.mark("import.domain/capture.begin")
    import "domain/capture"
    BootTrace.mark("import.domain/capture.end")
    BootTrace.mark("import.game/sourceText.begin")
    import "game/sourceText"
    BootTrace.mark("import.game/sourceText.end")
    BootTrace.mark("import.ui/sourceTextFont.begin")
    import "ui/sourceTextFont"
    BootTrace.mark("import.ui/sourceTextFont.end")
    BootTrace.mark("import.ui/dialog.begin")
    import "ui/dialog"
    BootTrace.mark("import.ui/dialog.end")
    BootTrace.mark("import.ui/menu.begin")
    import "ui/menu"
    BootTrace.mark("import.ui/menu.end")
    BootTrace.mark("import.ui/debug.begin")
    import "ui/debug"
    BootTrace.mark("import.ui/debug.end")
    BootTrace.mark("import.world/camera.begin")
    import "world/camera"
    BootTrace.mark("import.world/camera.end")
    BootTrace.mark("import.world/npc.begin")
    import "world/npc"
    BootTrace.mark("import.world/npc.end")
    BootTrace.mark("import.world/player.begin")
    import "world/player"
    BootTrace.mark("import.world/player.end")
    BootTrace.mark("import.world/overworld.begin")
    import "world/overworld"
    BootTrace.mark("import.world/overworld.end")
    BootTrace.mark("import.battle/battle.begin")
    import "battle/battle"
    BootTrace.mark("import.battle/battle.end")
    BootTrace.mark("import.battle/battleScene.begin")
    import "battle/battleScene"
    BootTrace.mark("import.battle/battleScene.end")
    BootTrace.mark("import.game/story.begin")
    import "game/story"
    BootTrace.mark("import.game/story.end")
    BootTrace.mark("import.data/maps.begin")
    import "data/maps"
    BootTrace.mark("import.data/maps.end")
    BootTrace.mark("import.game/context.begin")
    import "game/context"
    BootTrace.mark("import.game/context.end")
    BootTrace.mark("import.game/overworldState.begin")
    import "game/overworldState"
    BootTrace.mark("import.game/overworldState.end")
    BootTrace.mark("import.game/dialogState.begin")
    import "game/dialogState"
    BootTrace.mark("import.game/dialogState.end")
    BootTrace.mark("import.game/battleState.begin")
    import "game/battleState"
    BootTrace.mark("import.game/battleState.end")
    BootTrace.mark("import.game/debugState.begin")
    import "game/debugState"
    BootTrace.mark("import.game/debugState.end")
    BootTrace.mark("import.game/learningState.begin")
    import "game/learningState"
    BootTrace.mark("import.game/learningState.end")
    BootTrace.mark("import.game/saves.begin")
    import "game/saves"
    BootTrace.mark("import.game/saves.end")
    BootTrace.mark("import.game/titleState.begin")
    import "game/titleState"
    BootTrace.mark("import.game/titleState.end")
    BootTrace.mark("import.game/pauseState.begin")
    import "game/pauseState"
    BootTrace.mark("import.game/pauseState.end")
    BootTrace.mark("import.game/partyState.begin")
    import "game/partyState"
    BootTrace.mark("import.game/partyState.end")
    BootTrace.mark("import.game/fieldMoveState.begin")
    import "game/fieldMoveState"
    BootTrace.mark("import.game/fieldMoveState.end")
    BootTrace.mark("import.game/bagState.begin")
    import "game/bagState"
    BootTrace.mark("import.game/bagState.end")
    BootTrace.mark("import.game/shopState.begin")
    import "game/shopState"
    BootTrace.mark("import.game/shopState.end")
    BootTrace.mark("import.data/pilotWorld.begin")
    import "data/pilotWorld"
    BootTrace.mark("import.data/pilotWorld.end")
    BootTrace.mark("import.world/sliceEvents.begin")
    import "world/sliceEvents"
    BootTrace.mark("import.world/sliceEvents.end")
    BootTrace.mark("import.world/sliceSprites.begin")
    import "world/sliceSprites"
    BootTrace.mark("import.world/sliceSprites.end")
    BootTrace.mark("import.world/mapBindings.begin")
    import "world/mapBindings"
    BootTrace.mark("import.world/mapBindings.end")
    BootTrace.mark("import.data/viridianSlice.begin")
    import "data/viridianSlice"
    BootTrace.mark("import.data/viridianSlice.end")
    BootTrace.mark("import.data/pewterSlice.begin")
    import "data/pewterSlice"
    BootTrace.mark("import.data/pewterSlice.end")
    BootTrace.mark("import.world/importedMaps.begin")
    import "world/importedMaps"
    BootTrace.mark("import.world/importedMaps.end")
    BootTrace.mark("import.world/pewterSprites.begin")
    import "world/pewterSprites"
    BootTrace.mark("import.world/pewterSprites.end")
    BootTrace.mark("import.game/trainerEvents.begin")
    import "game/trainerEvents"
    BootTrace.mark("import.game/trainerEvents.end")
    BootTrace.mark("import.game/pewterEvents.begin")
    import "game/pewterEvents"
    BootTrace.mark("import.game/pewterEvents.end")
    BootTrace.mark("import.world/pewterBindings.begin")
    import "world/pewterBindings"
    BootTrace.mark("import.world/pewterBindings.end")
    BootTrace.mark("import.game/pewterWorld.begin")
    import "game/pewterWorld"
    BootTrace.mark("import.game/pewterWorld.end")
    BootTrace.mark("import.world/sourceActors.begin")
    import "world/sourceActors"
    BootTrace.mark("import.world/sourceActors.end")
    BootTrace.mark("import.world/npcMotion.begin")
    import "world/npcMotion"
    BootTrace.mark("import.world/npcMotion.end")
    BootTrace.mark("import.game/kantoWorld.begin")
    import "game/kantoWorld"
    BootTrace.mark("import.game/kantoWorld.end")
    BootTrace.mark("import.game/eventText.begin")
    import "game/eventText"
    BootTrace.mark("import.game/eventText.end")
    BootTrace.mark("import.game/eventArt.begin")
    import "game/eventArt"
    BootTrace.mark("import.game/eventArt.end")
    BootTrace.mark("import.game/healingComposition.begin")
    import "game/healingComposition"
    BootTrace.mark("import.game/healingComposition.end")
    BootTrace.mark("import.game/eventState.begin")
    import "game/eventState"
    BootTrace.mark("import.game/eventState.end")
    BootTrace.mark("import.data/ceruleanContent.begin")
    import "data/ceruleanContent"
    BootTrace.mark("import.data/ceruleanContent.end")
    BootTrace.mark("import.game/ceruleanStory.begin")
    import "game/ceruleanStory"
    BootTrace.mark("import.game/ceruleanStory.end")
    BootTrace.mark("import.game/ceruleanRoutes.begin")
    import "game/ceruleanRoutes"
    BootTrace.mark("import.game/ceruleanRoutes.end")
    BootTrace.mark("import.game/ceruleanRoutesState.begin")
    import "game/ceruleanRoutesState"
    BootTrace.mark("import.game/ceruleanRoutesState.end")
    BootTrace.mark("import.game/tutorialEscort.begin")
    import "game/tutorialEscort"
    BootTrace.mark("import.game/tutorialEscort.end")
    BootTrace.mark("import.game/kantoScenes.begin")
    import "game/kantoScenes"
    BootTrace.mark("import.game/kantoScenes.end")
    BootTrace.mark("import.game/kantoServices.begin")
    import "game/kantoServices"
    BootTrace.mark("import.game/kantoServices.end")
    BootTrace.mark("import.game/vermilionGifts.begin")
    import "game/vermilionGifts"
    BootTrace.mark("import.game/vermilionGifts.end")
    BootTrace.mark("import.game/vermilionShip.begin")
    import "game/vermilionShip"
    BootTrace.mark("import.game/vermilionShip.end")
    BootTrace.mark("import.game/vermilionStory.begin")
    import "game/vermilionStory"
    BootTrace.mark("import.game/vermilionStory.end")
    BootTrace.mark("import.game/vermilionStoryTerrain.begin")
    import "game/vermilionStoryTerrain"
    BootTrace.mark("import.game/vermilionStoryTerrain.end")
    BootTrace.mark("import.game/vermilionStoryIntent.begin")
    import "game/vermilionStoryIntent"
    BootTrace.mark("import.game/vermilionStoryIntent.end")
    BootTrace.mark("import.game/vermilionStoryHooks.begin")
    import "game/vermilionStoryHooks"
    BootTrace.mark("import.game/vermilionStoryHooks.end")
    BootTrace.mark("import.game/vermilionStoryState.begin")
    import "game/vermilionStoryState"
    BootTrace.mark("import.game/vermilionStoryState.end")
    BootTrace.mark("import.game/daycareState.begin")
    import "game/daycareState"
    BootTrace.mark("import.game/daycareState.end")
    BootTrace.mark("import.game/pokedexState.begin")
    import "game/pokedexState"
    BootTrace.mark("import.game/pokedexState.end")
    BootTrace.mark("import.game/pcState.begin")
    import "game/pcState"
    BootTrace.mark("import.game/pcState.end")
    BootTrace.mark("import.game/evolutionState.begin")
    import "game/evolutionState"
    BootTrace.mark("import.game/evolutionState.end")
    BootTrace.mark("import.world/pcTerminals.begin")
    import "world/pcTerminals"
    BootTrace.mark("import.world/pcTerminals.end")
    -- @harness imports-1
    BootTrace.mark("import.game/townMapState.begin")
    import "game/townMapState"
    BootTrace.mark("import.game/townMapState.end")
    BootTrace.mark("import.game/fieldItems.begin")
    import "game/fieldItems"
    BootTrace.mark("import.game/fieldItems.end")
    -- @harness imports-2

    local harness = nil
    -- @harness runtime


    -- Shared context: root machine, camera, npc manager, player, player pokemon.
    -- Global so dev tooling (autopilot, debug) can reach it.
    BootTrace.mark("import.game/fieldBattle.begin")
    import "game/fieldBattle"
    BootTrace.mark("import.game/fieldBattle.end")
    BootTrace.mark("import.game/homeRest.begin")
    import "game/homeRest"
    BootTrace.mark("import.game/homeRest.end")
    -- @harness imports-3

    BootTrace.mark("import.game/itemPCState.begin")
    import "game/itemPCState"
    BootTrace.mark("import.game/itemPCState.end")
    -- @harness imports-4

    BootTrace.mark("import.domain/fieldEncounters.begin")
    import "domain/fieldEncounters"
    BootTrace.mark("import.domain/fieldEncounters.end")
    -- @harness imports-5

    -- @harness imports-6

    -- @harness imports-7

    local function campaignActorMetadata(definition, event, runtimeGame)
        local metadata = KantoScenes.actorMetadata(definition, event, runtimeGame)
        local extra = VermilionStory.actorMetadata(event.id, runtimeGame)
        for _, condition in ipairs(extra.visibility or {}) do
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

        BootTrace.mark("CeruleanContent.registerPackage.begin")
        CeruleanContent.registerPackage("vermilion", "data/vermilionPreparation/")
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
        BootTrace.mark("Daycare.install.end")
        GameBootstrap.yieldIfDue()
        SourceEvents.registerWorldHooks("pokered:MUSEUM_1F:objects:1", {explore=KantoServices.check})
        SourceEvents.registerWorldHooks("pokered:PEWTER_CITY:script:default", {
            beforeSpawn=function(context)
                assert(KantoServices.onMapEnter(context.session, currentZone.stableID))
            end,
        })
        collectgarbage("collect")
        GameBootstrap.checkpoint()
        BootTrace.mark("GameContext.begin")
        game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        BootTrace.mark("GameContext.end")
        GameBootstrap.yieldIfDue()

        GameBootstrap.checkpoint()

        local machine <const> = game.machine
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
        BootTrace.mark("state.title.begin")
        machine:register("title", TitleState(game))
        BootTrace.mark("state.title.end")
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
        machine:register("event", DaycareState(game))
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
        -- Show the title before New Game or Continue. New Game starts Oak's opening.
        BootTrace.mark("title.start.begin")
        game.saves:start()
        BootTrace.mark("title.start.end")
        GameBootstrap.yieldIfDue()
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
