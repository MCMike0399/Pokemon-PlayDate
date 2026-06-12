-- game/overworldState.lua — Overworld play, with its own substate machine
--
-- Substates:
--   explore  — normal play: movement, NPC interaction, wild encounter checks
--   irisOut  — Gen 1 battle transition: world keeps animating while a black
--              iris closes in, then fires a callback (usually -> battle)
--   doorWarp — door/mat/stairs transition: GB-style shade fade to black,
--              then re-enters the overworld in the door's target zone
--
-- Dialog and the debug menu are NOT substates: they are pushed onto the ROOT
-- machine, so the overworld keeps updating (and drawing) beneath them while
-- input is routed to the overlay only.

local gfx <const> = playdate.graphics

-- ============================================================
-- EXPLORE substate
-- ============================================================

Class("ExploreSubstate"):extends(State)

function ExploreSubstate:init(owner)
    ExploreSubstate.super.init(self, "explore")
    self.owner = owner   -- the OverworldState
end

function ExploreSubstate:update()
    local game = self.owner.game
    local player = game.player

    -- Door warp check: landing on a door/mat/stairs tile leaves the zone
    if player.stepJustFinished then
        local door = currentZone:getDoorAt(player.gridX, player.gridY)
        if door then
            self.machine:change("doorWarp", door)
            return
        end
    end

    -- Wild encounter check (player.stepJustFinished was set during the
    -- previous frame's sprite update, exactly like the old main loop)
    if player.stepJustFinished and not DEBUG_FLAGS.noEncounters then
        if currentZone:checkEncounter(player.gridX, player.gridY) then
            local px, py = player:getPixelCenter()
            local ox, oy = gfx.getDrawOffset()
            local rootMachine = self.owner.machine
            self.machine:change("irisOut", px + ox, py + oy, function()
                rootMachine:change("battle",
                    game.playerPokemon, currentZone:rollEncounter(), nil)
            end)
            return
        end
    end

    playdate.frameTimer.updateTimers()

    local px, py = player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:follow(px, py, mw, mh)
    game.camera:apply()
    gfx.sprite.update()
end

function ExploreSubstate:handleInput()
    local game = self.owner.game
    local player = game.player
    if player.isMoving then return end

    if playdate.buttonIsPressed(playdate.kButtonUp) then
        player:tryMove(0, -1)
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        player:tryMove(0, 1)
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        player:tryMove(-1, 0)
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        player:tryMove(1, 0)
    end

    -- A: interact with the NPC we are facing
    if playdate.buttonJustPressed(playdate.kButtonA) then
        local fx, fy = player:getFacingTile()
        local npc = game.npcManager:getNPCAt(fx, fy)
        if npc then
            local rootMachine = self.owner.machine
            local lines = npc:getDialogLines()
            if npc.battleData and not npc.interacted then
                rootMachine:push("dialog", lines, function()
                    local enemy = Pokemon(npc.battleData.species, npc.battleData.level)
                    rootMachine:change("battle", game.playerPokemon, enemy, npc)
                end)
            else
                rootMachine:push("dialog", lines)
            end
        end
    end
end

-- ============================================================
-- IRIS-OUT substate (overworld -> battle transition)
-- ============================================================

Class("IrisOutSubstate"):extends(State)

local IRIS_DURATION <const> = 15
local IRIS_MAX_RADIUS <const> = 260

function IrisOutSubstate:init(owner)
    IrisOutSubstate.super.init(self, "irisOut")
    self.owner = owner
end

function IrisOutSubstate:enter(cx, cy, callback)
    self.timer = 0
    self.cx = cx
    self.cy = cy
    self.callback = callback
end

function IrisOutSubstate:update()
    self.timer = self.timer + 1
    playdate.frameTimer.updateTimers()

    local game = self.owner.game
    local px, py = game.player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:follow(px, py, mw, mh)
    game.camera:apply()
    gfx.sprite.update()

    if self.timer >= IRIS_DURATION then
        local callback = self.callback
        self.callback = nil
        if callback then callback() end
    end
end

function IrisOutSubstate:draw()
    local game = self.owner.game
    game.camera:reset()

    local progress = self.timer / IRIS_DURATION
    local radius = math.floor(IRIS_MAX_RADIUS * (1 - progress))
    if radius > 0 then
        local stencilImg = gfx.image.new(400, 240, gfx.kColorWhite)
        gfx.pushContext(stencilImg)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillCircleAtPoint(self.cx, self.cy, radius)
        gfx.popContext()
        gfx.setStencilImage(stencilImg)
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
        gfx.clearStencil()
    else
        gfx.setColor(gfx.kColorBlack)
        gfx.fillRect(0, 0, 400, 240)
    end

    game.camera:apply()
end

-- ============================================================
-- DOOR-WARP substate (zone -> zone transition through a door def)
-- ============================================================

Class("DoorWarpSubstate"):extends(State)

local DOOR_FADE_FRAMES <const> = 12

function DoorWarpSubstate:init(owner)
    DoorWarpSubstate.super.init(self, "doorWarp")
    self.owner = owner
end

function DoorWarpSubstate:enter(door)
    self.timer = 0
    self.door = door
end

function DoorWarpSubstate:update()
    self.timer = self.timer + 1
    playdate.frameTimer.updateTimers()
    gfx.sprite.update()

    if self.timer >= DOOR_FADE_FRAMES then
        local door = self.door
        self.door = nil
        switchZone(door.to)
        self.owner.machine:change("overworld", {
            entry = { x = door.toX, y = door.toY, facing = door.facing },
        })
    end
end

function DoorWarpSubstate:draw()
    -- GB-style palette fade: light -> dark -> black over the whole screen
    local game = self.owner.game
    game.camera:reset()

    local t = self.timer / DOOR_FADE_FRAMES
    if t < 1 / 3 then
        Shade.set(Shade.LIGHT)
    elseif t < 2 / 3 then
        Shade.set(Shade.DARK)
    else
        Shade.set(Shade.BLACK)
    end
    gfx.fillRect(0, 0, 400, 240)
    Shade.reset()

    game.camera:apply()
end

-- ============================================================
-- OVERWORLD top-level state
-- ============================================================

Class("OverworldState"):extends(State)

function OverworldState:init(game)
    OverworldState.super.init(self, "overworld")
    self.game = game
    self.builtZone = nil   -- zone the current world/sprites were built for
    self.savedPos = nil    -- player position remembered across battles

    self.sub = StateMachine()
    self.sub:register("explore", ExploreSubstate(self))
    self.sub:register("irisOut", IrisOutSubstate(self))
    self.sub:register("doorWarp", DoorWarpSubstate(self))
end

-- opts.respawn = true forces the zone spawn point (blackout, zone switch);
-- opts.entry = {x, y, facing} places the player exactly there (door warps)
function OverworldState:enter(opts)
    local game = self.game

    gfx.sprite.removeAll()
    setupOverworld()
    self.builtZone = currentZone

    local pos = currentZone.spawn
    local saved = self.savedPos
    local respawn = opts and opts.respawn
    local entry = opts and opts.entry
    if entry then
        pos = entry
    elseif saved and saved.zone == currentZone and not respawn then
        pos = saved
    end

    game.player = Player(pos.x, pos.y, currentZone.collision, game.npcManager)
    if pos.facing then
        game.player.facing = pos.facing
        game.player:updateSprite()
    end

    currentZone:spawnNPCs(game.npcManager)

    if not game.playerPokemon then
        game.playerPokemon = Pokemon("squirtle", 5)
    end

    local px, py = game.player:getPixelCenter()
    local mw, mh = getMapPixelSize()
    game.camera:snapTo(px, py, mw, mh)

    self.sub:change("explore")
end

function OverworldState:exit()
    local player = self.game.player
    if player then
        self.savedPos = {
            x = player.gridX, y = player.gridY,
            facing = player.facing, zone = self.builtZone,
        }
    end
end

function OverworldState:update()
    updateOverworldAnimations()
    self.sub:update()
end

function OverworldState:handleInput()
    self.sub:handleInput()
end

function OverworldState:draw()
    self.sub:draw()
end
