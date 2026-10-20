local gfx <const> = playdate.graphics

local battleFont <const> = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")

Class("BattleScene")

-- Lazy-load Pokemon battle sprites (supports all species)
local pokemonSprites = {}

local function getPokemonSprites(species)
    if pokemonSprites[species] then return pokemonSprites[species] end
    local front = gfx.image.new(PokemonArt.path(species, "front"))
    local back = gfx.image.new(PokemonArt.path(species, "back"))
    if front or back then
        pokemonSprites[species] = { front = front, back = back }
    end
    return pokemonSprites[species]
end

-- Status condition short labels
local statusLabels = {
    burn = "BRN", poison = "PSN", paralyze = "PAR",
    sleep = "SLP", freeze = "FRZ",
}

function BattleScene:init(battle)
    self.battle = battle
    self.mainMenu = BattleMenu()
    self.moveMenu = BattleMenu()
    self.inMoveSelect = false
    self.selectionRequest, self.selectionOpen = nil, false
    -- Intro transition
    self.introTimer = 0
    self.introPhase = "iris_in" -- iris_in → ready
    self.irisRadius = 0
    self.introDrawing = true
end

function BattleScene:mainOptions()
    if self.battle.party or self.battle.session then return {"FIGHT", "BAG", "POKEMON", "RUN"} end
    return {"FIGHT", "RUN"} -- Existing single-mon callers retain their menu.
end

function BattleScene:requestSelection(kind)
    if self.selectionRequest or self.selectionOpen then return false,"selection-open" end
    local ok,problem=self.battle:beginSelection(kind)
    if not ok then return false,problem end
    self.selectionRequest={kind=kind,forced=self.battle:needsForcedSwitch()}
    self.selectionOpen=true
    self.inMoveSelect=false
    self.mainMenu:hide();self.moveMenu:hide()
    return true
end

-- Owner takes each request exactly once, then owns its actual overlay lifecycle.
function BattleScene:takeSelectionRequest()
    local request=self.selectionRequest
    self.selectionRequest=nil
    return request
end

function BattleScene:completeSelection(cancelled)
    if cancelled then
        local ok,problem=self.battle:cancelSelection()
        if not ok then return false,problem end
    elseif self.battle.selectionKind then return false,"selection-unresolved" end
    self.selectionRequest,self.selectionOpen=nil,false
    self.mainMenu:hide();self.moveMenu:hide();self.inMoveSelect=false
    if not self.battle.isFlashing then self.flashHide=false end
    if self.battle.shakeTimer<=0 then self.shakeX,self.shakeY=0,0 end
    return true
end

function BattleScene:enter()
    local options=self:mainOptions()
    self.mainMenu.columns=#options==4 and 2 or 1
    self.mainMenu:show(options, function(index)
        local choice=options[index]
        if choice == "FIGHT" then
            if self.battle:needsStruggle() then
                if self.battle:selectStruggle() then
                    self.inMoveSelect = false
                    self.moveMenu:hide()
                    self.mainMenu:hide()
                end
                return
            end
            -- Fight: show move selection with type effectiveness icons and PP
            self.inMoveSelect = true
            local moveNames = {}
            for _, moveKey in ipairs(self.battle.player.moves) do
                local move = moveData[moveKey]
                local pp = self.battle.player.pp[moveKey] or 0
                local label = move.name
                -- Show type effectiveness icon next to move name
                local mult = TypeChart.getMatchup(move.type, self.battle.enemy.type, self.battle.enemy.type2)
                local icon = TypeChart.icon(mult)
                if icon ~= "" then
                    label = label .. " " .. icon
                end
                -- Show PP
                label = label .. " " .. pp .. "/" .. move.maxPP
                -- Grey out if no PP
                if pp <= 0 then
                    label = "~" .. label .. "~"
                end
                table.insert(moveNames, label)
            end
            self.moveMenu.columns = 2
            self.moveMenu:show(moveNames, function(moveIndex)
                -- The rules API validates phase/index/PP before UI commits.
                if not self.battle:selectMove(moveIndex) then return end
                self.inMoveSelect = false
                self.moveMenu:hide()
                self.mainMenu:hide()
            end, function()
                -- Cancel: back to main menu
                self.inMoveSelect = false
                self.moveMenu:hide()
                self.mainMenu:show(self:mainOptions(), self.mainMenu.onSelect, nil)
            end)
        elseif choice == "RUN" then
            if self.battle:tryRun() then self.mainMenu:hide() end
        elseif choice == "BAG" then
            self:requestSelection("bag")
        elseif choice == "POKEMON" then
            self:requestSelection("party")
        end
    end, nil)
