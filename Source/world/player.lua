local gfx <const> = playdate.graphics

class("Player").extends(gfx.sprite)

local MOVE_FRAMES <const> = 8

-- Characters draw 8px above their tile (GB drew sprites 4px up): the head
-- pokes over the tile above and tall grass covers just the legs
local SPRITE_Y_OFFSET <const> = -8

-- Pre-load all player images, scaled 2x for native feel
local function loadScaled(path)
    local img = assert(gfx.image.new(path), "missing image: " .. path)
    return img:scaledImage(2)
end

local function loadScaledFlipped(path)
    local scaled = loadScaled(path)
    local w, h = scaled:getSize()
    local flipped = gfx.image.new(w, h, gfx.kColorClear)
    gfx.pushContext(flipped)
    scaled:draw(0, 0, gfx.kImageFlippedX)
    gfx.popContext()
    return flipped
end

local playerImages = {
    down = loadScaled("images/overworld/player-down"),
    up = loadScaled("images/overworld/player-up"),
    left = loadScaled("images/overworld/player-left"),
    right = loadScaledFlipped("images/overworld/player-left"),
}

local playerWalk1Images = {
    down = loadScaled("images/overworld/player-down-walk"),
    up = loadScaled("images/overworld/player-up-walk"),
    left = loadScaled("images/overworld/player-left-walk1"),
    right = loadScaledFlipped("images/overworld/player-left-walk1"),
}

-- walk2 vertical frames are X-flipped so up/down steps alternate the lead
-- foot, exactly like Gen 1; side frames are genuinely different strides
local playerWalk2Images = {
    down = loadScaledFlipped("images/overworld/player-down-walk"),
    up = loadScaledFlipped("images/overworld/player-up-walk"),
    left = loadScaled("images/overworld/player-left-walk2"),
    right = loadScaledFlipped("images/overworld/player-left-walk2"),
}

