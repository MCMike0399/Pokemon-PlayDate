-- Field Poké Flute intent and source plans. Existing bag/session/battle owners
-- perform use, construction, capture and confirmed terminal transactions.
SnorlaxStory = {}
local function copy(value)
    return GameSession._copy(value)
end
function SnorlaxStory.definition(id)
    for _, definition in ipairs(TowerStory.scenes().snorlax) do
        if definition.id == id then
            return definition
        end
    end
end
function SnorlaxStory.descriptors(content)
    local result = {}
    for _, definition in ipairs(TowerStory.scenes().snorlax) do
        result[definition.id] = {kind = "bespoke", content = content, item = "pokeFlute"}
    end
    return result
end
function SnorlaxStory.actorMetadata(id)
    if id ~= "pokered:ROUTE_12:objects:1" and id ~= "pokered:ROUTE_16:objects:7" then
        return {}
    end
    local definition <const> = SnorlaxStory.definition(id)
    if not definition then
        return {}
    end
    return {visibility = {{group = "quest", id = definition.defeated_flag, equals = false}}}
end
-- Item use checks player position, not facing. Route16 accepts only East/West.
-- Call from root's existing field-key-item owner after the bag overlay closes.
function SnorlaxStory.fluteTarget(session, zoneID, x, y)
    if session:inventory():quantity("pokeFlute") == 0 then
        return nil, "no-flute"
    end
    for _, definition in ipairs(TowerStory.scenes().snorlax) do
        if definition.map_id == zoneID and not session:questFlag(definition.defeated_flag) then
            for _, position in ipairs(definition.flute_positions) do
                if position.x == x - TowerStory.padding(zoneID) and position.y == y then
                    return definition.id
                end
            end
        end
    end
    return nil, "no-snorlax-in-source-range"
end
function SnorlaxStory.arm(game)
    local id, reason = SnorlaxStory.fluteTarget(game.session, currentZone.stableID, game.player.gridX, game.player.gridY)
    if not id then
        return false, reason
    end
    local definition <const> = assert(SnorlaxStory.definition(id))
    if game.session:questFlag(definition.fight_flag) then
        return SourceEvents.dispatch(game, id)
    end
    local ok
    ok, reason = game.session:transact({flags = {[definition.fight_flag] = false, [definition.defeated_flag] = false},
        items = {pokeFlute = game.session:inventory():quantity("pokeFlute")}},
        {flags = {[definition.fight_flag] = true}, items = {}})
    if not ok then
        return false, reason
    end
    return SourceEvents.dispatch(game, id)
end
local fluteTexts
function SnorlaxStory.fluteText(label)
    if not fluteTexts then
        local data <const> = assert(json.decodeFile("data/towerStory/texts.json"))
        assert(data.schema == 1 and data.source_revision == "af519899719f0754965776faac0e836a3b906e6d",
            "unverified flute source text")
        fluteTexts = data.texts
    end
    local record <const> = fluteTexts[label]
    return record and copy(record) or nil
end
function SnorlaxStory.useFlute(bag)
    if KantoAudio and KantoAudio.playCue then KantoAudio.playCue("flute") end
    local game <const> = bag.game
    local machine <const> = game.machine
    local world <const> = machine:get("overworld")
    local player <const> = game.player
    if not bag:fieldBag() or machine._transitioning or machine:depth() ~= 2
        or machine.stack[1] ~= world or not world or not world.sub
        or world.sub:getCurrent() ~= "explore" or not player or player.isMoving
        or player.isJumping or player.stepJustFinished or player.pendingEdgeDoor or player.pendingConnection
        or game.session:getIntro().stage ~= "done" then
        return false, "field-only"
    end
    local id, reason = SnorlaxStory.fluteTarget(game.session, currentZone.stableID, player.gridX, player.gridY)
    if not id and reason ~= "no-snorlax-in-source-range" then
        return false, reason
    end
    local lines = {}
    if not id then
        for _, page in ipairs(EventText.pagesFrom({"_PlayedFluteNoEffectText"}, SnorlaxStory.fluteText)) do
            lines[#lines + 1] = {text = page.text, ending = page.ending}
        end
    end
    machine:pop()
    if id then
        return SnorlaxStory.arm(game)
    end
    machine:push("dialog", lines)
    return true
end
function SnorlaxStory.request(session, id)
    local definition <const> = assert(SnorlaxStory.definition(id))
    if not session:questFlag(definition.fight_flag) or session:questFlag(definition.defeated_flag)
        or session:inventory():quantity("pokeFlute") == 0 then
        return nil, "unarmed-source-snorlax"
    end
    return {
        id = id, zone_id = definition.map_id, species = definition.species, level = definition.level,
        guards = {flags = {[definition.defeated_flag] = false, [definition.fight_flag] = true},
            items = {pokeFlute = session:inventory():quantity("pokeFlute")}},
        rules = {capture = true, unidentified = false},
        outcomes = {
            victory = {flags = {[definition.defeated_flag] = true, [definition.fight_flag] = false}},
            caught = {flags = {[definition.defeated_flag] = true, [definition.fight_flag] = false}},
            run = {flags = {[definition.defeated_flag] = true, [definition.fight_flag] = false}},
            defeat = {flags = {[definition.fight_flag] = false}},
        },
    }
end
function SnorlaxStory.plan(id, observation)
    local definition <const> = assert(SnorlaxStory.definition(id))
    if observation.source_receipt then
        return {status = "ready", scene = "tower-story", scene_script = "snorlax-return", steps = {},
            source_receipt = copy(observation.source_receipt)}
    end
    if observation.flags[definition.defeated_flag] then
        return {status = "already-complete", steps = {}}
    end
    if observation.flags[definition.fight_flag] then
        return {status = "ready", scene = "tower-story", scene_script = "snorlax", steps = {}}
    end
    -- Talking to Snorlax does not use a bag item implicitly in Blue.
    return {status = "ready", steps = {{op = "dialog", labels = {
        definition.map_id == "pokered:ROUTE_12" and "_Route12SnorlaxText" or "_Route16Text7",
    }}}}
end
function SnorlaxStory.install(content)
    for id in pairs(SnorlaxStory.descriptors(content)) do
        assert(SourceEvents.has(id, content) and not SourceEventHandlers[id], "register Snorlax content first")
        local stableID <const> = id
        SourceEventHandlers[id] = function(observation)
            return SnorlaxStory.plan(stableID, observation)
        end
    end
    local definitions <const> = TowerStory.scenes().snorlax
    SourceEvents.registerWorldHooks("pokered:ROUTE_12:objects:1", {
        explore = function(game)
            local zoneID <const> = currentZone.stableID
            if zoneID ~= "pokered:ROUTE_12" and zoneID ~= "pokered:ROUTE_16" then
                return false
            end
            for _, definition in ipairs(definitions) do
                if definition.map_id == currentZone.stableID
                    and game.session:questFlag(definition.fight_flag)
                    and not game.session:questFlag(definition.defeated_flag) then
                    return SourceEvents.dispatch(game, definition.id)
                end
            end
            return false
        end,
    })
end
