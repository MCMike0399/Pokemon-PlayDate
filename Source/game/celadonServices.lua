import "game/celadonServiceData"
import "game/celadonEconomy"
-- SourceEvents remains the sole dispatcher. Root composes the controller into
-- its existing MidgameServicesState chain; ordinary department clerks stay put.
CeladonServices = {}
local CONTENT <const> = "celadonServices"
CeladonServices.GIRL = "pokered:CELADON_MART_ROOF:objects:2"
CeladonServices.SELLER = "pokered:GAME_CORNER:objects:2"
CeladonServices.EEVEE = "pokered:CELADON_MANSION_ROOF_HOUSE:objects:2"
local installed
local gifts <const> = {
    ["pokered:GAME_CORNER:objects:5"] = {coins=10, flag="EVENT_GOT_10_COINS", prefix="_GameCornerFishingGuru",
        before="WantToPlayText", after="WinsComeAndGoText", full="DontNeedMyCoinsText", received="Received10CoinsText"},
    ["pokered:GAME_CORNER:objects:9"] = {coins=20, flag="EVENT_GOT_20_COINS_2", prefix="_GameCornerClerk2",
        before="WantSomeCoinsText", after="INeedMoreCoinsText", full="YouHaveLotsOfCoinsText", received="Received20CoinsText"},
    ["pokered:GAME_CORNER:objects:10"] = {coins=20, flag="EVENT_GOT_20_COINS", prefix="_GameCornerGentleman",
        before="ThrowingMeOffText", after="CloselyWatchTheReelsText", full="YouGotYourOwnCoinsText",
        received="Received20CoinsText", exact_full=true},
}
function CeladonServices.coinGift(id)
    return gifts[id] and GameSession._copy(gifts[id]) or nil
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
    for id in pairs(gifts) do
        events[id] = {kind="bespoke",content=content,service="coin-gift",item="coinCase"}
    end
    events[CeladonServices.SELLER].item = "coinCase"
    return events
end
function CeladonServices.plan(id)
    local descriptor = assert(SourceEvents.descriptor(id), "registered Celadon service required")
    return {status="ready",scene="celadon-service",service=descriptor.service,steps={}}
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
end
function CeladonServices.reconcileActors(game)
    return assert(installed).reconcileActors(game)
end
