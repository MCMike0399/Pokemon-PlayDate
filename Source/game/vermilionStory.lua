-- Pinned bespoke Blue plans. Session/TrainerEvents/NPCMotion retain ownership.
VermilionStory = {}
local CONTENT <const> = "vermilionStory"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
VermilionStory.RIVAL = "pokered:SS_ANNE_2F:objects:2"
VermilionStory.CAPTAIN = "pokered:SS_ANNE_CAPTAINS_ROOM:objects:1"
VermilionStory.GUARD = "pokered:VERMILION_CITY:objects:3"
VermilionStory.SURGE = "pokered:VERMILION_GYM:objects:1"
VermilionStory.DOCK = "pokered:VERMILION_DOCK:hidden_events:1"
local cached, integration = {}, nil
local function copy(v) return GameSession._copy(v) end
local function data(name)
    if not cached[name] then
        local value = assert(json.decodeFile("data/vermilionStory/" .. name .. ".json"))
        assert(value.schema == 1 and value.source_revision == REVISION,"unverified Vermilion scene data")
        cached[name] = value
    end
    return cached[name]
end
function VermilionStory.scenes() return copy(data("scenes").scenes) end
function VermilionStory.trainers() return copy(data("trainers").trainers) end
function VermilionStory.text(label) return copy(assert(data("dialogue").texts[label],"missing Vermilion source text")) end
function VermilionStory.padding(zoneID)
    return SourceMaps.entry(assert(SourceMaps.nameForID(zoneID))).padding
end
function VermilionStory.descriptors()
    local events = copy(data("events").events)
    for id, d in pairs(events) do
        for _, p in ipairs(d.script_positions or {}) do
            p.x = p.x + VermilionStory.padding("pokered:" .. id:match("^pokered:([^:]+):"))
        end
    end
    return events
end
function VermilionStory.variant(x,y)
    for _, v in ipairs(data("scenes").scenes.rival.variants) do
        if v.trigger.x == x and v.trigger.y == y then return copy(v) end
    end
end
function VermilionStory.plan(id, state)
    local d = assert(data("events").events[id],"unsupported Vermilion scene")
    if id == VermilionStory.GUARD and state.flags.EVENT_SS_ANNE_LEFT and state.flags.EVENT_WALKED_OUT_OF_DOCK
        and not state.flags.EVENT_WALKED_PAST_GUARD_AFTER_SS_ANNE_LEFT then
        return {status="ready",scene="vermilion-story",scene_script="city-exit",steps={}}
    end
    if id == VermilionStory.SURGE then
        local plan = SourceEvents.compile(copy(d), state, id)
        plan.ram = plan.ram or {}
        plan.ram.wStringBuffer = ItemData.definitions.tm24.name
        return plan
    end
    if id == VermilionStory.RIVAL then
        if state.receipt then
            assert(state.receipt.id == id and state.receipt.won and state.trainers[id],"unconfirmed Anne rival receipt")
            return {status="ready",scene="vermilion-story",scene_script="rival-exit",steps={},
                ram={wAmountMoneyWon=state.receipt.payout}}
        end
        if state.trainers[id] then return {status="already-complete",steps={}} end
    end
    return {status="ready",scene="vermilion-story",scene_script=d.scene_script,steps={}}
end
function VermilionStory.captainReward(session)
    if session:questFlag("EVENT_GOT_HM01") then return nil,"already-complete" end
    return {expected={flags={EVENT_GOT_HM01=false,EVENT_RUBBED_CAPTAINS_BACK=true},
                items={hm01=session:inventory():quantity("hm01")}},
            changes={flags={EVENT_GOT_HM01=true},items={{op="add",id="hm01",quantity=1}}}}
end
function VermilionStory.actorMetadata(id, game)
    if id ~= VermilionStory.RIVAL then return {} end
    if game and game.trainers and game.trainers:peekReceipt(id) then return {} end
    return {visibility={{group="trainers",id=id,equals=false},
        {group="quest",id="VERMILION_SCENE_V1_RIVAL_SHOWN",equals=true}}}
end
function VermilionStory.reconcileActors(game)
    return assert(integration,"Vermilion scene integration missing").reconcileActors(game)
end
-- Pure source terrain projection supplied by the content owner. It must return
-- a complete detached WorldDeltas payload, never call setTile/apply/register.
function VermilionStory.projectWorld(world, effect)
    if not effect then return copy(world) end
    return assert(integration,"Vermilion scene integration missing").projectWorld(copy(world),effect)
end
function VermilionStory.install(options)
    assert(not integration,"Vermilion scenes already installed")
    options = options or {}
    options.projectWorld = options.projectWorld or VermilionStory.sourceWorld
    assert(type(options.projectWorld)=="function" and type(options.reconcileActors)=="function",
        "root atomic terrain projection and actor reconciliation required")
    local events = VermilionStory.descriptors()
    for id in pairs(events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id],"duplicate Vermilion event ownership")
    end
    integration = options
    for id,d in pairs(events) do
        if d.kind == "bespoke" then
            local stableID = id
            SourceEventHandlers[id] = function(state) return VermilionStory.plan(stableID,state) end
        end
    end
    SourceEvents.registerEventSource(CONTENT,events)
    SourceEvents.registerTextSource(CONTENT,VermilionStory.text)
    -- The two scene trainers are not ordinary content. Existing immutable
    -- trainer definitions and opaque encounter tokens freeze all three teams.
    SourceEvents.registerTrainerSource(CONTENT,VermilionStory.trainers)
    VermilionStory.installHooks()
end
