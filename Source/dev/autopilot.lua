-- Bounded actions used exclusively by the identified Simulator harness.
Autopilot = { update = function() end }

if not playdate.isSimulator or not HarnessBuild.enabled then
    return
end

local gfx <const> = playdate.graphics

local SHOTS_DIR <const> = HarnessBuild.output_dir

local DIRS <const> = {
    up = { 0, -1 }, down = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 },
}

local BUTTONS <const> = {
    a = playdate.kButtonA, b = playdate.kButtonB,
    up = playdate.kButtonUp, down = playdate.kButtonDown,
    left = playdate.kButtonLeft, right = playdate.kButtonRight,
}

local recording = nil   -- { name, total, count }
local results = {}

-- ------------------------------------------------------------
-- Synthetic input: wrap the button query functions so injected
-- presses are indistinguishable from real ones for exactly one frame
-- ------------------------------------------------------------
local injectedPress = {}
local held = {}
local released = {}

---@diagnostic disable-next-line: duplicate-set-field
function playdate.buttonJustPressed(button)
    return injectedPress[button] == true
end

---@diagnostic disable-next-line: duplicate-set-field
function playdate.buttonIsPressed(button)
    return injectedPress[button] == true or held[button] == true
end

function playdate.buttonJustReleased(button)
    return released[button] == true
end

function playdate.getButtonState()
    local current, pressed, up = 0, 0, 0
    for button in pairs(held) do current = current | button end
    for button in pairs(injectedPress) do current = current | button; pressed = pressed | button end
    for button in pairs(released) do up = up | button end
    return current, pressed, up
end

local function inject(button)
    injectedPress[button] = true
end

local function clearInjected()
    for k in pairs(released) do released[k] = nil end
    for k in pairs(injectedPress) do
        if not held[k] then released[k] = true end
        injectedPress[k] = nil
    end
end

local function screenshot(name)
    HarnessCapture.write(name)
end

