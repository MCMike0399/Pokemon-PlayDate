import "CoreLibs/object"
import "CoreLibs/graphics"
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
import "domain/pokemonCodec"
import "domain/saveStore"
import "data/items"
import "data/lightBall"
import "domain/items"
import "domain/worldMotion"
import "domain/itemStorage"
import "domain/pcItems"
import "domain/gameSession"
import "domain/teaching"
import "domain/sessionCodec"
import "data/captureData"
import "domain/capture"
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
import "game/pokedexState"
import "game/pcState"
import "game/evolutionState"
import "world/pcTerminals"
import "dev/sliceCatalog"
import "dev/sliceContracts"
import "dev/worldContracts"
import "dev/contracts"
import "dev/learnsetContracts"
import "dev/partyContracts"
import "dev/learningContracts"
import "dev/saveContracts"
import "dev/combatContracts"
import "dev/rngPersistenceContracts"
import "dev/growthContracts"
import "dev/itemContracts"
import "dev/sessionContracts"
import "dev/captureContracts"
import "dev/sessionBridgeContracts"
import "dev/partyBattleContracts"
import "dev/shopContracts"
import "dev/captureAnimationContracts"
import "dev/traversalContracts"
import "dev/eventContracts"
import "dev/eventCatalogContracts"
import "dev/pokedexContracts"
import "dev/earlyCombatContracts"
import "dev/runtimeArtContracts"
import "dev/pcContracts"
import "dev/evolutionContracts"
import "dev/healingCompositionContracts"
Contracts.register("learnsets", LearnsetContracts.run)
Contracts.register("collections", PartyContracts.run)
Contracts.register("learning", LearningContracts.run)
Contracts.register("persistence", SaveContracts.run)
Contracts.register("combat", CombatContracts.run)
Contracts.register("rng-persistence", RNGPersistenceContracts.run)
Contracts.register("world", WorldContracts.run)
Contracts.register("growth", GrowthContracts.run)
Contracts.register("items", ItemContracts.run)
Contracts.register("session", SessionContracts.run)
Contracts.register("capture", CaptureContracts.run)
Contracts.register("viridian-slice", SliceContracts.run)
Contracts.register("session-bridge", SessionBridgeContracts.run)
Contracts.register("party-battle", PartyBattleContracts.run)
Contracts.register("shop", ShopContracts.run)
Contracts.register("capture-animation", CaptureAnimationContracts.run)
Contracts.register("traversal", TraversalContracts.run)
Contracts.register("event-ui", EventContracts.run)
Contracts.register("event-catalog", EventCatalogContracts.run)
Contracts.register("pokedex", PokedexContracts.run)
Contracts.register("early-combat", EarlyCombatContracts.run)
Contracts.register("runtime-art", RuntimeArtContracts.run)
Contracts.register("pc-ui", PCContracts.run)
Contracts.register("evolution", EvolutionContracts.run)
Contracts.register("healing-composition", HealingCompositionContracts.run)
import "dev/trainerContracts"
Contracts.register("trainerContracts", TrainerContracts.run)
import "dev/pewterProviderContracts"
Contracts.register("pewterProviderContracts", PewterProviderContracts.run)
import "dev/pewterInstallContracts"
Contracts.register("pewterInstallContracts", PewterInstallContracts.run)
import "dev/eventReceiptContracts"
Contracts.register("eventReceiptContracts", EventReceiptContracts.run)
import "dev/battleLearningContracts"
Contracts.register("battleLearningContracts", BattleLearningContracts.run)
import "dev/battleLearningEvolutionContracts"
Contracts.register("battleLearningEvolutionContracts", BattleLearningEvolutionContracts.run)
import "dev/battleItemContracts"
Contracts.register("battle-items", BattleItemContracts.run)
import "dev/residualRewardProbe"
Contracts.register("native-condition-witness",ResidualRewardProbe.run)
import "dev/conditionCheckpointContracts"
Contracts.register("condition-checkpoints-v1",ConditionCheckpointContracts.run)
import "dev/rewardContracts"
Contracts.register("battle-rewards-v1", RewardContracts.run)
import "dev/individualContracts"
Contracts.register("individual-stats-v1", IndividualContracts.run)
import "dev/specimenContracts"
Contracts.register("specimenContracts", SpecimenContracts.run)
import "dev/specimenTrainerContracts"
Contracts.register("specimenTrainerContracts", SpecimenTrainerContracts.run)
import "dev/specimenOwnershipContracts"
Contracts.register("specimen-ownership", SpecimenOwnershipContracts.run)
import "dev/npcMotionContracts"
Contracts.register("npcMotionContracts", NPCMotionContracts.run)
import "dev/npcMotionLegacyContracts"
Contracts.register("npcMotionLegacyContracts", NPCMotionLegacyContracts.run)
import "dev/worldViewRollbackContracts"
Contracts.register("worldViewRollbackContracts", WorldViewRollbackContracts.run)
import "dev/heldItemContracts"
Contracts.register("held-items", HeldItemContracts.run)
import "dev/heldLifecycleContracts"
Contracts.register("held-lifecycle", HeldLifecycleContracts.run)
import "dev/abilityContracts"
Contracts.register("early-abilities", AbilityContracts.run)
import "dev/abilityCompatibilityContracts"
Contracts.register("ability-compatibility", AbilityCompatibilityContracts.run)
import "dev/brockMechanicsContracts"
Contracts.register("brock-mechanics", BrockMechanicsContracts.run)
import "game/townMapState"
import "game/fieldItems"
import "dev/brockMoveBatchContracts"
Contracts.register("brock-move-batch01", BrockMoveBatchContracts.run)
import "dev/brockMoveBatchErrataContracts"
Contracts.register("brock-move-batch01-errata", BrockMoveBatchErrataContracts.run)
import "dev/bideContracts"
Contracts.register("bide", BideContracts.run)
import "dev/traitContracts"
Contracts.register("specimen-sex-light-ball", TraitContracts.run)
import "dev/teachingContracts"
Contracts.register("teaching",TeachingContracts.run)
import "dev/bideTeachingContracts"
Contracts.register("bide-teaching", BideTeachingContracts.run)
import "dev/fieldItemContracts"
Contracts.register("brock-field-items",FieldItemContracts.run)
import "dev/sexAbilityContracts"
Contracts.register("sex-abilities",SexAbilityContracts.run)
import "dev/ownTempoContracts"
Contracts.register("own-tempo",OwnTempoContracts.run)
import "dev/chargeLockContracts"
Contracts.register("charge-lock",ChargeLockContracts.run)
import "dev/chargeOwnTempoContracts"
Contracts.register("charge-own-tempo",ChargeOwnTempoContracts.run)
import "dev/powerOrderContracts"
Contracts.register("basepower-order",PowerOrderContracts.run)
import "dev/rainContracts"
Contracts.register("rain",RainContracts.run)
import "dev/worrySeedContracts"
Contracts.register("worry-seed",WorrySeedContracts.run)
import "dev/brockIntegrationContracts"
Contracts.register("brock-integration",BrockIntegrationContracts.run)
import "dev/protectContracts"
Contracts.register("protect",ProtectContracts.run)
import "dev/sideContracts"
Contracts.register("sides",SideContracts.run)
import "dev/roostContracts"
Contracts.register("roost",RoostContracts.run)
import "dev/roostPredicateContracts"
Contracts.register("roost-predicates",RoostPredicateContracts.run)
import "dev/poisonFangContracts"
Contracts.register("poison-fang",PoisonFangContracts.run)
import "dev/secondaryContracts"
Contracts.register("secondaries",SecondaryContracts.run)
import "dev/titleRecoveryProbe"
Contracts.register("title-recovery-probe",TitleRecoveryProbe.run)
import "dev/titleRecoveryContracts"
Contracts.register("title-recovery",TitleRecoveryContracts.run)
import "dev/titleArchiveSafetyContracts"
Contracts.register("title-archive-safety",TitleArchiveSafetyContracts.run)
import "dev/catalog"
import "dev/pewterCatalogExporter"
PewterCatalogExporter.register()
import "dev/comprehensiveCatalogContracts"
Contracts.register("comprehensive-catalog", ComprehensiveCatalogContracts.run)
import "dev/catalogMotionContracts"
Contracts.register("catalog-motion", CatalogMotionContracts.run)
import "dev/catalogAbilityContracts"
Contracts.register("catalog-ability", CatalogAbilityContracts.run)
import "dev/presentationContracts"
Contracts.register("world-presentation", PresentationContracts.run)
import "dev/harness_build"
import "dev/harness_capture"
import "dev/diagnostics"
import "dev/fixtures"
import "dev/autopilot"
import "dev/harness"

