-- Blue title idle from pret/pokered af519899.
-- data/pokemon/title_mons.asm (DEF _BLUE) and engine/movie/title2.asm.
-- DisplayTitleScreen waits 200 frames, then TitleScreenScrollInMon passes
-- d=0. TitleScroll treats 0 as TitleScroll_Out, so the current species
-- leaves to the left. TitleScreenAnimateBallIfStarterOut then plays the
-- first five TitleBallYTable steps when that species is Charmander,
-- Squirtle, or Bulbasaur. TitleScreenPickNewMon passes d=1, which
-- TitleScroll treats as TitleScroll_In, so a different TitleMon enters
-- from the right. The inline "scroll in" / "scroll out" comments are
-- swapped relative to that branch.
--
-- title.asm DrawPlayerCharacter places gfx/title/player.png on a 5-by-7
-- OAM grid at ($5a, $60) and parks a Poké Ball on sprite 10. That sprite
-- is column 0, row 2 of the sheet. TitleBallYTable moves it. The species
-- slot does not draw the ball.

TitleIdle = {}

TitleIdle.MONS = {
    "squirtle", "charmander", "bulbasaur", "mankey", "hitmonlee", "vulpix",
    "chansey", "aerodactyl", "jolteon", "snorlax", "gloom", "poliwag",
    "doduo", "porygon", "gengar", "raichu",
}
TitleIdle.HOLD = 200
TitleIdle.BALL_REST = 0x74
TitleIdle.BALL_Y = { 0x71, 0x6f, 0x6e, 0x6d, 0x6c }

local STARTERS <const> = { squirtle = true, charmander = true, bulbasaur = true }
local OUT_SPEEDS <const> = { 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 8, 8, 8, 9, 9, 9 }
local IN_SPEEDS <const> = { 10, 10, 9, 9, 9, 9, 8, 8, 8, 8, 6, 6, 6, 5, 5, 3, 1 }
TitleIdle.OUT_FRAMES = #OUT_SPEEDS
TitleIdle.IN_FRAMES = #IN_SPEEDS
TitleIdle.OUT_DISTANCE = 93
TitleIdle.IN_DISTANCE = 120

local function beginIn(state, random)
    state.species = TitleIdle.pick(state.species, random)
    state.phase = "in"
    state.cursor = 0
    state.offset = TitleIdle.IN_DISTANCE
    state.ball = nil
end

function TitleIdle.start()
    return { species = "squirtle", phase = "hold", hold = 0, cursor = 0, offset = 0, ball = nil }
end

