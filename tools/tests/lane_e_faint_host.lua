-- Post-faint SHIFT and the trainer-wipe blackout page.
-- pret/pokered af519899 engine/battle/core.asm HandleEnemyMonFainted
-- (BIT_BATTLE_SHIFT clear shows _TrainerAboutToUseText and TWO_OPTION_MENU
-- before TrainerSentOutText) and HandlePlayerBlackOut
-- (_PlayerBlackedOutText2, then the last Center fly warp).
local ROOT = assert(arg[1], "repo path required")
local SOURCE = ROOT .. "/Source/"

local loaded = {}
local function loadPlaydate(path)
    local handle = assert(io.open(path, "r"))
    local source = assert(handle:read("a"))
    handle:close()
    source = source:gsub("([%w_%.]+)%s*([%+%-])=%s*", "%1 = %1 %2 ")
    return assert(load(source, "@" .. path))
end
function import(name)
    if loaded[name] then return end
    loaded[name] = true
    local ok, problem = pcall(loadPlaydate, SOURCE .. name .. ".lua")
    if not ok then loaded[name] = nil; error(problem) end
    local chunk = problem
    ok, problem = pcall(chunk)
    if not ok then loaded[name] = nil; error(problem) end
end

playdate = {
    kButtonA = 1,
    buttonJustPressed = function() return false end,
    buttonIsPressed = function() return false end,
    datastore = { read = function() return nil end },
}

import "lib/oop"
import "lib/rng"
import "lib/statemachine"
import "data/individualData"
import "domain/individualStats"
import "data/pokemon"
import "domain/party"
import "data/typechart"
import "battle/dsl"
import "battle/moves"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "battle/battle"

local function eq(actual, expected, label)
    if actual ~= expected then
        error(label .. " expected [" .. tostring(expected) .. "] got [" .. tostring(actual) .. "]")
    end
end
local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" and not battle.shiftChoice do
        guard = guard + 1
        if guard > 80 then error("script did not finish: " .. tostring(battle.message)) end
        lines[#lines + 1] = battle.message
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
    return table.concat(lines, "\n")
end

local function ask(style)
    assert(GameOptions.set("battleStyle", style))
    local lead = Pokemon("blastoise", 47)
    local bench = Pokemon("pidgey", 20)
    local foe = Pokemon("pidgeot", 5)
    local incoming = Pokemon("alakazam", 40)
    local roster = Party()
    assert(roster:add(lead))
    assert(roster:add(bench))
    local foes = Party()
    assert(foes:add(foe))
    assert(foes:add(incoming))
    local battle = Battle(lead, foe, "BLUE", {party = roster, enemyParty = foes})
    drain(battle)
    foe.hp = 0
    battle.presentationAttached = true
    battle:runScript(function()
        local result = battle:handleFaint("enemy")
        if result ~= "replacement" then return result end
        return battle:finishRound()
    end)
    return battle, drain(battle)
end

local shift, before = ask("SHIFT")
eq(shift.message, "Will RED\nchange POKéMON?", "shift question")
if not before:find("is about to use ALAKAZAM", 1, true) then
    error("about-to-use was not the page before the question: " .. before)
end
eq(shift.enemy.name, "PIDGEOT", "foe still the fainted mon")
if not shift.shiftChoice then error("YES/NO was not open") end
assert(shift:declineShift())
local after = drain(shift)
if not after:find("sent out ALAKAZAM", 1, true) then
    error("NO did not reach the send-out: " .. after)
end
eq(shift.player.name, "BLASTOISE", "NO keeps the lead")

local setBattle, setLog = ask("SET")
if setBattle.shiftChoice then error("SET asked to change") end
eq(setBattle.enemy.name, "ALAKAZAM", "SET sends the next foe")
if setLog:find("change POKéMON", 1, true) then error("SET printed the question") end
if not setLog:find("sent out ALAKAZAM", 1, true) then
    error("SET skipped the send-out: " .. setLog)
end
print("shift-faint-ok")

local only = Pokemon("pidgey", 20)
local foe = Pokemon("rattata", 50)
local roster = Party()
assert(roster:add(only))
local wipe = Battle(only, foe, "BLUE", {party = roster})
drain(wipe)
only.hp = 0
wipe:runScript(function() return wipe:handleFaint("player") end)
drain(wipe)
eq(wipe.message, "RED is out of\nuseable POKéMON!\n\nRED blacked\nout!", "blackout page")
eq(wipe.outcome, "defeat", "wipe outcome")
print("blackout-page-ok")
