import "battle/captureAnimation"

local gfx <const> = playdate.graphics

local battleFont <const> = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")

Class("BattleScene")

-- Lazy-load Pokemon battle sprites (supports all species)
local pokemonSprites = {}

local function getPokemonSprites(species)
    if pokemonSprites[species] then return pokemonSprites[species] end
    if species == "source-substitute" then
        pokemonSprites[species] = {
            front=assert(gfx.image.new("images/battle-effects/substitute-front")),
            back=assert(gfx.image.new("images/battle-effects/substitute-back")),
        }
        return pokemonSprites[species]
    end
    if species == "source-unidentified-ghost" then
        pokemonSprites[species] = {front=assert(gfx.image.new("images/title/ghost"))}
        return pokemonSprites[species]
    end
    local front = gfx.image.new(PokemonArt.path(species, "front"))
    local back = gfx.image.new(PokemonArt.path(species, "back"))
    if front or back then
        pokemonSprites[species] = { front = front, back = back }
    end
    return pokemonSprites[species]
end

-- Status condition short labels
local statusLabels = {
    burn = "BRN", poison = "PSN", badPoison = "PSN", paralyze = "PAR",
    sleep = "SLP", freeze = "FRZ",
}
local FULL_OPTIONS <const> = {"FIGHT", "BAG", "POKEMON", "RUN"}
local SHORT_OPTIONS <const> = {"FIGHT", "RUN"}
local PLATFORM_SHADE <const> = {0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55}
local function mirrored(anchor, offset)
    if anchor.mirror then return -offset end
    return offset
end
-- pokered prints both current and max PP with PrintNumber, bc = 1 byte / 2
-- digits, and the leading-zero flag clear. Digits below 10 are a blank, not
-- a zero or a hyphen (battle core: wBattleMenuCurrentPP and wMaxPP).
function BattleScene.ppField(value)
    assert(type(value) == "number" and value >= 0 and value <= 99 and value == math.floor(value), "pp digit")
    if value < 10 then return " " .. tostring(value) end
    return tostring(value)
end
function BattleScene.ppReadout(current, maxPP)
    return BattleScene.ppField(current) .. "/" .. BattleScene.ppField(maxPP)
end
-- PrintMenuItem (engine/battle/core.asm). The move list is names only.
-- The selected-move box is three rows: TYPE/ at column 1, the type name from
-- PrintMoveType at column 2 of the next row, then PrintNumber's 2-digit
-- current PP at column 5, '/', and the 2-digit max PP. A disabled move
-- prints "disabled!" on the middle row and skips the type and PP.
function BattleScene.moveDetailLines(typeName, current, maxPP, disabled)
    assert(type(typeName) == "string" and typeName == string.upper(typeName) and not typeName:find("%s"), "source type name")
    if disabled then return { "", "disabled!", "" } end
    return {
        "TYPE/",
        " " .. typeName,
        string.rep(" ", 4) .. BattleScene.ppReadout(current, maxPP),
    }
end

function BattleScene:init(battle)
    self.battle = battle
    battle.presentationAttached = true
    self.displayVitals = setmetatable({}, {__mode = "k"})
    self:vitals(battle.player)
    self:vitals(battle.enemy)
    self.mainMenu = BattleMenu()
    self.moveMenu = BattleMenu()
    self.inMoveSelect = false
    self.shiftMenu = BattleMenu()
    self.messageDialog = Dialog()
    self.messageReady = false
    self.messageSeen = nil
    self.playerShown = nil
    self.enemyShown = not battle.trainerName and battle.enemy or nil
    self.trainerVisible = battle.trainerName ~= nil
    self.selectionRequest, self.selectionOpen = nil, false
    self.captureSeen=setmetatable({}, {__mode="k"})
    self.captureAnimation=nil
    self.captureClosed=false
    -- Intro transition
    self.introTimer = 0
    self.introPhase = "iris_in" -- iris_in → ready
    self.irisRadius = 0
    self.introDrawing = true
end

