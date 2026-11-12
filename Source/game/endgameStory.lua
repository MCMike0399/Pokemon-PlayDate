-- League story generated from pinned pokered. Decisions read story.json.
-- Badge writes happen only through Giovanni's confirmed victory.
EndgameStory = {}
local CONTENT <const> = "endgame"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached, playCached
local pending = {}
local armed = {}
local sceneWrapped = false
local STARTED_ELITE_FOUR <const> = "EVENT_STARTED_ELITE_4"
local GIOVANNI_HIDE <const> = "TOGGLE_VIRIDIAN_GYM_GIOVANNI"
local OAK_SHOW <const> = "TOGGLE_CHAMPIONS_ROOM_OAK"
local MOLTRES <const> = "pokered:VICTORY_ROAD_2F:objects:6"
local BADGE_NAMES <const> = {
    BADGE_BOULDER = "BOULDERBADGE", BADGE_CASCADE = "CASCADEBADGE",
    BADGE_THUNDER = "THUNDERBADGE", BADGE_RAINBOW = "RAINBOWBADGE",
    BADGE_SOUL = "SOULBADGE", BADGE_MARSH = "MARSHBADGE",
    BADGE_VOLCANO = "VOLCANOBADGE", BADGE_EARTH = "EARTHBADGE",
}
local STARTER_NAMES <const> = {charmander = "CHARMANDER", squirtle = "SQUIRTLE", bulbasaur = "BULBASAUR"}
local INDIGO_RESET <const> = {
    "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0", "EVENT_AUTOWALKED_INTO_LORELEIS_ROOM",
    "EVENT_BEAT_BRUNOS_ROOM_TRAINER_0", "EVENT_AUTOWALKED_INTO_BRUNOS_ROOM",
    "EVENT_BEAT_AGATHAS_ROOM_TRAINER_0", "EVENT_AUTOWALKED_INTO_AGATHAS_ROOM",
    "EVENT_BEAT_LANCES_ROOM_TRAINER_0", "EVENT_BEAT_LANCE", "EVENT_LANCES_ROOM_LOCK_DOOR",
}
local VISIBILITY <const> = {
    ["pokered:VIRIDIAN_GYM:objects:1"] = {{group = "quest", id = GIOVANNI_HIDE, equals = false}},
    [MOLTRES] = {{group = "quest", id = "EVENT_BEAT_MOLTRES", equals = false}},
    ["pokered:VICTORY_ROAD_2F:objects:13"] = {{group = "quest", id = "TOGGLE_VICTORY_ROAD_2F_BOULDER", equals = false}},
    ["pokered:VICTORY_ROAD_3F:objects:10"] = {{group = "quest", id = "TOGGLE_VICTORY_ROAD_3F_BOULDER", equals = false}},
    ["pokered:CHAMPIONS_ROOM:objects:2"] = {{group = "quest", id = OAK_SHOW, equals = true}},
}

