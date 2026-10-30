-- One service dispatcher over SourceEvents. Existing gifts/pickups stay there.
MidgameServices = {}
local CONTENT <const> = "midgameServices"
local cached
local function data()
    if not cached then
        cached = assert(json.decodeFile("data/safariServices.json"))
        assert(cached.schema == 1 and cached.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified midgame service source")
    end
    return cached
end
local function copy(value)
    return Party._primitive(value)
end
function MidgameServices.text(label)
    return {recipe = copy(assert(data().texts[label], "missing service source text")), source = "pinned Blue service text"}
end
function MidgameServices.descriptors()
    return {
        [data().gate_worker] = {kind = "bespoke", content = CONTENT, service = "safari-admission"},
        [data().info_worker] = {kind = "bespoke", content = CONTENT, service = "safari-information"},
        [data().warden] = {kind = "bespoke", content = CONTENT, service = "warden",
            observed_items = {{item = "goldTeeth"}, {item = "hm04"}},
            full = {"_WardensHouseWardenHM04NoRoomText"}}
    }
end
function MidgameServices.warden(observation)
    local prefix = "_WardensHouseWarden"
    if observation.flags.EVENT_GOT_HM04 then
        return {status = "already-complete", steps = {{op = "dialog", labels = {prefix .. "HM04ExplanationText"}}}}
    end
    local teeth = assert(observation.items.goldTeeth, "explicit Gold Teeth quantity required")
    local hm = assert(observation.items.hm04, "explicit HM04 quantity required")
    if teeth == 0 and not observation.flags.EVENT_GAVE_GOLD_TEETH then
        return {status = "ready", scene = "midgame-service", service = "warden-question", steps = {}}
    end
    local steps = {}
    local items = {}
    if teeth > 0 then
        steps[#steps + 1] = {op = "dialog", labels = {prefix .. "GaveTheGoldTeethText"}}
        -- Source removes the Teeth before GiveItem: a full bag with Teeth has
        -- room afterward. One detached session transaction makes this atomic.
        items[#items + 1] = {op = "handoff", id = "goldTeeth", quantity = 1}
    elseif not observation.can_add.hm04 then
        return {status = "bag-full", steps = {{op = "dialog",
            labels = {prefix .. "ThanksText", prefix .. "HM04NoRoomText"}}}}
    end
    steps[#steps + 1] = {op = "dialog", labels = {prefix .. "ThanksText"}}
    steps[#steps + 1] = {op = "receipt", labels = {prefix .. "ReceivedHM04Text"}}
    items[#items + 1] = {op = "add", id = "hm04", quantity = 1}
    return {status = "ready", steps = steps,
        expected = {flags = {EVENT_GOT_HM04 = false, EVENT_GAVE_GOLD_TEETH = observation.flags.EVENT_GAVE_GOLD_TEETH == true},
            items = {goldTeeth = teeth, hm04 = hm}},
        changes = {flags = {EVENT_GOT_HM04 = true, EVENT_GAVE_GOLD_TEETH = true}, items = items},
        failure_labels = {prefix .. "HM04NoRoomText"}}
end
function MidgameServices.plan(id, observation)
    if id == data().warden then
        return MidgameServices.warden(observation)
    end
    local descriptor = assert(MidgameServices.descriptors()[id], "unsupported midgame service")
    return {status = "ready", scene = "midgame-service", service = descriptor.service, steps = {}}
end
function MidgameServices.install()
    local descriptors = MidgameServices.descriptors()
    for id in pairs(descriptors) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate midgame service identity")
    end
    for id in pairs(descriptors) do
        local stableID = id
        SourceEventHandlers[id] = function(observation)
            return MidgameServices.plan(stableID, observation)
        end
    end
    SourceEvents.registerEventSource(CONTENT, descriptors)
    SourceEvents.registerTextSource(CONTENT, MidgameServices.text)
    -- HM03 and Gold Teeth already belong to the installed source package.
    assert(SourceEvents.has(data().existing_surf_gift) and SourceEvents.has(data().existing_teeth_pickup),
        "installed Safari source rewards required")
end
-- This hook only claims the entrance script's exact trigger cells. Root's
-- return lifecycle calls the same gate event after an ending battle/step.
function MidgameServices.checkEntrance(game)
    if not currentZone or currentZone.stableID ~= data().gate or game.player.isMoving
        or game.machine:getCurrent() ~= "overworld" or game.machine:depth() ~= 1 then
        return false
    end
    if type(game.session.safariData) ~= "function" then
        return false
    end
    local state = game.session:safariData()
    if state.active then
        return false
    end
    local entry = SourceMaps.entry("SafariZoneGate")
    local x, y = game.player.gridX - entry.padding, game.player.gridY
    if y == 2 and (x == 3 or x == 4) then
        return SourceEvents.dispatch(game, data().gate_worker, {mode = "sight"})
    end
    return false
end