function BattleScene:mainOptions()
    if self.battle.party or self.battle.session then return FULL_OPTIONS end
    return SHORT_OPTIONS -- Existing single-mon callers retain their menu.
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
    if cancelled and self.battle.shiftChoice then
        self.shiftSeen = nil
        self:updateShiftMenu()
    end
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
            -- Names only. TYPE/ and PP stay in the selected-move box.
            self.inMoveSelect = true
            local moveNames = {}
            local moveKeys = {}
            for _, moveKey in ipairs(self.battle.conditions:movesOf(self.battle.player)) do
                moveKeys[#moveKeys + 1] = moveKey
                moveNames[#moveNames + 1] = moveData[moveKey].name
            end
            self.moveKeys = moveKeys
            self.moveDetailShown = nil
            self.moveMenu.columns = 1
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
    if self.captureClosed or self:isCaptureBlocking() or self:isVitalsBlocking() or self.battle.presentationRequest then
        return
    end
    if self.introPhase ~= "ready" or self.introDrawing then return end
    if self.battle.shiftChoice then
        if not self.selectionOpen then
            self.shiftMenu:handleInput()
        end
        return
    end
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
        self:syncMessage()
        if not self.messageReady then
            self.messageDialog:handleInput()
        end
        if self.messageReady then
            self.battle:handleInput()
        end
        self:syncMessage()
    end
    self:syncMessage()
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

    -- Enemy platform (top-right, like a cliff edge)
    if not self.trainerVisible then
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(275, 84, 115, 3)
    gfx.drawLine(265, 87, 275, 84)
    gfx.setPattern(PLATFORM_SHADE)
    gfx.fillRect(268, 87, 122, 6)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(268, 93, 390, 93)
    end

    -- Player platform (bottom-left, wider ground mound)
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(15, 150, 160, 3)
    gfx.drawLine(5, 153, 15, 150)
    gfx.drawLine(175, 150, 185, 153)
    gfx.setPattern(PLATFORM_SHADE)
    gfx.fillRect(8, 153, 175, 8)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(10, 161, 180, 161)
    gfx.drawLine(0, 168, 400, 168)
end

function BattleScene:update()
    if self.captureClosed then return end
    self:updateVitals()
    self:updatePresentation()
    self:syncMessage()
    self.messageDialog:update()
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
    self:updateShiftMenu()
    if not self.introDrawing and not self:isVitalsBlocking() and not self.battle.presentationRequest and self.battle:needsForcedSwitch() then
        self:requestSelection("party")
    end
    if not self.introDrawing then self:updateCapture() end
end

function BattleScene:updateCapture()
    local receipt=self.battle.captureResult
    if receipt and not self.captureSeen[receipt] then
        if self.captureAnimation then self.captureAnimation:cancel() end
        self.captureSeen[receipt]=true
        self.captureAnimation=CaptureAnimation(receipt)
        return -- Present original frame0 once; later updates advance it.
    end
    if self.captureAnimation then self.captureAnimation:update() end
end
function BattleScene:isCaptureBlocking()
    local receipt=self.battle.captureResult
    return (receipt and not self.captureSeen[receipt]) or (self.captureAnimation and not self.captureAnimation.done) or false
end
function BattleScene:getCaptureSnapshot()
    if self.captureClosed then return {phase="closed",frame=0,done=true,shake=0} end
    local receipt=self.battle.captureResult
    if receipt and not self.captureSeen[receipt] then return {phase="pending",frame=0,done=false,shake=0} end
    return self.captureAnimation and self.captureAnimation:getSnapshot() or {phase="idle",frame=0,done=true,shake=0}
end
function BattleScene:exit()
    if self.captureAnimation then self.captureAnimation:cancel() end
    self.battle.presentationAttached = false
    self.battle.presentationRequest = nil
    self.captureClosed=true
    self.selectionRequest,self.selectionOpen=nil,false
    self.mainMenu:hide();self.moveMenu:hide()
    playdate.display.setOffset(0,0)
end

-- Called once per simulation update, and for newly-created effects after input.
-- Drawing only consumes the cached values and never ticks either effect.
function BattleScene:updateEffects(advanceFlash, advanceShake)
    if not GameOptions.battleAnimations() then
        self.flashHide = false
        self.shakeX = 0
        self.shakeY = 0
        self.battle.flashTimer = 0
        self.battle.isFlashing = false
        self.battle.shakeTimer = 0
        return
    end
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
    if self.captureClosed then return end
    -- The twentieth iris frame still renders the fully-open stencil.
    if self.introTimer <= 20 and self.introDrawing then
        -- Draw black background, then reveal circle
        gfx.clear(gfx.kColorBlack)
        if self.irisRadius > 0 then
            -- Use stencil to mask the battle scene inside the circle
            if not self.irisImage then
                self.irisImage = gfx.image.new(400, 240, gfx.kColorBlack)
            end
            gfx.pushContext(self.irisImage)
                gfx.setDrawOffset(0, 0)
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(0, 0, 400, 240)
                gfx.setColor(gfx.kColorWhite)
                gfx.fillCircleAtPoint(200, 120, self.irisRadius)
            gfx.popContext()
            gfx.setStencilImage(self.irisImage)
            self:drawBattleField()
            gfx.clearStencil()
        end
        return
    end

    local fixed=self.selectionOpen or self:isCaptureBlocking()
    playdate.display.setOffset(fixed and 0 or (self.shakeX or 0), fixed and 0 or (self.shakeY or 0))

    self:drawBattleField()
end

function BattleScene:_text(slot, text, font)
    local cache = self.textCache
    if not cache then
        cache = {}
        self.textCache = cache
    end
    local entry = cache[slot]
    if entry and entry.text == text and entry.font == font then return entry end
    local previous = gfx.getFont()
    gfx.setFont(font)
    local width, height = gfx.getTextSize(text)
    if width < 1 then width = 1 end
    if height < 1 then height = 1 end
    local image = gfx.image.new(width, height, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(font)
    gfx.drawText(text, 0, 0)
    gfx.popContext()
    gfx.setFont(previous)
    entry = {text = text, font = font, image = image, width = width, height = height}
    cache[slot] = entry
    return entry
end
function BattleScene:_wrapped(slot, text, width, height)
    local cache = self.textCache
    if not cache then
        cache = {}
        self.textCache = cache
    end
    local entry = cache[slot]
    if entry and entry.text == text and entry.width == width and entry.height == height then return entry end
    local image = gfx.image.new(width, height, gfx.kColorClear)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setFont(gfx.getSystemFont())
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.drawTextInRect(text, 0, 0, width, height)
    gfx.popContext()
    entry = {text = text, image = image, width = width, height = height}
    cache[slot] = entry
    return entry
end
function BattleScene:drawBattleField()
    self:drawBackgroundBase()

    -- Draw pokemon sprites (before platforms so platforms overlap sprite bottoms)
    local flashHide = self.flashHide

    if self.trainerVisible then
        self:drawTrainer()
    end
    if self.enemyShown and (not self.captureAnimation or self.captureAnimation:isEnemyVisible())
        and not (flashHide and self.battle.attackerSide == "player") then
        self:drawPresentedPokemon(self.enemyShown, "enemy", 300, 20, false)
    end
    if self.playerShown and not (flashHide and self.battle.attackerSide == "enemy") then
        self:drawPresentedPokemon(self.playerShown, "player", 55, 70, true)
    end

    -- Draw platforms on top of sprites
    self:drawPlatforms()
    if self.captureAnimation then self.captureAnimation:draw() end
    self:drawPresentation()

    -- HUDs follow the same presented Pokemon as sprites, not the rules' active
    -- battlers, which already exist during trainer/send-out narration.
    if self.enemyShown == self.battle.enemy then
        -- Enemy info box (top-left): name/level row, then HP bar row.
        -- Heights are sized for the fonts (battleFont ~17px, system ~16px)
        -- so nothing pokes through the frame.
        local enemy = self.battle.enemy
        local enemyLevel,enemyHP,enemyMaxHP=self:shownVitals(enemy)
        local name = self.battle:opponentDisplayName()
        local hud = self.enemyHud
        if not hud or hud.name ~= name or hud.level ~= enemyLevel or hud.status ~= enemy.status then
            local label = self:_text("enemy-name", name .. "  Lv" .. enemyLevel, battleFont)
            local hpLabel = self:_text("enemy-hp", "HP", gfx.getSystemFont())
            local statusText = enemy.status and (statusLabels[enemy.status] or "???") or nil
            hud = {
                name = name, level = enemyLevel, status = enemy.status,
                label = label, hpLabel = hpLabel,
                statusImage = statusText and self:_text("enemy-status", statusText, gfx.getSystemFont()) or nil,
                boxW = math.max(140, label.width + 20),
            }
            self.enemyHud = hud
        end
        local eBoxW = hud.boxW
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(4, 4, eBoxW, 40)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(4, 4, eBoxW, 40)
        hud.label.image:draw(12, 7)
        hud.hpLabel.image:draw(12, 23)
        local eBarX, eBarW = 32, eBoxW - 44
        if hud.statusImage then
            eBarW = eBarW - 36
            hud.statusImage.image:draw(eBarX + eBarW + 6, 23)
        end
        self:drawHPBar(eBarX, 26, eBarW, 8, enemyHP, enemyMaxHP)
    end

    if self.playerShown == self.battle.player then
        -- Player info box (bottom-right): name/level, HP bar, HP numbers,
        -- and a thin XP gauge along the bottom edge
        local player = self.battle.player
        local playerLevel,playerHP,playerMaxHP=self:shownVitals(player)
        local hud = self.playerHud
        if not hud or hud.name ~= player.name or hud.level ~= playerLevel or hud.status ~= player.status then
            local label = self:_text("player-name", player.name .. "  Lv" .. playerLevel, battleFont)
            local hpLabel = self:_text("player-hp", "HP", gfx.getSystemFont())
            local statusText = player.status and (statusLabels[player.status] or "???") or nil
            hud = {
                name = player.name, level = playerLevel, status = player.status,
                label = label, hpLabel = hpLabel,
                statusImage = statusText and self:_text("player-status", statusText, gfx.getSystemFont()) or nil,
                boxW = math.max(150, label.width + 20),
            }
            self.playerHud = hud
        end
        local numbers = self.playerHpText
        if not numbers or numbers.hp ~= playerHP or numbers.max ~= playerMaxHP then
            numbers = self:_text("player-hp-num", playerHP .. "/" .. playerMaxHP, gfx.getSystemFont())
            numbers.hp, numbers.max = playerHP, playerMaxHP
            self.playerHpText = numbers
        end
        local pBoxW = hud.boxW
        local pBoxX = 396 - pBoxW
        local pBoxY = 102
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(pBoxX, pBoxY, pBoxW, 62)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(pBoxX, pBoxY, pBoxW, 62)
        hud.label.image:draw(pBoxX + 8, pBoxY + 5)
        hud.hpLabel.image:draw(pBoxX + 8, pBoxY + 22)
        local pBarX, pBarW = pBoxX + 28, pBoxW - 40
        if hud.statusImage then
            pBarW = pBarW - 36
            hud.statusImage.image:draw(pBarX + pBarW + 6, pBoxY + 22)
        end
        self:drawHPBar(pBarX, pBoxY + 25, pBarW, 8, playerHP, playerMaxHP)
        numbers.image:draw(pBoxX + pBoxW - numbers.width - 8, pBoxY + 36)
        -- XP gauge
        local view = self:vitals(player)
        local xpCurrent = view.xp - player:xpForLevel(view.xpLevel)
        local xpNeeded = player:xpForLevel(math.min(100, view.xpLevel + 1)) - player:xpForLevel(view.xpLevel)
        local xpRatio = xpNeeded > 0 and (xpCurrent / xpNeeded) or 1
        gfx.drawRect(pBoxX + 6, pBoxY + 52, pBoxW - 12, 6)
        local xpFill = math.floor(math.max(0, math.min(1, xpRatio)) * (pBoxW - 14))
        if xpFill > 0 then
            gfx.fillRect(pBoxX + 7, pBoxY + 53, xpFill, 4)
        end
    end

    -- Hidden HUDs must still leave narration in its usual system font.
    gfx.setFont(gfx.getSystemFont())

    -- Draw message box or menus
    local boxY = 180
    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect(0, boxY, 400, 60)
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(4, boxY + 4, 392, 52)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, boxY + 4, 392, 52)

    if self.battle.shiftChoice then
        self:_wrapped("shift-prompt", "Change POKEMON?", 180, 44).image:draw(14, boxY + 10)
        self.shiftMenu:draw(204, boxY + 4, 192, 52)
    elseif self.battle:isAwaitingCommand() then
        -- Draw text area on left
        self:_text("what-will", "What will", gfx.getSystemFont()).image:draw(14, boxY + 10)
        local name = self.battle.player.name
        local prompt = self.commandPrompt
        if not prompt or prompt.name ~= name then
            prompt = self:_text("command-prompt", name .. " do?", gfx.getSystemFont())
            prompt.name = name
            self.commandPrompt = prompt
        end
        prompt.image:draw(14, boxY + 28)

        -- Draw menu on right
        if self.inMoveSelect then
            self:drawMoveDetail(12, boxY + 8)
            self.moveMenu:draw(200, boxY + 4, 196, 52)
        else
            if #self:mainOptions()==4 then self.mainMenu:draw(204, boxY + 4, 192, 52)
            else self.mainMenu:draw(300, boxY + 4, 96, 52) end
        end
    else
        -- Word-wrapped inside the frame so long messages never escape
        if self.messageDialog.isActive then
            self.messageDialog:draw()
        else
            local message = self.battle.message or ""
            self:_wrapped("battle-message", message, 374, 44).image:draw(14, boxY + 10)
        end
    end

    -- Separator line
    gfx.setColor(gfx.kColorBlack)
    gfx.drawLine(0, 170, 400, 170)
end

function BattleScene:drawMoveDetail(x, y)
    local key = self.moveKeys and self.moveKeys[self.moveMenu.selectedIndex]
    if not key then return end
    local move = moveData[key]
    local battler = self.battle.player
    local pp = self.battle.conditions:ppOf(battler, key)
    local maxPP = self.battle.conditions:maxPPOf(battler, key)
    local disabled = self.battle.conditions:disabled(battler, key)
    local shown = self.moveDetailShown
    if not shown or shown.key ~= key or shown.pp ~= pp or shown.max ~= maxPP or shown.disabled ~= disabled then
        shown = {
            key = key, pp = pp, max = maxPP, disabled = disabled,
            lines = BattleScene.moveDetailLines(string.upper(move.type), pp, maxPP, disabled),
        }
        self.moveDetailShown = shown
    end
    local font = gfx.getSystemFont()
    for index, line in ipairs(shown.lines) do
        if line ~= "" then
            self:_text("move-detail-" .. index, line, font).image:draw(x, y + (index - 1) * 16)
        end
    end
end

function BattleScene:drawHPBar(x, y, w, h, hp, maxHP)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(x, y, w, h)
    local fillW = math.floor((hp / maxHP) * (w - 2))
    if fillW > 0 then
        gfx.fillRect(x + 1, y + 1, fillW, h - 2)
    end
end

function BattleScene:_scaledSprite(species, isBack, size, source)
    local cache = self.scaledSprites
    if not cache then
        cache = {}
        self.scaledSprites = cache
    end
    local key = species .. (isBack and ":b:" or ":f:") .. size
    local scaled = cache[key]
    if scaled then return scaled end
    local iw, ih = source:getSize()
    local scale = math.min(size / iw, size / ih)
    local sw = math.max(1, math.floor(iw * scale))
    local sh = math.max(1, math.floor(ih * scale))
    local image = gfx.image.new(sw, sh, gfx.kColorWhite)
    gfx.pushContext(image)
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy)
    source:drawScaled(0, 0, scale)
    gfx.popContext()
    scaled = {image = image, sw = sw, sh = sh}
    cache[key] = scaled
    return scaled
end
function BattleScene:drawPokemonSprite(species, x, y, isBack, size)
    size = size or 80
    local sprites = getPokemonSprites(species)
    if sprites then
        local img = isBack and sprites.back or sprites.front
        if img then
            local scaled = self:_scaledSprite(species, isBack, size, img)
            local dx = x + math.floor((size - scaled.sw) / 2)
            local dy = y + math.floor((size - scaled.sh) / 2)
            scaled.image:draw(dx, dy)
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

-- Display values never flow back into Pokemon, rewards or rules RNG.
function BattleScene:vitals(mon)
    local view = self.displayVitals[mon]
    if not view then
        local level, hp, maxHP = self.battle:presentationVitals(mon)
        view = {level = level, hp = hp, maxHP = maxHP, xp = mon.xp, xpLevel = level}
        self.displayVitals[mon] = view
    end
    return view
end

function BattleScene:shownVitals(mon)
    local view = self:vitals(mon)
    local request = self.activePresentation
    local level = request and request.kind == "experience" and request.details.pokemon == mon and view.xpLevel or view.level
    return level, math.ceil(view.hp), view.maxHP
end

function BattleScene:_battlers()
    local pair = self.battlerPair
    if not pair then
        pair = {false, false}
        self.battlerPair = pair
    end
    pair[1], pair[2] = self.battle.player, self.battle.enemy
    return pair
end
function BattleScene:updateVitals()
    for _, mon in ipairs(self:_battlers()) do
        local view = self:vitals(mon)
        local level, hp, maxHP = self.battle:presentationVitals(mon)
        view.level = level
        view.maxHP = maxHP
        local delta = hp - view.hp
        local step = math.max(1, maxHP / 30)
        view.hp = view.hp + math.max(-step, math.min(step, delta))
    end
end

function BattleScene:isVitalsBlocking()
    for _, mon in ipairs(self:_battlers()) do
        local _, hp = self.battle:presentationVitals(mon)
        if self:vitals(mon).hp ~= hp then
            return true
        end
    end
    return false
end

function BattleScene:updatePresentation()
    local request = self.battle.presentationRequest
    if not request then
        return
    end
    if request.kind ~= "experience" then
        self:updateVisualEvent(request)
        return
    end
    local details = request.details
    local mon = details.pokemon
    local view = self:vitals(mon)
    if self.activePresentation ~= request then
        self.activePresentation = request
        view.xp = details.fromXP
        view.xpLevel = details.fromLevel
    end
    -- Fill every crossed level to its edge, then start the next gauge.
    if view.xpLevel < mon.level and view.xp >= mon:xpForLevel(view.xpLevel + 1) then
        view.xpLevel = view.xpLevel + 1
        view.xp = mon:xpForLevel(view.xpLevel)
    else
        local ceiling = view.xpLevel < mon.level and mon:xpForLevel(view.xpLevel + 1) or mon.xp
        local span = mon:xpForLevel(math.min(100, view.xpLevel + 1)) - mon:xpForLevel(view.xpLevel)
        view.xp = math.min(ceiling, view.xp + math.max(1, math.ceil(span / 24)))
        if view.xpLevel == mon.level and view.xp >= mon.xp then
            self.activePresentation = nil
            self.battle:completePresentation(request)
        end
    end
end

function BattleScene:updateShiftMenu()
    local choice = self.battle.shiftChoice
    if choice and self.shiftSeen ~= choice then
        self.shiftSeen = choice
        self.shiftMenu:show({"CHANGE", "KEEP"}, function(index)
            if index == 1 then
                if self:requestSelection("party") then
                    self.shiftMenu:hide()
                end
            elseif self.battle:declineShift() then
                self.shiftMenu:hide()
            end
        end, function()
            self.battle:declineShift()
        end)
    elseif choice and not self.selectionOpen and not self.shiftMenu.isActive then
        self.shiftSeen = nil
    elseif not choice then
        self.shiftMenu:hide()
        self.shiftSeen = nil
    end
end

function BattleScene:updateVisualEvent(request)
    if self.activePresentation ~= request then
        self.activePresentation = request
        self.presentationFrame = 0
        if request.kind == "sendout" then
            self[request.details.side .. "Shown"] = nil
        end
    end
    if self:isVitalsBlocking() then
        return
    end
    self.presentationFrame = self.presentationFrame + 1
    local duration = request.kind == "move" and 24 or 20
    if not GameOptions.battleAnimations() then
        duration = 1
    end
    if request.kind == "sendout" and self.presentationFrame >= 10 then
        self[request.details.side .. "Shown"] = request.details.pokemon
    end
    if self.presentationFrame < duration then
        return
    end
    if request.kind == "trainerExit" then
        self.trainerVisible = false
    elseif request.kind == "sendout" then
        self[request.details.side .. "Shown"] = request.details.pokemon
    elseif request.kind == "recall" or request.kind == "faint" then
        self[request.details.side .. "Shown"] = nil
    end
    self.activePresentation = nil
    self.battle:completePresentation(request)
end

function BattleScene:drawPresentedPokemon(mon, side, x, y, isBack)
    local request = self.activePresentation
    local frame = self.presentationFrame or 0
    local size = 80
    local drop = 0
    if request and request.details.side == side then
        if request.kind == "recall" then
            size = math.max(4, math.floor(80 * (1 - frame / 20)))
        end
        if request.kind == "sendout" then
            size = math.min(80, math.max(4, (frame - 9) * 8))
        end
        if request.kind == "faint" then
            drop = frame * 5
        end
    end
    gfx.setClipRect(x, y, 80, 80)
    local species = self.battle.conditions:speciesOf(mon)
    local sendingOut = request and request.details.side == side and request.kind == "sendout"
    if not sendingOut and self.battle[side] == mon and self.battle.conditions:substituteHP(mon) > 0 then
        -- The source 7x7 canvas carries the doll's exact tile placement. Use
        -- the same fit, centering, pose offset and clipping as Pokemon art.
        species = "source-substitute"
    elseif side == "enemy" and self.battle.sourceEncounter and self.battle.sourceEncounter.unidentified then
        species = "source-unidentified-ghost"
    end
    self:drawPokemonSprite(species, x + (80 - size) // 2, y + (80 - size) // 2 + drop, isBack, size)
    gfx.clearClipRect()
end

function BattleScene:drawTrainer()
    local sourceClass = self.battle.trainerClass
    if not sourceClass then
        return
    end
    if self.trainerClassKey ~= sourceClass then
        self.trainerClassKey = sourceClass
        local class = sourceClass:gsub("^OPP_", "")
        self.trainerImageClass = class
        self.trainerImage = gfx.image.new("images/title/trainers/" .. class)
    end
    if not self.trainerImage then
        return
    end
    local offset = self.activePresentation and self.activePresentation.kind == "trainerExit"
        and (self.presentationFrame or 0) * 6 or 0
    local w, h = self.trainerImage:getSize()
    self.trainerImage:draw(340 - w // 2 + offset, 8)
end

-- Ten reusable monochrome motifs cover all seventeen Gen V types.
local moveMotifs <const> = {
    normal = "impact", fighting = "impact", fire = "flame", dragon = "flame",
    water = "wave", grass = "vine", electric = "bolt", ice = "shards",
    poison = "bubbles", ground = "rubble", rock = "rubble", steel = "rubble",
    psychic = "rings", ghost = "rings", dark = "rings", flying = "wind", bug = "wind",
}

function BattleScene:drawPresentation()
    local request = self.activePresentation
    if not request or request.kind == "experience" or not GameOptions.battleAnimations() then
        return
    end
    local frame = self.presentationFrame or 0
    local details = request.details
    gfx.setColor(gfx.kColorBlack)
    gfx.setClipRect(0, 0, 400, 168)
    if request.kind == "sendout" then
        local x = details.side == "enemy" and 340 or 95
        local y = details.side == "enemy" and 62 or 112
        if frame < 10 then
            local t = frame / 10
            local startX = details.side == "enemy" and 400 or 0
            local ballX = startX + (x - startX) * t
            local ballY = y - math.sin(t * math.pi) * 35
            gfx.setColor(gfx.kColorWhite)
            gfx.fillCircleAtPoint(ballX, ballY, 6)
            gfx.setColor(gfx.kColorBlack)
            gfx.drawCircleAtPoint(ballX, ballY, 6)
            gfx.drawLine(ballX - 6, ballY, ballX + 6, ballY)
            gfx.fillCircleAtPoint(ballX, ballY, 2)
        else
            for ray = 0, 7 do
                local angle = ray * math.pi / 4
                local radius = (frame - 9) * 4
                gfx.drawLine(x + math.cos(angle) * radius, y + math.sin(angle) * radius,
                    x + math.cos(angle) * (radius + 6), y + math.sin(angle) * (radius + 6))
            end
        end
    elseif request.kind == "move" then
        -- Missing targetsFoe keeps the older foe-aimed picture. Agility and
        -- the other user moves pass false and stay on the mover.
        local anchor = Battle.moveAnchor(details.side, details.targetsFoe ~= false)
        local x, y = anchor.x, anchor.y
        local motif = moveMotifs[details.moveType] or "impact"
        for index = 1, 6 do
            local phase = (frame + index * 4) % 24
            local dx = mirrored(anchor, (index - 3) * 12)
            local dy = (index % 3 - 1) * 15
            if motif == "impact" then
                gfx.drawLine(x - phase, y - phase, x + phase, y + phase)
                gfx.drawLine(x + phase, y - phase, x - phase, y + phase)
            elseif motif == "flame" then
                gfx.fillPolygon(x + dx, y + 24 - phase * 2, x + dx - 5, y + 34 - phase, x + dx + 5, y + 34 - phase)
            elseif motif == "wave" then
                gfx.drawCircleAtPoint(x + mirrored(anchor, -24 + phase * 2), y + dy, 4 + index % 3)
            elseif motif == "vine" then
                gfx.drawLine(x + mirrored(anchor, -30) + dx, y + 30, x + mirrored(anchor, -20 + phase) + dx, y - phase)
                gfx.drawLine(x + mirrored(anchor, -20 + phase) + dx, y - phase, x + mirrored(anchor, -26 + phase) + dx, y - phase - 6)
            elseif motif == "bolt" then
                gfx.drawLine(x + dx, y - 32, x + mirrored(anchor, -7) + dx, y - 4)
                gfx.drawLine(x + mirrored(anchor, -7) + dx, y - 4, x + mirrored(anchor, 6) + dx, y - 10)
                gfx.drawLine(x + mirrored(anchor, 6) + dx, y - 10, x + mirrored(anchor, -phase) + dx, y + 28)
            elseif motif == "shards" then
                gfx.drawPolygon(x + dx, y - 32 + phase * 2, x + dx - 5, y - 24 + phase * 2,
                    x + dx, y - 16 + phase * 2, x + dx + 5, y - 24 + phase * 2)
            elseif motif == "bubbles" then
                gfx.drawCircleAtPoint(x + dx, y + 30 - phase * 2, 3 + index % 4)
            elseif motif == "rubble" then
                gfx.fillRect(x + dx, y + 25 - math.sin(phase / 24 * math.pi) * 30, 5, 5)
            elseif motif == "rings" then
                gfx.drawCircleAtPoint(x, y, phase * 2 + index * 2)
            elseif motif == "wind" then
                gfx.drawLine(x + mirrored(anchor, -45 + phase * 2), y + dy, x + mirrored(anchor, -20 + phase * 2), y + dy - 8)
            end
        end
    end
    gfx.clearClipRect()
end

function BattleScene:syncMessage()
    -- Include script generation: repeated identical narration is still a new
    -- page, while drawing remains a read-only consumer of the cached dialog.
    local phase = self.battle.machine:current()
    local serial = phase and phase.messageSerial or 0
    if self.messageSeen == self.battle.message and self.messagePhase == phase and self.messageSerial == serial then
        return
    end
    self.messageSeen = self.battle.message
    self.messagePhase = phase
    self.messageSerial = serial
    self.messageReady = false
    if self.battle.message == "" then
        return
    end
    self.messageDialog:show({self.battle.message}, function()
        self.messageReady = true
    end)
end
