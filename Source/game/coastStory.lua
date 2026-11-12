-- Seafoam currents and boulder holes, the Mansion switches, the Secret Key,
-- and Blaine's quiz. Coordinates and button lists are pret/pokered
-- af519899. Simulated joypad bytes are consumed from the end of the RLE
-- expansion, so the button queue is that expansion reversed.
CoastStory = {}

local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"

local function copy(list)
    local out = {}
    for index, value in ipairs(list) do
        out[index] = value
    end
    return out
end

local function expand(steps)
    local forward = {}
    for _, step in ipairs(steps) do
        for _ = 1, step[2] do
            forward[#forward + 1] = step[1]
        end
    end
    local played = {}
    for index = #forward, 1, -1 do
        played[#played + 1] = forward[index]
    end
    return played
end

local function both(flags, left, right)
    return flags[left] == true and flags[right] == true
end

-- scripts/SeafoamIslandsB3F.asm and SeafoamIslandsB4F.asm.
local B3_STAIRS <const> = expand({ { "down", 6 }, { "right", 5 }, { "down", 3 } })
local B3_LEFT <const> = expand({ { "down", 6 }, { "right", 2 }, { "down", 4 } })
local B3_RIGHT <const> = expand({ { "down", 6 }, { "right", 2 }, { "down", 4 }, { "left", 1 } })
local B4_LEFT <const> = expand({ { "up", 3 }, { "right", 3 }, { "up", 1 } })
local B4_RIGHT <const> = expand({ { "up", 3 }, { "right", 2 }, { "up", 1 } })

-- Hole order is wCoordIndex. Landings are DungeonWarpData in
-- data/maps/special_warps.asm. Boulder flags are the CheckBoulderCoords events.
local HOLES <const> = {
    ["pokered:SEAFOAM_ISLANDS_1F"] = {
        destination = "pokered:SEAFOAM_ISLANDS_B1F",
        entry = "SeafoamIslandsB1F",
        coords = { { x = 17, y = 6 }, { x = 24, y = 6 } },
        landings = { { x = 18, y = 7 }, { x = 23, y = 7 } },
        falls = {
            { flag = "EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE" },
            { flag = "EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE" },
        },
    },
    ["pokered:SEAFOAM_ISLANDS_B1F"] = {
        destination = "pokered:SEAFOAM_ISLANDS_B2F",
        entry = "SeafoamIslandsB2F",
        coords = { { x = 18, y = 6 }, { x = 23, y = 6 } },
        landings = { { x = 19, y = 7 }, { x = 22, y = 7 } },
        falls = {
            { flag = "EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE" },
            { flag = "EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE" },
        },
    },
    ["pokered:SEAFOAM_ISLANDS_B2F"] = {
        destination = "pokered:SEAFOAM_ISLANDS_B3F",
        entry = "SeafoamIslandsB3F",
        coords = { { x = 19, y = 6 }, { x = 22, y = 6 } },
        landings = { { x = 18, y = 7 }, { x = 19, y = 7 } },
        falls = {
            { flag = "EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE" },
            { flag = "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE" },
        },
    },
    ["pokered:SEAFOAM_ISLANDS_B3F"] = {
        destination = "pokered:SEAFOAM_ISLANDS_B4F",
        entry = "SeafoamIslandsB4F",
        coords = { { x = 3, y = 16 }, { x = 6, y = 16 } },
        landings = { { x = 4, y = 14 }, { x = 5, y = 14 } },
        falls = {
            { flag = "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE" },
            { flag = "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE" },
        },
    },
    ["pokered:POKEMON_MANSION_3F"] = {
        coords = { { x = 16, y = 14 }, { x = 17, y = 14 }, { x = 19, y = 14 } },
        landings = {
            { map = "pokered:POKEMON_MANSION_1F", entry = "PokemonMansion1F", x = 16, y = 14 },
            { map = "pokered:POKEMON_MANSION_1F", entry = "PokemonMansion1F", x = 16, y = 14 },
            { map = "pokered:POKEMON_MANSION_2F", entry = "PokemonMansion2F", x = 18, y = 14 },
        },
    },
}

local B4_EXIT <const> = {
    { x = 20, y = 17 },
    { x = 21, y = 17 },
    { x = 20, y = 16 },
    { x = 21, y = 16 },
}

-- hidden_events.asm. The high nibble is hGymGateAnswer, and YesNoChoice
-- stores YES as menu item 0. AdjustEventBit adds nothing because
-- EVENT_CINNABAR_GYM_GATE0_UNLOCKED is bit 0 of its byte, so question N
-- unlocks GATE{N}. Gate blocks are CinnabarGymGateCoords. $0e is the open floor.
local QUIZ <const> = {
    { x = 15, y = 7, index = 1, answer = "yes" },
    { x = 10, y = 1, index = 2, answer = "no" },
    { x = 9, y = 7, index = 3, answer = "no" },
    { x = 9, y = 13, index = 4, answer = "no" },
    { x = 1, y = 13, index = 5, answer = "yes" },
    { x = 1, y = 7, index = 6, answer = "no" },
}

local GATES <const> = {
    { index = 1, x = 9, y = 3, closed = 0x54 },
    { index = 2, x = 6, y = 3, closed = 0x54 },
    { index = 3, x = 6, y = 6, closed = 0x54 },
    { index = 4, x = 3, y = 8, closed = 0x5f },
    { index = 5, x = 2, y = 6, closed = 0x54 },
    { index = 6, x = 2, y = 3, closed = 0x54 },
}

-- lb bc is y, x. $0e is empty floor. $2d, $54 and $5f are closed gates.
local function door(x, y, closed, open)
    return { x = x, y = y, off = closed, on = open }
end

local MANSION <const> = {
    ["pokered:POKEMON_MANSION_1F"] = {
        switch = { x = 2, y = 5 },
        doors = {
            door(12, 6, 0x0e, 0x2d),
            door(8, 3, 0x2d, 0x0e),
            door(10, 8, 0x2d, 0x0e),
            door(13, 13, 0x2d, 0x0e),
        },
    },
    ["pokered:POKEMON_MANSION_2F"] = {
        switch = { x = 2, y = 11 },
        doors = {
            door(4, 2, 0x0e, 0x5f),
            door(9, 4, 0x54, 0x0e),
            door(3, 11, 0x5f, 0x0e),
        },
    },
    ["pokered:POKEMON_MANSION_3F"] = {
        switch = { x = 10, y = 5 },
        doors = {
            door(7, 2, 0x0e, 0x5f),
            door(7, 5, 0x5f, 0x0e),
        },
    },
    ["pokered:POKEMON_MANSION_B1F"] = {
        switches = { { x = 20, y = 3 }, { x = 18, y = 25 } },
        doors = {
            door(13, 8, 0x0e, 0x2d),
            door(6, 11, 0x0e, 0x5f),
            door(4, 3, 0x5f, 0x0e),
            door(8, 8, 0x54, 0x0e),
        },
    },
}

local OPEN_FLOOR <const> = 0x0e

function CoastStory.revision()
    return REVISION
end

function CoastStory.holes()
    return HOLES
end

local function holeIndex(floor, x, y)
    for index, coord in ipairs(floor.coords) do
        if coord.x == x and coord.y == y then
            return index
        end
    end
end

function CoastStory.boulderFall(map, x, y)
    local floor = HOLES[map]
    if not floor or not floor.falls then
        return nil
    end
    local index = holeIndex(floor, x, y)
    if not index then
        return nil
    end
    local fall = floor.falls[index]
    return { index = index, flag = fall.flag }
end

-- pret/pokered af519899 toggleable_objects.asm and the Seafoam scripts.
-- A down-hole flag hides the boulder that fell and shows the matching
-- boulder on the floor below. B3F's toggle ids are not its object order:
-- toggle 1 is object 2, toggle 2 is object 3, toggle 3 is object 5,
-- toggle 4 is object 6. Objects with no row stay put.
local BOULDER_VISIBILITY <const> = {
    ["pokered:SEAFOAM_ISLANDS_1F:objects:1"] = {
        { group = "quest", id = "EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_1F:objects:2"] = {
        { group = "quest", id = "EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B1F:objects:1"] = {
        { group = "quest", id = "EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE", equals = true },
        { group = "quest", id = "EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B1F:objects:2"] = {
        { group = "quest", id = "EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE", equals = true },
        { group = "quest", id = "EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B2F:objects:1"] = {
        { group = "quest", id = "EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE", equals = true },
        { group = "quest", id = "EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B2F:objects:2"] = {
        { group = "quest", id = "EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE", equals = true },
        { group = "quest", id = "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B3F:objects:2"] = {
        { group = "quest", id = "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B3F:objects:3"] = {
        { group = "quest", id = "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE", equals = false },
    },
    ["pokered:SEAFOAM_ISLANDS_B3F:objects:5"] = {
        { group = "quest", id = "EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE", equals = true },
    },
    ["pokered:SEAFOAM_ISLANDS_B3F:objects:6"] = {
        { group = "quest", id = "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE", equals = true },
    },
    ["pokered:SEAFOAM_ISLANDS_B4F:objects:1"] = {
        { group = "quest", id = "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE", equals = true },
    },
    ["pokered:SEAFOAM_ISLANDS_B4F:objects:2"] = {
        { group = "quest", id = "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE", equals = true },
    },
}

function CoastStory.boulderVisibility(id)
    local rules = BOULDER_VISIBILITY[id]
    if not rules then
        return nil
    end
    local copy = {}
    for index, rule in ipairs(rules) do
        copy[index] = { group = rule.group, id = rule.id, equals = rule.equals }
    end
    return copy
end

function CoastStory.boulderVisible(id, flags)
    local rules = BOULDER_VISIBILITY[id]
    if not rules then
        return true
    end
    flags = flags or {}
    for _, rule in ipairs(rules) do
        if (flags[rule.id] == true) ~= rule.equals then
            return false
        end
    end
    return true
end

function CoastStory.playerHole(map, x, y, onWarp)
    if onWarp then
        return nil
    end
    local floor = HOLES[map]
    if not floor then
        return nil
    end
    local index = holeIndex(floor, x, y)
    if not index then
        return nil
    end
    local landing = floor.landings[index]
    return {
        index = index,
        map = landing.map or floor.destination,
        entry = landing.entry or floor.entry,
        x = landing.x,
        y = landing.y,
    }
end

-- Currents that the default map script checks every step pass arrival=false.
-- The four surf tiles run only as the dungeon-warp MoveObject script.
function CoastStory.current(map, x, y, flags, arrival)
    flags = flags or {}
    local b3 = both(flags, "EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE", "EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE")
    local b4 = both(flags, "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE", "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE")
    if map == "pokered:SEAFOAM_ISLANDS_B3F" and x == 15 and y == 8 then
        if not b3 then
            return nil
        end
        return { kind = "b3-stairs", buttons = copy(B3_STAIRS), forced_warp = true, surf = false }
    end
    if arrival and map == "pokered:SEAFOAM_ISLANDS_B3F" and y == 7 and (x == 18 or x == 19) then
        if not b3 then
            return { kind = x == 18 and "b3-left" or "b3-right", surf = true }
        end
        return {
            kind = x == 18 and "b3-left" or "b3-right",
            buttons = copy(x == 18 and B3_LEFT or B3_RIGHT),
            forced_warp = true,
            surf = true,
        }
    end
    if arrival and map == "pokered:SEAFOAM_ISLANDS_B4F" and y == 14 and (x == 4 or x == 5) then
        local row = {
            kind = x == 4 and "b4-left" or "b4-right",
            surf = true,
            dismount_before_last = true,
        }
        if b4 then
            row.buttons = copy(x == 4 and B4_LEFT or B4_RIGHT)
        end
        return row
    end
    if map == "pokered:SEAFOAM_ISLANDS_B4F" then
        for index, coord in ipairs(B4_EXIT) do
            if coord.x == x and coord.y == y then
                if not b3 then
                    return nil
                end
                local ups = index >= 3 and 1 or 2
                local buttons = {}
                for _ = 1, ups do
                    buttons[#buttons + 1] = "up"
                end
                return { kind = "b4-exit", buttons = buttons, forced_warp = false, surf = false }
            end
        end
    end
end

-- engine/overworld/field_move_messages.asm IsSurfingAllowed, lines 21-50.
-- B4F denies Surf only at (7, 11), and only before both SEAFOAM4
-- boulders are down (CheckBothEventsSet sets Z when both are set, and
-- that path returns with Surf still allowed). B3F is not in that check.
-- CheckForceBikeOrSurf still forces Surf on B3F (18, 7)/(19, 7) and
-- B4F (4, 14)/(5, 14); those arrivals are CoastStory.current.
function CoastStory.currentTooFast(map, x, y, flags)
    if map ~= "pokered:SEAFOAM_ISLANDS_B4F" then
        return false
    end
    if both(flags or {}, "EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE", "EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE") then
        return false
    end
    return x == 7 and y == 11
end

local ARTICUNO_FLAG <const> = "EVENT_BEAT_ARTICUNO"

function CoastStory.articuno(beaten)
    if beaten then
        return nil, "already-fought"
    end
    return {
        id = "pokered:SEAFOAM_ISLANDS_B4F:objects:3",
        species = "articuno",
        level = 50,
        x = 6,
        y = 1,
        sight = 0,
        flag = ARTICUNO_FLAG,
    }
end

-- Same request shape as Moltres. SourceEncounters.prepare rejects anything
-- that is not the pinned object, level, and non-loss hide flag.
function CoastStory.articunoRequest(flags)
    local bird <const> = CoastStory.articuno(flags and flags[ARTICUNO_FLAG] == true)
    if not bird then
        return nil, "already-fought"
    end
    return {
        id = bird.id,
        zone_id = "pokered:SEAFOAM_ISLANDS_B4F",
        species = bird.species,
        level = bird.level,
        guards = { flags = { [bird.flag] = false }, items = {} },
        rules = { capture = true, unidentified = false },
        outcomes = {
            victory = { flags = { [bird.flag] = true } },
            caught = { flags = { [bird.flag] = true } },
            run = { flags = { [bird.flag] = true } },
            defeat = { flags = {} },
        },
    }
end

function CoastStory.articunoPlan(observation)
    local receipt = observation.source_receipt
    if receipt then
        return {
            status = "ready", scene = "coast-articuno", scene_script = "return", steps = {},
            source_receipt = {
                id = receipt.id, zone_id = receipt.zone_id, confirmed = receipt.confirmed,
                kind = receipt.kind, completed = receipt.completed,
            },
        }
    end
    if observation.flags and observation.flags[ARTICUNO_FLAG] then
        return { status = "already-complete", steps = {} }
    end
    return { status = "ready", scene = "coast-articuno", scene_script = "battle", steps = {} }
end

local articunoText
function CoastStory.articunoText(label)
    if not articunoText then
        local data <const> = assert(json.decodeFile("data/zCoast/dialogue.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified coast dialogue")
        articunoText = data.texts
    end
    return articunoText[label]
end

function CoastStory.secretKey()
    return {
        id = "pokered:POKEMON_MANSION_B1F:objects:8",
        map = "pokered:POKEMON_MANSION_B1F",
        x = 5,
        y = 13,
        item = "secretKey",
        flag = "PICKUP:pokered:POKEMON_MANSION_B1F:objects:8",
    }
end

-- CinnabarIslandDefaultScript checks the tile south of the gym warp.
function CoastStory.gymDoor(x, y, hasKey)
    if hasKey or x ~= 18 or y ~= 4 then
        return nil
    end
    return { facing = "up", step = "down", text = { "The door is", "locked..." } }
end

function CoastStory.quizAt(x, y)
    for _, row in ipairs(QUIZ) do
        if row.x == x and row.y == y then
            return { index = row.index, answer = row.answer }
        end
    end
end

function CoastStory.quizAnswer(index, choice)
    local row
    for _, candidate in ipairs(QUIZ) do
        if candidate.index == index then
            row = candidate
            break
        end
    end
    if not row or (choice ~= "yes" and choice ~= "no") then
        return nil
    end
    if choice == row.answer then
        return { correct = true, flag = "EVENT_CINNABAR_GYM_GATE" .. index .. "_UNLOCKED" }
    end
    return { correct = false, opponent = index + 2 }
end

-- text/data text_2.asm at af519899. YES is the first menu item, matching
-- YesNoChoice item 0. The question stays up while the menu is open.
local QUIZ_QUESTIONS <const> = {
    "CATERPIE evolves into BUTTERFREE?",
    "There are 9 certified #MON LEAGUE BADGEs?",
    "POLIWAG evolves 3 times?",
    "Are thunder moves effective against ground element-type #MON?",
    "#MON of the same kind and level are not identical?",
    "TM28 contains TOMBSTONER?",
}

function CoastStory.quizLines(index)
    local question = QUIZ_QUESTIONS[index]
    if not question then
        return nil
    end
    return {
        intro = {
            "#MON Quiz!",
            "Get it right and the door opens to the next room!",
            "Get it wrong and face a trainer!",
            "If you want to conserve your #MON for the GYM LEADER... Then get it right! Here we go!",
        },
        question = question,
        correct = { "You're absolutely correct!", "Go on through!" },
        incorrect = { "Sorry! Bad call!" },
    }
end

function CoastStory.gymGates(flags)
    flags = flags or {}
    local blocks = {}
    for _, gate in ipairs(GATES) do
        local open = flags["EVENT_CINNABAR_GYM_GATE" .. gate.index .. "_UNLOCKED"] == true
        blocks[#blocks + 1] = {
            x = gate.x,
            y = gate.y,
            block = open and OPEN_FLOOR or gate.closed,
            solid = not open,
        }
    end
    return blocks
end

function CoastStory.mansionSwitch(map, x, y)
    local floor = MANSION[map]
    if not floor then
        return nil
    end
    if floor.switch and floor.switch.x == x and floor.switch.y == y then
        return { facing = "up" }
    end
    for _, switch in ipairs(floor.switches or {}) do
        if switch.x == x and switch.y == y then
            return { facing = "up" }
        end
    end
end

function CoastStory.switchDecision(on, yes)
    if not yes then
        return { on = on == true, changed = false }
    end
    return { on = on ~= true, changed = true }
end

function CoastStory.mansionDoors(map, on)
    local floor = MANSION[map]
    if not floor then
        return nil
    end
    local blocks = {}
    for _, entry in ipairs(floor.doors) do
        local block = on and entry.on or entry.off
        blocks[#blocks + 1] = { x = entry.x, y = entry.y, block = block, solid = block ~= OPEN_FLOOR }
    end
    return blocks
end

-- A surfing step off a foot-tile $14 edge is a real connection. Walking
-- still stops on that solid cell. Both banks have to be the same water.
function CoastStory.surfEdge(surfing, origin, arrival, outside)
    if surfing ~= true or outside ~= true or type(origin) ~= "table" or type(arrival) ~= "table" then
        return false
    end
    local function water(cell)
        return cell.water_candidate == true and cell.foot_tile == 0x14
    end
    return water(origin) and water(arrival)
end

function CoastStory.scriptFlags(map)
    if map == "pokered:SEAFOAM_ISLANDS_1F" then
        return { set = { EVENT_IN_SEAFOAM_ISLANDS = true } }
    end
    if map == "pokered:CINNABAR_ISLAND" then
        return { clear = { EVENT_MANSION_SWITCH_ON = true, EVENT_LAB_STILL_REVIVING_FOSSIL = true } }
    end
end
