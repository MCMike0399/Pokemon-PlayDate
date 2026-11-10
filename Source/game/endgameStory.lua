-- League story generated from pinned pokered. Decisions read story.json.
-- Badge writes happen only through Giovanni's confirmed victory.
EndgameStory = {}
local CONTENT <const> = "endgame"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached
local pending = {}
local armed = {}

local function story()
    if not cached then
        local data <const> = assert(json.decodeFile("data/endgame/story.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified endgame story")
        cached = data
    end
    return cached
end

function EndgameStory.story()
    return story()
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
    local row <const> = story().texts[label]
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

local function pointsOf(room)
    if room.entrance then
        return room.entrance
    end
    if room.walk_coord then
        return {room.walk_coord}
    end
    return {}
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
            return {status = "ready", steps = moves(room.walk_in or room.walk)}
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
        -- title. The hide flag is the in-memory session write. No save.
        steps[#steps + 1] = {op = "credits"}
        plan.steps = steps
        plan.return_to = hall.return_to
        plan.saves = false
        return plan
    end
    for _, guard in ipairs(data.route23.guards) do
        if id == guard.id then
            if observation.flags[guard.passed] then
                return {status = "already-complete", steps = {}}
            end
            if observation.flags[guard.badge] then
                return flagPlan(observation, {[guard.passed] = true}, data.route23.accepted_text)
            end
            return {status = "denied", steps = {
                {op = "dialog", labels = {data.route23.denied_text}},
                {op = "move", direction = "down", count = 1}}}
        end
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
            local closed <const> = game.session:questFlag(room.lock_event)
                and not game.session:questFlag(room.beat_event)
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
    elseif currentZone.stableID == "pokered:HALL_OF_FAME"
        and not game.session:questFlag(data.hall_of_fame.hides[1]) and not armed.hall then
        armed.hall = true
        return SourceEvents.dispatch(game, data.hall_of_fame.oak_id)
    elseif currentZone.stableID == "pokered:CHAMPIONS_ROOM"
        and not game.session:questFlag(data.champion.flag) then
        if armed.justWalked == data.champion.id then
            armed.justWalked = nil
            armed.champion = "fought"
            return SourceEvents.dispatch(game, data.champion.id, {mode = "sight"})
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
            if room.lock_coords and room.lock_event and at(room.lock_coords, x, y)
                and not game.session:questFlag(room.lock_event) then
                game.session:setQuestFlag(room.lock_event, true)
                EndgameStory.applyRoom(game)
            end
            local walked <const> = room.autowalk_event and game.session:questFlag(room.autowalk_event)
            if armed.justWalked == room.id then
                armed.justWalked = nil
                armed[room.id] = "fought"
                return SourceEvents.dispatch(game, room.id, {mode = "sight"})
            end
            if not walked and not armed[room.id] and at(pointsOf(room), x, y) then
                if room.autowalk_event then
                    game.session:setQuestFlag(room.autowalk_event, true)
                end
                if room.lock_event and not game.session:questFlag(room.lock_event) then
                    game.session:setQuestFlag(room.lock_event, true)
                    EndgameStory.applyRoom(game)
                end
                armed.justWalked = room.id
                return SourceEvents.dispatch(game, scriptId(room))
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
    for _, name in ipairs(leader.victory_flags) do
        flags[name] = true
    end
    addTrainer(leader, {kind = "trainer", content = CONTENT, before = copy(leader.before),
        won = copy(leader.won), after = copy(leader.after),
        reward = {item = leader.item, flag = leader.reward_flag, before = copy(leader.reward_before),
            success = copy(leader.reward_success), full = copy(leader.reward_full), full_status = "bag-full"},
        victory = {flags = flags, guard_flags = copy(leader.victory_flags)}})
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
        {kind = "trainer", content = CONTENT, before = copy(champ.before), won = copy(champ.won),
            after = copy(champ.after), lost = copy(champ.lost),
            victory = {flags = {[champ.flag] = true}, guard_flags = {champ.flag}}})
    trainers[champ.id].rival_parties = copy(champ.parties_by_player_starter)
    events["pokered:VIRIDIAN_CITY:script:gym-gate"] = {kind = "bespoke", content = CONTENT}
    events["pokered:VIRIDIAN_GYM:script:arrow"] = {kind = "bespoke", content = CONTENT}
    events["pokered:CHAMPIONS_ROOM:script:entrance"] = {kind = "bespoke", content = CONTENT}
    for _, room in ipairs(data.elite_four) do
        events[scriptId(room)] = {kind = "bespoke", content = CONTENT}
    end
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
end
