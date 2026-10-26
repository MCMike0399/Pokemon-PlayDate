-- Private staged entry-point overlay; never compiled in production.

-- @harness imports-1
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

-- @harness imports-2
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
import "dev/harness_capture"
import "dev/diagnostics"
import "dev/fixtures"
import "dev/autopilot"
import "dev/harness"

-- @harness imports-3
import "dev/homeLeadContracts"
Contracts.register("home-lead",HomeLeadContracts.run)

-- @harness imports-4
import "dev/itemPCContracts"
Contracts.register("red-pc-items",ItemPCContracts.run)

-- @harness imports-5
import "dev/fieldEncounterContracts"
Contracts.register("field-encounters",FieldEncounterContracts.run)

-- @harness imports-6
import "dev/rewardFaultGuards"
Contracts.register("reward-fault-guards",RewardFaultGuards.run)

-- @harness imports-7
import "dev/weatherRewardWitness"
Contracts.register("weather-reward-witness",WeatherRewardWitness.run)


import "dev/whirlwindContracts"
Contracts.register("whirlwind", WhirlwindContracts.run)
import "dev/moveFailureContracts"
Contracts.register("move-failure", MoveFailureContracts.run)
import "dev/sourceMapContracts"
Contracts.register("source-maps", SourceMapContracts.run)

import "dev/sourceEventContracts"
Contracts.register("source-events",SourceEventContracts.run)
import "dev/sourceTextContracts"
Contracts.register("source-text", SourceTextContracts.run)

import "dev/scriptedNPCContracts"
Contracts.register("scripted-npc", ScriptedNPCContracts.run)

import "dev/genericActorContracts"
Contracts.register("generic-actors", GenericActorContracts.run)

-- @harness runtime
harness = Harness
