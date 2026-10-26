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

-- Rebuild through the source spawner and existing motion owner. Reconciliation
-- preserves ordinary actors' full saved values, including their random timers.
function KantoScenes.reconcileActors(game)
    local zone = currentZone
    local descriptor = SourceActors.describe(zone.stableID,WorldDeltas.export(),game)
    if not descriptor then return end
    local flags = game.session:flags()
    local payload = WorldMotionData.reconcile(game.npcManager.motion:snapshot(),descriptor,flags)
    local poses = {}
    if zone.stableID == "pokered:MT_MOON_B2F" then
        if flags.quest.EVENT_GOT_DOME_FOSSIL then poses[NERD]={x=13,y=7,facing="up"}
        elseif flags.quest.EVENT_GOT_HELIX_FOSSIL then poses[NERD]={x=12,y=7,facing="up"} end
    elseif zone.stableID == "pokered:BILLS_HOUSE" and flags.quest.EVENT_USED_CELL_SEPARATOR_ON_BILL then
        poses[BILL.."2"] = flags.quest.EVENT_MET_BILL and {x=4,y=4,facing="down"} or {x=1,y=2,facing="down"}
    end
    local padding = SourceMaps.entry(assert(SourceMaps.nameForID(zone.stableID))).padding
    for _, value in ipairs(payload.actors) do
        local pose = poses[value.id]
        if pose then
            value.x,value.y,value.facing = pose.x+padding,pose.y,pose.facing
            value.origin_x,value.target_x,value.origin_y,value.target_y = value.x,value.x,value.y,value.y
            value.phase,value.tick,value.delay_raw,value.delay_left = value.phase=="static" and "static" or "ready",0,0,0
        end
    end
    SourceActors.refresh(game,zone)
    zone:spawnNPCs(game.npcManager)
    game.npcManager.motion:attach(game,zone,payload)
end

function KantoScenes.install()
    assert(not installed, "Kanto scenes already installed")
    CeruleanStory.install({reconcileActors=KantoScenes.reconcileActors})
    CeruleanRoutes.install({reconcileActors=KantoScenes.reconcileActors})
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
