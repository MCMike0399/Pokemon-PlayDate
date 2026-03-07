local gfx <const> = playdate.graphics

class("Player").extends(gfx.sprite)

local MOVE_FRAMES <const> = 8

-- Pre-load all player images, scaled 2x for native feel
local function loadScaled(path)
    local img = gfx.image.new(path)
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

local playerWalk2Images = {
    down = loadScaled("images/overworld/player-down-walk"),
    up = loadScaled("images/overworld/player-up-walk"),
    left = loadScaled("images/overworld/player-left-walk2"),
    right = loadScaledFlipped("images/overworld/player-left-walk2"),
}

function Player:init(gridX, gridY, collisionMap)
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
    self.walkToggle = false  -- alternates lead foot between steps
    self.stepJustFinished = false

    self:setImage(playerImages.down)
    self:setCenter(0, 0)
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE)
    self:setZIndex(100)
    self:add()
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
        if npcManager and npcManager:getNPCAt(targetGX, targetGY) then
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
        end

        -- Walk frame for most of the step, standing for last 2 frames
        -- Gives: stride -> stand -> stride -> stand (zig-zag, not cycling)
        local walkImages = self.walkToggle and playerWalk1Images or playerWalk2Images
        if self.moveFrames <= MOVE_FRAMES - 2 then
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
