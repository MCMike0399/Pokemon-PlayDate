-- Stable-ID boundaries use the existing single SourceEvents dispatcher.
local CITY <const> = "pokered:VERMILION_CITY"
local GYM <const> = "pokered:VERMILION_GYM"
local ANNE <const> = "pokered:SS_ANNE_2F"
local DOCK <const> = "pokered:VERMILION_DOCK"
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"
function VermilionStory.departureExit(game, destination, door)
    local p = game.player
    if currentZone.stableID ~= "pokered:SS_ANNE_1F" or destination ~= DOCK
        or not game.session:questFlag("EVENT_GOT_HM01") or game.session:questFlag("EVENT_SS_ANNE_LEFT") then return false end
    -- Both source exit cells share dock warp #2. The root supplies the exact
    -- completed DoorWarp descriptor; a battle/Continue/other map load cannot
    -- manufacture this intent merely by being on the dock with HM01.
    return door and p.gridY == 0 and (p.gridX == 26 or p.gridX == 27)
        and (door.source_event_id == "pokered:SS_ANNE_1F:warps:1" or door.source_event_id == "pokered:SS_ANNE_1F:warps:2")
        and door.toX == 14 + VermilionStory.padding(DOCK) and (door.toY == 2 or door.toY == 3)
end
function VermilionStory.allowDoor(game, door)
    local provider = WorldDeltas.definitionProvider()
    local target = provider and provider:hasKey(door.to) and provider:descriptor(door.to).id or door.to
    if target == DOCK and currentZone.stableID == CITY then
        return not game.session:questFlag("EVENT_SS_ANNE_LEFT") and game.session:inventory():quantity("ssTicket") > 0
    end
    if currentZone.stableID == DOCK and target == "pokered:SS_ANNE_1F" then
        return not game.session:questFlag("EVENT_SS_ANNE_LEFT")
    end
    return true
end
function VermilionStory.check(game)
    local p, session = game.player,game.session
    if currentZone.stableID == CITY then
        if session:questFlag("EVENT_SS_ANNE_LEFT") and session:questFlag("EVENT_WALKED_OUT_OF_DOCK")
            and not session:questFlag("EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT")
            and p.gridX==18+VermilionStory.padding(CITY) and p.gridY==31 then
            return SourceEvents.dispatch(game,VermilionStory.GUARD)
        end
        local t = VermilionStory.scenes().boarding
        if p.stepJustFinished and p.gridX == t.x + VermilionStory.padding(CITY) and p.gridY == t.y and p.facing == t.facing then
            return SourceEvents.dispatch(game,t.id)
        end
    elseif currentZone.stableID == ANNE and not session:trainerDefeated(VermilionStory.RIVAL) then
        if VermilionStory.variant(p.gridX-VermilionStory.padding(ANNE),p.gridY) then
            if not session:questFlag("VERMILION_SCENE_V1_RIVAL_SHOWN") then
                assert(session:transact({flags={VERMILION_SCENE_V1_RIVAL_SHOWN=false},
                    trainers={[VermilionStory.RIVAL]=false},items={}},
                    {flags={VERMILION_SCENE_V1_RIVAL_SHOWN=true},items={}}))
                VermilionStory.reconcileActors(game)
            end
            return SourceEvents.dispatch(game,VermilionStory.RIVAL)
        end
    elseif currentZone.stableID == DOCK and session:questFlag(PENDING) then
        return SourceEvents.dispatch(game,VermilionStory.DOCK)
    end
    return false
end
function VermilionStory.tryTrash(game)
    if currentZone.stableID ~= GYM then return false end
    local x,y = game.player:getFacingTile()
    x = x - VermilionStory.padding(GYM)
    for _, can in ipairs(VermilionStory.scenes().trash.cans) do
        if x == can.x and y == can.y then return SourceEvents.dispatch(game,can.id) end
    end
    return false
end
function VermilionStory.installHooks()
    SourceEvents.registerWorldHooks(VermilionStory.RIVAL,{
        beforeSpawn=function(game, context)
            if currentZone.stableID == ANNE then
                -- The content owner merges actorMetadata into its resolver.
                -- No actor coordinates or visibility are written here.
                SourceActors.refresh(game,currentZone)
                context.reconcile = true
            end
        end,
        explore=VermilionStory.check,
    })
    SourceEvents.registerWorldHooks(VermilionStory.SURGE,{
        beforeSpawn=VermilionStory.reconcileWorld,
        onEnter=function(game, options)
            -- Pinned Blue resets the FIRST INDEX on city load, not Gym entry.
            -- First/second lock flags survive re-entry; Continue consumes no RNG.
            if currentZone.stableID == CITY and options and options.fromDoor then
                local ok,reason = VermilionStory.commitIntent(game,"entry")
                assert(ok or reason=="already-complete",reason)
            end
        end,
        interact=VermilionStory.tryTrash,
    })
    SourceEvents.registerWorldHooks(VermilionStory.DOCK,{
        onLeave=function(game, destination, door)
            if currentZone.stableID==DOCK and destination==CITY and game.session:questFlag(PENDING)
                and game.session:questFlag("EVENT_SS_ANNE_LEFT") then
                assert(game.session:transact({flags={[PENDING]=true,EVENT_WALKED_OUT_OF_DOCK=false},items={}},
                    {flags={[PENDING]=false,EVENT_WALKED_OUT_OF_DOCK=true},items={}}))
            end
            if VermilionStory.departureExit(game,destination,door) and not game.session:questFlag(PENDING) then
                local ok,reason = game.session:transact({flags={EVENT_GOT_HM01=true,EVENT_SS_ANNE_LEFT=false,[PENDING]=false},items={}},
                    {flags={[PENDING]=true},items={}})
                assert(ok,reason)
            end
        end,
    })
end
