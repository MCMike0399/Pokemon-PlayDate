-- League story generated from pinned pokered. Decisions read story.json.
-- Badge writes happen only through Giovanni's confirmed victory.
EndgameStory = {}
local CONTENT <const> = "endgame"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local cached, playCached, visualCached, spriteCatalog
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

local function visual()
    if not visualCached then
        local data <const> = assert(json.decodeFile("data/endgame/visual.json"))
        assert(data.schema == 1 and data.source_revision == REVISION and type(data.blocks) == "table",
            "unverified endgame visual map")
        visualCached = data
    end
    return visualCached
end

local function endgameSprites()
    if not spriteCatalog then
        local data <const> = assert(json.decodeFile("data/zEndgame/sprites.json"))
        assert(data.schema == 1 and data.source_revision == REVISION, "unverified endgame sprites")
        spriteCatalog = data.sprites
    end
    return spriteCatalog
end

function EndgameStory.visual()
    return visual()
end

function EndgameStory.unmappedSprites()
    local names = {}
    for index, name in ipairs(visual().unmapped_sprites) do
        names[index] = name
    end
    return names
end

function EndgameStory.monTypes(species)
    local types <const> = visual().types[species]
    if not types then
        return {}
    end
    return {types[1], types[2]}
end

function EndgameStory.hallPhotoTiming()
    return visual().hall
end

