-- Leader rewards compile through the existing ordinary SourceEvents trainer
-- planner. Only the source Dojo choice needs delegated controller behavior.
MidgameGymStory = {}
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
MidgameGymStory.MASTER = "pokered:FIGHTING_DOJO:objects:1"
local cached
local function copy(value)
    return GameSession._copy(value)
end
function MidgameGymStory.descriptors()
    if not cached then
        local data <const> = assert(json.decodeFile("data/midgameGymStory/events.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified gym story data")
        cached = data.events
    end
    return copy(cached)
end
function MidgameGymStory.plan(id, observation)
    local descriptor <const> = assert(MidgameGymStory.descriptors()[id])
    if id == MidgameGymStory.MASTER then
        descriptor.kind = "trainer"
        if observation.flags.EVENT_DEFEATED_FIGHTING_DOJO and not observation.receipt then
            return {status = "already-complete", steps = {{op = "dialog",
                labels = {"_FightingDojoKarateMasterStayAndTrainWithUsText"}}}}
        end
        local plan <const> = SourceEvents.compile(descriptor, observation, id)
        if observation.receipt then
            plan.steps[#plan.steps + 1] = {op = "dialog", labels = descriptor.after}
        end
        return plan
    end
    assert(descriptor.species, "ordinary gym descriptor has no bespoke plan")
    if observation.flags.EVENT_GOT_HITMONLEE or observation.flags.EVENT_GOT_HITMONCHAN then
        return {status = "already-complete", steps = {{op = "dialog",
            labels = {"_FightingDojoBetterNotGetGreedyText"}}}}
    end
    return {status = "ready", scene = "dojo-gift", steps = {}, species = descriptor.species,
        choice_label = descriptor.choice_label}
end
function MidgameGymStory.giftOffer(id)
    local descriptor <const> = assert(MidgameGymStory.descriptors()[id])
    assert(descriptor.species, "source Dojo gift required")
    -- Source doesn't test master defeat inside either ball's script. Preserve
    -- the actual source guard (neither choice collected), with no added policy.
    return {species = descriptor.species, level = descriptor.level, price = 0,
        flag = "EVENT_DEFEATED_FIGHTING_DOJO",
        guard_flags = {EVENT_GOT_HITMONLEE = false, EVENT_GOT_HITMONCHAN = false},
        extra_flags = {[descriptor.flag] = true}}
end
function MidgameGymStory.actorMetadata(id)
    local descriptor <const> = MidgameGymStory.descriptors()[id]
    if descriptor and descriptor.species then
        -- Only the chosen ball vanishes. The other remains and says greedy.
        return {visibility = {{group = "quest", id = descriptor.flag, equals = false}}}
    end
    return {}
end
function MidgameGymStory.install()
    for id, descriptor in pairs(MidgameGymStory.descriptors()) do
        assert(SourceEvents.has(id, descriptor.content), "register reserved gym content first")
        if descriptor.kind == "bespoke" then
            assert(not SourceEventHandlers[id], "duplicate gym story handler")
            local stableID <const> = id
            SourceEventHandlers[id] = function(observation)
                return MidgameGymStory.plan(stableID, observation)
            end
        end
    end
    SourceEvents.registerWorldHooks(MidgameGymStory.MASTER, {
        explore = function(game)
            if currentZone.stableID ~= "pokered:FIGHTING_DOJO"
                or game.session:questFlag("EVENT_BEAT_KARATE_MASTER")
                or game.session:questFlag("EVENT_DEFEATED_FIGHTING_DOJO") then
                return false
            end
            local padding <const> = SourceMaps.entry("FightingDojo").padding
            if game.player.gridX == 4 + padding and game.player.gridY == 3 then
                game.player.facing = "right"
                game.player:updateSprite()
                for _, npc in ipairs(game.npcManager.npcs) do
                    if npc.def and npc.def.source_event_id == MidgameGymStory.MASTER then
                        return SourceActors.interact(game, npc, MidgameGymStory.MASTER)
                    end
                end
                error("source Dojo master missing at its trigger")
            end
            return false
        end,
    })
end
