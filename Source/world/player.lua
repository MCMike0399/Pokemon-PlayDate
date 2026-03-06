local gfx <const> = playdate.graphics

class("Player").extends(gfx.sprite)

local TILE_SIZE <const> = 16
local MOVE_FRAMES <const> = 8

-- Pre-load all player images
local playerImages = {
    down = gfx.image.new("images/overworld/player-down"),
    up = gfx.image.new("images/overworld/player-up"),
    left = gfx.image.new("images/overworld/player-right"),
    right = gfx.image.new("images/overworld/player-left"),
}

local playerWalkImages = {
    down = gfx.image.new("images/overworld/player-down-walk"),
    up = gfx.image.new("images/overworld/player-up-walk"),
    left = gfx.image.new("images/overworld/player-right-walk"),
    right = gfx.image.new("images/overworld/player-left-walk"),
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

    self:setImage(playerImages.down)
    self:setCenter(0, 0)
    self:moveTo(self.gridX * TILE_SIZE, self.gridY * TILE_SIZE)
    self:setZIndex(100)
    self:add()
end

function Player:updateSprite()
    if self.isMoving then
        self:setImage(playerWalkImages[self.facing])
    else
        self:setImage(playerImages[self.facing])
    end
end

function Player:canMoveTo(gx, gy)
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

    -- Check for NPC at target position
    if npcManager and npcManager:getNPCAt(targetGX, targetGY) then
        return
    end

    if self:canMoveTo(targetGX, targetGY) then
        self.isMoving = true
        self.moveFrames = 0
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
    if self.isMoving then
        self.moveFrames = self.moveFrames + 1
        local t = self.moveFrames / MOVE_FRAMES
        if t >= 1 then
            t = 1
            self.isMoving = false
            -- Don't switch to idle here; let next frame's input decide
        end
        local px = self.startPixelX + (self.targetPixelX - self.startPixelX) * t
        local py = self.startPixelY + (self.targetPixelY - self.startPixelY) * t
        self:moveTo(px, py)
    else
        -- Only show idle if no movement started this frame
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
    return self.gridX * TILE_SIZE + TILE_SIZE / 2, self.gridY * TILE_SIZE + TILE_SIZE / 2
end
