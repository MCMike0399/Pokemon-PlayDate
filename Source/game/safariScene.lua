-- Safari presentation only. Original enemy/capture art; no rules or RNG calls.
Class("SafariScene")
local gfx <const> = playdate.graphics
function SafariScene:init(enemy)
    self.enemy = enemy
    self.image = assert(gfx.image.new(PokemonArt.path(enemy.species, "front")), "missing original Safari enemy art")
end
function SafariScene:draw(resources, animation, command, frame)
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(self.enemy.name, 12, 10)
    gfx.drawText("Lv" .. self.enemy.level, 12, 30)
    gfx.drawText("SAFARI GAME", 12, 76)
    gfx.drawText("BALLS  " .. resources.balls, 12, 100)
    gfx.drawText("STEPS  " .. resources.steps, 12, 120)
    if not animation or animation:isEnemyVisible() then
        local width, height = self.image:getSize()
        local scale = math.min(80 / width, 80 / height)
        self.image:drawScaled(300 + (80 - width * scale) // 2, 30 + (80 - height * scale) // 2, scale)
    end
    if animation then
        animation:draw()
    elseif command == "bait" or command == "rock" then
        -- An object travels to the source-art enemy. It owns no actor/hit state.
        local fraction = math.min(1, frame / 12)
        local x = 105 + 235 * fraction
        local y = 120 - 50 * fraction - 30 * math.sin(fraction * math.pi)
        gfx.setColor(command == "rock" and gfx.kColorBlack or gfx.kColorWhite)
        gfx.fillCircleAtPoint(x, y, 4)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawCircleAtPoint(x, y, 4)
    end
    gfx.popContext()
end
