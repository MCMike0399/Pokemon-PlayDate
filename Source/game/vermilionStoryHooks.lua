-- Stable-ID boundaries use the existing single SourceEvents dispatcher.
local CITY <const> = "pokered:VERMILION_CITY"
local GYM <const> = "pokered:VERMILION_GYM"
local ANNE <const> = "pokered:SS_ANNE_2F"
local DOCK <const> = "pokered:VERMILION_DOCK"
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"

function VermilionStory.departureExit(game, destination, door)
    local player <const> = game.player
    if currentZone.stableID ~= "pokered:SS_ANNE_1F" or destination ~= DOCK
        or not game.session:questFlag("EVENT_GOT_HM01")
        or game.session:questFlag("EVENT_SS_ANNE_LEFT") then
        return false
    end
    -- Both source exit cells share dock warp #2. A battle, Continue or other
    -- map load cannot manufacture this actual completed DoorWarp descriptor.
    return door and player.gridY == 0 and (player.gridX == 26 or player.gridX == 27)
        and (door.source_event_id == "pokered:SS_ANNE_1F:warps:1"
            or door.source_event_id == "pokered:SS_ANNE_1F:warps:2")
        and door.toX == 14 + VermilionStory.padding(DOCK)
        and (door.toY == 2 or door.toY == 3)
end

function VermilionStory.allowDoor(game, door)
    local provider <const> = WorldDeltas.definitionProvider()
    local target <const> = provider and provider:hasKey(door.to)
        and provider:descriptor(door.to).id or door.to
    if target == DOCK and currentZone.stableID == CITY then
        return not game.session:questFlag("EVENT_SS_ANNE_LEFT")
            and game.session:inventory():quantity("ssTicket") > 0
    end
    if currentZone.stableID == DOCK and target == "pokered:SS_ANNE_1F" then
        return not game.session:questFlag("EVENT_SS_ANNE_LEFT")
    end
    return true
end

function VermilionStory.check(game)
    local player <const> = game.player
    local session <const> = game.session
    if currentZone.stableID == CITY then
        if session:questFlag("EVENT_SS_ANNE_LEFT")
            and session:questFlag("EVENT_WALKED_OUT_OF_DOCK")
            and not session:questFlag("EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT")
            and player.gridX == 18 + VermilionStory.padding(CITY) and player.gridY == 31 then
            return SourceEvents.dispatch(game, VermilionStory.GUARD)
        end
        local trigger <const> = VermilionStory.scenes().boarding
        if player.stepJustFinished and player.gridX == trigger.x + VermilionStory.padding(CITY)
            and player.gridY == trigger.y and player.facing == trigger.facing then
            return SourceEvents.dispatch(game, trigger.id)
        end
    elseif currentZone.stableID == ANNE and not session:trainerDefeated(VermilionStory.RIVAL) then
        if VermilionStory.variant(player.gridX - VermilionStory.padding(ANNE), player.gridY) then
            if not session:questFlag("VERMILION_SCENE_V1_RIVAL_SHOWN") then
                local expected <const> = {
                    flags = {VERMILION_SCENE_V1_RIVAL_SHOWN = false},
                    trainers = {[VermilionStory.RIVAL] = false},
                    items = {},
                }
                local changes <const> = {
                    flags = {VERMILION_SCENE_V1_RIVAL_SHOWN = true},
                    items = {},
                }
                assert(session:transact(expected, changes))
                VermilionStory.reconcileActors(game)
            end
            return SourceEvents.dispatch(game, VermilionStory.RIVAL)
        end
    elseif currentZone.stableID == DOCK and session:questFlag(PENDING) then
        return SourceEvents.dispatch(game, VermilionStory.DOCK)
    end
    return false
end

function VermilionStory.tryTrash(game)
    if currentZone.stableID ~= GYM then
        return false
    end
    local x, y = game.player:getFacingTile()
    x = x - VermilionStory.padding(GYM)
    for _, can in ipairs(VermilionStory.scenes().trash.cans) do
        if x == can.x and y == can.y then
            return SourceEvents.dispatch(game, can.id)
        end
    end
    return false
end

function VermilionStory.installHooks()
    SourceEvents.registerWorldHooks(VermilionStory.RIVAL, {
        beforeSpawn = function(game, context)
            VermilionShip.beforeSpawn(game)
            if currentZone.stableID == ANNE then
                -- The content owner merges actorMetadata into its resolver.
                -- Actor coordinates and visibility remain in their owners.
                SourceActors.refresh(game, currentZone)
                context.reconcile = true
            end
        end,
        explore = VermilionStory.check,
    })
    SourceEvents.registerWorldHooks(VermilionStory.SURGE, {
        beforeSpawn = VermilionStory.reconcileWorld,
        onEnter = function(game, options)
            -- Blue samples the first index on city load, not Gym entry.
            -- First/second lock flags survive; Continue consumes no RNG.
            if currentZone.stableID == CITY and options and options.fromDoor then
                local ok, reason = VermilionStory.commitIntent(game, "entry")
                assert(ok or reason == "already-complete", reason)
            end
        end,
        interact = VermilionStory.tryTrash,
    })
    SourceEvents.registerWorldHooks(VermilionStory.DOCK, {
        onLeave = function(game, destination, door)
            if currentZone.stableID == DOCK and destination == CITY
                and game.session:questFlag(PENDING)
                and game.session:questFlag("EVENT_SS_ANNE_LEFT") then
                local expected <const> = {
                    flags = {[PENDING] = true, EVENT_WALKED_OUT_OF_DOCK = false},
                    items = {},
                }
                local changes <const> = {
                    flags = {[PENDING] = false, EVENT_WALKED_OUT_OF_DOCK = true},
                    items = {},
                }
                assert(game.session:transact(expected, changes))
            end
            if VermilionStory.departureExit(game, destination, door)
                and not game.session:questFlag(PENDING) then
                local expected <const> = {
                    flags = {EVENT_GOT_HM01 = true, EVENT_SS_ANNE_LEFT = false, [PENDING] = false},
                    items = {},
                }
                local changes <const> = {
                    flags = {[PENDING] = true},
                    items = {},
                }
                local ok, reason = game.session:transact(expected, changes)
                assert(ok, reason)
            end
            VermilionShip.onLeave(game, destination)
        end,
    })
end
