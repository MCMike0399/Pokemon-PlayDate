-- Composition only: source owners retain their plans, transactions and leases.
-- Import after EventState; install after ordinary Cerulean content registration.
import "game/ceruleanStory"
import "game/ceruleanRoutes"
import "game/ceruleanRoutesState"
import "game/tutorialEscort"
KantoScenes = {}
local installed = false
local BILL <const> = "pokered:BILLS_HOUSE:objects:"
local NERD <const> = "pokered:MT_MOON_B2F:objects:1"
local GUIDE <const> = "pokered:PEWTER_CITY:objects:5"
local PC <const> = "pokered:BILLS_HOUSE:hidden_events:1"
local storyZones = { ["pokered:BILLS_HOUSE"]=true, ["pokered:MT_MOON_B2F"]=true }

-- Root folds this into its one content resolver. A nil context means immutable
-- validation/catalog metadata; only an explicit runtime context sees receipts.
function KantoScenes.actorMetadata(definition, event, game)
    local result = {visibility={}}
    for _, metadata in ipairs({CeruleanStory.actorMetadata(event.id), CeruleanRoutes.actorMetadata(event.id,game)}) do
        for _, condition in ipairs(metadata.visibility or {}) do
            result.visibility[#result.visibility+1] = Party._primitive(condition)
        end
    end
    return result
end

-- Both scene entry points share the same runtime-aware pose reconciliation.
KantoScenes.reconcileActors = CeruleanStory.reconcileActors

function KantoScenes.install()
    assert(not installed, "Kanto scenes already installed")
    -- Qualified owners declare membership here. World callbacks remain cheap
    -- boot wiring; they do not imply that scene/text data has been prepared.
    CeruleanStory.install({reconcileActors=KantoScenes.reconcileActors})
    GameBootstrap.yieldIfDue()
    CeruleanRoutes.install({reconcileActors=KantoScenes.reconcileActors})
    GameBootstrap.yieldIfDue()
    SourceEvents.registerWorldHooks(CeruleanRoutes.ROUTE, {
        beforeSpawn=function(game, context)
            local before = game.session:flags().quest
            assert(CeruleanRoutes.initialize(game.session))
            local after = game.session:flags().quest
            -- Only the explicit old-save migration changes actor membership.
            if currentZone.stableID == "pokered:ROUTE_22" and context.actors
                and (before.EVENT_1ST_ROUTE22_RIVAL_BATTLE ~= after.EVENT_1ST_ROUTE22_RIVAL_BATTLE
                    or before.EVENT_ROUTE22_RIVAL_WANTS_BATTLE ~= after.EVENT_ROUTE22_RIVAL_WANTS_BATTLE) then
                context.reconcile = true
            end
            SourceActors.refresh(game,currentZone)
        end,
        explore=CeruleanRoutes.check,
    })
    SourceEvents.registerWorldHooks(BILL.."1", {
        onEnter=function(game)
            if storyZones[currentZone.stableID] then KantoScenes.reconcileActors(game) end
        end,
        onLeave=function(game, destination)
            if currentZone.stableID == "pokered:BILLS_HOUSE" and destination == "pokered:ROUTE_25" then
                assert(CeruleanStory.onHouseExit(game.session))
            end
        end,
    })
    SourceEvents.registerWorldHooks(PC, {
        interact=function(game)
            local p = game.player
            local id = CeruleanStory.pcInteraction(currentZone.stableID,p.gridX,p.gridY,p.facing)
            return id and SourceEvents.dispatch(game,id) or false
        end,
    })
    SourceEvents.registerWorldHooks(NERD, {
        explore=function(game)
            local p = game.player
            local id = CeruleanStory.trigger(game.session,currentZone.stableID,p.gridX,p.gridY)
            return id and SourceEvents.dispatch(game,id) or false
        end,
        suppressEncounters=function(game)
            local p = game.player
            return CeruleanStory.suppressEncounters(game.session,currentZone.stableID,p.gridX,p.gridY)
        end,
    })
    SourceEvents.registerWorldHooks(GUIDE, {actorPositions=TutorialEscortData.actorPositions,
        explore=function(game)
            local id = TutorialEscort.trigger(game)
            return id and TutorialEscort.dispatch(game,id) or false
        end,
        interact=TutorialEscort.tryInteract,
    })
    installed = true
end