function EndgameStory.hallPhotos(record)
    local photos = {}
    for _, mon in ipairs(record or {}) do
        photos[#photos + 1] = {kind = "pokemon", species = mon.species, level = mon.level,
            name = mon.name, types = EndgameStory.monTypes(mon.species), cry = mon.species,
            pic = "front"}
    end
    photos[#photos + 1] = {kind = "player", name = "RED", pic = "player"}
    return photos
end

-- PrintMonType is called at hlcoord 3, 9. The labels are HoFMonInfoText at
-- hlcoord 2, 6, and <NEXT> is double-spaced, so each type name lands on the
-- row under its TYPEn/ label. Equal types take EraseType2Text.
function EndgameStory.hallRows(photo)
    if not photo or photo.kind == "player" then
        return EndgameStory.playerHallRows(photo and photo.stats)
    end
    local types <const> = photo.types or {}
    local rows = {
        {text = photo.name or "", col = 1, row = 4},
        {text = "LEVEL/", col = 2, row = 6},
        {text = tostring(photo.level or ""), col = 8, row = 7},
        {text = "TYPE1/", col = 2, row = 8},
        {text = types[1] or "", col = 3, row = 9},
    }
    if types[2] and types[2] ~= types[1] then
        rows[#rows + 1] = {text = "TYPE2/", col = 2, row = 10}
        rows[#rows + 1] = {text = types[2], col = 3, row = 11}
    end
    return rows
end

function EndgameStory.hallCaptionRow()
    return {text = "HALL OF FAME", col = 4, row = 15}
end

function EndgameStory.hallCaptionDue(clock)
    return clock > visual().hall.mon_delay
end

-- DMG ScrollPic, not the SGB sla. DelayFrame shows the current hSCX, then
-- the step is added. The loop returns once the add lands on the target, so
-- that target is the hold and is not itself a scroll frame.
-- Back: hSCX $c0 step +4 until $a0, hSCY stays $d0. Front: hSCY cleared,
-- hSCX $a0 step -4 until 0. The pic tiles stay at hlcoord 12, 5.
function EndgameStory.hallScrollSpec(which)
    if which == "back" then
        return {pic = "back", scx = 0xc0, scy = 0xd0, step = 4, target = 0xa0}
    end
    return {pic = "front", scx = 0xa0, scy = 0x00, step = -4, target = 0x00}
end

function EndgameStory.hallScrollFrames(which)
    local spec <const> = EndgameStory.hallScrollSpec(which)
    local scx = spec.scx
    local frames = 0
    repeat
        frames = frames + 1
        scx = (scx + spec.step) % 256
    until scx == spec.target
    return frames
end

function EndgameStory.hallPicOrigin(scx, scy)
    -- Tile (12, 5) is map pixel (96, 40). Coords past the right edge stay
    -- positive; coords that wrapped past the left edge become negative.
    local x = (96 - scx) % 256
    local y = (40 - scy) % 256
    if x > 160 then
        x = x - 256
    end
    if y > 144 then
        y = y - 256
    end
    return x, y
end

function EndgameStory.hallScrollFrame(which, index)
    local spec <const> = EndgameStory.hallScrollSpec(which)
    local scx = spec.scx
    for _ = 2, index do
        scx = (scx + spec.step) % 256
    end
    local x, y = EndgameStory.hallPicOrigin(scx, spec.scy)
    return {pic = spec.pic, scx = scx, scy = spec.scy, x = x, y = y}
end

function EndgameStory.hallRest()
    return {pic = "front", scx = 0, scy = 0, x = 96, y = 40}
end

-- Red's card uses these paths once both open. Until then it uses the overworld grid.
local RED_PIC_FRONT <const> = "images/player/red-pic-front"
local RED_PIC_BACK <const> = "images/player/red-pic-back"
local redHallPics = nil

local function redPicOpens(path)
    local imageNew = playdate and playdate.graphics and playdate.graphics.image and playdate.graphics.image.new
    if not imageNew then
        return false
    end
    local ok, image = pcall(imageNew, path)
    return ok and image ~= nil
end

function EndgameStory.playerHallPics(opens)
    local ready = false
    if opens then
        ready = opens(RED_PIC_FRONT) and opens(RED_PIC_BACK)
    elseif redHallPics then
        return redHallPics
    else
        ready = redPicOpens(RED_PIC_FRONT) and redPicOpens(RED_PIC_BACK)
        redHallPics = ready and {source = "RedPicFront", front = RED_PIC_FRONT, back = RED_PIC_BACK}
            or {source = "overworld"}
        return redHallPics
    end
    if ready then
        return {source = "RedPicFront", front = RED_PIC_FRONT, back = RED_PIC_BACK}
    end
    return {source = "overworld"}
end

function EndgameStory.hallView()
    -- 2x Game Boy screen, shifted up so the row-15 caption fits in 240px.
    return {scale = 2, x = 40, y = -48, width = 160, height = 144}
end

function EndgameStory.hallPixel(gbX, gbY)
    local view <const> = EndgameStory.hallView()
    return view.x + gbX * view.scale, view.y + gbY * view.scale
end

function EndgameStory.hallBoxes()
    return {
        info = {col = 0, row = 2, width = 12, height = 11},
        caption = {col = 2, row = 13, width = 16, height = 5},
        -- HoFDisplayPlayerStats. The name box is hlcoord 5, 0 b=2 c=9.
        -- The stats box is hlcoord 0, 4 b=6 c=10. No HALL OF FAME box.
        playerName = {col = 5, row = 0, width = 11, height = 4},
        playerStats = {col = 0, row = 4, width = 12, height = 8},
    }
end

-- PrintNumber hours: 1 byte, 3 digits, right aligned, no leading zeroes.
-- Minutes: LEADING_ZEROES, 2 digits. Tile $6d between them is ":".
function EndgameStory.formatPlayTime(hours, minutes)
    hours = math.floor(hours or 0)
    minutes = math.floor(minutes or 0)
    if hours < 0 then hours = 0 elseif hours > 255 then hours = 255 end
    if minutes < 0 then minutes = 0 elseif minutes > 59 then minutes = 59 end
    return string.format("%3d:%02d", hours, minutes)
end

-- PrintBCDNumber, 3 bytes, LEADING_ZEROES suppresses zeroes, MONEY_SIGN prints
-- ¥ on the first non-zero digit. Suppressed digits stay spaces.
function EndgameStory.formatMoney(amount)
    amount = math.floor(amount or 0)
    if amount < 0 then amount = 0 elseif amount > 999999 then amount = 999999 end
    local digits <const> = string.format("%06d", amount)
    local parts = {}
    local started = false
    for index = 1, 6 do
        local digit <const> = digits:sub(index, index)
        if digit == "0" and not started then
            parts[#parts + 1] = " "
        else
            if not started then
                parts[#parts + 1] = "¥"
                started = true
            end
            parts[#parts + 1] = digit
        end
    end
    if not started then
        return "     ¥0"
    end
    return table.concat(parts)
end

-- DisplayDexRating's table: owned < threshold selects that paragraph.
-- Hall of Fame sets EVENT_HALL_OF_FAME_DEX_RATING first, so the text is
-- copied to wDexRatingText instead of the Oak's Lab completion screen.
local DEX_RATINGS <const> = {
    {10, "You still have\nlots to do.\nLook for POKéMON\nin grassy areas!"},
    {20, "You're on the\nright track! \nGet a FLASH HM\nfrom my AIDE!"},
    {30, "You still need\nmore POKéMON!\nTry to catch\nother species!"},
    {40, "Good, you're\ntrying hard!\nGet an ITEMFINDER\nfrom my AIDE!"},
    {50, "Looking good!\nGo find my AIDE\nwhen you get 50!"},
    {60, "You finally got at\nleast 50 species!\nBe sure to get\nEXP.ALL from my\nAIDE!"},
    {70, "Ho! This is geting\neven better!"},
    {80, "Very good!\nGo fish for some\nmarine POKéMON!"},
    {90, "Wonderful!\nDo you like to\ncollect things?"},
    {100, "I'm impressed!\nIt must have been\ndifficult to do!"},
    {110, "You finally got at\nleast 100 species!\nI can't believe\nhow good you are!"},
    {120, "You even have the\nevolved forms of\nPOKéMON! Super!"},
    {130, "Excellent! Trade\nwith friends to\nget some more!"},
    {140, "Outstanding!\nYou've become a\nreal pro at this!"},
    {150, "I have nothing\nleft to say!\nYou're the\nauthority now!"},
    {152, "Your POKéDEX is\nentirely complete!\nCongratulations!"},
}

function EndgameStory.dexRating(owned)
    owned = math.floor(owned or 0)
    for _, row in ipairs(DEX_RATINGS) do
        if owned < row[1] then
            return row[2]
        end
    end
    return DEX_RATINGS[#DEX_RATINGS][2]
end

function EndgameStory.playerHallRows(stats)
    stats = stats or {}
    return {
        {text = stats.name or "RED", col = 7, row = 2},
        {text = "PLAY TIME", col = 1, row = 6},
        {text = EndgameStory.formatPlayTime(stats.hours, stats.minutes), col = 5, row = 7},
        {text = "MONEY", col = 1, row = 9},
        {text = EndgameStory.formatMoney(stats.money), col = 4, row = 10},
    }
end

-- HoFPrintTextAndDelay is 120 frames. Order is DexSeenOwnedText, then
-- DexRatingText, then the wDexRatingText paragraph copied by DisplayDexRating.
function EndgameStory.countFlags(flags)
    local count = 0
    for _, set in pairs(flags or {}) do
        if set then
            count = count + 1
        end
    end
    return count
end

-- wPlayTimeHours/Minutes have no session field yet, so those stay 0 until
-- a clock exists. Money and the dex counts come from the live session.
function EndgameStory.playerHallStats(session)
    local stats = {name = "RED", hours = 0, minutes = 0, money = 0, seen = 0, owned = 0}
    if not session then
        return stats
    end
    if session.title then
        local title <const> = session:title()
        if title and title.playerName then
            stats.name = title.playerName
        end
    end
    if session.inventory then
        local inventory <const> = session:inventory()
        if inventory and inventory.money then
            stats.money = inventory:money()
        end
    end
    if session.pokedex then
        local dex <const> = session:pokedex()
        if dex then
            stats.seen = EndgameStory.countFlags(dex.seen)
            stats.owned = EndgameStory.countFlags(dex.owned)
        end
    end
    if session.playTime then
        local time <const> = session:playTime()
        stats.hours = time.hours or 0
        stats.minutes = time.minutes or 0
    end
    return stats
end

function EndgameStory.playerHallPages(stats)
    stats = stats or {}
    local seen <const> = math.floor(stats.seen or 0)
    local owned <const> = math.floor(stats.owned or 0)
    return {
        {delay = 120, text = "POKéDEX   Seen:" .. tostring(seen) .. "\n         Owned:" .. tostring(owned)},
        {delay = 120, text = "POKéDEX Rating:"},
        {delay = 120, text = EndgameStory.dexRating(owned)},
    }
end

-- The HALL OF FAME box is drawn inside the party loop only, after the
-- 80-frame hold. HoFDisplayPlayerStats never draws it.
function EndgameStory.hallShowsCaption(photo, stage, clock)
    return photo and photo.kind == "pokemon" and (stage == "fade" or EndgameStory.hallCaptionDue(clock))
end

function EndgameStory.blockKeys(tileset, blockId)
    local rows <const> = visual().blocks[tileset]
    return rows and rows[tostring(blockId)]
end

local SPIN_FACING <const> = {down = "left", left = "up", up = "right", right = "down"}

function EndgameStory.spinnerFacing(facing)
    return assert(SPIN_FACING[facing], "spinner facing")
end

function EndgameStory.exclamation(id)
    local data <const> = story()
    if id == data.champion.id or id == data.route22_rival.id or id == data.viridian_gym.leader.id then
        return false
    end
    for _, room in ipairs(data.elite_four) do
        if id == room.id then
            return false
        end
    end
    return nil
end

function EndgameStory.oakCells()
    -- Source column x = 3. Champions Room adds two columns of padding, so the
    -- runtime object and its warps sit at x = 5. The host probe has no map table.
    local pad = 0
    if SourceMaps and SourceMaps.entry then
        local ok, entry = pcall(SourceMaps.entry, "ChampionsRoom")
        if ok and entry and entry.padding then
            pad = entry.padding
        end
    end
    local x = 3 + pad
    local cells = {}
    for y = 6, 1, -1 do
        cells[#cells + 1] = {x = x, y = y}
    end
    -- (3, 7) and (3, 0) are warps. They stay unlisted until the movement
    -- engine grants Oak transit across those two cells.
    if SourceActors and SourceActors.championsOakMayCrossWarp then
        cells[#cells + 1] = {x = x, y = 7}
        cells[#cells + 1] = {x = x, y = 0}
    end
    return cells
end

function EndgameStory.playCue(name)
    if type(name) ~= "string" or not KantoAudio or not KantoAudio.playSFX then
        return false
    end
    return pcall(KantoAudio.playSFX, name) == true
end

function EndgameStory.playCry(species)
    if type(species) ~= "string" or not KantoAudio or not KantoAudio.playCry then
        return false
    end
    return pcall(KantoAudio.playCry, species) == true
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
            local fade <const> = visual().fade
            plan.disappear = {flag = GIOVANNI_HIDE, fade_out_steps = fade.out_steps,
                fade_frames = fade.frames, delay = fade.delay, fade_in_steps = fade.in_steps}
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
        -- OakEntranceAfterVictoryMovement is five ups from the warp at (3, 7).
        -- WalkToHallOfFame_RLEMovement is up 4, left 1. The third up lands on
        -- the hall warp at (4, 0); pokered warps there and drops the rest.
        -- Simulated joypad movement ignores sprite collision. The engine does
        -- not, until the lane A patch, so a blocked step still warps.
        plan.oakWalk = true
        plan.simulated = true
        plan.showOak = OAK_SHOW
        plan.follow = {{direction = "up", count = 4}, {direction = "left", count = 1}}
        local oak <const> = "pokered:CHAMPIONS_ROOM:objects:2"
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = copy(champ.after)}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakText"}}
        plan.steps[#plan.steps + 1] = {op = "move-npc", id = oak, direction = "up", count = 5}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakCongratulatesPlayerText"},
            face_player = "left", face = {{id = id, direction = "left"}, {id = oak, direction = "down"}}}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakDisappointedWithRivalText"},
            face = {{id = oak, direction = "right"}}}
        plan.steps[#plan.steps + 1] = {op = "dialog", labels = {"_ChampionsRoomOakComeWithMeText"},
            face = {{id = oak, direction = "down"}}}
        plan.steps[#plan.steps + 1] = {op = "move-npc", id = oak, direction = "up", count = 2}
        plan.steps[#plan.steps + 1] = {op = "move", direction = "up", count = 3}
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
    return {status = "ready", scene = "endgame", scene_script = "moltres", cry = "moltres", steps = {}}
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
        local spin <const> = visual().spinner
        return {status = "ready", spin = true,
            audio = {source = spin.source, name = spin.score, when = "start"},
            steps = moves(steps)}
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
            return {status = "ready", steps = approachWalk(room, pending.x)}
        end
    end
    local gate <const> = data.route22_gate
    if id == gate.id then
        if observation.flags[gate.badge] then
            return {status = "ready", steps = {{op = "dialog", labels = gate.accepted_text}}}
        end
        local denied <const> = visual().denied
        return {status = "denied", steps = {
            {op = "dialog", labels = {gate.denied_text[1]}},
            {op = "dialog", labels = {gate.denied_text[2]}, audio = {source = denied.source, name = denied.score}},
            {op = "move", direction = "down", count = 1}}}
    end
    local hall <const> = data.hall_of_fame
    if id == hall.oak_id then
        local writes = {[hall.hides[1]] = true}
        for _, name in ipairs(INDIGO_RESET) do
            writes[name] = false
        end
        local plan <const> = flagPlan(observation, writes, {hall.oak_text})
        local steps <const> = moves(hall.walk)
        steps[#steps + 1] = plan.steps[1]
        -- HallOfFamePC records the party, resets the Indigo range, sets the
        -- blackout map to Pallet Town, saves, plays the credits, then Init.
        steps[#steps + 1] = {op = "credits"}
        plan.steps = steps
        plan.return_to = hall.return_to
        plan.saves = true
        assert(hall.blackout_map == "PALLET_TOWN", "hall of fame blackout map")
        plan.blackout = {zone_id = "pokered:PALLET_TOWN", x = 3, y = 17, facing = "up"}
        if pending.party then
            plan.record = EndgameStory.hallRecord(pending.party)
            pending.party = nil
        end
        -- AnimateHallOfFame shows every party Pokémon, then Red, then the credits.
        plan.photos = EndgameStory.hallPhotos(plan.record)
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
            local denied <const> = visual().denied
            return {status = "denied", ram = ram, steps = {
                {op = "dialog", labels = {data.route23.denied_text}},
                {op = "move", direction = "down", count = 1, audio = {source = denied.source, name = denied.score}}}}
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

local DOORS <const> = {
    LoreleisRoom = {tileset = "GYM", open = 5, closed = 36},
    BrunosRoom = {tileset = "GYM", open = 5, closed = 36},
    AgathasRoom = {tileset = "CEMETERY", open = 14, closed = 59},
}
local LANCE_BLOCKS <const> = {tileset = "DOJO", open = {49, 50}, closed = {114, 115}}
local tileOverlays = {}

function EndgameStory.clearOverlay(zone, x, y)
    local id <const> = tostring(zone) .. ":" .. x .. ":" .. y
    local sprite <const> = tileOverlays[id]
    if sprite then
        sprite:remove()
        tileOverlays[id] = nil
    end
end

function EndgameStory.overlayMissing(zone, x, y, key)
    local record <const> = visual().missing_tiles[key]
    local gfx <const> = playdate and playdate.graphics
    if not record or not gfx or not SpriteFactory then
        return
    end
    EndgameStory.clearOverlay(zone, x, y)
    local image <const> = SpriteFactory.makeSprite(record.grid, {0, 0})
    local sprite <const> = gfx.sprite.new(image)
    local size <const> = TILE_SIZE or 32
    sprite:setCenter(0, 0)
    sprite:moveTo(x * size, y * size)
    sprite:setZIndex(20)
    sprite:add()
    tileOverlays[tostring(zone) .. ":" .. x .. ":" .. y] = sprite
end

local function paintBlock(zone, block, padding, keys)
    if not keys or not zone.setTile then
        return
    end
    local places <const> = {{0, 0, 1}, {1, 0, 2}, {0, 1, 3}, {1, 1, 4}}
    for _, place in ipairs(places) do
        local x <const> = block.x * 2 + place[1] + padding
        local y <const> = block.y * 2 + place[2]
        local key <const> = keys[place[3]]
        local ok <const> = pcall(function()
            zone:setTile(x, y, key)
        end)
        if ok then
            EndgameStory.clearOverlay(zone, x, y)
        else
            EndgameStory.overlayMissing(zone, x, y, key)
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
            paintBlock(zone, switch.block, padding, EndgameStory.blockKeys("CAVERN", switch.tile))
            setBlock(zone, switch.block, padding, 0)
        end
    end
    for _, room in ipairs(data.elite_four) do
        if room.map == name and room.exit_block then
            local open <const> = game.session:questFlag(room.flag) == true
            local door <const> = DOORS[name]
            if door then
                paintBlock(zone, room.exit_block, padding,
                    EndgameStory.blockKeys(door.tileset, open and door.open or door.closed))
            end
            setBlock(zone, room.exit_block, padding, open and 0 or 1)
        end
        if room.map == name and room.entrance_blocks then
            -- Map load closes the door whenever the lock flag is set. Beating
            -- Lance does not reopen it; the north warp is the way forward.
            local closed <const> = game.session:questFlag(room.lock_event)
            local ids <const> = closed and LANCE_BLOCKS.closed or LANCE_BLOCKS.open
            for index, block in ipairs(room.entrance_blocks) do
                paintBlock(zone, block, padding, EndgameStory.blockKeys(LANCE_BLOCKS.tileset, ids[index]))
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
        local padding <const> = entry and entry.padding or 0
        if switch.tile then
            paintBlock(currentZone, switch.block, padding, EndgameStory.blockKeys("CAVERN", switch.tile))
        end
        setBlock(currentZone, switch.block, padding, 0)
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

local function unmapped(source)
    for _, name in ipairs(visual().unmapped_sprites) do
        if name == source then
            return true
        end
    end
    return false
end

local artPrepared = false

function EndgameStory.prepareArt()
    if artPrepared then
        return
    end
    assert(CeruleanContent and SpriteFactory, "endgame art is installed with the source actors")
    local originalKey <const> = CeruleanContent.key
    local originalPose <const> = CeruleanContent.poseImage
    local originalSprite <const> = CeruleanContent.sprite
    local originalMeta <const> = CeruleanContent._spritePoseMetadata
    local originalStep <const> = CeruleanContent.stepImage

    function CeruleanContent.key(source)
        if unmapped(source) then
            return "endgame_" .. source:lower()
        end
        return originalKey(source)
    end

    function CeruleanContent.poseImage(source, pose, facing)
        if not unmapped(source) then
            return originalPose(source, pose, facing)
        end
        local strip <const> = assert(endgameSprites()[source], "missing endgame sprite")
        local direction <const> = facing == "right" and "left" or facing
        local index <const> = (pose == "stand" and strip.standing or strip.walking)[direction]
        local grid <const> = assert(strip.frames[tostring(index)], "missing endgame sprite frame")
        local image = SpriteFactory.makeSprite(grid, {0, 0})
        if facing == "right" or pose == "alternate" and (facing == "down" or facing == "up") then
            image = SpriteFactory.flipped(image)
        end
        return image
    end

    function CeruleanContent.sprite(source)
        if not unmapped(source) then
            return originalSprite(source)
        end
        return copy(assert(endgameSprites()[source], "missing endgame sprite"))
    end

    function CeruleanContent._spritePoseMetadata(source)
        if not unmapped(source) then
            return originalMeta(source)
        end
        local strip <const> = assert(endgameSprites()[source], "missing endgame sprite")
        return {standing = copy(strip.standing), fixed = strip.fixed}
    end

    function CeruleanContent.stepImage(source, facing, tick)
        if not unmapped(source) then
            return originalStep(source, facing, tick)
        end
        local pose <const> = CeruleanContent.poseAtTick(tick)
        return CeruleanContent.poseImage(source, pose == "stand" and "stand" or pose, facing)
    end

    artPrepared = true
end

function EndgameStory.setShown(state, name, value)
    if state.session and state.session.setQuestFlag then
        state.session:setQuestFlag(name, value)
    end
    if KantoScenes and KantoScenes.reconcileActors and state.game then
        KantoScenes.reconcileActors(state.game)
    end
end

function EndgameStory.applyFacing(state, step)
    if not step then
        return
    end
    if step.face_player and state.player then
        state.player.facing = step.face_player
        if state.player.updateSprite then
            state.player:updateSprite()
        end
    end
    for _, pose in ipairs(step.face or {}) do
        local manager = state.game and state.game.npcManager
        if manager then
            for _, npc in ipairs(manager.npcs) do
                if npc.def and npc.def.source_event_id == pose.id and npc.setFacing then
                    npc:setFacing(pose.direction)
                end
            end
        end
    end
end

function EndgameStory.skipBlockedMove(state, advance)
    -- One blocked cell would fail the whole champion ending. Skip the rest of
    -- this simulated walk and keep the dialogue and the hall warp.
    while state.ops[state.index] and (state.ops[state.index].op == "move"
        or state.ops[state.index].op == "move-npc") do
        state.index = state.index + 1
    end
    state.phase = "running"
    state.waiting = "none"
    if state.ops[state.index] then
        advance(state)
    end
end

function EndgameStory.beginPhotos(state, advance)
    state.photoAdvance = advance
    state.photo = {index = 1, clock = 0, stage = "preamble"}
    state.phase = "hall-photo"
    state.waiting = "hall-of-fame"
    -- pokered engine/movie/hall_of_fame.asm AnimateHallOfFame plays
    -- MUSIC_HALL_OF_FAME before the party photo loop.
    if KantoAudio and KantoAudio.playCue then KantoAudio.playCue("hall_of_fame") end
end

function EndgameStory.updatePhotos(state)
    local timing <const> = visual().hall
    local photo <const> = state.photo
    photo.clock = photo.clock + 1
    if photo.stage == "preamble" and photo.clock > timing.preamble then
        photo.stage = "scroll-back"
        photo.clock = 1
    elseif photo.stage == "scroll-back" and photo.clock > EndgameStory.hallScrollFrames("back") then
        photo.stage = "scroll-front"
        photo.clock = 1
    elseif photo.stage == "scroll-front" and photo.clock > EndgameStory.hallScrollFrames("front") then
        -- Name, level, types, and the cry start only once both scrolls return.
        photo.stage = "show"
        photo.clock = 1
        local entry <const> = state.plan.photos[photo.index]
        if entry and entry.kind == "player" then
            if not entry.stats then
                entry.stats = EndgameStory.playerHallStats(state.session)
            end
            photo.page = 1
            photo.dexRating = "EVENT_HALL_OF_FAME_DEX_RATING"
            if state.session and state.session.setQuestFlag then
                -- SetEvent, then CheckAndResetEventA inside DisplayDexRating.
                -- The paragraph is chosen and the flag does not stay set.
                state.session:setQuestFlag(photo.dexRating, true)
                state.session:setQuestFlag(photo.dexRating, false)
            end
        end
        if entry and entry.cry then
            -- pokered HoFDisplayMonInfo ends in PlayCry once the name,
            -- level, and types are on screen.
            if KantoAudio and KantoAudio.playCry then
                KantoAudio.playCry(entry.cry)
            else
                EndgameStory.playCry(entry.cry)
            end
        end
    elseif photo.stage == "show" and state.plan.photos[photo.index]
        and state.plan.photos[photo.index].kind == "player" and photo.clock > 120 then
        local page <const> = photo.page or 1
        if page >= 3 then
            photo.stage = "fade"
            photo.clock = 1
        else
            photo.page = page + 1
            photo.clock = 1
        end
    elseif photo.stage == "show" and photo.clock > timing.mon_delay + timing.caption then
        photo.stage = "fade"
        photo.clock = 1
    elseif photo.stage == "fade" and photo.clock > timing.fade_white then
        photo.index = photo.index + 1
        if photo.index > #state.plan.photos then
            state.photosDone = true
            state.phase = "running"
            state.waiting = "none"
            local advance <const> = state.photoAdvance
            state.photo = nil
            if advance then
                advance(state)
            end
            return
        end
        photo.stage = "scroll-back"
        photo.clock = 1
    end
end

function EndgameStory.beginDisappear(state)
    state.phase = "giovanni-fade"
    state.waiting = state.plan.disappear.flag
    state.fadeClock = 0
end

function EndgameStory.updateDisappear(state, commit)
    local fade <const> = visual().fade
    state.fadeClock = (state.fadeClock or 0) + 1
    local outFrames <const> = fade.out_steps * fade.frames
    local inFrames <const> = fade.in_steps * fade.frames
    if not state.fadeHid and state.fadeClock >= outFrames then
        state.fadeHid = true
        if state.plan.expected and state.session and state.session.transact then
            local ok, reason = state.session:transact(state.plan.expected, state.plan.changes)
            if not ok then
                state:fail(reason)
                return
            end
            state.committed = true
            state.plan.expected = nil
            state.plan.changes = nil
            if KantoScenes and KantoScenes.reconcileActors then
                KantoScenes.reconcileActors(state.game)
            end
        end
    end
    if state.fadeClock >= outFrames + fade.delay + inFrames then
        state.phase = "running"
        commit(state)
    end
end

function EndgameStory.drawFade(gfx, state)
    local fade <const> = visual().fade
    local clock <const> = state.fadeClock or 0
    local step
    if not state.fadeHid then
        step = math.min(fade.out_steps, math.floor(clock / fade.frames) + 1)
    else
        local into <const> = clock - fade.out_steps * fade.frames - fade.delay
        step = math.max(1, fade.in_steps - math.floor(math.max(into, 0) / fade.frames))
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    if step >= fade.out_steps then
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    elseif step >= 3 and Shade then
        gfx.setPattern(Shade.DARK)
        gfx.fillRect(0, 0, 400, 240)
    elseif step >= 2 and Shade then
        gfx.setPattern(Shade.LIGHT)
        gfx.fillRect(0, 0, 400, 240)
    end
    gfx.popContext()
end

local function photoImage(gfx, state, photo, which)
    if photo.kind == "player" then
        local pics <const> = EndgameStory.playerHallPics()
        if pics.source == "RedPicFront" and gfx.image then
            local path <const> = which == "back" and pics.back or pics.front
            local ok, image = pcall(gfx.image.new, path)
            if ok then
                return image
            end
        end
        if state.player and state.player.getImage then
            return state.player:getImage()
        end
        return nil
    end
    if PokemonArt and gfx.image then
        local ok, image = pcall(gfx.image.new, PokemonArt.path(photo.species, which))
        if ok then
            return image
        end
    end
    return nil
end

local function blitHallPic(gfx, image, gbX, gbY)
    if not image then
        return
    end
    local px, py = EndgameStory.hallPixel(gbX, gbY)
    local scale <const> = EndgameStory.hallView().scale
    if image.drawScaled then
        image:drawScaled(px, py, scale)
    else
        image:draw(px, py)
    end
end

local function drawHallBox(gfx, box)
    local px, py = EndgameStory.hallPixel(box.col * 8, box.row * 8)
    local scale <const> = EndgameStory.hallView().scale
    gfx.drawRect(px, py, box.width * 8 * scale, box.height * 8 * scale)
end

function EndgameStory.drawPhoto(gfx, state)
    local photo = state.photo and state.plan.photos[state.photo.index]
    local view <const> = EndgameStory.hallView()
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.setFont(gfx.getSystemFont())
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)
    if not photo or state.photo.stage == "preamble" then
        gfx.popContext()
        return
    end
    gfx.setClipRect(view.x, 0, view.width * view.scale, 240)
    local stage <const> = state.photo.stage
    if stage == "scroll-back" or stage == "scroll-front" then
        local which <const> = stage == "scroll-back" and "back" or "front"
        local frame <const> = EndgameStory.hallScrollFrame(which, state.photo.clock)
        blitHallPic(gfx, photoImage(gfx, state, photo, frame.pic), frame.x, frame.y)
        gfx.popContext()
        return
    end
    local rest <const> = EndgameStory.hallRest()
    blitHallPic(gfx, photoImage(gfx, state, photo, rest.pic), rest.x, rest.y)
    local boxes <const> = EndgameStory.hallBoxes()
    if photo.kind == "pokemon" then
        drawHallBox(gfx, boxes.info)
    elseif photo.kind == "player" then
        drawHallBox(gfx, boxes.playerName)
        drawHallBox(gfx, boxes.playerStats)
    end
    for _, row in ipairs(EndgameStory.hallRows(photo)) do
        local px, py = EndgameStory.hallPixel(row.col * 8, row.row * 8)
        gfx.drawText(row.text, px, py)
    end
    if photo.kind == "player" then
        local pages <const> = EndgameStory.playerHallPages(photo.stats)
        local page <const> = pages[state.photo.page or 1]
        if page then
            local px, py = EndgameStory.hallPixel(8, 13 * 8)
            gfx.drawText(page.text, px, py)
        end
    elseif EndgameStory.hallShowsCaption(photo, stage, state.photo.clock) then
        local caption <const> = EndgameStory.hallCaptionRow()
        drawHallBox(gfx, boxes.caption)
        local px, py = EndgameStory.hallPixel(caption.col * 8, caption.row * 8)
        gfx.drawText(caption.text, px, py)
    end
    if stage == "fade" and Shade then
        gfx.clearClipRect()
        gfx.setPattern(Shade.LIGHT)
        gfx.fillRect(0, 0, 400, 240)
    end
    gfx.popContext()
end

function EndgameStory.drawOverlay(state)
    local gfx <const> = playdate and playdate.graphics
    if not gfx then
        return
    end
    if state.phase == "giovanni-fade" then
        EndgameStory.drawFade(gfx, state)
    elseif state.phase == "hall-photo" then
        EndgameStory.drawPhoto(gfx, state)
    end
end

function EndgameStory.clearSpin(state)
    for _, sprite in ipairs(state.spinSprites or {}) do
        sprite:remove()
    end
    state.spinSprites = nil
end

function EndgameStory.showSpinner(state, anim)
    EndgameStory.clearSpin(state)
    local gfx <const> = playdate and playdate.graphics
    if not gfx or not SpriteFactory then
        return
    end
    local size <const> = TILE_SIZE or 32
    state.spinSprites = {}
    for _, cell in ipairs(visual().spinner.cells) do
        local image <const> = SpriteFactory.makeSprite(anim and cell.after or cell.before, {0, 0})
        local sprite <const> = gfx.sprite.new(image)
        sprite:setCenter(0, 0)
        sprite:moveTo(cell.x * size, cell.y * size)
        sprite:setZIndex(40)
        sprite:add()
        state.spinSprites[#state.spinSprites + 1] = sprite
    end
end

function EndgameStory.spinTick(state)
    local player <const> = state.player
    if player and player.facing then
        player.facing = EndgameStory.spinnerFacing(player.facing)
        if player.updateSprite then
            player:updateSprite()
        end
    end
    local remaining = 0
    for index = state.index, #(state.ops or {}) do
        if state.ops[index].op == "move" then
            remaining = remaining + 1
        end
    end
    local anim <const> = remaining % 2 == 1
    if state.spinAnim ~= anim then
        state.spinAnim = anim
        EndgameStory.showSpinner(state, anim)
    end
end

function EndgameStory.interceptAdvance(state, advance)
    local step = state.ops and state.ops[state.index]
    if not step or not state.plan then
        return false
    end
    if step.audio and step.audio.name then
        -- Route 22's gate uses SFX_DENIED. Arrow-tile scripts use
        -- SFX_ARROW_TILES. Both are installed Kanto cues.
        if KantoAudio and KantoAudio.playCue and (step.audio.name == "denied" or step.audio.name == "arrow_tiles") then
            KantoAudio.playCue(step.audio.name)
        else
            EndgameStory.playCue(step.audio.name)
        end
    end
    if state.plan.spin and step.op == "move" and not state.spinStarted then
        state.spinStarted = true
        if state.plan.audio then
            if KantoAudio and KantoAudio.playCue then
                KantoAudio.playCue(state.plan.audio.name)
            else
                EndgameStory.playCue(state.plan.audio.name)
            end
        end
    end
    if step.op == "credits" and state.plan.photos and not state.photosDone then
        EndgameStory.beginPhotos(state, advance)
        return true
    end
    EndgameStory.applyFacing(state, step)
    if step.op == "move-npc" and state.plan.showOak and not state.oakShown then
        state.oakShown = true
        EndgameStory.setShown(state, state.plan.showOak, true)
    end
    if step.op == "move" and state.plan.oakWalk and state.oakShown and not state.oakHidden then
        state.oakHidden = true
        EndgameStory.setShown(state, state.plan.showOak, false)
    end
    return false
end

function EndgameStory.interceptUpdate(state, commit)
    if state.phase == "hall-photo" then
        EndgameStory.updatePhotos(state)
        return true
    end
    if state.phase == "giovanni-fade" then
        EndgameStory.updateDisappear(state, commit)
        return true
    end
    return false
end

local eventWrapped = false

local function wrapEvents()
    if eventWrapped or not EventState then
        return
    end
    eventWrapped = true
    local advance <const> = EventState.advance
    local update <const> = EventState.update
    local commit <const> = EventState.commit
    local draw <const> = EventState.draw
    function EventState:advance()
        if EndgameStory.interceptAdvance(self, advance) then
            return
        end
        advance(self)
        if self.phase == "failed" and self.plan and self.plan.oakWalk then
            EndgameStory.skipBlockedMove(self, advance)
        end
    end
    function EventState:update()
        if EndgameStory.interceptUpdate(self, commit) then
            return
        end
        update(self)
        if self.plan and self.plan.spin then
            if self.phase == "move" then
                EndgameStory.spinTick(self)
            elseif self.spinSprites then
                EndgameStory.clearSpin(self)
            end
        end
    end
    function EventState:commit()
        if self.plan and self.plan.disappear and not self.disappearPlayed then
            self.disappearPlayed = true
            EndgameStory.beginDisappear(self)
            return
        end
        return commit(self)
    end
    function EventState:draw()
        draw(self)
        EndgameStory.drawOverlay(self)
    end
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
    SourceEvents.registerWorldHooks("pokered:CHAMPIONS_ROOM:objects:2", {
        actorPositions = function()
            return EndgameStory.oakCells()
        end,
    })
    wrapEvents()
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
            EndgameStory.playCry(state.plan.cry or "moltres")
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
