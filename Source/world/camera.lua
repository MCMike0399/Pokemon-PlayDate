local gfx <const> = playdate.graphics

Class("Camera")

function Camera:init()
    self.x = 0
    self.y = 0
end

function Camera:follow(targetX, targetY, mapPixelW, mapPixelH)
    local screenW = 400
    local screenH = 240

    self.x = targetX - screenW / 2
    self.y = targetY - screenH / 2

    -- Clamp to map bounds
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
