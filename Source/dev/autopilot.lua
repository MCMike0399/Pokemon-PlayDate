-- ============================================================
-- Autopilot: simulator-only automation bridge
-- ============================================================
-- Polls the game's Data folder (~/Developer/PlaydateSDK/Disk/Data/
-- com.poc.pokemon/ on the host) for "autopilot.txt" command files
-- written by tools/autopilot.py, executes them, and acks with
-- "autopilot-done.txt". Screenshots are written straight to the
-- host filesystem via playdate.simulator.writeToFile().
-- Does nothing on a real device.
--
-- Commands (one per line):
--   move <up|down|left|right> [n]   walk n tiles (default 1)
--   face <up|down|left|right>       turn without stepping
--   warp <gridX> <gridY>            teleport + snap camera
--   wait <frames>                   idle for n frames
--   shot <name>                     screenshot -> tools/shots/<name>.png
--   record <name> <n>               capture next n frames -> <name>-NN.png
--   encounters <on|off>             toggle wild encounters
--   press <a|b|up|down|left|right>  inject one button press (menus, dialog)
--   mash <btn> <n> [gap]            press <btn> n times, every gap frames (default 16)
--   battle <species> <level>        jump straight into a wild battle
--   gamestate                       report state stack, battle phase, transitions
--   seed <n>                        math.randomseed(n) for deterministic runs
--   debug <open|close>              push/pop the debug menu overlay
--   pokemon                         report player pokemon species/lv/hp/xp/status
--   state                           dump player/overlay diagnostics
--   dumpimg <name>                  write the player's current sprite image

Autopilot = { update = function() end }

if not playdate.isSimulator then
    return
end

local gfx <const> = playdate.graphics

local CMD_FILE <const> = "autopilot.txt"
local DONE_FILE <const> = "autopilot-done.txt"
local SHOTS_DIR <const> = "~/Developer/PlaydateSDK/PlayDate-Pokemon-PoC/tools/shots/"
local POLL_INTERVAL <const> = 10

local DIRS <const> = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}

local BUTTONS <const> = {
    a = playdate.kButtonA, b = playdate.kButtonB,
    up = playdate.kButtonUp, down = playdate.kButtonDown,
    left = playdate.kButtonLeft, right = playdate.kButtonRight,
}

local queue = {}
local active = nil      -- command currently executing
local recording = nil   -- { name, total, count }
local pendingAck = false
local pollCountdown = 0
local results = {}

-- ------------------------------------------------------------
-- Synthetic input: wrap the button query functions so injected
-- presses are indistinguishable from real ones for exactly one frame
-- ------------------------------------------------------------
local injectedPress = {}

local realJustPressed = playdate.buttonJustPressed
local realIsPressed = playdate.buttonIsPressed

---@diagnostic disable-next-line: duplicate-set-field
function playdate.buttonJustPressed(button)
    return injectedPress[button] == true or realJustPressed(button)
end

---@diagnostic disable-next-line: duplicate-set-field
function playdate.buttonIsPressed(button)
    return injectedPress[button] == true or realIsPressed(button)
end

local function inject(button)
    injectedPress[button] = true
end

local function clearInjected()
    for k in pairs(injectedPress) do
        injectedPress[k] = nil
    end
end

local function screenshot(name)
    playdate.simulator.writeToFile(gfx.getDisplayImage(), SHOTS_DIR .. name .. ".png")
end

local function writeDone(player)
    local f = playdate.file.open(DONE_FILE, playdate.file.kFileWrite)
    if not f then return end
    for _, line in ipairs(results) do
        f:write(line .. "\n")
    end
    if player then
        f:write(string.format("pos %d %d facing %s\n", player.gridX, player.gridY, player.facing))
    end
    f:write("done\n")
    f:close()
    results = {}
end