-- Visual verification harness: render every TileFactory tile and every
-- SpriteFactory frame onto labeled contact sheets, so art can be checked
-- without walking the game. Also dumps each player frame individually for
-- a pixel-identity diff against the retired PNGs.
local function buildAtlas()
    local tiles = TileFactory.generateAll()
    local cols, cell = 8, 36
    local rows = math.ceil(NUM_TILE_TYPES / cols)
    local timg = gfx.image.new(cols * cell, rows * cell + 6, gfx.kColorWhite)
    gfx.pushContext(timg)
    gfx.setColor(gfx.kColorBlack)
    for i = 1, NUM_TILE_TYPES do
        local img = tiles:getImage(i)
        if img then
            local c, r = (i - 1) % cols, (i - 1) // cols
            img:draw(c * cell + 2, r * cell + 2)
            gfx.drawText(tostring(i), c * cell + 2, r * cell + 33)
        end
    end
    gfx.popContext()
    playdate.simulator.writeToFile(timg, SHOTS_DIR .. "atlas_tiles.png")

    local frames = {}
    local function add(label, img) frames[#frames + 1] = { label, img } end
    local P = SpriteFactory
    add("Pdn", P.playerStand.down); add("Pup", P.playerStand.up)
    add("Plf", P.playerStand.left); add("Prt", P.playerStand.right)
    add("Pdw", P.playerWalk1.down); add("Plw1", P.playerWalk1.left); add("Plw2", P.playerWalk2.left)
    for _, key in ipairs({ "oak", "rival", "mom", "daisy" }) do
        local s = P.npc[key]
        add(key .. ".d", s.down); add(key .. ".u", s.up)
        add(key .. ".l", s.left); add(key .. ".r", s.right)
    end
    local scols, scell = 6, 44
    local srows = math.ceil(#frames / scols)
    local simg = gfx.image.new(scols * scell, srows * scell, gfx.kColorWhite)
    gfx.pushContext(simg)
    for i, f in ipairs(frames) do
        local c, r = (i - 1) % scols, (i - 1) // scols
        local x, y = c * scell + 2, r * scell + 2
        Shade.set(Shade.DARK); gfx.fillRect(x, y, 32, 32); Shade.reset()
        gfx.setColor(gfx.kColorBlack); gfx.drawRect(x, y, 32, 32)
        f[2]:draw(x, y)
        gfx.drawText(f[1], x, y + 33)
    end
    gfx.popContext()
    playdate.simulator.writeToFile(simg, SHOTS_DIR .. "atlas_sprites.png")
end

-- Returns true when the command has finished
function Autopilot.step(cmd, game)
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

    elseif name == "atlas" then
        if VisualCatalog then
            Autopilot.catalog = VisualCatalog.write(SHOTS_DIR)
        else
            buildAtlas()
        end
        results[#results + 1] = "atlas -> atlas_tiles.png, atlas_sprites.png"
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

    elseif name == "hold" then
        local button = BUTTONS[cmd[2]]
        if not held[button] then inject(button) end
        held[button] = true
        return true

    elseif name == "release" then
        local button = BUTTONS[cmd[2]]
        held[button] = nil
        released[button] = true
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

    elseif name == "dismiss" then
        -- Checks the state BEFORE each press, so the press that closes the
        -- dialog is the last one — it can't re-open the NPC interaction
        if game.machine:getCurrent() ~= "dialog" then
            results[#results + 1] = "dismissed -> " .. game.machine:stackNames()
            return true
        end
        if cmd.cooldown == nil then cmd.cooldown = 0 end
        if cmd.cooldown > 0 then
            cmd.cooldown = cmd.cooldown - 1
            return false
        end
        inject(BUTTONS.a)
        cmd.cooldown = 16
        return false

    elseif name == "battle" then
        local species = cmd[2]
        local level = tonumber(cmd[3]) or 5
        if not (species and pokemonData[species]) then
            results[#results + 1] = "err battle: unknown species " .. tostring(species)
            return true
        end
        if not game:getPlayerPokemon() then
            results[#results + 1] = "err battle: no player pokemon yet"
            return true
        end
        game.machine:change("battle", game:getPlayerPokemon(), Pokemon(species, level), nil)
        results[#results + 1] = "battle " .. species .. " " .. level
        return true

    elseif name == "intro" then
        local sub = cmd[2]
        if sub == "skip" or sub == "reset" then
            Autopilot.resetControls()
            HarnessFixtures.reset(game, { intro = sub, opening = sub ~= "skip" })
        end
        results[#results + 1] = "intro " .. tostring(sub)
            .. " stage=" .. Story.get(game).stage .. " starter=" .. tostring(Story.get(game).starter)
        return true

    elseif name == "gamestate" then
        local line = "gamestate " .. game.machine:stackNames()
        local top = game.machine:current()
        if top and top.battle then
            line = line .. " phase=" .. tostring(top.battle:phase())
                .. " msg=[" .. tostring(top.battle.message) .. "]"
        end
        if currentZone then
            line = line .. " zone=[" .. currentZone.name .. "]"
        end
        line = line .. " story=" .. Story.get(game).stage
        if player then
            line = line .. string.format(" player=%d,%d", player.gridX, player.gridY)
        end
        results[#results + 1] = line
        results[#results + 1] = "transitions " .. game:recentTransitions()
        return true

    elseif name == "seed" then
        math.randomseed(tonumber(cmd[2]) or 0)
        if RulesRNG then RulesRNG.seed(tonumber(cmd[2]) or 0) end
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
        local p = game:getPlayerPokemon()
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
        -- Stepping onto a door starts a fade and rebuilds the player; wait
        -- it out (remaining steps continue in the destination zone)
        local top = game.machine:current()
        if top.sub and top.sub:getCurrent() ~= "explore" then
            return false
        end
        if cmd.remaining == nil then cmd.remaining = tonumber(cmd[3]) or 1 end
        if player.isMoving then return false end
        if cmd.remaining <= 0 then return true end
        player:tryMove(dir[1], dir[2])
        if not player.isMoving then
            if player.pendingEdgeDoor then
                -- Walking into an edge exit: the warp starts on the next
                -- explore update; queued commands wait it out
                results[#results + 1] = string.format("edge-door %s at %d,%d",
                    cmd[2], player.gridX, player.gridY)
                return true
            end
            results[#results + 1] = string.format("blocked %s at %d,%d", cmd[2], player.gridX, player.gridY)
            return true
        end
        cmd.remaining = cmd.remaining - 1
        return false

    elseif name == "face" then
        assert(game.machine:is("overworld"), "face requires overworld")
        if DIRS[cmd[2]] then
            player.facing = cmd[2]
            player:updateSprite()
        end
        return true

    elseif name == "warp" then
        assert(game.machine:is("overworld"), "warp requires overworld")
        local gx, gy = tonumber(cmd[2]), tonumber(cmd[3])
        assert(gx and gy and gx >= 0 and gy >= 0 and gx < currentZone.width and gy < currentZone.height,
            "warp outside current zone")
        if gx and gy then
            player.isMoving = false
            player.stepJustFinished = false
            player.pendingEdgeDoor = nil
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

function Autopilot.beginFrame()
    clearInjected()
end

function Autopilot.resetControls()
    clearInjected()
    for key in pairs(held) do held[key] = nil end
    for key in pairs(released) do released[key] = nil end
    results = {}
    recording = nil
end

function Autopilot.takeResults()
    local found = results
    results = {}
    return found
end

function Autopilot.afterFrame()
    if recording then
        recording.count = recording.count + 1
        screenshot(string.format("%s-%02d", recording.name, recording.count))
        if recording.count >= recording.total then recording = nil end
    end
end

function Autopilot.isRecording() return recording ~= nil end

function Autopilot.inputSnapshot()
    local state = { held = {}, pressed = {}, released = {} }
    for name, button in pairs(BUTTONS) do
        if held[button] then state.held[#state.held + 1] = name end
        if injectedPress[button] then state.pressed[#state.pressed + 1] = name end
        if released[button] then state.released[#state.released + 1] = name end
    end
    return state
end
