-- pret/pokered af519899 engine/menus/naming_screen.asm
-- engine/movie/oak_speech/oak_speech2.asm ChoosePlayerName / ChooseRivalName
-- constants/player_constants.asm DEF _BLUE
-- data/text/alphabets.asm
-- text/NameRatersHouse.asm and scripts/NameRatersHouse.asm
-- PLAYER_NAME_LENGTH is 8 including the terminator, so 7 tiles.
-- NAME_LENGTH is 11 including the terminator, so 10 tiles for a nickname.

NamingScreen = {}

NamingScreen.PLAYER_PRESETS = {"NEW NAME", "BLUE", "GARY", "JOHN"}
NamingScreen.RIVAL_PRESETS = {"NEW NAME", "RED", "ASH", "JACK"}
NamingScreen.PLAYER_LIMIT = 7
NamingScreen.MON_LIMIT = 10

NamingScreen.UPPER = {
    {"A", "B", "C", "D", "E", "F", "G", "H", "I"},
    {"J", "K", "L", "M", "N", "O", "P", "Q", "R"},
    {"S", "T", "U", "V", "W", "X", "Y", "Z", " "},
    {"×", "(", ")", ":", ";", "[", "]", "PK", "MN"},
    {"-", "?", "!", "♂", "♀", "/", ".", ",", "ED"},
}
NamingScreen.LOWER = {
    {"a", "b", "c", "d", "e", "f", "g", "h", "i"},
    {"j", "k", "l", "m", "n", "o", "p", "q", "r"},
    {"s", "t", "u", "v", "w", "x", "y", "z", " "},
    {"×", "(", ")", ":", ";", "[", "]", "PK", "MN"},
    {"-", "?", "!", "♂", "♀", "/", ".", ",", "ED"},
}

function NamingScreen.header(kind, speciesName)
    if kind == "rival" then return "RIVAL's NAME?" end
    if kind == "mon" then return (speciesName or "POKEMON") .. " NICKNAME?" end
    return "YOUR NAME?"
end

function NamingScreen.askText(speciesName)
    return "Do you want to give a nickname to " .. (speciesName or "POKEMON") .. "?"
end

function NamingScreen.new(kind, options)
    options = options or {}
    local limit = kind == "mon" and NamingScreen.MON_LIMIT or NamingScreen.PLAYER_LIMIT
    local phase = "keyboard"
    local presets
    if kind == "player" then
        phase = "presets"
        presets = NamingScreen.PLAYER_PRESETS
    elseif kind == "rival" then
        phase = "presets"
        presets = NamingScreen.RIVAL_PRESETS
    elseif options.ask then
        phase = "ask"
    end
    return {
        kind = kind,
        phase = phase,
        presets = presets,
        cursor = 1,
        row = 1,
        col = 1,
        upper = true,
        chars = {},
        limit = limit,
        speciesName = options.speciesName,
        rater = options.rater == true,
        finished = false,
        result = nil,
    }
end

function NamingScreen.text(state)
    return table.concat(state.chars)
end

function NamingScreen.glyph(state)
    if state.row == 6 then
        return state.upper and "lower case" or "UPPER CASE"
    end
    local grid = state.upper and NamingScreen.UPPER or NamingScreen.LOWER
    return grid[state.row][state.col]
end

local function clampFull(state)
    if #state.chars >= state.limit then
        state.row = 5
        state.col = 9
    end
end

local function submit(state)
    if #state.chars == 0 then
        if state.kind == "player" or state.kind == "rival" then
            return
        end
        state.finished = true
        state.result = false
        return
    end
    state.finished = true
    state.result = NamingScreen.text(state)
end