local function readCommands()
    local f = playdate.file.open(CMD_FILE, playdate.file.kFileRead)
    if not f then return end
    while true do
        local line = f:readline()
        if not line then break end
        local parts = {}
        for w in line:gmatch("%S+") do parts[#parts + 1] = w end
        if #parts > 0 then
            queue[#queue + 1] = parts
        end
    end
    f:close()
    playdate.file.delete(CMD_FILE)
    pendingAck = true
end

-- Returns true when the command has finished
local function step(cmd, game)
    local name = cmd[1]
    local player = game.player

    -- Commands that work in any state ------------------------------------

    if name == "wait" then
        if cmd.left == nil then cmd.left = tonumber(cmd[2]) or 1 end
        cmd.left = cmd.left - 1
        return cmd.left <= 0

    elseif name == "shot" then
        screenshot(cmd[2] or "shot")
        results[#results + 1] = "shot " .. (cmd[2] or "shot")
        return true

    elseif name == "record" then
        recording = { name = cmd[2] or "rec", total = tonumber(cmd[3]) or 16, count = 0 }
        return true

    elseif name == "encounters" then
        DEBUG_FLAGS.noEncounters = (cmd[2] == "off")
        return true

    elseif name == "press" then
        local button = BUTTONS[cmd[2]]
        if not button then
            results[#results + 1] = "err press: bad button " .. tostring(cmd[2])
            return true
        end
        inject(button)
        return true

    elseif name == "mash" then
        local button = BUTTONS[cmd[2]]
        if not button then
            results[#results + 1] = "err mash: bad button " .. tostring(cmd[2])
            return true
        end
        if cmd.count == nil then
            cmd.count = tonumber(cmd[3]) or 1
            cmd.gap = tonumber(cmd[4]) or 16
            cmd.cooldown = 0
        end
        if cmd.cooldown > 0 then
            cmd.cooldown = cmd.cooldown - 1
            return false
        end
        inject(button)
        cmd.count = cmd.count - 1
        cmd.cooldown = cmd.gap
        return cmd.count <= 0

    elseif name == "battle" then
        local species = cmd[2]
        local level = tonumber(cmd[3]) or 5
        if not (species and pokemonData[species]) then
            results[#results + 1] = "err battle: unknown species " .. tostring(species)
            return true
        end
        if not game.playerPokemon then
            results[#results + 1] = "err battle: no player pokemon yet"
            return true
        end
        game.machine:change("battle", game.playerPokemon, Pokemon(species, level), nil)
        results[#results + 1] = "battle " .. species .. " " .. level
        return true

    elseif name == "gamestate" then
        local line = "gamestate " .. game.machine:stackNames()
        local top = game.machine:current()
        if top and top.battle then
            line = line .. " phase=" .. tostring(top.battle:phase())
                .. " msg=[" .. tostring(top.battle.message) .. "]"
        end
        if player then
            line = line .. string.format(" player=%d,%d", player.gridX, player.gridY)
        end
        results[#results + 1] = line
        results[#results + 1] = "transitions " .. game:recentTransitions()
        return true

    elseif name == "seed" then
        math.randomseed(tonumber(cmd[2]) or 0)
        results[#results + 1] = "seed " .. tostring(cmd[2])
        return true

    elseif name == "debug" then
        if cmd[2] == "open" and game.machine:is("overworld") then
            game.machine:push("debug")
        elseif cmd[2] == "close" and game.machine:is("debug") then
            game.machine:pop()
        end
        results[#results + 1] = "debug " .. tostring(cmd[2]) .. " -> " .. game.machine:stackNames()
        return true

    elseif name == "pokemon" then
        local p = game.playerPokemon
        if p then
            results[#results + 1] = string.format("pokemon %s lv%d hp=%d/%d xp=%d status=%s",
                p.species, p.level, p.hp, p.maxHP, p.xp, tostring(p.status))
        else
            results[#results + 1] = "pokemon none"
        end
        return true
    end

    -- Commands that need the overworld player -----------------------------

    if not player then
        results[#results + 1] = "err " .. name .. ": no player (state="
            .. game.machine:stackNames() .. ")"
        return true
    end

    if name == "move" then
        local dir = DIRS[cmd[2]]
        if not dir then
            results[#results + 1] = "err move: bad direction " .. tostring(cmd[2])
            return true
        end
        -- A step can trigger an encounter that yanks us out of the overworld;
        -- abort instead of waiting forever on a frozen walk interpolation
        if game.machine:getCurrent() ~= "overworld" then
            results[#results + 1] = string.format("interrupted move at %d,%d (state=%s)",
                player.gridX, player.gridY, game.machine:stackNames())
            return true
        end
        if cmd.remaining == nil then cmd.remaining = tonumber(cmd[3]) or 1 end
        if player.isMoving then return false end
        if cmd.remaining <= 0 then return true end
        player:tryMove(dir[1], dir[2])
        if not player.isMoving then
            results[#results + 1] = string.format("blocked %s at %d,%d", cmd[2], player.gridX, player.gridY)
            return true
        end
        cmd.remaining = cmd.remaining - 1
        return false

    elseif name == "face" then
        if DIRS[cmd[2]] then
            player.facing = cmd[2]
            player:updateSprite()
        end
        return true

    elseif name == "warp" then
        local gx, gy = tonumber(cmd[2]), tonumber(cmd[3])
        if gx and gy then
            player.gridX = gx
            player.gridY = gy
            player:moveTo(gx * TILE_SIZE, gy * TILE_SIZE)
            local px, py = player:getPixelCenter()
            local mw, mh = getMapPixelSize()
            game.camera:snapTo(px, py, mw, mh)
        end
        return true

    elseif name == "dumpimg" then
        -- write the player's CURRENT sprite image (what the engine draws)
        playdate.simulator.writeToFile(player:getImage(), SHOTS_DIR .. (cmd[2] or "sprite") .. ".png")
        results[#results + 1] = "dumpimg " .. (cmd[2] or "sprite")
        return true

    elseif name == "state" then
        local ov = player.grassOverlay
        results[#results + 1] = string.format(
            "state player=%.0f,%.0f grid=%d,%d facing=%s toggle=%s overlay vis=%s pos=%.0f,%.0f z=%d",
            player.x, player.y, player.gridX, player.gridY, player.facing,
            tostring(player.walkToggle), tostring(ov:isVisible()), ov.x, ov.y, ov:getZIndex())
        return true
    end

    results[#results + 1] = "err unknown command: " .. tostring(name)
    return true
end

function Autopilot.update(game)
    -- Injected presses last exactly one frame
    clearInjected()

    -- Capture first: getDisplayImage() returns the last completed frame
    if recording then
        recording.count = recording.count + 1
        screenshot(string.format("%s-%02d", recording.name, recording.count))
        if recording.count >= recording.total then
            results[#results + 1] = string.format("recorded %s %d", recording.name, recording.total)
            recording = nil
        end
    end

    if not game then return end

    if active == nil and #queue > 0 then
        active = table.remove(queue, 1)
    end
    if active and step(active, game) then
        active = nil
    end

    if pendingAck and active == nil and #queue == 0 and recording == nil then
        pendingAck = false
        writeDone(game.player)
    end

    pollCountdown = pollCountdown - 1
    if pollCountdown <= 0 then
        pollCountdown = POLL_INTERVAL
        if active == nil and #queue == 0 and playdate.file.exists(CMD_FILE) then
            readCommands()
        end
    end
end