end

function BattleScene:handleInput()
    if self.introPhase ~= "ready" or self.introDrawing then return end
    if self.battle:needsForcedSwitch() then self:requestSelection("party");return end
    if self.selectionOpen then return end

    local flashTimer, isFlashing = self.battle.flashTimer, self.battle.isFlashing
    local shakeTimer, shakeIntensity = self.battle.shakeTimer, self.battle.shakeIntensity
    if self.battle:isAwaitingCommand() then
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
    -- Input can advance a script and start a hit after this frame's update.
    -- Present that new effect on this frame, as the original draw did.
    local flashChanged = self.battle.flashTimer ~= flashTimer or self.battle.isFlashing ~= isFlashing
    local shakeChanged = self.battle.shakeTimer ~= shakeTimer or self.battle.shakeIntensity ~= shakeIntensity
    if flashChanged or shakeChanged then self:updateEffects(flashChanged, shakeChanged) end
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

function BattleScene:update()
    self.introDrawing = self.introPhase == "iris_in"
    -- Intro transition
    if self.introPhase == "iris_in" then
        self.introTimer = self.introTimer + 1
        local maxRadius = 260
        local duration = 20
        self.irisRadius = math.floor((self.introTimer / duration) * maxRadius)
        if self.introTimer >= duration then
            self.introPhase = "ready"
            self.irisRadius = maxRadius
        end

    end
    self:updateEffects(true, not self.introDrawing)
    if not self.introDrawing and self.battle:needsForcedSwitch() then self:requestSelection("party") end
end

-- Called once per simulation update, and for newly-created effects after input.
-- Drawing only consumes the cached values and never ticks either effect.
function BattleScene:updateEffects(advanceFlash, advanceShake)
    if advanceFlash then
        self.flashHide = self.battle.isFlashing and self.battle.flashTimer > 0
            and math.floor(self.battle.flashTimer) % 2 == 0
        if self.battle.isFlashing then
            self.battle.flashTimer = self.battle.flashTimer - 1
            if self.battle.flashTimer <= 0 then self.battle.isFlashing = false end
        end
    end
    if advanceShake then
        self.shakeX, self.shakeY = 0, 0
        if self.battle.shakeTimer > 0 then
            self.shakeX = math.random(-self.battle.shakeIntensity, self.battle.shakeIntensity)
            self.shakeY = math.random(-self.battle.shakeIntensity, self.battle.shakeIntensity)
            self.battle.shakeTimer = self.battle.shakeTimer - 1
            if self.battle.shakeTimer <= 0 then self.shakeX, self.shakeY = 0, 0 end
        end
    end
end

function BattleScene:draw()
    -- The twentieth iris frame still renders the fully-open stencil.
    if self.introTimer <= 20 and self.introDrawing then
        -- Draw black background, then reveal circle
        gfx.clear(gfx.kColorBlack)
        if self.irisRadius > 0 then
            -- Use stencil to mask the battle scene inside the circle
            local stencilImg = gfx.image.new(400, 240, gfx.kColorBlack)
            gfx.pushContext(stencilImg)
                gfx.setColor(gfx.kColorWhite)
                gfx.fillCircleAtPoint(200, 120, self.irisRadius)
            gfx.popContext()
            gfx.setStencilImage(stencilImg)
            self:drawBattleField()
            gfx.clearStencil()
        end
        return
    end

    playdate.display.setOffset(self.selectionOpen and 0 or (self.shakeX or 0), self.selectionOpen and 0 or (self.shakeY or 0))

    self:drawBattleField()
end