local function story()
    if not cached then
        local data <const> = assert(json.decodeFile("data/endgame/story.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified endgame story")
        cached = data
    end
    return cached
end

local function play()
    if not playCached then
        local data <const> = assert(json.decodeFile("data/endgame/play.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified endgame play text")
        playCached = data
    end
    return playCached
end

function EndgameStory.story()
    return story()
end

function EndgameStory.badgeName(badge)
    return assert(BADGE_NAMES[badge], "unknown badge name")
end

function EndgameStory.indigoReset()
    local names = {}
    for index, name in ipairs(INDIGO_RESET) do
        names[index] = name
    end
    return names
end

function EndgameStory.hallRecord(members)
    assert(type(members) == "table" and #members <= 6, "hall of fame party")
    local record = {}
    for _, mon in ipairs(members) do
        assert(type(mon.species) == "string" and type(mon.level) == "number", "hall of fame member")
        record[#record + 1] = {species = mon.species, level = mon.level, name = mon.name}
    end
    return record
end

function EndgameStory.noteParty(members)
    pending.party = members
end

function EndgameStory.noteRoute22Tile(index)
    pending.route22 = index
end

function EndgameStory.noteStarter(starter)
    pending.starter = starter
end

function EndgameStory.entranceAction(room, x, y, flags)
    if flags[room.flag] then
        return nil
    end
    local index
    for position, point in ipairs(room.entrance or {}) do
        if point.x == x and point.y == y then
            index = position
            break
        end
    end
    if room.walk_coord and room.walk_coord.x == x and room.walk_coord.y == y and not room.entrance then
        return "autowalk"
    end
    if not index then
        return nil
    end
    local walked <const> = room.autowalk_event and flags[room.autowalk_event]
    if not walked and index >= 3 then
        return "autowalk"
    end
    return "dont-run"
end

function EndgameStory.besideTrainer(room, x, y)
    for position, point in ipairs(room.trigger or {}) do
        if position > 2 then
            break
        end
        if point.x == x and point.y == y then
            return true
        end
    end
    return false
end

function EndgameStory.holeWarp(mapName, x, y, flags)
    local hole <const> = story().victory_road.hole
    if hole.map == mapName and hole.x == x and hole.y == y and not flags[hole.event] then
        return {to = "kanto_victory_road_2f", toX = 22, toY = 16, facing = "down"}
    end
    return nil
end

function EndgameStory.badgeValue(flags)
    local value = 0
    for index, name in ipairs(story().badge_bits) do
        if flags[name] then
            value = value + (1 << (index - 1))
        end
    end
    return value
end

function EndgameStory.gymDoor(flags)
    local gym <const> = story().viridian_gym
    if flags[gym.open_event] then
        return "open"
    end
    if EndgameStory.badgeValue(flags) == gym.required_mask then
        return "open-and-set"
    end
    return "locked"
end

function EndgameStory.arrow(x, y)
    for _, tile in ipairs(story().viridian_gym.arrows) do
        if tile.x == x and tile.y == y then
            return tile.steps
        end
    end
    return nil
end

function EndgameStory.route22Party(playerStarter)
    local row <const> = story().route22_rival.parties_by_player_starter[playerStarter]
    assert(row, "route 22 rival needs the session starter")
    return row
end

function EndgameStory.championParty(playerStarter)
    local row <const> = story().champion.parties_by_player_starter[playerStarter]
    assert(row, "champion needs the session starter")
    return row
end

function EndgameStory.route23Guard(x, y, flags)
    for _, guard in ipairs(story().route23.guards) do
        if guard.y == y and (guard.x_below == nil or x < guard.x_below) then
            if flags[guard.passed] then
                return nil
            end
            return guard, flags[guard.badge] == true
        end
    end
    return nil
end

function EndgameStory.boulderSwitch(mapName, x, y)
    for _, switch in ipairs(story().victory_road.switches) do
        if switch.map == mapName and switch.x == x and switch.y == y then
            return switch
        end
    end
    local hole <const> = story().victory_road.hole
    if hole.map == mapName and hole.x == x and hole.y == y then
        return hole
    end
    return nil
end

function EndgameStory.credits()
    return story().hall_of_fame.credits
end

function EndgameStory.creditTiming()
    return story().hall_of_fame.timing
end

local function copy(value)
    if GameSession then
        return GameSession._copy(value)
    end
    return value
end

function EndgameStory.text(label)
    local row <const> = story().texts[label] or play().texts[label]
    assert(row, "missing endgame text: " .. tostring(label))
    return copy(row)
end

local function moves(steps)
    local plan = {}
    for _, step in ipairs(steps) do
        local left = step.count
        while left > 0 do
            local count = left > 8 and 8 or left
            plan[#plan + 1] = {op = "move", direction = step.direction, count = count}
            left = left - count
        end
    end
    return plan
end

local function approachWalk(room)
    -- Lorelei, Bruno and Agatha walk exactly six tiles up from the door.
    -- Sight is 0, so the walk does not start the battle.
    return moves(room.walk_in or room.walk)
end

function EndgameStory.approachWalk(room, _)
    return approachWalk(room)
end

local function starterName(observation)
    local starter <const> = observation.starter or pending.starter
    return assert(STARTER_NAMES[starter], "endgame text needs the session starter")
end

local function itemName(id)
    local definitions <const> = ItemData and ItemData.definitions
    local row <const> = definitions and definitions[id]
    return row and row.name or id
end

local function trainerPlan(row, observation, id)
    local flags <const> = observation.flags or {}
    local trainers <const> = observation.trainers or {}
    local plan = {status = "ready", steps = {}}
    if observation.receipt and observation.receipt.won then
        plan.ram = {wAmountMoneyWon = observation.receipt.payout}
        plan.steps[1] = {op = "confirmed-dialog", labels = copy(row.won)}
        plan.steps[2] = {op = "confirmed-dialog", labels = {"_MoneyForWinningText"}}
    elseif observation.receipt then
        return {status = "lost", steps = {}}
    end
    if not trainers[id] then
        plan.status = "trainer-battle"
        plan.steps[#plan.steps + 1] = {op = "trainer", id = id, before = copy(row.before), mode = observation.mode or "talk"}
        return plan
    end
    if row.item and row.reward_flag and not flags[row.reward_flag] then
        local item <const> = row.item
        local flag <const> = row.reward_flag
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = copy(row.reward_before)}
        if observation.can_add and observation.can_add[item] then
            plan.ram = plan.ram or {}
            plan.ram.wStringBuffer = itemName(item)
            plan.expected = {flags = {[flag] = false}, items = {[item] = (observation.items and observation.items[item]) or 0},
                trainers = {[id] = true}}
            plan.changes = {flags = {[flag] = true}, items = {{op = "add", id = item, quantity = 1}}, trainers = {}}
            plan.steps[#plan.steps + 1] = {op = "receipt", labels = copy(row.reward_success)}
            plan.failure_labels = copy(row.reward_full)
        else
            plan.status = "bag-full"
            plan.steps[#plan.steps + 1] = {op = "dialog", labels = copy(row.reward_full)}
        end
        return plan
    end
    if not observation.receipt then
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = copy(row.after)}
        if flags[GIOVANNI_HIDE] ~= true and id == story().viridian_gym.leader.id then
            plan.expected = {flags = {[GIOVANNI_HIDE] = false}, items = {}, trainers = {}}
            plan.changes = {flags = {[GIOVANNI_HIDE] = true}, items = {}, trainers = {}}
        end
    end
    return plan
end

local function flagPlan(observation, writes, labels)
    local expected = {flags = {}, items = {}}
    local changes = {flags = {}, items = {}}
    for name, value in pairs(writes) do
        expected.flags[name] = observation.flags[name] == true
        changes.flags[name] = value
    end
    local steps = {}
    if labels then
        steps[1] = {op = "dialog", labels = labels}
    end
    return {status = "ready", steps = steps, expected = expected, changes = changes}
end

local function scriptId(room)
    local token <const> = room.id:match("^pokered:([^:]+):")
    return "pokered:" .. token .. ":script:entrance"
end

function EndgameStory.championPlan(id, observation)
    local champ <const> = story().champion
    local plan <const> = trainerPlan({before = champ.before, won = champ.won, after = champ.after}, observation, id)
    if observation.receipt and observation.receipt.won then
        plan.ram = plan.ram or {}
        plan.ram.wNameBuffer = starterName(observation)
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = copy(champ.after)}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakText"}}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakCongratulatesPlayerText"}}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakDisappointedWithRivalText"}}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakComeWithMeText"}}
        plan.steps[#plan.steps + 1] = {op = "warp", to = "kanto_hall_of_fame", toX = 5, toY = 7, facing = "up"}
    end
    return plan
end

function EndgameStory.route22Approach(index)
    -- triggers.route22 is (29, 4) then (29, 5). pokered coord index 0 is the
    -- upper tile and skips the first right. The lower tile walks all four.
    if index == 1 then
        return {{op = "move-npc", direction = "right", count = 3}, player = "left", rival = "right"}
    end
    return {{op = "move-npc", direction = "right", count = 4}, player = "down", rival = "up"}
end

function EndgameStory.route22RivalPlan(id, observation)
    local rival <const> = story().route22_rival
    if observation.receipt and observation.receipt.won then
        return {status = "ready", ram = {wAmountMoneyWon = observation.receipt.payout}, steps = {
            {op = "confirmed-dialog", labels = copy(rival.won)},
            {op = "confirmed-dialog", labels = {"_MoneyForWinningText"}},
            {op = "dialog", labels = copy(rival.after)}}}
    end
    if observation.receipt then
        return {status = "lost", steps = {}}
    end
    if observation.trainers and observation.trainers[id] then
        return {status = "already-complete", steps = {{op = "dialog", labels = copy(rival.after)}}}
    end
    local approach <const> = EndgameStory.route22Approach(pending.route22 or 2)
    pending.route22 = nil
    local steps = {}
    for _, step in ipairs(approach) do
        steps[#steps + 1] = {op = "move-npc", id = id, direction = step.direction, count = step.count}
    end
    steps[#steps + 1] = {op = "face-npc", id = id, direction = approach.rival}
    steps[#steps + 1] = {op = "face-player", direction = approach.player}
    steps[#steps + 1] = {op = "trainer", id = id, before = copy(rival.before), mode = "script"}
    return {status = "ready", steps = steps}
end

function EndgameStory.moltresRequest(flags)
    local flag <const> = "EVENT_BEAT_MOLTRES"
    assert(flags[flag] ~= true, "already-complete")
    return {id = MOLTRES, zone_id = "pokered:VICTORY_ROAD_2F", species = "moltres", level = 50,
        guards = {flags = {[flag] = false}, items = {}},
        rules = {capture = true, unidentified = false},
        outcomes = {victory = {flags = {[flag] = true}}, caught = {flags = {[flag] = true}},
            run = {flags = {[flag] = true}}, defeat = {flags = {}}}}
end

function EndgameStory.moltresPlan(id, observation)
    if observation.source_receipt then
        return {status = "ready", scene = "endgame", scene_script = "moltres-return", steps = {},
            source_receipt = copy(observation.source_receipt)}
    end
    if observation.flags and observation.flags.EVENT_BEAT_MOLTRES then
        return {status = "already-complete", steps = {}}
    end
    return {status = "ready", scene = "endgame", scene_script = "moltres", steps = {}}
end

function EndgameStory.plan(id, observation)
    local data <const> = story()
    local gym <const> = data.viridian_gym
    if id == "pokered:VIRIDIAN_CITY:script:gym-gate" then
        local decision <const> = EndgameStory.gymDoor(observation.flags)
        if decision == "locked" then
            return {status = "locked", steps = {
                {op = "dialog", labels = {gym.locked_text}},
                {op = "move", direction = "down", count = 1}}}
        end
        if decision == "open-and-set" then
            return flagPlan(observation, {[gym.open_event] = true})
        end
        return {status = "already-complete", steps = {}}
    end
    if id == "pokered:VIRIDIAN_GYM:script:arrow" then
        local x <const> = observation.arrow_x or pending.x
        local y <const> = observation.arrow_y or pending.y
        local steps <const> = assert(EndgameStory.arrow(x, y), "viridian arrow tile missing")
        return {status = "ready", steps = moves(steps)}
    end
    if id == "pokered:CHAMPIONS_ROOM:script:entrance" then
        return {status = "ready", steps = moves(data.champion.walk)}
    end
    for _, room in ipairs(data.elite_four) do
        if id == scriptId(room) then
            if pending.dont_run == room.id then
                pending.dont_run = nil
                return {status = "ready", steps = {
                    {op = "dialog", labels = {room.dont_run_text}},
                    {op = "move", direction = "up", count = 1}}}
            end
            return {status = "ready", steps = approachWalk(room)}
        end
    end
    local gate <const> = data.route22_gate
    if id == gate.id then
        if observation.flags[gate.badge] then
            return {status = "ready", steps = {{op = "dialog", labels = gate.accepted_text}}}
        end
        return {status = "denied", steps = {
            {op = "dialog", labels = gate.denied_text},
            {op = "move", direction = "down", count = 1}}}
    end
    local hall <const> = data.hall_of_fame
    if id == hall.oak_id then
        local plan <const> = flagPlan(observation, {[hall.hides[1]] = true}, {hall.oak_text})
        local steps <const> = moves(hall.walk)
        steps[#steps + 1] = plan.steps[1]
        -- HallOfFamePC plays the credits, then the cartridge returns to the
        -- title. The party record stays on the plan. The save schema does not
        -- keep it, and this plan does not write a save.
        steps[#steps + 1] = {op = "credits"}
        plan.steps = steps
        plan.return_to = hall.return_to
        plan.saves = false
        if pending.party then
            plan.record = EndgameStory.hallRecord(pending.party)
            pending.party = nil
        end
        return plan
    end
    for _, guard in ipairs(data.route23.guards) do
        if id == guard.id then
            local ram <const> = {wNameBuffer = EndgameStory.badgeName(guard.badge)}
            if observation.flags[guard.passed] then
                return {status = "already-complete", steps = {}}
            end
            if observation.flags[guard.badge] then
                local plan <const> = flagPlan(observation, {[guard.passed] = true}, data.route23.accepted_text)
                plan.ram = ram
                return plan
            end
            return {status = "denied", ram = ram, steps = {
                {op = "dialog", labels = {data.route23.denied_text}},
                {op = "move", direction = "down", count = 1}}}
        end
    end
    if id == data.viridian_gym.leader.id then
        return trainerPlan(data.viridian_gym.leader, observation, id)
    end
    if id == data.champion.id then
        return EndgameStory.championPlan(id, observation)
    end
    if id == data.route22_rival.id then
        return EndgameStory.route22RivalPlan(id, observation)
    end
    if id == MOLTRES then
        return EndgameStory.moltresPlan(id, observation)
    end
    if id == "pokered:VICTORY_ROAD_3F:script:hole" then
        return {status = "ready", steps = {{op = "warp", to = "kanto_victory_road_2f", toX = 22, toY = 16, facing = "down"}}}
    end
    if id == "pokered:CHAMPIONS_ROOM:objects:2" then
        return {status = "ready", ram = {wNameBuffer = starterName(observation)}, steps = {
            {op = "dialog", labels = {"_ChampionsRoomOakText"}},
            {op = "dialog", labels = {"_ChampionsRoomOakCongratulatesPlayerText"}},
            {op = "dialog", labels = {"_ChampionsRoomOakDisappointedWithRivalText"}},
            {op = "dialog", labels = {"_ChampionsRoomOakComeWithMeText"}}}}
    end
    error("unknown endgame event: " .. tostring(id))
end

local function setCollision(zone, x, y, solid)
    if y < 0 or x < 0 or not zone.collision or not zone.collision[y + 1] or zone.collision[y + 1][x + 1] == nil then
        return
    end
    local row = {}
    for index = 1, #zone.collision[y + 1] do
        row[index] = zone.collision[y + 1][index]
    end
    row[x + 1] = solid
    zone.collision[y + 1] = row
end

local function setBlock(zone, block, padding, solid)
    for dy = 0, 1 do
        for dx = 0, 1 do
            setCollision(zone, block.x * 2 + dx + padding, block.y * 2 + dy, solid)
        end
    end
end

function EndgameStory.applyRoom(game)
    local data <const> = story()
    local zone <const> = currentZone
    if not zone or not game.session then
        return
    end
    local name <const> = SourceMaps.nameForID(zone.stableID)
    local entry <const> = name and SourceMaps.entry(name)
    local padding <const> = entry and entry.padding or 0
    if zone.stableID == "pokered:ROUTE_23" then
        for _, event in ipairs(data.route23.reset_events) do
            game.session:setQuestFlag(event, false)
        end
        game.session:setQuestFlag(data.route23.show_toggle, false)
        game.session:setQuestFlag(data.route23.hide_toggle, true)
    end
    if name == "VictoryRoad2F" or zone.stableID == "pokered:INDIGO_PLATEAU_LOBBY" then
        game.session:setQuestFlag("EVENT_VICTORY_ROAD_1_BOULDER_ON_SWITCH", false)
    end
    if zone.stableID == "pokered:LORELEIS_ROOM" then
        game.session:setQuestFlag(STARTED_ELITE_FOUR, true)
    elseif zone.stableID == "pokered:INDIGO_PLATEAU_LOBBY" and game.session:questFlag(STARTED_ELITE_FOUR) then
        for _, event in ipairs(INDIGO_RESET) do
            game.session:setQuestFlag(event, false)
        end
        game.session:setQuestFlag(STARTED_ELITE_FOUR, false)
    end
    for _, switch in ipairs(data.victory_road.switches) do
        if switch.map == name and game.session:questFlag(switch.event) then
            setBlock(zone, switch.block, padding, 0)
        end
    end
    for _, room in ipairs(data.elite_four) do
        if room.map == name and room.exit_block then
            setBlock(zone, room.exit_block, padding, game.session:questFlag(room.flag) and 0 or 1)
        end
        if room.map == name and room.entrance_blocks then
            -- Map load closes the door whenever the lock flag is set. Beating
            -- Lance does not reopen it; the north warp is the way forward.
            local closed <const> = game.session:questFlag(room.lock_event)
            for _, block in ipairs(room.entrance_blocks) do
                setBlock(zone, block, padding, closed and 1 or 0)
            end
        end
    end
end

function EndgameStory.boulderLanded(game, mapName, x, y)
    local switch <const> = EndgameStory.boulderSwitch(mapName, x, y)
    if not switch or not game.session then
        return nil
    end
    if switch.event and not game.session:questFlag(switch.event) then
        game.session:setQuestFlag(switch.event, true)
    end
    if switch.hide_toggle then
        game.session:setQuestFlag(switch.hide_toggle, true)
        game.session:setQuestFlag(switch.show_toggle, false)
    end
    if switch.block and currentZone then
        local entry <const> = SourceMaps.entry(mapName)
        setBlock(currentZone, switch.block, entry and entry.padding or 0, 0)
    end
    return switch
end

local function at(points, x, y)
    for _, point in ipairs(points) do
        if point.x == x and point.y == y then
            return true
        end
    end
    return false
end

local function sourceCell(player, entry)
    return player.gridX - entry.padding, player.gridY
end

function EndgameStory.check(game)
    local data <const> = story()
    local player <const> = game.player
    if not currentZone or not player or player.isMoving then
        return false
    end
    local name <const> = SourceMaps.nameForID(currentZone.stableID)
    local entry <const> = name and SourceMaps.entry(name)
    if not entry then
        return false
    end
    local x, y = sourceCell(player, entry)
    local intro <const> = game.session.getIntro and game.session:getIntro()
    if intro and intro.starter then
        pending.starter = intro.starter
    end
    if name ~= "ChampionsRoom" then
        armed.champion = nil
    end
    if name ~= "Route22Gate" then
        armed.gate = nil
    end
    if currentZone.stableID == "pokered:VIRIDIAN_CITY" then
        local trigger <const> = data.viridian_gym.trigger
        if x == trigger.x and y == trigger.y and EndgameStory.gymDoor(game.session:flags().quest) ~= "open" then
            return SourceEvents.dispatch(game, "pokered:VIRIDIAN_CITY:script:gym-gate")
        end
    elseif currentZone.stableID == "pokered:VIRIDIAN_GYM" then
        if EndgameStory.arrow(x, y) then
            pending.x, pending.y = x, y
            return SourceEvents.dispatch(game, "pokered:VIRIDIAN_GYM:script:arrow")
        end
    elseif currentZone.stableID == "pokered:ROUTE_22_GATE" then
        local gate <const> = data.route22_gate
        if at(gate.coords, x, y) and not armed.gate then
            if game.session:questFlag(gate.badge) then
                armed.gate = true
            end
            return SourceEvents.dispatch(game, gate.id)
        end
    elseif currentZone.stableID == "pokered:ROUTE_23" then
        local guard <const> = EndgameStory.route23Guard(x, y, game.session:flags().quest)
        if guard then
            return SourceEvents.dispatch(game, guard.id)
        end
    elseif name == "VictoryRoad3F" then
        local hole <const> = EndgameStory.holeWarp(name, x, y, game.session:flags().quest)
        if hole then
            return SourceEvents.dispatch(game, "pokered:VICTORY_ROAD_3F:script:hole")
        end
    elseif currentZone.stableID == "pokered:HALL_OF_FAME"
        and not game.session:questFlag(data.hall_of_fame.hides[1]) and not armed.hall then
        local party <const> = game.session:party()
        local members = {}
        for index = 1, party:count() do
            local mon <const> = party:get(index)
            members[#members + 1] = {species = mon.species, level = mon.level, name = mon.name}
        end
        pending.party = members
        armed.hall = true
        return SourceEvents.dispatch(game, data.hall_of_fame.oak_id)
    elseif currentZone.stableID == "pokered:CHAMPIONS_ROOM"
        and not game.session:questFlag(data.champion.flag) then
        if armed.justWalked == data.champion.id then
            armed.justWalked = nil
            armed.champion = "fought"
            return SourceEvents.dispatch(game, data.champion.id, {mode = "script"})
        end
        if not armed.champion then
            armed.justWalked = data.champion.id
            armed.champion = "walk"
            return SourceEvents.dispatch(game, "pokered:CHAMPIONS_ROOM:script:entrance")
        end
    end
    for _, room in ipairs(data.elite_four) do
        if room.map ~= name then
            armed[room.id] = nil
        elseif not game.session:questFlag(room.flag) then
            local flags <const> = game.session:flags().quest
            if room.lock_coords and room.lock_event and at(room.lock_coords, x, y)
                and not flags[room.lock_event] then
                game.session:setQuestFlag(room.lock_event, true)
                EndgameStory.applyRoom(game)
            end
            if room.entrance then
                local action <const> = EndgameStory.entranceAction(room, x, y, flags)
                -- The six-step walk stops at y=5. Sight is 0, so the player
                -- talks once they are next to the trainer.
                if action == "autowalk" and not armed[room.id] then
                    if room.autowalk_event then
                        game.session:setQuestFlag(room.autowalk_event, true)
                    end
                    pending.x, pending.y, pending.dont_run = x, y, nil
                    armed[room.id] = "walked"
                    return SourceEvents.dispatch(game, scriptId(room))
                end
                if action == "dont-run" then
                    pending.dont_run = room.id
                    return SourceEvents.dispatch(game, scriptId(room))
                end
            elseif room.walk_coord then
                if EndgameStory.besideTrainer(room, x, y) and armed[room.id] ~= "fought" then
                    armed[room.id] = "fought"
                    return SourceEvents.dispatch(game, room.id, {mode = "talk"})
                end
                if x == room.walk_coord.x and y == room.walk_coord.y and armed.justWalked ~= room.id then
                    pending.dont_run = nil
                    armed.justWalked = room.id
                    return SourceEvents.dispatch(game, scriptId(room))
                end
                if armed.justWalked == room.id then
                    armed.justWalked = nil
                end
            end
        end
    end
    return false
end

local function trainerRow(row)
    return {id = row.id, map_id = row.map_id, name = row.name, sprite_source = row.sprite_source,
        sight_range_cells = row.sight or 0, talk_only = true, party = copy(row.party), payout = row.payout}
end

local function trainerEvent(row)
    return {kind = "trainer", content = CONTENT, before = copy(row.before), won = copy(row.won),
        after = copy(row.after), victory = {flags = {[row.flag] = true}, guard_flags = {row.flag}}}
end

function EndgameStory.install()
    local data <const> = story()
    local events = {}
    local trainers = {}
    local function addTrainer(row, event)
        trainers[row.id] = trainerRow(row)
        events[row.id] = event or trainerEvent(row)
    end
    local leader <const> = data.viridian_gym.leader
    local flags = {}
    local guards = {}
    local deactivate = {}
    for _, name in ipairs(leader.victory_flags) do
        flags[name] = true
        guards[#guards + 1] = name
    end
    for _, row in ipairs(data.viridian_gym.trainers) do
        flags[row.flag] = true
        guards[#guards + 1] = row.flag
        deactivate[row.id] = true
    end
    addTrainer(leader, {kind = "bespoke", content = CONTENT, before = copy(leader.before),
        won = copy(leader.won), after = copy(leader.after), item = leader.item,
        reward = {item = leader.item, flag = leader.reward_flag},
        victory = {flags = flags, trainers = deactivate, guard_flags = guards}})
    for _, row in ipairs(data.viridian_gym.trainers) do
        addTrainer(row)
    end
    for _, row in ipairs(data.victory_road.trainers) do
        addTrainer(row)
    end
    for _, row in ipairs(data.elite_four) do
        addTrainer(row)
    end
    local rival <const> = data.route22_rival
    local charmander <const> = rival.parties_by_player_starter.charmander
    trainers[rival.id] = {id = rival.id, map_id = rival.map_id, name = "BLUE",
        sprite_source = rival.sprite_source, sight_range_cells = 0, talk_only = true,
        party = copy(charmander.party), payout = charmander.payout,
        rival_parties = copy(rival.parties_by_player_starter)}
    local champ <const> = data.champion
    local champParty <const> = champ.parties_by_player_starter.charmander
    addTrainer({id = champ.id, map_id = champ.map_id, name = "BLUE", sprite_source = champ.sprite_source,
        sight = 0, party = champParty.party, payout = champParty.payout},
        {kind = "bespoke", content = CONTENT, before = copy(champ.before), won = copy(champ.won),
            after = copy(champ.after), lost = copy(champ.lost),
            victory = {flags = {[champ.flag] = true}, guard_flags = {champ.flag}}})
    trainers[champ.id].rival_parties = copy(champ.parties_by_player_starter)
    events["pokered:VIRIDIAN_CITY:script:gym-gate"] = {kind = "bespoke", content = CONTENT}
    events["pokered:VIRIDIAN_GYM:script:arrow"] = {kind = "bespoke", content = CONTENT}
    events["pokered:CHAMPIONS_ROOM:script:entrance"] = {kind = "bespoke", content = CONTENT}
    for _, room in ipairs(data.elite_four) do
        events[scriptId(room)] = {kind = "bespoke", content = CONTENT}
        if room.beat_event then
            local victory <const> = events[room.id].victory
            victory.flags[room.beat_event] = true
            victory.guard_flags[#victory.guard_flags + 1] = room.beat_event
        end
    end
    events["pokered:VICTORY_ROAD_3F:script:hole"] = {kind = "bespoke", content = CONTENT}
    events[MOLTRES] = {kind = "bespoke", content = CONTENT}
    events["pokered:CHAMPIONS_ROOM:objects:2"] = {kind = "bespoke", content = CONTENT}
    events["pokered:VIRIDIAN_GYM:objects:10"] = {kind = "cases", content = CONTENT, cases = {{
        when = {flags = {EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = true}},
        ["then"] = {kind = "program", steps = {{op = "dialog", labels = {"_ViridianGymGuidePostBattleText"}}}},
    }}, otherwise = {kind = "program", steps = {{op = "dialog", labels = {"_ViridianGymGuidePreBattleText"}}}}}
    -- The Route 22 league sign is already a cerulean program.
    events["pokered:ROUTE_23:background_events:1"] = {kind = "program", content = CONTENT,
        steps = {{op = "dialog", labels = {"_Route23VictoryRoadGateSignText"}}}}
    local pickups <const> = {
        {"pokered:VIRIDIAN_GYM:objects:11", "revive"},
        {"pokered:VICTORY_ROAD_1F:objects:3", "tm43"},
        {"pokered:VICTORY_ROAD_1F:objects:4", "rareCandy"},
        {"pokered:VICTORY_ROAD_2F:objects:7", "tm17"},
        {"pokered:VICTORY_ROAD_2F:objects:8", "fullHeal"},
        {"pokered:VICTORY_ROAD_2F:objects:9", "tm05"},
        {"pokered:VICTORY_ROAD_2F:objects:10", "guardSpec"},
        {"pokered:VICTORY_ROAD_3F:objects:5", "maxRevive"},
        {"pokered:VICTORY_ROAD_3F:objects:6", "tm47"},
    }
    for _, pickup in ipairs(pickups) do
        events[pickup[1]] = {kind = "pickup", content = CONTENT, item = pickup[2],
            flag = "PICKUP:" .. pickup[1], success = {"_FoundItemText"}, full = {"_NoMoreRoomForItemText"}}
    end
    local boulderText <const> = {{op = "dialog", labels = {"_BoulderText"}}}
    for _, boulder in ipairs({
        "pokered:VICTORY_ROAD_1F:objects:5", "pokered:VICTORY_ROAD_1F:objects:6", "pokered:VICTORY_ROAD_1F:objects:7",
        "pokered:VICTORY_ROAD_2F:objects:11", "pokered:VICTORY_ROAD_2F:objects:12", "pokered:VICTORY_ROAD_2F:objects:13",
        "pokered:VICTORY_ROAD_3F:objects:7", "pokered:VICTORY_ROAD_3F:objects:8", "pokered:VICTORY_ROAD_3F:objects:9",
        "pokered:VICTORY_ROAD_3F:objects:10",
    }) do
        events[boulder] = {kind = "program", content = CONTENT, steps = boulderText}
    end
    events["pokered:INDIGO_PLATEAU_LOBBY:objects:1"] = {kind = "program", content = CONTENT, steps = {{
        op = "heal", id = "IndigoPlateauLobby", nurse_id = "pokered:INDIGO_PLATEAU_LOBBY:objects:1",
        welcome = "_PokemonCenterWelcomeText", prompt = "_ShallWeHealYourPokemonText",
        before = "_NeedYourPokemonText", after = "_PokemonFightingFitText", farewell = "_PokemonCenterFarewellText",
        checkpoint = {facing = "down", x = 9, y = 6, zone_id = "pokered:INDIGO_PLATEAU"}}}}
    events["pokered:INDIGO_PLATEAU_LOBBY:objects:2"] = {kind = "program", content = CONTENT,
        steps = {{op = "dialog", labels = {"_IndigoPlateauLobbyGymGuideText"}}}}
    events["pokered:INDIGO_PLATEAU_LOBBY:objects:3"] = {kind = "program", content = CONTENT,
        steps = {{op = "dialog", labels = {"_IndigoPlateauLobbyCooltrainerFText"}}}}
    events["pokered:INDIGO_PLATEAU_LOBBY:objects:4"] = {kind = "program", content = CONTENT,
        steps = {{op = "shop", id = "indigoPlateauLobbyClerkText"}}}
    events["pokered:INDIGO_PLATEAU_LOBBY:objects:5"] = {kind = "program", content = CONTENT, steps = {
        {op = "dialog", labels = {"_CableClubNPCWelcomeText"}},
        {op = "dialog", labels = {"_CableClubNPCPleaseApplyHereHaveToSaveText"}}}}
    for _, guard in ipairs(data.route23.guards) do
        events[guard.id] = {kind = "bespoke", content = CONTENT}
    end
    events[data.hall_of_fame.oak_id] = {kind = "bespoke", content = CONTENT}
    events[data.route22_gate.id] = {kind = "bespoke", content = CONTENT}
    for id, event in pairs(events) do
        assert(not SourceEvents.has(id), "duplicate endgame event: " .. id)
        if event.kind == "bespoke" then
            local stable <const> = id
            SourceEventHandlers[id] = function(observation)
                return EndgameStory.plan(stable, observation)
            end
        end
    end
    SourceEvents.registerTextSource(CONTENT, EndgameStory.text)
    SourceEvents.registerEventSource(CONTENT, events)
    SourceEvents.registerTrainerSource(CONTENT, function()
        return trainers
    end)
    SourceEvents.registerWorldHooks("pokered:VIRIDIAN_CITY:script:gym-gate", {
        onEnter = function(game)
            EndgameStory.applyRoom(game)
        end,
        explore = EndgameStory.check,
    })
    if HideoutTowerController and not sceneWrapped then
        local previous <const> = HideoutTowerController.advance
        function HideoutTowerController.advance(state)
            if EndgameStory.advanceScene(state) then
                return true
            end
            return previous(state)
        end
        sceneWrapped = true
    end
end

function EndgameStory.actorMetadata(id)
    return {visibility = copy(VISIBILITY[id] or {})}
end

function EndgameStory.advanceScene(state)
    if not state.plan or state.plan.scene ~= "endgame" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if not state.endgameScene or state.endgameScene.epoch ~= state.epoch then
        state.endgameScene = {epoch = state.epoch, phase = "text"}
        if state.plan.scene_script == "moltres" then
            state:source({"_VictoryRoad2FMoltresBattleText"}, function()
                state:advance()
            end)
            return true
        end
        if state.plan.scene_script == "moltres-return" then
            if KantoScenes and KantoScenes.reconcileActors then
                KantoScenes.reconcileActors(state.game)
            end
            state:finish()
            return true
        end
        state:fail("unsupported-endgame-scene")
        return true
    end
    if state.plan.scene_script == "moltres" and state.endgameScene.phase == "text" then
        state.endgameScene.phase = "battle"
        local request <const> = EndgameStory.moltresRequest(state.session:flags().quest)
        local ok, reason = FieldBattle.startSourceEncounter(state.game, request)
        if not ok then
            state:fail(reason)
        end
    end
    return true
end
