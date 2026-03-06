local gfx <const> = playdate.graphics

class("BattleScene").extends()

-- Pre-load Pokemon battle sprites
local pokemonSprites = {
    squirtle = {
        front = gfx.image.new("images/pokemon/squirtle-front"),
        back = gfx.image.new("images/pokemon/squirtle-back"),
    },
    charmander = {
        front = gfx.image.new("images/pokemon/charmander-front"),
        back = gfx.image.new("images/pokemon/charmander-back"),
    },
}

function BattleScene:init(battle)
    self.battle = battle
    self.mainMenu = BattleMenu()
    self.moveMenu = BattleMenu()
    self.inMoveSelect = false
end

function BattleScene:enter()
    self.mainMenu:show({"FIGHT", "RUN"}, function(index)
        if index == 1 then
            -- Fight: show move selection
            self.inMoveSelect = true
            local moveNames = {}
            for _, moveKey in ipairs(self.battle.player.moves) do
                table.insert(moveNames, moveData[moveKey].name)
            end
            self.moveMenu:show(moveNames, function(moveIndex)
                self.inMoveSelect = false
                self.moveMenu:hide()
                self.mainMenu:hide()
                self.battle:selectMove(moveIndex)
            end, function()
                -- Cancel: back to main menu
                self.inMoveSelect = false
                self.moveMenu:hide()
                self.mainMenu:show({"FIGHT", "RUN"}, self.mainMenu.onSelect, nil)
            end)
        elseif index == 2 then
            -- Run
            self.mainMenu:hide()
            self.battle:tryRun()
        end
    end, nil)
end

function BattleScene:handleInput()
    if self.battle.state == "menu" or self.battle.state == "moveSelect" then
        if self.inMoveSelect then
            self.moveMenu:handleInput()
        else
            if not self.mainMenu.isActive then
                self:enter()
            end
            self.mainMenu:handleInput()
        end
    else
        self.battle:handleInput()
    end
end

function BattleScene:drawBackground()
    gfx.clear(gfx.kColorWhite)

    -- Ground area: light sparse dots (very subtle texture)
    gfx.setColor(gfx.kColorBlack)
    for x = 0, 400, 12 do
        for y = 95, 168, 10 do
            local jitter = (x * 7 + y * 3) % 11
            if jitter < 3 then
                gfx.drawPixel(x + (jitter * 2), y + (jitter))
            end
        end
    end

    -- Enemy platform (top-right, like a cliff edge)
    -- Main platform surface
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(275, 84, 115, 3)
    -- Sloped left edge
    gfx.drawLine(265, 87, 275, 84)
    -- Shading lines underneath (tapering)
    local lightShade = {0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55}
    gfx.setPattern(lightShade)
    gfx.fillRect(268, 87, 122, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(268, 93, 390, 93)

    -- Player platform (bottom-left, wider ground mound)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(15, 150, 160, 3)
    -- Sloped edges
    gfx.drawLine(5, 153, 15, 150)
    gfx.drawLine(175, 150, 185, 153)
    -- Shading underneath
    gfx.setPattern(lightShade)
    gfx.fillRect(8, 153, 175, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(10, 161, 180, 161)
    -- Extra ground line
    gfx.drawLine(0, 168, 400, 168)
end

function BattleScene:draw()
    self:drawBackground()

    -- Draw enemy info (top-left) with white background for readability
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(6, 6, 140, 36)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(6, 6, 140, 36)
    gfx.drawText(self.battle.enemy.name .. "  Lv" .. self.battle.enemy.level, 10, 10)
    self:drawHPBar(10, 28, 120, 10, self.battle.enemy.hp, self.battle.enemy.maxHP)

    -- Draw player info (bottom-right, above menu) with white background
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(246, 106, 140, 52)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(246, 106, 140, 52)
    gfx.drawText(self.battle.player.name .. "  Lv" .. self.battle.player.level, 250, 110)
    self:drawHPBar(250, 128, 120, 10, self.battle.player.hp, self.battle.player.maxHP)
    gfx.drawText(self.battle.player.hp .. "/" .. self.battle.player.maxHP, 300, 140)

    -- Draw pokemon sprites
    local flashHide = self.battle.isFlashing and self.battle.flashTimer > 0 and math.floor(self.battle.flashTimer) % 2 == 0

    -- Enemy sprite (top-right) - front view
    if not flashHide or self.battle.turnQueue[self.battle.turnIndex] == nil or self.battle.turnQueue[self.battle.turnIndex].attacker ~= "player" then
        self:drawPokemonSprite(self.battle.enemy.species, 300, 20, false)
    end

    -- Player sprite (bottom-left) - back view
    if not flashHide or self.battle.turnQueue[self.battle.turnIndex] == nil or self.battle.turnQueue[self.battle.turnIndex].attacker ~= "enemy" then
        self:drawPokemonSprite(self.battle.player.species, 60, 80, true)
    end

    -- Update flash timer
    if self.battle.isFlashing then
        self.battle.flashTimer = self.battle.flashTimer - 1
        if self.battle.flashTimer <= 0 then
            self.battle.isFlashing = false
        end
    end

    -- Draw message box or menus
    local boxY = 180
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, 60)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, 52)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, 52)

    if self.battle.state == "menu" or self.battle.state == "moveSelect" then
        -- Draw text area on left
        gfx.drawText("What will", 14, boxY + 12)
        gfx.drawText(self.battle.player.name .. " do?", 14, boxY + 30)

        -- Draw menu on right
        if self.inMoveSelect then
            self.moveMenu:draw(240, boxY + 4, 156, 52)
        else
            self.mainMenu:draw(300, boxY + 4, 96, 52)
        end
    else
        -- Draw message
        gfx.drawText(self.battle.message, 14, boxY + 18)
    end

    -- Separator line
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, 170, 400, 170)
end

function BattleScene:drawHPBar(x, y, w, h, hp, maxHP)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)
    local fillW = math.floor((hp / maxHP) * (w - 2))
    if fillW > 0 then
        gfx.fillRect(x + 1, y + 1, fillW, h - 2)
    end
end

function BattleScene:drawPokemonSprite(species, x, y, isBack)
    local size = 64
    local sprites = pokemonSprites[species]
    if sprites then
        local img = isBack and sprites.back or sprites.front
        if img then
            local iw, ih = img:getSize()
            local dx = x + math.floor((size - iw) / 2)
            local dy = y + math.floor((size - ih) / 2)
            -- Clear area behind sprite so dither pattern doesn't bleed through
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(dx, dy, iw, ih)
            img:draw(dx, dy)
        end
    end
end