function BattleScene:drawBattleField()
    self:drawBackgroundBase()

    -- Draw pokemon sprites (before platforms so platforms overlap sprite bottoms)
    local flashHide = self.flashHide

    -- Enemy sprite (top-right) - front view; hidden while flashing from a player hit
    if not (flashHide and self.battle.attackerSide == "player") then
        self:drawPokemonSprite(self.battle.enemy.species, 300, 20, false)
    end

    -- Player sprite (bottom-left) - back view; hidden while flashing from an enemy hit
    if not (flashHide and self.battle.attackerSide == "enemy") then
        self:drawPokemonSprite(self.battle.player.species, 55, 70, true)
    end

    -- Draw platforms on top of sprites
    self:drawPlatforms()

    -- Enemy info box (top-left): name/level row, then HP bar row.
    -- Heights are sized for the fonts (battleFont ~17px, system ~16px)
    -- so nothing pokes through the frame.
    local enemy = self.battle.enemy
    gfx.setFont(battleFont)
    local enemyLabel = enemy.name .. "  Lv" .. enemy.level
    local enemyTextW, _ = gfx.getTextSize(enemyLabel)
    local eBoxW = math.max(140, enemyTextW + 20)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, 4, eBoxW, 40)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, 4, eBoxW, 40)
    gfx.drawText(enemyLabel, 12, 7)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawText("HP", 12, 23)
    local eBarX, eBarW = 32, eBoxW - 44
    if enemy.status then
        eBarW = eBarW - 36
        gfx.drawText(statusLabels[enemy.status] or "???", eBarX + eBarW + 6, 23)
    end
    self:drawHPBar(eBarX, 26, eBarW, 8, enemy.hp, enemy.maxHP)

    -- Player info box (bottom-right): name/level, HP bar, HP numbers,
    -- and a thin XP gauge along the bottom edge
    local player = self.battle.player
    gfx.setFont(battleFont)
    local playerLabel = player.name .. "  Lv" .. player.level
    local playerTextW, _ = gfx.getTextSize(playerLabel)
    local pBoxW = math.max(150, playerTextW + 20)
    local pBoxX = 396 - pBoxW
    local pBoxY = 102
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(pBoxX, pBoxY, pBoxW, 62)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(pBoxX, pBoxY, pBoxW, 62)
    gfx.drawText(playerLabel, pBoxX + 8, pBoxY + 5)
    gfx.setFont(gfx.getSystemFont())
    gfx.drawText("HP", pBoxX + 8, pBoxY + 22)
    local pBarX, pBarW = pBoxX + 28, pBoxW - 40
    if player.status then
        pBarW = pBarW - 36
        gfx.drawText(statusLabels[player.status] or "???", pBarX + pBarW + 6, pBoxY + 22)
    end
    self:drawHPBar(pBarX, pBoxY + 25, pBarW, 8, player.hp, player.maxHP)
    local hpText = player.hp .. "/" .. player.maxHP
    local hpTextW, _ = gfx.getTextSize(hpText)
    gfx.drawText(hpText, pBoxX + pBoxW - hpTextW - 8, pBoxY + 36)
    -- XP gauge
    local xpCurrent = player.xp - player:xpForLevel(player.level)
    local xpNeeded = player.xpToNext - player:xpForLevel(player.level)
    local xpRatio = xpNeeded > 0 and (xpCurrent / xpNeeded) or 1
    gfx.drawRect(pBoxX + 6, pBoxY + 52, pBoxW - 12, 6)
    local xpFill = math.floor(xpRatio * (pBoxW - 14))
    if xpFill > 0 then
        gfx.fillRect(pBoxX + 7, pBoxY + 53, xpFill, 4)
    end

    -- Draw message box or menus
    local boxY = 180
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, 60)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, 52)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, 52)

    if self.battle:isAwaitingCommand() then
        -- Draw text area on left
        gfx.drawText("What will", 14, boxY + 10)
        gfx.drawText(self.battle.player.name .. " do?", 14, boxY + 28)

        -- Draw menu on right
        if self.inMoveSelect then
            self.moveMenu:draw(4, boxY + 4, 392, 52)
        else
            if #self:mainOptions()==4 then self.mainMenu:draw(204, boxY + 4, 192, 52)
            else self.mainMenu:draw(300, boxY + 4, 96, 52) end
        end
    else
        -- Word-wrapped inside the frame so long messages never escape
        gfx.drawTextInRect(self.battle.message, 14, boxY + 10, 374, 44)
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
