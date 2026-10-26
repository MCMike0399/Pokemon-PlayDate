-- ROOT PATCH: append inside Source/domain/gameSession.lua, where state/copy/
-- world/location/rngData/object are lexical owner helpers. Do not import this
-- file as a gameplay module. It is reviewable patch input, not a second owner.
local function sceneEqual(a, b)
    if type(a) ~= type(b) then
        return false
    end
    if type(a) ~= "table" then
        return a == b
    end
    for key, value in pairs(a) do
        if not sceneEqual(value, b[key]) then
            return false
        end
    end
    for key in pairs(b) do
        if a[key] == nil then
            return false
        end
    end
    return true
end

local sceneIntents <const> = setmetatable({}, {__mode = "k"})

function GameSession:forkWorldRNG()
    local stream <const> = RulesRNG.new(1)
    stream:restoreData(self:worldRngData())
    local token <const> = {}
    sceneIntents[token] = {session = self, epoch = state[self].sceneEpoch or 0}
    return stream, token
end

function GameSession:transactScene(expected, changes, scene)
    local current <const> = state[self]
    local ticket <const> = type(scene) == "table" and sceneIntents[scene.token]
    if not ticket or ticket.session ~= self or ticket.epoch ~= (current.sceneEpoch or 0) then
        return false, "stale-scene-intent"
    end
    sceneIntents[scene.token] = nil -- One attempt, including validation failure.
    local ok, prepared = pcall(function()
        assert(GameSession.activeRNGSession() == self, "inactive-scene-session")
        object(scene, {
            beforeWorld = true,
            world = true,
            beforeRng = true,
            rng = true,
            location = true,
            token = true,
        })
        assert(sceneEqual(WorldDeltas.export(), scene.beforeWorld), "stale-scene-world")
        assert(sceneEqual(self:worldRngData(), scene.beforeRng), "stale-scene-world-rng")
        local candidate <const> = world(current.deps, scene.world)
        local position <const> = location(current.deps, scene.location, candidate)
        local checkpoint <const> = location(current.deps, current.checkpoint, candidate)
        local stream <const> = RulesRNG.new(1)
        stream:restoreData(rngData(scene.rng))
        return {
            world = candidate,
            location = position,
            checkpoint = checkpoint,
            stream = stream,
            actors = WorldMotionData.empty(),
        }
    end)
    if not ok then
        return false, tostring(prepared)
    end
    -- WorldDeltas preflights, applies with owner rollback, and returns an undo.
    -- No callback/yield occurs between application and the session transaction.
    local applied, undo = pcall(WorldDeltas.apply, prepared.world)
    if not applied then
        return false, tostring(undo)
    end
    local accepted, reason = self:transact(expected, changes)
    if not accepted then
        undo()
        return false, reason
    end
    -- Every fallible value was prepared; preserve retained session/bag identity.
    current.world, current.location, current.checkpoint = prepared.world, prepared.location, prepared.checkpoint
    current.worldRng, current.currentActors = prepared.stream, prepared.actors
    current.sceneEpoch = (current.sceneEpoch or 0) + 1
    return true
end