-- Tall grass overlay: drawn over the player's legs while in grass (Gen 1
-- style). A splayed rustle variant shows briefly when a step lands in
-- grass (FRLG-style), then settles to the normal overlay.
---@type _Image
local grassOverlayImage
---@type _Image
local grassRustleImage
local function buildOverlayHalf(tile)
    local img = playdate.graphics.image.new(TILE_SIZE, TILE_SIZE // 2)
    gfx.pushContext(img)
    tile:draw(0, -TILE_SIZE // 2)
    gfx.popContext()
    return img
end
local function getGrassOverlay()
    if not grassOverlayImage then
        grassOverlayImage = buildOverlayHalf(TileFactory.tallGrass())
        grassRustleImage = buildOverlayHalf(TileFactory.tallGrassRustle())
    end
    return grassOverlayImage
end

-- Exit arrow (Gen 2/3): a chunky bobbing arrow that appears in the void
-- beside an exit mat, pointing the way out. Authored as a 16x16 silhouette
-- (block shaft + triangular head) and rendered at TILE_SIZE with a 1px
-- black outline so it reads on both the black void and lighter tiles.
local exitArrowImages
local function inArrowRight(x, y)
    if x >= 1 and x <= 7 and y >= 5 and y <= 10 then return true end   -- shaft
    if x >= 7 and x <= 13 then                                         -- head
        local half = 13 - x
        return y >= 7 - half and y <= 7 + half
    end
    return false
end
-- The other three are coordinate transforms of the right-pointing arrow:
-- mirror x for left, transpose for down, transpose+mirror for up
local function inArrowLeft(x, y) return inArrowRight(15 - x, y) end
local function inArrowDown(x, y) return inArrowRight(y, x) end
local function inArrowUp(x, y)   return inArrowRight(15 - y, x) end

local function buildArrow(inFn)
    local scale = TILE_SIZE // 16
    local img = gfx.image.new(TILE_SIZE, TILE_SIZE, gfx.kColorClear)
    gfx.pushContext(img)
    for y = 0, 15 do
        for x = 0, 15 do
            if inFn(x, y) then
                gfx.setColor(gfx.kColorWhite)
                gfx.fillRect(x * scale, y * scale, scale, scale)
            elseif inFn(x - 1, y) or inFn(x + 1, y) or inFn(x, y - 1) or inFn(x, y + 1) then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(x * scale, y * scale, scale, scale)
            end
        end
    end
    gfx.popContext()
    return img
end

local function getExitArrows()
    if not exitArrowImages then
        exitArrowImages = {
            up = buildArrow(inArrowUp),
            down = buildArrow(inArrowDown),
            left = buildArrow(inArrowLeft),
            right = buildArrow(inArrowRight),
        }
    end
    return exitArrowImages
end

function Player:init(gridX, gridY, collisionMap, npcManager)
    Player.super.init(self)

    self.gridX = gridX
    self.gridY = gridY
    self.facing = "down"
    self.isMoving = false
    self.moveFrames = 0
    self.startPixelX = 0
    self.startPixelY = 0
    self.targetPixelX = 0
    self.targetPixelY = 0
    self.collisionMap = collisionMap
    self.npcManager = npcManager
    self.walkToggle = false  -- alternates lead foot between steps
    self.stepJustFinished = false
    self.rustleFrames = 0    -- grass splay countdown after landing in grass
    self.pendingEdgeDoor = nil  -- set by tryMove when walking into an edge exit

    self:setImage(playerImages.down)
    self:setCenter(0, 0)
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE)
    self:setZIndex(100)
    self:add()

    self.grassOverlay = gfx.sprite.new(getGrassOverlay())
    self.grassOverlay:setCenter(0, 0)
    self.grassOverlay:setZIndex(101)
    self.grassOverlay:setVisible(false)
    self.grassOverlay:add()

    self.exitArrow = gfx.sprite.new()
    self.exitArrow:setCenter(0, 0)
    self.exitArrow:setZIndex(102)
    self.exitArrow:setVisible(false)
    self.exitArrow:add()
    self.arrowTimer = 0
end

-- Show the bobbing exit arrow when standing still on an exit-mat tile,
-- in the void tile just past the door, pointing the way out
local ARROW_DELTA <const> = { up = {0,-1}, down = {0,1}, left = {-1,0}, right = {1,0} }

function Player:updateExitArrow()
    local door = (not self.isMoving) and currentZone
        and currentZone:getEdgeDoorAt(self.gridX, self.gridY)
    if not door then
        self.exitArrow:setVisible(false)
        self.arrowTimer = 0
        return
    end

    self.arrowTimer = self.arrowTimer + 1
    local dir = door.edge
    local d = ARROW_DELTA[dir]
    self.exitArrow:setImage(getExitArrows()[dir])
    -- Two-state bob: nudge a few px toward the exit every ~8 frames
    local bob = (math.floor(self.arrowTimer / 8) % 2 == 0) and 0 or 3
    local ax = (self.gridX + d[1]) * TILE_SIZE + d[1] * bob
    local ay = (self.gridY + d[2]) * TILE_SIZE + d[2] * bob
    self.exitArrow:moveTo(ax, ay)
    self.exitArrow:setVisible(true)
end

-- Show the grass overlay on the player's tile when standing in tall grass
function Player:updateGrassOverlay()
    local row = currentZone and currentZone.tiles[self.gridY + 1]
    local onGrass = row and row[self.gridX + 1] == 8
    self.grassOverlay:setVisible(onGrass or false)
    if onGrass then
        if self.rustleFrames > 0 then
            self.rustleFrames = self.rustleFrames - 1
            self.grassOverlay:setImage(grassRustleImage)
        else
            self.grassOverlay:setImage(grassOverlayImage)
        end
        self.grassOverlay:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE + TILE_SIZE // 2)
    end
end

-- All position updates go through here, so the visual offset applies to
-- init, walking interpolation, and debug/autopilot warps alike
function Player:moveTo(x, y)
    Player.super.moveTo(self, x, y + SPRITE_Y_OFFSET)
end

function Player:updateSprite()
    if self.isMoving then
        self:setImage(playerWalk1Images[self.facing])
    else
        self:setImage(playerImages[self.facing])
    end
end

function Player:canMoveTo(gx, gy)
    -- Debug noclip: walk through everything
    if DEBUG_FLAGS and DEBUG_FLAGS.noclip then return true end
    if gx < 0 or gy < 0 then return false end
    if gy + 1 > #self.collisionMap or gx + 1 > #self.collisionMap[1] then return false end
    return self.collisionMap[gy + 1][gx + 1] == 0
end

function Player:tryMove(dx, dy)
    if self.isMoving then return end

    if dy == -1 then self.facing = "up"
    elseif dy == 1 then self.facing = "down"
    elseif dx == -1 then self.facing = "left"
    elseif dx == 1 then self.facing = "right"
    end

    self:updateSprite()

    local targetGX = self.gridX + dx
    local targetGY = self.gridY + dy

    -- Check for NPC at target position (skip during noclip)
    if not (DEBUG_FLAGS and DEBUG_FLAGS.noclip) then
        if self.npcManager:getNPCAt(targetGX, targetGY) then
            return
        end
    end

    if self:canMoveTo(targetGX, targetGY) then
        self.isMoving = true
        self.moveFrames = 0
        self.walkToggle = not self.walkToggle
        self.startPixelX = self.gridX * TILE_SIZE
        self.startPixelY = self.gridY * TILE_SIZE
        self.gridX = targetGX
        self.gridY = targetGY
        self.targetPixelX = self.gridX * TILE_SIZE
        self.targetPixelY = self.gridY * TILE_SIZE
        self:updateSprite()
    elseif currentZone then
        -- Walking into the room edge from an exit mat (Gen 2/3 gates):
        -- explore picks this up and starts the door warp
        local door = currentZone:getEdgeDoorAt(self.gridX, self.gridY, self.facing)
        if door then
            self.pendingEdgeDoor = door
        end
    end
end

function Player:update()
    self.stepJustFinished = false

    if self.isMoving then
        self.moveFrames = self.moveFrames + 1
        local t = self.moveFrames / MOVE_FRAMES
        if t >= 1 then
            t = 1
            self.isMoving = false
            self.stepJustFinished = true
            local row = currentZone and currentZone.tiles[self.gridY + 1]
            if row and row[self.gridX + 1] == 8 then
                self.rustleFrames = 6
            end
        end

        -- Even Gen 1 cadence: stride for the first half of the step,
        -- standing for the second half. walkToggle alternates the lead
        -- leg between steps: stride A -> stand -> stride B -> stand
        local walkImages = self.walkToggle and playerWalk1Images or playerWalk2Images
        if self.moveFrames <= MOVE_FRAMES // 2 then
            self:setImage(walkImages[self.facing])
        else
            self:setImage(playerImages[self.facing])
        end

        local px = self.startPixelX + (self.targetPixelX - self.startPixelX) * t
        local py = self.startPixelY + (self.targetPixelY - self.startPixelY) * t
        self:moveTo(px, py)
    else
        self:setImage(playerImages[self.facing])
    end

    self:updateGrassOverlay()
    self:updateExitArrow()
end

function Player:getFacingTile()
    local dx, dy = 0, 0
    if self.facing == "up" then dy = -1
    elseif self.facing == "down" then dy = 1
    elseif self.facing == "left" then dx = -1
    elseif self.facing == "right" then dx = 1
    end
    return self.gridX + dx, self.gridY + dy
end

function Player:getPixelCenter()
    -- Use actual sprite position (smoothly interpolated during movement)
    return self.x + TILE_SIZE / 2, self.y + TILE_SIZE / 2
end
