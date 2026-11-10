-- Host checks for the Silph 7F battle path: self-move animation side,
-- damage totals, the waiting text box, and the SHIFT party menu.
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

local pressedA = false
playdate = {
    kButtonA = 1,
    buttonJustPressed = function(button) return pressedA and button == 1 end,
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
        error(label .. " expected " .. tostring(expected) .. " got " .. tostring(actual))
    end
end
local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 80 then error("script did not finish: " .. tostring(battle.message)) end
        if battle.shiftChoice then return table.concat(lines, "\n") end
        lines[#lines + 1] = battle.message
        script.waiting = false
        battle.presentationRequest = nil
        script:advance()
    end
    return table.concat(lines, "\n")
end
local function own(mon, moves)
    mon.moves = moves
    mon.pp = {}
    for _, key in ipairs(moves) do mon.pp[key] = moveData[key].maxPP end
end
local function opened()
    local player = Pokemon("blastoise", 47)
    local enemy = Pokemon("pidgeot", 37)
    local party = Party()
    assert(party:add(player))
    local battle = Battle(player, enemy, "BLUE", {party = party})
    drain(battle)
    eq(battle:phase(), "command", "intro")
    return battle, player, enemy
end

local function anchorOf(userSide, key)
    local battle, player, enemy = opened()
    own(player, {"agility", "tackle"})
    own(enemy, {"agility", "tackle"})
    battle.presentationAttached = true
    battle:runScript(function()
        battle:resolveTurn({
            side = userSide,
            actor = battle[userSide],
            key = key,
            move = moveData[key],
        })
    end)
    local script = battle.machine:get("script")
    for _ = 1, 20 do
        local request = battle.presentationRequest
        if request and request.kind == "move" then
            eq(request.details.side, userSide, key .. " user")
            local anchor = Battle.moveAnchor(request.details.side, request.details.targetsFoe)
            return anchor
        end
        script.waiting = false
        script:advance()
    end
    error(key .. " from " .. userSide .. " did not present a move")
end

local foeAgility = anchorOf("enemy", "agility")
eq(foeAgility.side, "enemy", "foe agility side")
eq(foeAgility.mirror, true, "foe agility mirror")
local playerAgility = anchorOf("player", "agility")
eq(playerAgility.side, "player", "player agility side")
eq(playerAgility.mirror, false, "player agility mirror")
local playerTackle = anchorOf("player", "tackle")
eq(playerTackle.side, "enemy", "player tackle side")
local foeTackle = anchorOf("enemy", "tackle")
eq(foeTackle.side, "player", "foe tackle side")
eq(moveData.agility.targetId, 7, "agility target")
eq(Battle:targetsFoe(moveData.agility), false, "agility is self")

local quiet, attacker, defender = opened()
own(attacker, {"tackle"})
own(defender, {"agility"})
local before = defender.hp
local text = (function()
    quiet:runScript(function()
        quiet:resolveTurn({
            side = "player", actor = attacker, key = "tackle", move = moveData.tackle,
        })
    end)
    return drain(quiet)
end)()
if defender.hp >= before then error("tackle did not drain HP") end
if text:find("took", 1, true) or text:find("damage!", 1, true) then
    error("normal play printed a damage total:\n" .. text)
end
quiet.debugDamageNumbers = true
own(attacker, {"tackle"})
local loud = (function()
    quiet:runScript(function()
        quiet:resolveTurn({
            side = "player", actor = attacker, key = "tackle", move = moveData.tackle,
        })
    end)
    return drain(quiet)
end)()
if not loud:find("took", 1, true) then error("debug flag did not print the total:\n" .. loud) end

local box = opened()
box:runScript(function()
    box:say("PIDGEOT took 46 damage!")
    box:say("It's super effective!")
end)
local script = box.machine:get("script")
eq(script.waiting, true, "box waiting")
eq(box.message, "PIDGEOT took 46 damage!", "damage box")
script.messageTimer = 11
script:handleInput()
eq(box.message, "PIDGEOT took 46 damage!", "no A leaves the box")
eq(script.waiting, true, "still waiting")
pressedA = true
script.messageTimer = 10
script:handleInput()
eq(box.message, "PIDGEOT took 46 damage!", "frame 10 does not advance")
script.messageTimer = 11
script:handleInput()
eq(box.message, "It's super effective!", "A advances the box")
eq(box:phase(), "script", "next box")
pressedA = false

local lead = Pokemon("blastoise", 47)
local bench = Pokemon("pidgey", 20)
local fainted = Pokemon("rattata", 5)
fainted.hp = 0
local foe = Pokemon("pidgeot", 37)
local incoming = Pokemon("alakazam", 40)
local roster = Party()
assert(roster:add(lead))
assert(roster:add(bench))
assert(roster:add(fainted))
local foes = Party()
assert(foes:add(foe))
assert(foes:add(incoming))
local shift = Battle(lead, foe, "BLUE", {party = roster, enemyParty = foes})
drain(shift)
foe.hp = 0
shift.presentationAttached = true
shift:runScript(function() return shift:finishRound() end)
drain(shift)
if not shift.shiftChoice then error("SHIFT did not offer a change") end
assert(shift:beginSelection("party"))
local ok, reason = shift:chooseParty(1)
eq(ok, false, "active rejected")
eq(reason, "already-active", "already out reason")
eq(Battle.partyRejection(lead, reason), "BLASTOISE is already out!", "already out text")
eq(shift.shiftChoice ~= nil, true, "shift still open")
ok, reason = shift:chooseParty(3)
eq(ok, false, "fainted rejected")
eq(reason, "fainted", "fainted reason")
assert(shift:cancelSelection())
assert(shift:declineShift())
drain(shift)
eq(shift.player, lead, "B keeps the lead")
eq(shift.enemy, incoming, "foe is sent")
eq(shift:phase(), "command", "battle continues")

local lead2 = Pokemon("blastoise", 47)
local bench2 = Pokemon("pidgey", 20)
local foe2 = Pokemon("pidgeot", 37)
local incoming2 = Pokemon("alakazam", 40)
local roster2 = Party()
assert(roster2:add(lead2))
assert(roster2:add(bench2))
local foes2 = Party()
assert(foes2:add(foe2))
assert(foes2:add(incoming2))
local changed = Battle(lead2, foe2, "BLUE", {party = roster2, enemyParty = foes2})
drain(changed)
foe2.hp = 0
changed.presentationAttached = true
changed:runScript(function() return changed:finishRound() end)
drain(changed)
assert(changed:beginSelection("party"))
assert(changed:chooseParty(2))
drain(changed)
eq(changed.player, bench2, "bench comes in")
eq(changed.enemy, incoming2, "foe after the switch")
eq(changed:phase(), "command", "switch returns to command")

playdate.graphics = {
    font = { new = function() return {} end },
    image = { new = function() return {} end },
    kColorWhite = 1, kColorBlack = 0, kColorClear = 2,
    kDrawModeCopy = 0,
}
import "battle/captureAnimation"
import "battle/battleScene"
eq(BattleScene.ppReadout(5, 15), " 5/15", "single current PP")
eq(BattleScene.ppReadout(13, 15), "13/15", "two-digit current PP")
eq(BattleScene.ppReadout(23, 25), "23/25", "bite PP")
eq(BattleScene.ppReadout(3, 5), " 3/ 5", "single current and max PP")
eq(BattleScene.ppReadout(0, 5), " 0/ 5", "zero current PP")
local function detail(typeName, current, maxPP, disabled)
    return table.concat(BattleScene.moveDetailLines(typeName, current, maxPP, disabled), "\n")
end
eq(detail("WATER", 5, 15, false), "TYPE/\n WATER\n     5/15", "single current PP box")
eq(detail("NORMAL", 13, 15, false), "TYPE/\n NORMAL\n    13/15", "two-digit PP box")
eq(detail("DARK", 3, 5, false), "TYPE/\n DARK\n     3/ 5", "single current and max PP")
eq(detail("WATER", 0, 15, true), "\ndisabled!\n", "disabled move box")
for _, sample in ipairs({ detail("WATER", 5, 15, false), detail("GROUND", 10, 10, false), "SURF" }) do
    if sample:find("!", 1, true) or sample:find(" X", 1, true) or sample:find("-", 1, true) then
        error("move menu still draws an effectiveness mark: " .. sample)
    end
end
local function sameList(actual, expected, label)
    eq(#actual, #expected, label .. " length")
    for index, value in ipairs(expected) do
        eq(actual[index], value, label .. " " .. index)
    end
end
sameList(BattleScene.moveSlots({"STRENGTH", "SKULL BASH", "SURF", "BITE"}),
    {"STRENGTH", "SKULL BASH", "SURF", "BITE"}, "four moves")
sameList(BattleScene.moveSlots({"TACKLE"}), {"TACKLE", "-", "-", "-"}, "one move")
local layout = BattleScene.moveSelectLayout()
eq(layout.rows, 4, "four move rows")
eq(layout.promptDrawn, false, "command line is not redrawn")
eq(layout.typeBox.y + layout.typeBox.h - 1, layout.moveBox.y, "one shared border row")
eq(layout.sharedRow, layout.moveBox.y, "shared row is the move box top")
eq(layout.typeBox.x, 0, "type box starts at column 0")
eq(layout.typeBox.w, 11 * 20, "type box is 11 tiles wide")
eq(layout.moveBox.x, 4 * 20, "move box starts at column 4")
eq(layout.moveBox.w, 16 * 20, "move box is 16 tiles wide")
eq(layout.junctionX, 11 * 20 - 1, "corner sits on column 10")
eq(math.floor((layout.moveBox.h - 8) / layout.line) >= 4, true, "four names fit")
local function covered(x, y)
    for _, rect in ipairs(layout.clears) do
        if x >= rect.x and y >= rect.y and x < rect.x + rect.w and y < rect.y + rect.h then
            return true
        end
    end
    return false
end
eq(covered(14, 190), true, "What will is inside a cleared box")
eq(covered(14, 208), true, "name do? is inside a cleared box")
local paint = BattleScene.moveSelectPaint(
    {"STRENGTH", "SKULL BASH", "SURF", "BITE"},
    BattleScene.moveDetailLines("NORMAL", 15, 15, false))
sameList(paint.slots, {"STRENGTH", "SKULL BASH", "SURF", "BITE"}, "painted moves")
for _, text in ipairs(paint.texts) do
    if text:find("What will", 1, true) or text:find("do?", 1, true) or text:find("!", 1, true) then
        error("move menu paints leftover command text: " .. text)
    end
end
local single = BattleScene.moveSelectPaint({"TACKLE"}, BattleScene.moveDetailLines("NORMAL", 35, 35, false))
sameList(single.slots, {"TACKLE", "-", "-", "-"}, "painted empty slots")

print("battle-path-host ok")