function NamingScreen.press(state, button)
    if state.finished then return state.result end
    if state.phase == "presets" then
        local count = #state.presets
        if button == "up" then
            state.cursor = state.cursor - 1
            if state.cursor < 1 then state.cursor = count end
        elseif button == "down" then
            state.cursor = state.cursor % count + 1
        elseif button == "a" then
            if state.cursor == 1 then
                state.phase = "keyboard"
                state.row, state.col = 1, 1
            else
                state.finished = true
                state.result = state.presets[state.cursor]
            end
        end
        if state.finished then return state.result end
        return nil
    end
    if state.phase == "ask" then
        if button == "up" or button == "down" then
            state.cursor = state.cursor == 1 and 2 or 1
        elseif button == "a" then
            if state.cursor == 1 then
                state.phase = "keyboard"
                state.row, state.col = 1, 1
            else
                state.finished = true
                state.result = false
            end
        elseif button == "b" then
            state.finished = true
            state.result = false
        end
        if state.finished then return state.result end
        return nil
    end
    if button == "up" then
        state.row = state.row - 1
        if state.row < 1 then
            state.row = 6
            state.col = 1
        elseif state.row == 6 then
            state.col = 1
        end
    elseif button == "down" then
        state.row = state.row + 1
        if state.row > 6 then
            state.row = 1
        elseif state.row == 6 then
            state.col = 1
        end
    elseif button == "right" and state.row ~= 6 then
        state.col = state.col + 1
        if state.col > 9 then state.col = 1 end
    elseif button == "left" and state.row ~= 6 then
        state.col = state.col - 1
        if state.col < 1 then state.col = 9 end
    elseif button == "select" or (button == "a" and state.row == 6) then
        state.upper = not state.upper
    elseif button == "b" then
        if #state.chars > 0 then
            table.remove(state.chars)
        end
    elseif button == "start" or (button == "a" and NamingScreen.glyph(state) == "ED") then
        submit(state)
    elseif button == "a" then
        if #state.chars < state.limit then
            state.chars[#state.chars + 1] = NamingScreen.glyph(state)
        end
    end
    clampFull(state)
    if state.finished then return state.result end
    return nil
end

-- scripts/NameRatersHouse.asm. OT mismatch is the impeccable branch
-- (carry from NameRatersHouseCheckMonOTScript) and does not rename.
NameRater = {}

NameRater.WANT = {
    "Hello, hello! I am the official NAME RATER!",
    "Want me to rate the nicknames of your POKEMON?",
}
NameRater.WHICH = {"Which POKEMON should I look at?"}
NameRater.WHAT = {"Fine! What should we name it?"}
NameRater.COME = {"Fine! Come any time you like!"}

function NameRater.decent(name)
    return {
        name .. ", is it? That is a decent nickname!",
        "But, would you like me to give it a nicer name?",
        "How about it?",
    }
end

function NameRater.renamed(name)
    return {
        "OK! This POKEMON has been renamed " .. name .. "!",
        "That's a better name than before!",
    }
end

function NameRater.impeccable(name)
    return {
        name .. ", is it? That is a truly impeccable name!",
        "Take good care of " .. name .. "!",
    }
end

function NameRater.start()
    return {phase = "want"}
end

function NameRater.lines(state)
    if state.phase == "want" then return NameRater.WANT end
    if state.phase == "which" then return NameRater.WHICH end
    if state.phase == "decent" then return NameRater.decent(state.mon.name) end
    if state.phase == "what" then return NameRater.WHAT end
    if state.phase == "renamed" then return NameRater.renamed(state.mon.name) end
    if state.phase == "impeccable" then return NameRater.impeccable(state.mon.name) end
    if state.phase == "come" then return NameRater.COME end
    return {}
end

function NameRater.answer(state, yes)
    if state.phase == "want" then
        state.phase = yes and "which" or "come"
    elseif state.phase == "decent" then
        state.phase = yes and "what" or "come"
    end
    return state.phase
end

function NameRater.inspect(state, mon)
    state.mon = {name = mon.name, otMatches = mon.otMatches == true}
    if state.phase ~= "which" then return state.phase end
    state.phase = state.mon.otMatches and "decent" or "impeccable"
    return state.phase
end

function NameRater.rename(state, name)
    if state.phase ~= "what" then return state.phase end
    if type(name) ~= "string" or name == "" then
        state.phase = "come"
        return state.phase
    end
    state.mon.name = name
    state.phase = "renamed"
    return state.phase
end

if Class then
    import "game/gbFont"
    local gfx <const> = playdate.graphics
    Class("NamingState"):extends(State)

    function NamingState:init(game)
        NamingState.super.init(self, "naming")
        self.game = game
    end

    function NamingState:enter(options)
        options = options or {}
        self.onDone = options.onDone
        self.done = false
        self.screen = NamingScreen.new(options.kind or "player", options)
    end

    function NamingState:finish(result)
        if self.done then return end
        self.done = true
        local callback = self.onDone
        self.onDone = nil
        self.machine:pop()
        if callback then callback(result) end
    end

    function NamingState:handleInput()
        if self.done or not self.screen or self.screen.finished then return end
        local button
        if playdate.buttonJustPressed(playdate.kButtonUp) then button = "up"
        elseif playdate.buttonJustPressed(playdate.kButtonDown) then button = "down"
        elseif playdate.buttonJustPressed(playdate.kButtonLeft) then button = "left"
        elseif playdate.buttonJustPressed(playdate.kButtonRight) then button = "right"
        elseif playdate.buttonJustPressed(playdate.kButtonA) then button = "a"
        elseif playdate.buttonJustPressed(playdate.kButtonB) then button = "b"
        end
        if not button then return end
        local result = NamingScreen.press(self.screen, button)
        if self.screen.finished then self:finish(result) end
    end

    function NamingState:draw()
        local screen = self.screen
        if not screen then return end
        local x, y = gfx.getDrawOffset()
        gfx.setDrawOffset(0, 0)
        gfx.clear(gfx.kColorWhite)
        GbFont.drawBox(TitleIdle.textBox(0, 0, 18, 16))
        GbFont.drawTight(NamingScreen.header(screen.kind, screen.speciesName), 24, 20)
        if screen.phase == "presets" then
            for index, label in ipairs(screen.presets) do
                local marker = index == screen.cursor and TitleIdle.CURSOR or " "
                GbFont.drawTight(marker .. label, 24, 36 + (index - 1) * 20)
            end
        elseif screen.phase == "ask" then
            GbFont.drawTight(NamingScreen.askText(screen.speciesName), 24, 48)
            GbFont.drawTight((screen.cursor == 1 and TitleIdle.CURSOR or " ") .. "YES", 24, 96)
            GbFont.drawTight((screen.cursor == 2 and TitleIdle.CURSOR or " ") .. "NO", 24, 120)
        else
            GbFont.drawTight(NamingScreen.text(screen), 24, 40)
            local grid = screen.upper and NamingScreen.UPPER or NamingScreen.LOWER
            for row, letters in ipairs(grid) do
                local cursor = 24
                for col, letter in ipairs(letters) do
                    local marker = (row == screen.row and col == screen.col) and TitleIdle.CURSOR or " "
                    GbFont.drawTight(marker .. letter, cursor, 64 + (row - 1) * 18)
                    cursor = cursor + 36
                end
            end
            local caseMark = screen.row == 6 and TitleIdle.CURSOR or " "
            local caseLabel = screen.upper and "lower case" or "UPPER CASE"
            GbFont.drawTight(caseMark .. caseLabel, 24, 168)
            GbFont.drawTight("B delete   A on ED done", 24, 196)
        end
        gfx.setDrawOffset(x, y)
    end

    function NamingState:exit()
        gfx.sprite.addDirtyRect(0, 0, 400, 240)
    end
end
