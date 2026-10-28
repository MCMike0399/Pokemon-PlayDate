-- Exact Blue scene plans layered onto SourceEvents, never a regional dispatcher.
TowerStory = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
TowerStory.GHOST = "pokered:POKEMON_TOWER_6F:hidden_events:1"
TowerStory.FUJI = "pokered:POKEMON_TOWER_7F:objects:4"
TowerStory.HOUSE_FUJI = "pokered:MR_FUJIS_HOUSE:objects:5"
local cached
local integration
local function copy(value)
    return GameSession._copy(value)
end
function TowerStory.scenes()
    if not cached then
        local data <const> = assert(json.decodeFile("data/towerStory/scenes.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified Tower scenes")
        cached = data.scenes
    end
    return copy(cached)
end
function TowerStory.padding(zoneID)
    return SourceMaps.entry(assert(SourceMaps.nameForID(zoneID))).padding
end
function TowerStory.rocket(id)
    for _, rocket in ipairs(TowerStory.scenes().rockets) do
        if rocket.id == id then
            return rocket
        end
    end
end
function TowerStory.departureFlag(id)
    assert(TowerStory.rocket(id), "source Tower Rocket required")
    return "POKEMON_TOWER_ROCKET_V1_LEFT_" .. id:match("(%d+)$")
end
function TowerStory.variant(id, x, y)
    local rocket <const> = assert(TowerStory.rocket(id))
    for _, variant in ipairs(rocket.variants) do
        if variant.player.x == x and variant.player.y == y then
            return variant
        end
    end
end
function TowerStory.descriptors(content, houseContent)
    local events = {
        [TowerStory.GHOST] = {kind = "bespoke", content = content, item = "silphScope"},
        [TowerStory.FUJI] = {kind = "bespoke", content = content},
    }
    events[TowerStory.HOUSE_FUJI] = TowerStory.decorate(TowerStory.HOUSE_FUJI, {
        kind = "gift", content = houseContent or "midgameEast", item = "pokeFlute", flag = "EVENT_GOT_POKE_FLUTE",
        prefix = {{op = "dialog", labels = {"_MrFujisHouseMrFujiIThinkThisMayHelpYourQuestText"}}},
        success = {"_MrFujisHouseMrFujiReceivedPokeFluteText", "_MrFujisHouseMrFujiPokeFluteExplanationText"},
        full = {"_MrFujisHouseMrFujiPokeFluteNoRoomText"},
        completed = {"_MrFujisHouseMrFujiHasMyFluteHelpedYouText"},
    })
    for _, rocket in ipairs(TowerStory.scenes().rockets) do
        local positions = copy(rocket.script_positions)
        for _, position in ipairs(positions) do
            position.x = position.x + TowerStory.padding("pokered:POKEMON_TOWER_7F")
        end
        events[rocket.id] = {kind = "bespoke", content = content, script_positions = positions}
    end
    return events
end
function TowerStory.actorMetadata(id, game)
    if TowerStory.rocket(id) then
        return {visibility = {{group = "quest", id = TowerStory.departureFlag(id), equals = false}}}
    elseif id == TowerStory.FUJI then
        return {visibility = {{group = "quest", id = "EVENT_RESCUED_MR_FUJI", equals = false}}}
    elseif id == TowerStory.HOUSE_FUJI then
        return {visibility = {{group = "quest", id = "EVENT_RESCUED_MR_FUJI", equals = true}}}
    end
    return {}
end
function TowerStory.decorate(id, descriptor)
    local result <const> = copy(descriptor)
    if id == TowerStory.HOUSE_FUJI then
        -- The content worker retains the ordinary source gift: no bespoke owner
        -- for the bag-full retry, receipt, collection flag or flute item.
        return {kind = "cases", content = result.content, cases = {
            {when = {flags = {EVENT_RESCUED_MR_FUJI = true}}, ["then"] = result},
        }, otherwise = {kind = "program", steps = {}}}
    end
    return result
end
function TowerStory.plan(id, observation)
    if id == TowerStory.FUJI then
        if observation.flags.EVENT_RESCUED_MR_FUJI then
            return {status = "already-complete", steps = {}}
        end
        local target <const> = TowerStory.scenes().fuji.destination
        return SourceEvents.compile({kind = "program", steps = {
            {op = "dialog", labels = {"_PokemonTower7FMrFujiRescueText"}},
            {op = "set-flag", id = "EVENT_RESCUED_MR_FUJI", value = true},
            {op = "set-flag", id = "EVENT_RESCUED_MR_FUJI_2", value = true},
            {op = "warp", to = target.map_id, toX = target.x + TowerStory.padding(target.map_id),
                toY = target.y, facing = target.facing},
        }}, observation, id)
    end
    if id == TowerStory.GHOST then
        if observation.source_receipt then
            return {status = "ready", scene = "tower-story", scene_script = "ghost-return", steps = {},
                source_receipt = copy(observation.source_receipt)}
        end
        if observation.flags.EVENT_BEAT_GHOST_MAROWAK then
            return {status = "already-complete", steps = {}}
        end
        return {status = "ready", scene = "tower-story", scene_script = "ghost", steps = {}}
    end
    assert(TowerStory.rocket(id), "unsupported Tower source event")
    if not observation.trainers[id] then
        local descriptor <const> = assert(SourceEvents.descriptor(id))
        descriptor.kind = "trainer"
        return SourceEvents.compile(descriptor, observation, id)
    end
    if observation.flags[TowerStory.departureFlag(id)] then
        return {status = "already-complete", steps = {}}
    end
    return {status = "ready", scene = "tower-story", scene_script = "rocket-exit", steps = {},
        confirmed_receipt = copy(observation.receipt),
        ram = observation.receipt and {wAmountMoneyWon = observation.receipt.payout} or nil}
end
function TowerStory.ghostRequest(session)
    local ghost <const> = TowerStory.scenes().ghost
    if session:questFlag(ghost.flag) then
        return nil, "already-complete"
    end
    local identified <const> = session:inventory():quantity("silphScope") > 0
    return {
        id = ghost.id, zone_id = "pokered:POKEMON_TOWER_6F", species = ghost.species, level = ghost.level,
        guards = {flags = {[ghost.flag] = false}, items = {silphScope = session:inventory():quantity("silphScope")}},
        rules = {capture = false, unidentified = not identified, restless_soul = true,
            intro_labels = identified and {"_EnemyAppearedText", "_UnveiledGhostText"}
                or {"_EnemyAppearedText", "_GhostCantBeIDdText"},
            player_block_label = "_ScaredText", enemy_block_label = "_GetOutText"},
        outcomes = {
            victory = {flags = {[ghost.flag] = true}},
            run = {flags = {}}, defeat = {flags = {}},
        },
    }
end
function TowerStory.install(content, options)
    assert(not integration, "Tower story already installed")
    integration = assert(options)
    assert(type(options.reconcileActors) == "function", "content actor reconciliation required")
    for id in pairs(TowerStory.descriptors(content)) do
        assert(SourceEvents.has(id), "register Tower content first")
        if SourceEvents.descriptor(id).kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate Tower handler")
            local stableID <const> = id
            SourceEventHandlers[id] = function(observation)
                return TowerStory.plan(stableID, observation)
            end
        end
    end
    SourceEvents.registerWorldHooks(TowerStory.GHOST, {
        beforeSpawn = function(game, context)
            if currentZone.stableID == "pokered:POKEMON_TOWER_7F" or currentZone.stableID == "pokered:MR_FUJIS_HOUSE" then
                SourceActors.refresh(game, currentZone)
                context.reconcile = true
            end
        end,
        explore = function(game)
            local ghost <const> = TowerStory.scenes().ghost
            if currentZone.stableID == "pokered:POKEMON_TOWER_6F" and not game.session:questFlag(ghost.flag)
                and game.player.gridX == ghost.x + TowerStory.padding(currentZone.stableID)
                and game.player.gridY == ghost.y then
                return SourceEvents.dispatch(game, ghost.id)
            end
            if currentZone.stableID == "pokered:POKEMON_TOWER_7F" then
                for _, rocket in ipairs(TowerStory.scenes().rockets) do
                    if game.session:trainerDefeated(rocket.id)
                        and not game.session:questFlag(TowerStory.departureFlag(rocket.id)) then
                        return SourceEvents.dispatch(game, rocket.id)
                    end
                end
            end
            return false
        end,
    })
end
function TowerStory.integration()
    return assert(integration, "Tower story integration missing")
end
