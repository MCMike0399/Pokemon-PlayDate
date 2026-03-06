local gfx <const> = playdate.graphics

local battleFont <const> = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")

Class("BattleScene")

-- Lazy-load Pokemon battle sprites (supports all 156 Gen 5 species)
local pokemonSprites = {}

local function getPokemonSprites(species)
    if pokemonSprites[species] then return pokemonSprites[species] end
    local front = gfx.image.new("images/pokemon/" .. species .. "-front")
    local back = gfx.image.new("images/pokemon/" .. species .. "-back")
    if front or back then
        pokemonSprites[species] = { front = front, back = back }
    end
    return pokemonSprites[species]
end

function BattleScene:init(battle)
    self.battle = battle
    self.mainMenu = BattleMenu()
    self.moveMenu = BattleMenu()
    self.inMoveSelect = false
end

function BattleScene:enter()
    self.mainMenu:show({"FIGHT", "RUN"}, function(index)
        if index == 1 then
            -- Fight: show move selection with type effectiveness icons
            self.inMoveSelect = true
            local moveNames = {}
            for _, moveKey in ipairs(self.battle.player.moves) do
                local move = moveData[moveKey]
                local label = move.name
                -- Show type effectiveness icon next to move name
                local mult = TypeChart.getMatchup(move.type, self.battle.enemy.type, self.battle.enemy.type2)
                local icon = TypeChart.icon(mult)
                if icon ~= "" then
                    label = label .. " " .. icon
                end
                table.insert(moveNames, label)
            end
            self.moveMenu.columns = 2
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

function BattleScene:drawBackgroundBase()
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
end

function BattleScene:drawPlatforms()
    local lightShade = {0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55}

    -- Enemy platform (top-right, like a cliff edge)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(275, 84, 115, 3)
    gfx.drawLine(265, 87, 275, 84)
    gfx.setPattern(lightShade)
    gfx.fillRect(268, 87, 122, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(268, 93, 390, 93)

    -- Player platform (bottom-left, wider ground mound)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(15, 150, 160, 3)
    gfx.drawLine(5, 153, 15, 150)
    gfx.drawLine(175, 150, 185, 153)
    gfx.setPattern(lightShade)
    gfx.fillRect(8, 153, 175, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(10, 161, 180, 161)
    gfx.drawLine(0, 168, 400, 168)
end

function BattleScene:draw()
    -- Screen shake
    if self.battle.shakeTimer > 0 then
        local ox = math.random(-self.battle.shakeIntensity, self.battle.shakeIntensity)
        local oy = math.random(-self.battle.shakeIntensity, self.battle.shakeIntensity)
        playdate.display.setOffset(ox, oy)
        self.battle.shakeTimer = self.battle.shakeTimer - 1
        if self.battle.shakeTimer <= 0 then
            playdate.display.setOffset(0, 0)
        end
    end

    self:drawBackgroundBase()

    -- Draw pokemon sprites (before platforms so platforms overlap sprite bottoms)
    local flashHide = self.battle.isFlashing and self.battle.flashTimer > 0 and math.floor(self.battle.flashTimer) % 2 == 0

    -- Enemy sprite (top-right) - front view
    if not flashHide or self.battle.turnQueue[self.battle.turnIndex] == nil or self.battle.turnQueue[self.battle.turnIndex].attacker ~= "player" then
        self:drawPokemonSprite(self.battle.enemy.species, 300, 20, false)
    end

    -- Player sprite (bottom-left) - back view
    if not flashHide or self.battle.turnQueue[self.battle.turnIndex] == nil or self.battle.turnQueue[self.battle.turnIndex].attacker ~= "enemy" then
        self:drawPokemonSprite(self.battle.player.species, 55, 70, true)
    end

    -- Draw platforms on top of sprites
    self:drawPlatforms()

    -- Draw enemy info (top-left)
    local enemyLabel = self.battle.enemy.name .. "  Lv" .. self.battle.enemy.level
    gfx.setFont(battleFont)
    local enemyTextW, _ = gfx.getTextSize(enemyLabel)
    local enemyBoxW = math.max(130, enemyTextW + 16)
    local enemyBarW = enemyBoxW - 16
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, 4, enemyBoxW, 30)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, 4, enemyBoxW, 30)
    gfx.drawText(enemyLabel, 8, 6)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawText("HP", 8, 22)
    self:drawHPBar(24, 23, enemyBarW - 16, 8, self.battle.enemy.hp, self.battle.enemy.maxHP)

    -- Draw player info (bottom-right, above menu)
    local playerLabel = self.battle.player.name .. "  Lv" .. self.battle.player.level
    gfx.setFont(battleFont)
    local playerTextW, _ = gfx.getTextSize(playerLabel)
    local hpText = self.battle.player.hp .. "/" .. self.battle.player.maxHP
    gfx.setFont(gfx.getSystemFont())
    local hpTextW, _ = gfx.getTextSize(hpText)
    local playerBoxW = math.max(130, playerTextW + 16)
    local playerBarW = playerBoxW - 16
    local playerBoxX = 396 - playerBoxW
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(playerBoxX, 110, playerBoxW, 42)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(playerBoxX, 110, playerBoxW, 42)
    gfx.setFont(battleFont)
    gfx.drawText(playerLabel, playerBoxX + 4, 112)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawText("HP", playerBoxX + 4, 128)
    self:drawHPBar(playerBoxX + 20, 129, playerBarW - 18, 8, self.battle.player.hp, self.battle.player.maxHP)
    gfx.drawText(hpText, playerBoxX + playerBoxW - hpTextW - 6, 140)

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
            self.moveMenu:draw(4, boxY + 4, 392, 52)
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
    local size = 80
    local sprites = getPokemonSprites(species)
    if sprites then
        local img = isBack and sprites.back or sprites.front
        if img then
            local iw, ih = img:getSize()
            local scale = math.min(size / iw, size / ih)
            local sw = math.floor(iw * scale)
            local sh = math.floor(ih * scale)
            local dx = x + math.floor((size - sw) / 2)
            local dy = y + math.floor((size - sh) / 2)
            gfx.setColor(gfx.kColorWhite)
            gfx.fillRect(dx, dy, sw, sh)
            img:drawScaled(dx, dy, scale)
            return
        end
    end
    -- Fallback: draw a placeholder silhouette with species initial
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(x, y, size, size)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRoundRect(x + 2, y + 2, size - 4, size - 4, 4)
    local initial = string.upper(string.sub(species, 1, 3))
    local tw, th = gfx.getTextSize(initial)
    gfx.drawText(initial, x + math.floor((size - tw) / 2), y + math.floor((size - th) / 2))
end
