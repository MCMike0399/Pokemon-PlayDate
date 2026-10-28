import "game/gameOptions"

-- One deliberate 24-degree detent per entry, without acceleration.
Class("CrankScroll")
local DETENT <const> = 24
local reader

function CrankScroll:init()
    self:reset()
end

function CrankScroll:reset()
    self.remainder = 0
    playdate.getCrankChange()
end

function CrankScroll:steps(change)
    if not GameOptions.crankScrolling() then
        self.remainder = 0
        return 0
    end
    self.remainder = self.remainder + change
    local steps = self.remainder >= 0 and math.floor(self.remainder / DETENT)
        or math.ceil(self.remainder / DETENT)
    self.remainder = self.remainder - steps * DETENT
    return steps
end

function CrankScroll:read()
    if reader ~= self or playdate.isCrankDocked() then
        reader = self
        self:reset()
        return 0
    end
    return self:steps(playdate.getCrankChange())
end

function CrankScroll:move(index, count)
    local steps = self:read()
    if count < 5 then
        self.remainder = 0
        return index
    end
    return (index - 1 + steps) % count + 1
end