function TitleIdle.pick(current, random)
    for _ = 1, 32 do
        local species = TitleIdle.MONS[random(#TitleIdle.MONS)]
        if species ~= current then return species end
    end
    for index, species in ipairs(TitleIdle.MONS) do
        if species == current then return TitleIdle.MONS[index % #TitleIdle.MONS + 1] end
    end
    return TitleIdle.MONS[1]
end

function TitleIdle.advance(state, random)
    if state.phase == "hold" then
        if state.hold == TitleIdle.HOLD then
            state.phase = "out"
            state.cursor = 0
            state.offset = 0
            state.ball = nil
            return
        end
        state.hold = state.hold + 1
        return
    end
    if state.phase == "out" then
        if state.cursor == #OUT_SPEEDS then
            if STARTERS[state.species] then
                state.phase = "ball"
                state.ball = 0
            else
                beginIn(state, random)
            end
            return
        end
        state.cursor = state.cursor + 1
        state.offset = state.offset - OUT_SPEEDS[state.cursor]
        return
    end
    if state.phase == "ball" then
        if state.ball == #TitleIdle.BALL_Y then
            beginIn(state, random)
            return
        end
        state.ball = state.ball + 1
        return
    end
    if state.cursor == #IN_SPEEDS then
        state.phase = "hold"
        state.hold = 0
        state.cursor = 0
        state.offset = 0
        state.ball = nil
        return
    end
    state.cursor = state.cursor + 1
    state.offset = state.offset - IN_SPEEDS[state.cursor]
end

-- DrawPlayerCharacter sprite 10. title.asm writes the grid row-major.
TitleIdle.PLAYER_COLUMNS = 5
TitleIdle.PLAYER_ROWS = 7
TitleIdle.BALL_SPRITE = 10
TitleIdle.PLAYER_OAM_X = 0x5a
TitleIdle.PLAYER_OAM_Y = 0x60
TitleIdle.TILE = 8
-- main_menu.asm MainMenu waits 20 frames before HandleMenuInput.
-- DisplayContinueGameInfo waits 30 frames after the info box is drawn.
TitleIdle.MENU_DELAY = 20
TitleIdle.CONTINUE_DELAY = 30
TitleIdle.CONTINUE_LABELS = {"PLAYER", "BADGES", "POKéDEX", "TIME"}
-- engine/movie/title.asm CopyrightTextString. The tile row is graphic;
-- this is the same notice in the system font.
TitleIdle.COPYRIGHT = "(C) '95.'96.'98 GAME FREAK inc."
TitleIdle.BADGE_FLAGS = {
    "BADGE_BOULDER", "BADGE_CASCADE", "BADGE_THUNDER", "BADGE_RAINBOW",
    "BADGE_SOUL", "BADGE_MARSH", "BADGE_VOLCANO", "BADGE_EARTH",
}
-- 400x240 placement. The Game Boy screen is 160x144; Playdate scale is 2,
-- so Red (40x56) sits on the right and the TitleMon keeps the open slot.
TitleIdle.LAYOUT = {
    logo = {x = 8, y = 4, scale = 2},
    version = {x = 24, y = 112, scale = 2},
    player = {x = 308, y = 118, scale = 2},
    mon = {x = 28, y = 128, scale = 2},
    monClip = {x = 8, y = 108, w = 276, h = 124},
    copyright = {x = 16, y = 222},
}

function TitleIdle.ballTile()
    local index = TitleIdle.BALL_SPRITE
    return index % TitleIdle.PLAYER_COLUMNS, math.floor(index / TitleIdle.PLAYER_COLUMNS)
end

function TitleIdle.ballOamY(state)
    if state.phase == "ball" and state.ball and state.ball > 0 then
        return TitleIdle.BALL_Y[state.ball]
    end
    return TitleIdle.BALL_REST
end

function TitleIdle.mainMenu(hasSave)
    if hasSave then
        return {"CONTINUE", "NEW GAME", "OPTION"}
    end
    return {"NEW GAME", "OPTION"}
end

-- draw_start_menu.asm DrawStartMenu. The Pokédex row is absent until
-- EVENT_GOT_POKEDEX. The fourth row is wPlayerName, not a fixed label.
function TitleIdle.startMenu(hasDex, playerName)
    local items = {}
    if hasDex then items[#items + 1] = "POKéDEX" end
    items[#items + 1] = "POKéMON"
    items[#items + 1] = "ITEM"
    items[#items + 1] = playerName
    items[#items + 1] = "SAVE"
    items[#items + 1] = "OPTION"
    items[#items + 1] = "EXIT"
    return items
end

function TitleIdle.startAction(hasDex, index)
    local actions = {"pokemon", "item", "trainer", "save", "option", "exit"}
    if hasDex then
        table.insert(actions, 1, "pokedex")
    end
    return actions[index]
end

-- PrintPlayTime: hours in 3 digits, colon tile, minutes in 2 digits.
function TitleIdle.playTimeText(hours, minutes)
    hours = math.max(0, math.min(255, math.floor(hours or 0)))
    minutes = math.max(0, math.min(59, math.floor(minutes or 0)))
    return string.format("%3d:%02d", hours, minutes)
end

function TitleIdle.countFlags(flags)
    local count = 0
    for _, id in ipairs(TitleIdle.BADGE_FLAGS) do
        if flags and flags[id] then count = count + 1 end
    end
    return count
end

-- Lane F owns KantoAudio. playTitle is the seam; missing means silence.
function TitleIdle.playMusic()
    if type(KantoAudio) == "table" and type(KantoAudio.playTitle) == "function" then
        return pcall(KantoAudio.playTitle) == true
    end
    return false
end
