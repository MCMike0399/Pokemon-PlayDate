-- Preparation adapter for CeruleanContent's one package registration. Root
-- supplies the tiny optional transform seam; no second registry/dispatcher.
HideoutTowerContent = {}
local function copy(value)
    return GameSession._copy(value)
end
function HideoutTowerContent.package(name, events, trainerData)
    local additions = {}
    local function include(descriptors)
        for id, descriptor in pairs(descriptors) do
            if descriptor.content == name then
                additions[id] = descriptor
            end
        end
    end
    if name == "midgameEast" then
        include(RocketHideoutStory.descriptors(name))
        for _, id in ipairs({RocketHideoutStory.SCOPE, RocketHideoutStory.KEY}) do
            assert(events[id], "ordinary Hideout pickup missing from content")
            events[id] = RocketHideoutStory.decorate(id, events[id])
        end
    end
    if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F")
        and (name == "midgameEast" or name == "midgameSouth") then
        include(TowerStory.descriptors("midgameSouth", "midgameEast"))
        include(SnorlaxStory.descriptors("midgameSouth"))
    end
    for id, descriptor in pairs(additions) do
        local value <const> = copy(events[id] or {})
        for key, field in pairs(descriptor) do
            value[key] = copy(field)
        end
        events[id] = value
    end
    include(MidgameGymStory.descriptors())
    if SilphStory and name == "midgameSaffron" then
        include(SilphStory.descriptors())
    end
    for id, descriptor in pairs(additions) do
        local value = copy(events[id] or {})
        for key, field in pairs(descriptor) do
            value[key] = copy(field)
        end
        events[id] = value
    end
    local trainers = {}
    for id, descriptor in pairs(events) do
        if descriptor.kind == "bespoke" and trainerData.trainers[id] then
            trainers[id] = copy(trainerData.trainers[id])
        end
    end
    if TowerStory and name == "midgameSouth" then
        local class = assert(trainerData.rival_classes.OPP_RIVAL2, "content lacks source Rival2 classes")
        local variants = {}
        for starter, index in pairs(TowerStory.scenes().rival.rival_party_indices) do
            local party = copy(assert(class.parties[index]).party)
            variants[starter] = {party = party, payout = class.base_money * party[#party].level}
        end
        trainers[TowerStory.RIVAL] = {id = TowerStory.RIVAL, map_id = "pokered:POKEMON_TOWER_2F",
            name = "BLUE", sprite_source = "SPRITE_BLUE", sight_range_cells = 0, talk_only = true,
            x = 14 + TowerStory.padding("pokered:POKEMON_TOWER_2F"), y = 5,
            source_flag = "EVENT_BEAT_POKEMON_TOWER_RIVAL", party = copy(variants.charmander.party),
            payout = variants.charmander.payout, rival_parties = variants}
    end
    if SilphStory and name == "midgameSaffron" then
        local class = assert(trainerData.rival_classes.OPP_RIVAL2)
        local variants = {}
        for starter, index in pairs({charmander = 7, squirtle = 8, bulbasaur = 9}) do
            local party = copy(assert(class.parties[index]).party)
            variants[starter] = {party = party, payout = class.base_money * party[#party].level}
        end
        local event = assert(SilphStory.scenes().rival)
        trainers[SilphStory.RIVAL] = {id = SilphStory.RIVAL, map_id = "pokered:SILPH_CO_7F",
            name = "BLUE", sprite_source = "SPRITE_BLUE", sight_range_cells = 0, talk_only = true,
            x = event.origin.x + SilphStory.padding("pokered:SILPH_CO_7F"), y = event.origin.y, source_flag = "EVENT_BEAT_SILPH_CO_RIVAL",
            party = copy(variants.charmander.party), payout = variants.charmander.payout,
            rival_parties = variants}
    end
    return events, trainers
end
function HideoutTowerContent.actorMetadata(id, game)
    local result = {visibility = {}}
    local values = {RocketHideoutStory.actorMetadata(id, game),
        MidgameGymStory.actorMetadata(id), CeladonServices.actorMetadata(id)}
    if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then
        values[#values + 1] = TowerStory.actorMetadata(id, game)
        values[#values + 1] = SnorlaxStory.actorMetadata(id)
    elseif id == "pokered:MR_FUJIS_HOUSE:objects:5" then
        -- Fuji is not home before the parked Tower rescue.
        values[#values + 1] = {visibility={{group="quest", id="EVENT_RESCUED_MR_FUJI", equals=true}}}
    end
    if SilphStory and SourceMaps.nameForID("pokered:SILPH_CO_1F") then
        values[#values + 1] = SilphStory.actorMetadata(id, game)
    end
    for _, extra in ipairs(values) do
        for _, condition in ipairs(extra.visibility or {}) do
            result.visibility[#result.visibility + 1] = copy(condition)
        end
    end
    return result
end
function HideoutTowerContent.install()
    RocketHideoutStory.install("midgameEast", {
        openEntrance = RocketHideoutStoryWorld.openEntrance,
        reconcileWorld = RocketHideoutStoryWorld.reconcile,
        reconcileActors = KantoScenes.reconcileActors,
    })
    if TowerStory and SourceMaps.nameForID("pokered:POKEMON_TOWER_1F") then
        TowerStory.install("midgameSouth", {reconcileActors=KantoScenes.reconcileActors})
        SnorlaxStory.install("midgameSouth")
    end
    MidgameGymStory.install()
    if SilphStory and SourceMaps.nameForID("pokered:SILPH_CO_1F") then
        SilphStory.install({reconcileActors=KantoScenes.reconcileActors})
    end
end
