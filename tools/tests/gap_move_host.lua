-- Host for the eight pokered move gaps. Not part of the Playdate build.
local ROOT = assert(arg[1], "repo path required")
local CASE = assert(arg[2], "case required")
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
import "data/fieldMoveBattleData"
import "domain/decimalInteger"
import "domain/gameSession"
import "domain/npcTrades"
import "domain/pokemonCodec"
import "battle/battle"

local function drain(battle)
    local lines = {}
    local script = battle.machine:get("script")
    local guard = 0
    while battle:phase() == "script" do
        guard = guard + 1
        if guard > 400 then error("script did not finish: " .. tostring(battle.message)) end
        lines[#lines + 1] = battle.message or ""
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

local function battleOf(playerSpecies, enemySpecies, playerMoves, enemyMoves)
    RulesRNG.seed(1)
    local player = Pokemon(playerSpecies, 50)
    local enemy = Pokemon(enemySpecies, 50)
    player.maxHP, player.hp = 400, 200
    enemy.maxHP, enemy.hp = 400, 400
    player.spe, enemy.spe = 400, 10
    own(player, playerMoves)
    own(enemy, enemyMoves)
    local party = Party()
    assert(party:add(player))
    local foes = Party()
    assert(foes:add(enemy))
    local battle = Battle(player, enemy, "BLUE", {party = party, enemyParty = foes})
    drain(battle)
    if battle:phase() ~= "command" then
        error("did not reach command: " .. tostring(battle:phase()) .. " " .. tostring(battle.message))
    end
    return battle, player, enemy
end

local function turn(battle, index)
    local beforeP, beforeE = battle.player.hp, battle.enemy.hp
    assert(battle:selectMove(index or 1), "select failed")
    local text = drain(battle)
    return text, beforeP - battle.player.hp, beforeE - battle.enemy.hp
end

local function lockedTurn(battle)
    local beforeP, beforeE = battle.player.hp, battle.enemy.hp
    battle:update()
    if battle:phase() ~= "script" then
        return "", beforeP - battle.player.hp, beforeE - battle.enemy.hp, false
    end
    local text = drain(battle)
    return text, beforeP - battle.player.hp, beforeE - battle.enemy.hp, true
end

local function write(key, value)
    io.write(key .. " " .. tostring(value) .. "\n")
end

if CASE == "razor-wind" or CASE == "sky-attack" then
    local key = CASE == "razor-wind" and "razorWind" or "skyAttack"
    if key == "skyAttack" then moveData.skyAttack.accuracy = 100 end
    local battle, player, enemy = battleOf("pidgeot", "rattata", {key}, {"tackle"})
    local ppBefore = player.pp[key]
    local text, hurt, dealt = turn(battle, 1)
    write("case", CASE)
    write("whirlwind", text:find("made a whirlwind!", 1, true) ~= nil)
    write("glowing", text:find("is glowing!", 1, true) ~= nil)
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("charge-dealt", dealt)
    write("charge-hurt", hurt)
    write("pp", ppBefore - (player.pp[key] or 0))
    local text2, hurt2, dealt2, continued = lockedTurn(battle)
    write("continued", continued)
    write("release-dealt", dealt2)
    write("release-hurt", hurt2)
    write("release-failed", text2:find("But it failed!", 1, true) ~= nil)
    write("phase", battle:phase())
    write("enemy-hp", enemy.hp)
    if key == "razorWind" then write("crit-stage", moveData.razorWind.critStage) end
elseif CASE == "mist" then
    local battle, player = battleOf("articuno", "rattata", {"mist", "splash"}, {"growl"})
    local text = turn(battle, 1)
    write("case", "mist")
    write("shrouded", text:find("shrouded in mist!", 1, true) ~= nil)
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("protected", text:find("protected by Mist!", 1, true) ~= nil)
    write("atk", player.statStages.atk)
    write("turns", battle.conditions:sideTurns(player, "mist"))
    local wore = false
    for _ = 1, 8 do
        local step = turn(battle, 2)
        if step:find("wore off", 1, true) then wore = true; break end
    end
    write("wore-off", wore)
    write("atk-after", player.statStages.atk)
    local dropped = false
    if wore then
        local again = turn(battle, 2)
        dropped = again:find("ATTACK fell", 1, true) ~= nil or player.statStages.atk < 0
    end
    write("dropped-after", dropped)
    write("phase", battle:phase())
elseif CASE == "mimic" then
    local battle, player = battleOf("ditto", "rattata", {"mimic", "splash"}, {"tackle", "growl"})
    local text = turn(battle, 1)
    write("case", "mimic")
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("learned", text:find("learned ", 1, true) ~= nil)
    write("slot", player.moves[1])
    write("pp", player.pp[player.moves[1]])
    write("other", player.moves[2])
    local battle2, player2 = battleOf("ditto", "rattata", {"tackle", "mimic"}, {"tackle"})
    local text2 = turn(battle2, 2)
    write("fail-known", text2:find("But it failed!", 1, true) ~= nil)
    write("slot-kept", player2.moves[2])
    battle:clearVolatiles()
    write("restored", player.moves[1])
elseif CASE == "minimize" then
    local battle, player = battleOf("clefable", "rattata", {"minimize"}, {"tackle"})
    local text = turn(battle, 1)
    local state = battle.conditions.members[player]
    write("case", "minimize")
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("sharply", text:find("rose sharply", 1, true) ~= nil)
    write("eva", player.statStages.eva)
    write("flag", state and state.minimize == true)
    local function strike(moveKey, minimized)
        local strikeBattle, _, strikeEnemy = battleOf("tauros", "snorlax", {moveKey}, {"splash"})
        if minimized then strikeBattle.conditions:of(strikeEnemy).minimize = true end
        local _, _, dealt = turn(strikeBattle, 1)
        return dealt
    end
    write("stomp-plain", strike("stomp", false))
    write("stomp-min", strike("stomp", true))
    write("tackle-plain", strike("tackle", false))
    write("tackle-min", strike("tackle", true))
elseif CASE == "metronome" then
    local battle, player = battleOf("clefable", "rattata", {"metronome"}, {"splash"})
    local real = RulesRNG.random
    function RulesRNG.random(a, b)
        local eligible = battle.metronomeEligible
        if eligible and a == 1 and b == #eligible then
            for index, key in ipairs(eligible) do
                if key == "tackle" then return index end
            end
        end
        return real(a, b)
    end
    local text, _, dealt = turn(battle, 1)
    local eligible = battle.metronomeEligible or {}
    local hasMeta, hasStruggle = false, false
    for _, key in ipairs(eligible) do
        if key == "metronome" then hasMeta = true end
        if key == "struggle" then hasStruggle = true end
    end
    write("case", "metronome")
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("called-tackle", text:find("TACKLE", 1, true) ~= nil)
    write("dealt", dealt)
    local banned = {"metronome", "struggle", "counter", "mimic", "mirrorMove", "transform"}
    local function listed(list, key)
        for _, item in ipairs(list) do
            if item == key then return true end
        end
        return false
    end
    local blocked = 0
    for _, key in ipairs(banned) do
        if not listed(eligible, key) then blocked = blocked + 1 end
    end
    local forced = 0
    for _, key in ipairs(banned) do
        local probe = battleOf("clefable", "rattata", {"metronome"}, {"splash"})
        local roll = RulesRNG.random
        function RulesRNG.random(a, b)
            local choices = probe.metronomeEligible
            if choices and a == 1 and b == #choices then
                for index, choice in ipairs(choices) do
                    if choice == key then return index end
                end
                for index, choice in ipairs(choices) do
                    if choice == "tackle" then return index end
                end
            end
            return roll(a, b)
        end
        turn(probe, 1)
        if probe.metronomePick ~= key then forced = forced + 1 end
        RulesRNG.random = roll
    end
    write("has-metronome", hasMeta)
    write("has-struggle", hasStruggle)
    write("banned-absent", blocked)
    write("forced-blocked", forced)
    write("has-tackle", listed(eligible, "tackle"))
    write("has-cut", listed(eligible, "cut"))
    write("has-shadow-claw", listed(eligible, "shadowClaw"))
    write("eligible", #eligible)
    write("pp", player.pp.metronome)
    write("phase", battle:phase())
elseif CASE == "dream-eater" then
    local awake, playerA, enemyA = battleOf("hypno", "rattata", {"dreamEater"}, {"splash"})
    local textA, _, dealtA = turn(awake, 1)
    local hpA = playerA.hp
    write("case", "dream-awake")
    write("failed", textA:find("But it failed!", 1, true) ~= nil)
    write("dealt", dealtA)
    write("healed", playerA.hp - 200)
    local asleep, playerS, enemyS = battleOf("hypno", "rattata", {"dreamEater"}, {"splash"})
    enemyS.status = "sleep"
    enemyS.statusTurns = 3
    enemyS.sleepDuration = 3
    local before = playerS.hp
    local textS, _, dealtS = turn(asleep, 1)
    write("asleep-failed", textS:find("But it failed!", 1, true) ~= nil)
    write("asleep-dealt", dealtS)
    write("asleep-healed", playerS.hp - before)
    write("drained", textS:find("energy drained", 1, true) ~= nil)
    write("phase", asleep:phase())
elseif CASE == "conversion" then
    local battle, player, enemy = battleOf("squirtle", "gastly", {"conversion", "ember"}, {"lick"})
    local text = turn(battle, 1)
    local first, second = battle:effectiveTypes(player)
    write("case", "conversion")
    write("failed", text:find("But it failed!", 1, true) ~= nil)
    write("type1", first)
    write("type2", tostring(second))
    write("target1", enemy.type)
    write("became-target", first == enemy.type)
    local mono, water = battleOf("rattata", "gastly", {"conversion", "tackle"}, {"lick"})
    local textM = turn(mono, 1)
    local stay = mono:effectiveTypes(water)
    write("mono-failed", textM:find("But it failed!", 1, true) ~= nil)
    write("mono-type", stay)
else
    error("unknown case " .. CASE)
end
