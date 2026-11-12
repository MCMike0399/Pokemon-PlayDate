-- Host checks for the lane G front end. No Simulator.
local root = arg[1]
assert(root and root ~= "", "usage: lua lane_g_host.lua <repo>")

dofile(root .. "/Source/game/titleIdle.lua")
dofile(root .. "/Source/game/introMovie.lua")
dofile(root .. "/Source/game/namingState.lua")
dofile(root .. "/Source/game/story.lua")
dofile(root .. "/Source/game/gameOptions.lua")

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. ": " .. tostring(actual) .. " ~= " .. tostring(expected), 2)
    end
end

local col, row = TitleIdle.ballTile()
eq(col, 0, "ball column")
eq(row, 2, "ball row")
local resting = TitleIdle.start()
eq(TitleIdle.ballOamY(resting), 0x74, "ball rests at $74")
resting.phase = "ball"
resting.ball = 1
eq(TitleIdle.ballOamY(resting), 0x71, "first bounce row")
resting.ball = #TitleIdle.BALL_Y
eq(TitleIdle.ballOamY(resting), 0x6c, "fifth bounce row is still Red's ball")

local withSave = TitleIdle.mainMenu(true)
eq(withSave[1], "CONTINUE", "continue label")
eq(withSave[2], "NEW GAME", "new game label")
eq(withSave[3], "OPTION", "option label")
eq(#withSave, 3, "source main menu length")
local fresh = TitleIdle.mainMenu(false)
eq(fresh[1], "NEW GAME", "no-save first row")
eq(fresh[2], "OPTION", "no-save second row")
eq(TitleIdle.CONTINUE_LABELS[1], "PLAYER", "continue player")
eq(TitleIdle.CONTINUE_LABELS[2], "BADGES", "continue badges")
eq(TitleIdle.CONTINUE_LABELS[3], "POKéDEX", "continue dex")
eq(TitleIdle.CONTINUE_LABELS[4], "TIME", "continue time")
eq(TitleIdle.playTimeText(1, 5), "  1:05", "play time")
eq(TitleIdle.playTimeText(255, 0), "255:00", "max hours")
eq(TitleIdle.MENU_DELAY, 20, "main menu delay")
eq(TitleIdle.CONTINUE_DELAY, 30, "continue info delay")
local flags = {BADGE_BOULDER = true, BADGE_CASCADE = true}
eq(TitleIdle.countFlags(flags), 2, "two badges")

local noDex = TitleIdle.startMenu(false, "BLUE")
eq(table.concat(noDex, ","), "POKéMON,ITEM,BLUE,SAVE,OPTION,EXIT", "start menu without dex")
local dex = TitleIdle.startMenu(true, "GARY")
eq(dex[1], "POKéDEX", "dex row")
eq(dex[4], "GARY", "player name row")
eq(TitleIdle.startAction(false, 2), "item", "item index")
eq(TitleIdle.startAction(false, 4), "save", "save index")
eq(TitleIdle.startAction(false, 5), "option", "option index")
eq(TitleIdle.startAction(false, 6), "exit", "exit index")
eq(TitleIdle.startAction(true, 1), "pokedex", "dex action")
eq(TitleIdle.startAction(true, 5), "save", "save index with dex")
eq(TitleIdle.playMusic(), false, "title music seam is silent")

local intro = IntroMovie.start()
eq(IntroMovie.current(intro).id, "copyright", "intro opens on the copyright")
for _ = 1, 179 do IntroMovie.advance(intro, true) end
eq(IntroMovie.current(intro).id, "copyright", "copyright ignores A")
IntroMovie.advance(intro, false)
eq(IntroMovie.current(intro).id, "black-bars", "copyright lasts 180 frames")
for _ = 1, 64 do IntroMovie.advance(intro, true) end
eq(IntroMovie.current(intro).id, "shooting-star", "bars last 64 frames")
IntroMovie.advance(intro, true)
eq(IntroMovie.current(intro).id, "nidorino-enter", "star skip omits the 40-frame hold")
IntroMovie.advance(intro, true)
eq(intro.done, true, "a press during the fight leaves the intro")

local full = IntroMovie.start()
local guard = 0
while not full.done do
    IntroMovie.advance(full, false)
    guard = guard + 1
    if guard > 5000 then error("intro did not finish") end
end
eq(full.done, true, "unskipped intro finishes")

local player = NamingScreen.new("player")
eq(player.presets[2], "BLUE", "blue player preset")
eq(player.presets[3], "GARY", "gary preset")
eq(player.presets[4], "JOHN", "john preset")
eq(NamingScreen.press(player, "down"), nil, "preset cursor moves")
eq(player.cursor, 2, "second preset")
eq(NamingScreen.press(player, "a"), "BLUE", "preset confirms")
local custom = NamingScreen.new("player")
NamingScreen.press(custom, "a")
eq(custom.phase, "keyboard", "NEW NAME opens the keyboard")
eq(NamingScreen.header("player"), "YOUR NAME?", "player header")
eq(NamingScreen.header("rival"), "RIVAL's NAME?", "rival header")
for _ = 1, 7 do NamingScreen.press(custom, "a") end
eq(#custom.chars, 7, "player name stops at 7")
eq(custom.row, 5, "full name forces ED")
eq(custom.col, 9, "ED column")
local rival = NamingScreen.new("rival")
eq(rival.presets[2], "RED", "blue rival preset")
eq(rival.presets[3], "ASH", "ash preset")
eq(rival.presets[4], "JACK", "jack preset")
local nick = NamingScreen.new("mon", {speciesName = "SQUIRTLE", ask = true})
eq(NamingScreen.press(nick, "down"), nil, "nickname no is the second row")
eq(NamingScreen.press(nick, "a"), false, "no keeps the species name")
local typed = NamingScreen.new("mon", {speciesName = "SQUIRTLE", ask = true})
NamingScreen.press(typed, "a")
eq(typed.phase, "keyboard", "yes opens the nickname keyboard")
NamingScreen.press(typed, "a")
eq(NamingScreen.text(typed), "A", "first letter")
eq(typed.limit, 10, "nickname limit")

local session = {title = function() return {playerName = "RED", rivalName = "BLUE"} end}
local game = {session = session}
eq(Story.playerName(game), "RED", "default player")
eq(Story.remember(game, "player", "BLUE"), true, "remember player")
eq(Story.playerName(game), "BLUE", "saved player replaces RED")
eq(Story.remember(game, "rival", "ASH"), true, "remember rival")
eq(Story.rivalName(game), "ASH", "saved rival")
local greeted = table.concat(Story.labGreet(game), "\n")
assert(not greeted:find("RED", 1, true), "lab greet dropped RED")
assert(greeted:find("BLUE", 1, true), "lab greet uses the player name")
assert(greeted:find("ASH", 1, true), "lab greet uses the rival name")
local lines = table.concat(Story.refreshOpeningLines(game), "\n")
assert(lines:find("Right! So your name is BLUE!", 1, true), "oak close uses the player")
assert(lines:find("His name is ASH!", 1, true), "oak close uses the rival")
eq(GameOptions.rows[1].label, "TEXT SPEED", "text speed row")
eq(GameOptions.rows[1].choices[1], "FAST", "fast is the left choice")
eq(GameOptions.rows[4].label, "CRANK SCROLL", "crank row kept")
eq(GameOptions.cancelLabel, "CANCEL", "options cancel")
eq(GameOptions.rows[2].choices[1], "ON", "battle animation on")
eq(GameOptions.rows[2].choices[2], "OFF", "battle animation off")
eq(GameOptions.rows[3].choices[1], "SHIFT", "shift")
eq(GameOptions.rows[3].choices[2], "SET", "set")

local rater = NameRater.start()
NameRater.answer(rater, false)
eq(rater.phase, "come", "name rater no")
rater = NameRater.start()
NameRater.answer(rater, true)
eq(rater.phase, "which", "name rater which")
NameRater.inspect(rater, {name = "LOLA", otMatches = false})
eq(rater.phase, "impeccable", "traded mon is impeccable")
rater = NameRater.start()
NameRater.answer(rater, true)
NameRater.inspect(rater, {name = "SQUIRTLE", otMatches = true})
eq(rater.phase, "decent", "own mon can be renamed")
NameRater.answer(rater, true)
eq(rater.phase, "what", "name rater asks")
NameRater.rename(rater, "BUBBLE")
eq(rater.phase, "renamed", "name rater renamed")
eq(rater.mon.name, "BUBBLE", "new nickname")

print("lane-g-host ok")
