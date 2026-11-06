local gfx <const> = playdate.graphics

Class("Camera")

-- A map smaller than the screen has no legal scroll. Pin that axis to the
-- origin. The old upper bound was `map - screen`, which is negative and pulled
-- the room to the bottom/right, leaving the default white background above it.
local function clampOrigin(value, mapSize, screenSize)
    local limit = mapSize - screenSize
    if limit < 0 then limit = 0 end
    if value < 0 then return 0 end
    if value > limit then return limit end
    return value
end

function Camera:init()
    self.x = 0
    self.y = 0
end

function Camera:follow(targetX, targetY, mapPixelW, mapPixelH)
    local screenW = 400
    local screenH = 240

    local goalX = clampOrigin(targetX - screenW / 2, mapPixelW, screenW)
    local goalY = clampOrigin(targetY - screenH / 2, mapPixelH, screenH)

    -- Smooth lerp (20% per frame at 30fps)
    local lerp = 0.2
    self.x = self.x + (goalX - self.x) * lerp
    self.y = self.y + (goalY - self.y) * lerp

    -- Snap when very close to avoid perpetual sub-pixel drift
    if math.abs(self.x - goalX) < 0.5 then self.x = goalX end
    if math.abs(self.y - goalY) < 0.5 then self.y = goalY end
end

function Camera:snapTo(targetX, targetY, mapPixelW, mapPixelH)
    self.x = clampOrigin(targetX - 400 / 2, mapPixelW, 400)
    self.y = clampOrigin(targetY - 240 / 2, mapPixelH, 240)
end

function Camera:apply()
    gfx.setDrawOffset(-self.x, -self.y)
end

function Camera:reset()
    gfx.setDrawOffset(0, 0)
end
