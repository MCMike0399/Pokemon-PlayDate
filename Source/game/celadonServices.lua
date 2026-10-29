import "game/celadonServiceData"
import "game/celadonEconomy"
import "game/celadonSlots"
import "domain/coinWallet"
-- SourceEvents remains the sole dispatcher. Root composes the controller into
-- its existing MidgameServicesState chain; ordinary department clerks stay put.
CeladonServices = {}
local CONTENT <const> = "celadonServices"
CeladonServices.GIRL = "pokered:CELADON_MART_ROOF:objects:2"
CeladonServices.SELLER = "pokered:GAME_CORNER:objects:2"
CeladonServices.LIFT = "pokered:CELADON_MART_ELEVATOR:background_events:1"
CeladonServices.EEVEE = "pokered:CELADON_MANSION_ROOF_HOUSE:objects:2"
local installed
function CeladonServices.coinGift(id)
    return CeladonServices.policy().coin_gifts[id]
end
function CeladonServices.policy()
    return CeladonServiceData.policy()
end
function CeladonServices.text(label)
    return CeladonServiceData.text(label)
end
function CeladonServices.descriptors(content)
    content = content or CONTENT
    local events = {
        [CeladonServices.GIRL] = {kind="bespoke", content=content, service="drink-girl"},
        [CeladonServices.SELLER] = {kind="bespoke", content=content, service="coin-exchange"},
        [CeladonServices.EEVEE] = {kind="bespoke", content=content, service="eevee"},
        ["pokered:GAME_CORNER:objects:7"] = {kind="cases", content=content,
            cases={{when={flags={EVENT_BEAT_ERIKA=true}}, ["then"]={kind="program",steps={
                {op="dialog",labels={"_GameCornerGymGuideTheyOfferRarePokemonText"}}}}}},
            otherwise={kind="program",steps={{op="dialog",labels={"_GameCornerGymGuideChampInMakingText"}}}}},
    }
    local observed = {{item="coinCase"}}
    for _, drink in ipairs(CeladonServices.policy().drinks) do
        observed[#observed+1] = {item=drink.item}
        observed[#observed+1] = {item=drink.tm}
    end
    events[CeladonServices.GIRL].observed_items = observed
    for index = 1, 3 do
        events["pokered:CELADON_MART_ROOF:background_events:" .. index] = {kind="bespoke",content=content,service="vending"}
    end
    for id in pairs(CeladonServices.policy().coin_gifts) do
        events[id] = {kind="bespoke",content=content,service="coin-gift",item="coinCase"}
    end
    events[CeladonServices.SELLER].item = "coinCase"
    events[CeladonServices.LIFT] = {kind="bespoke",content=content,service="elevator"}
    for index = 1,3 do
        events["pokered:GAME_CORNER_PRIZE_ROOM:background_events:" .. index] =
            {kind="bespoke",content=content,service="prize",window=index,item="coinCase"}
    end
    for _, machine in ipairs(CeladonServices.policy().machines) do
        if machine.condition == "ANY_FACING" then
            events[machine.id] = {kind="bespoke",content=content,service="slots",item="coinCase"}
        else
            local labels = {SLOTS_SOMEONESKEYS="_GameCornerSomeonesKeysText",
                SLOTS_OUTTOLUNCH="_GameCornerOutToLunchText",SLOTS_OUTOFORDER="_GameCornerOutOfOrderText"}
            events[machine.id] = {kind="program",content=content,steps={
                {op="dialog",labels={assert(labels[machine.condition])}}}}
        end
    end
    for _, hidden in ipairs(CeladonServices.policy().hidden_coins) do
        if hidden.shadowed_by_slot then
            events[hidden.id] = {kind="program",content=content,steps={}}
        else
            events[hidden.id] = {kind="bespoke",content=content,service="hidden-coins",item="coinCase"}
        end
    end
    return events
end
function CeladonServices.plan(id)
    local descriptor = assert(SourceEvents.descriptor(id), "registered Celadon service required")
    return {status="ready",scene="celadon-service",service=descriptor.service,window=descriptor.window,steps={}}
end
function CeladonServices.actorMetadata(id)
    if id == CeladonServices.EEVEE then
        return {visibility={{group="quest",id=CeladonServices.policy().eevee.flag,equals=false}}}
    end
    return {}
end
function CeladonServices.install(options)
    assert(not installed, "Celadon services already installed")
    options = options or {}
    assert(type(options.reconcileActors) == "function", "existing actor reconciler required")
    installed = options
    local events = CeladonServices.descriptors(options.content)
    local fresh = {}
    for id, descriptor in pairs(events) do
        if not SourceEvents.has(id) then
            fresh[id] = descriptor
        else
            assert(SourceEvents.descriptor(id).content == descriptor.content, "Celadon content ownership conflict")
        end
        if descriptor.kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate Celadon service handler")
            local stableID = id
            SourceEventHandlers[id] = function() return CeladonServices.plan(stableID) end
        end
    end
    if next(fresh) then
        assert(not options.content or options.content == CONTENT, "merge custom content descriptors before install")
        SourceEvents.registerEventSource(CONTENT, fresh)
    end
    if not options.content or options.content == CONTENT then
        SourceEvents.registerTextSource(CONTENT, CeladonServices.text)
    end
    SourceEvents.registerWorldHooks(CeladonServices.LIFT, {
        interact=CeladonServices.tryHidden,
        onEnter=function(game, context)
            -- Blue sets CUR_MAP_LOADED_2 after battles as well as map entry.
            if currentZone.stableID == "pokered:GAME_CORNER" and type(game.session.enterCeladonCorner) == "function" then
                local accepted, reason = game.session:enterCeladonCorner(game.session:fieldWorldEpoch())
                assert(accepted,reason)
            end
        end,
        onLeave=function(game,destination)
            if destination == "pokered:CELADON_MART_ELEVATOR" then
                for _, entry in ipairs(CeladonServices.policy().elevator) do
                    if currentZone.stableID == entry.map_id then
                        assert(CeladonServices.selectFloor(game.session,entry.floor))
                        return
                    end
                end
                error("source Celadon elevator origin required")
            end
        end,
    })
end
function CeladonServices.reconcileActors(game)
    return assert(installed).reconcileActors(game)
end

function CeladonServices.machine(id)
    for _, machine in ipairs(CeladonServices.policy().machines) do
        if machine.id == id then return machine end
    end
end
function CeladonServices.hiddenCoin(id)
    for _, hidden in ipairs(CeladonServices.policy().hidden_coins) do
        if hidden.id == id then return hidden end
    end
end
function CeladonServices.tryHidden(game)
    if currentZone.stableID ~= "pokered:GAME_CORNER" then return false end
    local x,y = game.player:getFacingTile()
    for _, machine in ipairs(CeladonServices.policy().machines) do
        if x == machine.x and y == machine.y then
            if machine.condition == "ANY_FACING" and game.player.facing ~= "left" and game.player.facing ~= "right" then
                return true
            end
            return SourceEvents.dispatch(game,machine.id)
        end
    end
    for _, hidden in ipairs(CeladonServices.policy().hidden_coins) do
        if x == hidden.x and y == hidden.y then
            if game.session:inventory():quantity("coinCase") == 0 or game.session:questFlag(hidden.flag) then return true end
            return SourceEvents.dispatch(game,hidden.id)
        end
    end
    return false
end
local function floorFlag(floor)
    return "CELADON_SERVICES_LIFT_V1_" .. floor
end
function CeladonServices.selectFloor(session, floor)
    assert(Party._integer(floor,1,5),"source Celadon floor required")
    local expected, changes = {flags={},items={}}, {flags={},items={}}
    for index = 1,5 do
        expected.flags[floorFlag(index)] = session:questFlag(floorFlag(index))
        changes.flags[floorFlag(index)] = index == floor
    end
    if expected.flags[floorFlag(floor)] then return true end
    return session:transact(expected,changes)
end
function CeladonServices.elevatorBindings(session)
    local result = {}
    local cabin = "pokered:CELADON_MART_ELEVATOR"
    local padding = SourceMaps.entry("CeladonMartElevator").padding
    local selected
    for _, entry in ipairs(CeladonServices.policy().elevator) do
        local id = entry.map_id .. ":warps:" .. (entry.source_warp_byte+1)
        result[id] = {status="bound",source_event_id=id,to=cabin,toX=1+padding,toY=3,
            preserveFacing=true,source_target_warp=1}
        if session and session:questFlag(floorFlag(entry.floor)) then selected = entry end
    end
    if selected then
        for index = 1,2 do
            local id = cabin .. ":warps:" .. index
            result[id] = {status="bound",source_event_id=id,to=selected.map_id,
                toX=selected.x+SourceMaps.entry("CeladonMart"..selected.floor.."F").padding,toY=selected.y,
                preserveFacing=true,source_target_warp=selected.source_warp_byte+1}
        end
    end
    return result
end
