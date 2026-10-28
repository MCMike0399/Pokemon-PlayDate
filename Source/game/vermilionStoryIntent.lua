-- Durable scene values are versioned booleans in the existing quest codec.
-- No scene singleton, RNG stream, tile ledger or UI holds progression state.
local PREFIX <const> = "VERMILION_SCENE_V1_"
local firstFlag <const> = "EVENT_1ST_LOCK_OPENED"
local secondFlag <const> = "EVENT_2ND_LOCK_OPENED"

local function copy(v)
    return GameSession._copy(v)
end

local function bit(flag, i)
    return PREFIX .. flag .. "_" .. i
end

local function read(session, name)
    local n = 0
    for i = 0, 3 do
        if session:questFlag(bit(name, i)) then
            n = n | (1 << i)
        end
    end
    assert(n <= 14, "invalid persisted gym can")
    return n
end

local function write(changes, name, value)
    assert(Party._integer(value, 0, 14), "invalid gym can")
    for i = 0, 3 do
        changes[bit(name, i)] = value & (1 << i) ~= 0
    end
end

function VermilionStory.puzzle(session)
    return {
        initialized = session:questFlag(PREFIX .. "INITIALIZED"),
        first = read(session, "FIRST"),
        second = read(session, "SECOND"),
        first_open = session:questFlag(firstFlag),
        solved = session:questFlag(secondFlag)
    }
end

-- Blue uses swap(Random) & mask, subtracts 1, and falls into ROM zero padding
-- on underflow. Preserve that exceptional can-0 result; do not fake adjacency.
function VermilionStory.secondCan(first, byte)
    assert(Party._integer(first, 0, 14) and Party._integer(byte, 0, 255), "bounded source puzzle input required")
    local row = VermilionStory.scenes().trash.table[first + 1]
    local swapped = ((byte & 15) << 4) | (byte >> 4)
    local offset = (swapped & row[1]) - 1
    return offset < 0 and 0 or row[offset + 2] & 15
end

local function guardPuzzle(session)
    local flags = {
        [PREFIX .. "INITIALIZED"] = session:questFlag(PREFIX .. "INITIALIZED"),
        [firstFlag] = session:questFlag(firstFlag),
        [secondFlag] = session:questFlag(secondFlag)
    }
    for _, name in ipairs({"FIRST", "SECOND"}) do
        for i = 0, 3 do
            flags[bit(name, i)] = session:questFlag(bit(name, i))
        end
    end
    -- Alternating revision bits give each reversible transition the existing
    -- false->true transaction guard without accumulating unbounded flags.
    for _, name in ipairs({"TURN_A", "TURN_B"}) do
        flags[PREFIX .. name] = session:questFlag(PREFIX .. name)
    end
    return flags
end

-- Called only from an entered controller / real world boundary. This function
-- forks the SESSION world stream, never RulesRNG/global randomness. Failed
-- transactions publish neither sampled values nor advanced stream state.
function VermilionStory.intent(session, kind, index, beforeWorld, location)
    local beforeRng = session:worldRngData()
    local random, token = session:forkWorldRNG() -- tiny root owner extension, see patch
    local expected, changes = {flags = guardPuzzle(session), items = {}}, {flags = {}, items = {}}
    local p = VermilionStory.puzzle(session)
    local effect, label
    if kind == "barrier" then
        if currentZone.stableID == "pokered:VERMILION_GYM" then
            effect = p.solved and "gym-open" or "gym-close"
        elseif currentZone.stableID == "pokered:VERMILION_DOCK" and session:questFlag("EVENT_SS_ANNE_LEFT") then
            expected.flags.EVENT_SS_ANNE_LEFT = true
            effect = "ship-departed"
        else
            return nil, "no-scene-barrier"
        end
    elseif kind == "entry" then
        if p.solved then
            return nil, "already-complete"
        end
        -- The Blue city load samples the first index; it does not clear the
        -- permanent second lock or the first-lock flag. Continue preserves it.
        write(changes.flags, "FIRST", random:random(0, 255) & 14)
        changes.flags[PREFIX .. "INITIALIZED"] = true
    elseif kind == "trash" then
        assert(Party._integer(index, 0, 14), "bounded source trash index required")
        if p.solved then
            return nil, "solved"
        end
        if not p.initialized then
            p.first = random:random(0, 255) & 14
            write(changes.flags, "FIRST", p.first)
            changes.flags[PREFIX .. "INITIALIZED"] = true
        end
        if p.first_open then
            if index == p.second then
                changes.flags[secondFlag] = true
                effect, label = "gym-open", "_VermilionGymTrashSuccessText3"
            else
                changes.flags[firstFlag] = false
                write(changes.flags, "FIRST", random:random(0, 255) & 14)
                effect, label = "gym-close", "_VermilionGymTrashFailText"
            end
        elseif index == p.first then
            changes.flags[firstFlag] = true
            write(changes.flags, "SECOND", VermilionStory.secondCan(index, random:random(0, 255)))
            label = "_VermilionGymTrashSuccessText1"
        else
            label = "_VermilionGymTrashText"
        end
    elseif kind == "departure" then
        expected.flags.VERMILION_SCENE_V1_DEPARTURE_PENDING = true
        expected.flags.EVENT_GOT_HM01 = true
        expected.flags.EVENT_SS_ANNE_LEFT = false
        changes.flags.EVENT_SS_ANNE_LEFT = true
        changes.flags.EVENT_STARTED_WALKING_OUT_OF_DOCK = true
        effect = "ship-departed"
    else
        error("unsupported Vermilion intent")
    end
    local a, b = PREFIX .. "TURN_A", PREFIX .. "TURN_B"
    if expected.flags[a] then
        changes.flags[a], changes.flags[b] = false, true
    else
        changes.flags[a], changes.flags[b] = true, false
    end
    return {
        expected = expected,
        changes = changes,
        label = label,
        scene = {
            token = token,
            beforeWorld = copy(beforeWorld),
            world = VermilionStory.projectWorld(beforeWorld, effect),
            beforeRng = beforeRng,
            rng = random:toData(),
            location = copy(location)
        }
    }
end

function VermilionStory.commitIntent(game, kind, index)
    local player = assert(game.player)
    local plan, reason = VermilionStory.intent(game.session, kind, index, WorldDeltas.export(),
        {zone_id = currentZone.stableID, x = player.gridX, y = player.gridY, facing = player.facing})
    if not plan then
        return false, reason
    end
    local accepted
    accepted, reason = game.session:transactScene(plan.expected, plan.changes, plan.scene)
    if not accepted then
        return false, reason
    end
    return true, plan.label
end