playdate.display.setRefreshRate(30)
if not HarnessBuild.enabled then
    RulesRNG.seed(playdate.getSecondsSinceEpoch())
end

-- Shared context: root machine, camera, npc manager, player, player pokemon.
-- Global so dev tooling (autopilot, debug) can reach it.
import "game/fieldBattle"
import "game/homeRest"
import "dev/homeLeadContracts"
Contracts.register("home-lead",HomeLeadContracts.run)

import "game/itemPCState"
import "dev/itemPCContracts"
Contracts.register("red-pc-items",ItemPCContracts.run)

import "domain/fieldEncounters"
import "dev/fieldEncounterContracts"
Contracts.register("field-encounters",FieldEncounterContracts.run)

import "dev/rewardFaultGuards"
Contracts.register("reward-fault-guards",RewardFaultGuards.run)

import "dev/weatherRewardWitness"
Contracts.register("weather-reward-witness",WeatherRewardWitness.run)

game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})

local machine <const> = game.machine
machine:register("overworld", OverworldState(game))
machine:register("dialog", DialogState(game))
machine:register("battle", BattleState(game))
machine:register("debug", DebugState(game))
machine:register("learning", LearningState(game))
machine:register("evolution", EvolutionState(game))
machine:register("title", TitleState(game))
machine:register("pause", PauseState(game))
machine:register("party", PartyState(game))
machine:register("bag", BagState(game))
machine:register("shop", ShopState(game))
machine:register("event", EventState(game))
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
-- New game: the intro questline starts in Red's bedroom with Oak's
-- monologue (debug menu "Skip Intro" jumps straight to free play)
game.saves:start()

---@diagnostic disable-next-line: duplicate-set-field
local function updateGame()
    Harness.beforeFrame(game)

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
    if Harness.isQuiescent then return end
    if HarnessBuild.enabled and playdate.isSimulator then
        local ok, message = pcall(updateGame)
        Harness.afterFrame(game, not ok and tostring(message) or nil)
    else
        updateGame()
    end
end
