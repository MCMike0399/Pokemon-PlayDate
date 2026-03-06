local gfx <const> = playdate.graphics

Class("Camera")

function Camera:init()
    self.x = 0
    self.y = 0
end

function Camera:follow(targetX, targetY, mapPixelW, mapPixelH)
    local screenW = 400
    local screenH = 240

    local goalX = targetX - screenW / 2
    local goalY = targetY - screenH / 2

    -- Clamp to map bounds
    if goalX < 0 then goalX = 0 end
    if goalY < 0 then goalY = 0 end
    if goalX > mapPixelW - screenW then goalX = mapPixelW - screenW end
    if goalY > mapPixelH - screenH then goalY = mapPixelH - screenH end

    -- Smooth lerp (20% per frame at 30fps)
    local lerp = 0.2
    self.x = self.x + (goalX - self.x) * lerp
    self.y = self.y + (goalY - self.y) * lerp

    -- Snap when very close to avoid perpetual sub-pixel drift
    if math.abs(self.x - goalX) < 0.5 then self.x = goalX end
    if math.abs(self.y - goalY) < 0.5 then self.y = goalY end
end

function Camera:snapTo(targetX, targetY, mapPixelW, mapPixelH)
    local screenW = 400
    local screenH = 240

    self.x = targetX - screenW / 2
    self.y = targetY - screenH / 2

    if self.x < 0 then self.x = 0 end
    if self.y < 0 then self.y = 0 end
    if self.x > mapPixelW - screenW then self.x = mapPixelW - screenW end
    if self.y > mapPixelH - screenH then self.y = mapPixelH - screenH end
end

function Camera:apply()
    gfx.setDrawOffset(-self.x, -self.y)
end

function Camera:reset()
    gfx.setDrawOffset(0, 0)
end
