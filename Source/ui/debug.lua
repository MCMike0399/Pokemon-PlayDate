local gfx <const> = playdate.graphics

Class("DebugMenu")

-- Debug flags (global so other systems can read them)
DEBUG_FLAGS = {
    noclip = false,
    showFPS = false,
    showGrid = false,
}

local MENU_X <const> = 20
local MENU_Y <const> = 16
local MENU_W <const> = 360
local MENU_H <const> = 208
local LINE_H <const> = 22
local MAX_VISIBLE <const> = 8

function DebugMenu:init()
    self.isActive = false
    self.selectedIndex = 1
    self.scrollOffset = 0
    self.subMenu = nil       -- nil = main menu, string = submenu name
    self.subIndex = 1
    self.subScrollOffset = 0
    self.tempValue = 5       -- reusable numeric picker value
    self.onClose = nil
    self.message = nil
    self.messageTimer = 0

    self.mainOptions = {
        { label = "Wild Battle",  action = "wildBattle" },
        { label = "Heal Pokemon", action = "heal" },
        { label = "Set Level",    action = "setLevel" },
        { label = "Noclip",       action = "toggle", flag = "noclip" },
        { label = "Show FPS",     action = "toggle", flag = "showFPS" },
        { label = "Show Grid",    action = "toggle", flag = "showGrid" },
        { label = "Reset NPCs",   action = "resetNPCs" },
        { label = "Warp Player",  action = "warp" },
        { label = "Close",        action = "close" },
    }

    -- Build species list from pokemonData
    self.speciesList = {}
    for key, _ in pairs(pokemonData) do
        table.insert(self.speciesList, key)
    end
    table.sort(self.speciesList)

    -- Warp presets
    self.warpPresets = {
        { label = "Spawn (6,7)",     x = 6, y = 7 },
        { label = "Oak (10,7)",      x = 9, y = 7 },
        { label = "Rival (13,9)",    x = 12, y = 9 },
        { label = "Pond (8,10)",     x = 7, y = 10 },
        { label = "South (10,13)",   x = 10, y = 13 },
    }
end

function DebugMenu:open(onClose)
    self.isActive = true
    self.selectedIndex = 1
    self.scrollOffset = 0
    self.subMenu = nil
    self.subIndex = 1
    self.subScrollOffset = 0
    self.message = nil
    self.onClose = onClose
end

function DebugMenu:close()
    self.isActive = false
    if self.onClose then self.onClose() end
end

function DebugMenu:showMessage(msg)
    self.message = msg
    self.messageTimer = 45 -- ~1.5 seconds at 30fps
end

function DebugMenu:handleInput()
    if not self.isActive then return end

    -- Flash message takes priority
    if self.message then
        self.messageTimer = self.messageTimer - 1
        if self.messageTimer <= 0 or playdate.buttonJustPressed(playdate.kButtonA) then
            self.message = nil
        end
        return
    end

    if self.subMenu then
        self:handleSubInput()
    else
        self:handleMainInput()
    end
end

function DebugMenu:handleMainInput()
    local count = #self.mainOptions

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then self.selectedIndex = count end
        self:adjustScroll(self.selectedIndex, count)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > count then self.selectedIndex = 1 end
        self:adjustScroll(self.selectedIndex, count)
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        self:executeMain(self.mainOptions[self.selectedIndex])
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        self:close()
    end
end

function DebugMenu:adjustScroll(index, count)
    if index <= self.scrollOffset + 1 then
        self.scrollOffset = math.max(0, index - 1)
    elseif index > self.scrollOffset + MAX_VISIBLE then
        self.scrollOffset = index - MAX_VISIBLE
    end
    -- Wrap-around scroll
    if index == 1 then self.scrollOffset = 0 end
    if index == count and count > MAX_VISIBLE then
        self.scrollOffset = count - MAX_VISIBLE
    end
end

function DebugMenu:executeMain(option)
    if option.action == "close" then
        self:close()
    elseif option.action == "toggle" then
        DEBUG_FLAGS[option.flag] = not DEBUG_FLAGS[option.flag]
        local state = DEBUG_FLAGS[option.flag] and "ON" or "OFF"
        self:showMessage(option.label .. ": " .. state)
    elseif option.action == "heal" then
        self:doHeal()
    elseif option.action == "resetNPCs" then
        self:doResetNPCs()
    elseif option.action == "wildBattle" then
        self.subMenu = "speciesSelect"
        self.subIndex = 1
        self.subScrollOffset = 0
    elseif option.action == "setLevel" then
        self.subMenu = "levelPick"
        self.tempValue = 5
    elseif option.action == "warp" then
        self.subMenu = "warpSelect"
        self.subIndex = 1
        self.subScrollOffset = 0
    end
end

function DebugMenu:handleSubInput()
    if self.subMenu == "speciesSelect" then
        self:handleListInput(self.speciesList, function(index)
            self.selectedSpecies = self.speciesList[index]
            self.subMenu = "battleLevelPick"
            self.tempValue = 5
        end)
    elseif self.subMenu == "battleLevelPick" then
        self:handleNumberInput(1, 100, function(level)
            self:doWildBattle(self.selectedSpecies, level)
        end)
    elseif self.subMenu == "levelPick" then
        self:handleNumberInput(1, 100, function(level)
            self:doSetLevel(level)
        end)
    elseif self.subMenu == "warpSelect" then
        local labels = {}
        for _, preset in ipairs(self.warpPresets) do
            table.insert(labels, preset.label)
        end
        self:handleListInput(labels, function(index)
            self:doWarp(self.warpPresets[index].x, self.warpPresets[index].y)
        end)
    end
end

function DebugMenu:handleListInput(items, onSelect)
    local count = #items

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.subIndex = self.subIndex - 1
        if self.subIndex < 1 then self.subIndex = count end
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.subIndex = self.subIndex + 1
        if self.subIndex > count then self.subIndex = 1 end
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        onSelect(self.subIndex)
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        self.subMenu = nil
    end

    -- Scroll
    if self.subIndex <= self.subScrollOffset + 1 then
        self.subScrollOffset = math.max(0, self.subIndex - 1)
    elseif self.subIndex > self.subScrollOffset + MAX_VISIBLE then
        self.subScrollOffset = self.subIndex - MAX_VISIBLE
    end
    if self.subIndex == 1 then self.subScrollOffset = 0 end
    if self.subIndex == count and count > MAX_VISIBLE then
        self.subScrollOffset = count - MAX_VISIBLE
    end
end

function DebugMenu:handleNumberInput(minVal, maxVal, onConfirm)
    local step = 1
    -- Hold left/right for fast adjust
    if playdate.buttonIsPressed(playdate.kButtonRight) then step = 5 end

    if playdate.buttonJustPressed(playdate.kButtonUp) then
        self.tempValue = math.min(maxVal, self.tempValue + step)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then
        self.tempValue = math.max(minVal, self.tempValue - step)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then
        self.tempValue = math.min(maxVal, self.tempValue + 5)
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then
        self.tempValue = math.max(minVal, self.tempValue - 5)
    elseif playdate.buttonJustPressed(playdate.kButtonA) then
        onConfirm(self.tempValue)
    elseif playdate.buttonJustPressed(playdate.kButtonB) then
        self.subMenu = nil
    end
end

-- ============================================================
-- ACTIONS
-- ============================================================

function DebugMenu:doHeal()
    -- Emit signal so main.lua can heal the player pokemon
    self:showMessage("Pokemon healed!")
    self.pendingAction = { type = "heal" }
end

function DebugMenu:doResetNPCs()
    self:showMessage("NPCs reset!")
    self.pendingAction = { type = "resetNPCs" }
end

function DebugMenu:doWildBattle(species, level)
    self.isActive = false
    self.pendingAction = { type = "wildBattle", species = species, level = level }
    if self.onClose then self.onClose() end
end

function DebugMenu:doSetLevel(level)
    self.subMenu = nil
    self:showMessage("Level set to " .. level .. "!")
    self.pendingAction = { type = "setLevel", level = level }
end

function DebugMenu:doWarp(x, y)
    self.subMenu = nil
    self:showMessage("Warped to (" .. x .. "," .. y .. ")!")
    self.pendingAction = { type = "warp", x = x, y = y }
end

function DebugMenu:consumeAction()
    local action = self.pendingAction
    self.pendingAction = nil
    return action
end

-- ============================================================
-- DRAWING
-- ============================================================

function DebugMenu:draw()
    if not self.isActive then return end

    -- Dim background
    local dimPattern = {0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55}
    gfx.setPattern(dimPattern)
    gfx.fillRect(0, 0, 400, 240)

    -- Main panel
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(MENU_X, MENU_Y, MENU_W, MENU_H)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(MENU_X, MENU_Y, MENU_W, MENU_H)
    gfx.drawRect(MENU_X + 1, MENU_Y + 1, MENU_W - 2, MENU_H - 2)

    -- Title bar
    gfx.fillRect(MENU_X + 2, MENU_Y + 2, MENU_W - 4, 20)
    gfx.setImageDrawMode(gfx.kDrawModeInverted)
    gfx.drawText("DEBUG MENU", MENU_X + 10, MENU_Y + 5)
    gfx.setImageDrawMode(gfx.kDrawModeCopy)

    -- Flash message overlay
    if self.message then
        local msgW, msgH = gfx.getTextSize(self.message)
        local bx = 200 - (msgW + 20) / 2
        local by = 100
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(bx, by, msgW + 20, msgH + 16)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(bx, by, msgW + 20, msgH + 16)
        gfx.drawRect(bx + 1, by + 1, msgW + 18, msgH + 14)
        gfx.drawText(self.message, bx + 10, by + 8)
        return
    end

    local contentY = MENU_Y + 26

    if self.subMenu then
        self:drawSubMenu(contentY)
    else
        self:drawMainMenu(contentY)
    end
end

function DebugMenu:drawMainMenu(startY)
    for i = 1, math.min(MAX_VISIBLE, #self.mainOptions) do
        local optIndex = i + self.scrollOffset
        if optIndex > #self.mainOptions then break end

        local option = self.mainOptions[optIndex]
        local y = startY + (i - 1) * LINE_H
        local label = option.label

        -- Show toggle state inline
        if option.action == "toggle" then
            local state = DEBUG_FLAGS[option.flag] and "[ON]" or "[OFF]"
            label = label .. "  " .. state
        end

        if optIndex == self.selectedIndex then
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(MENU_X + 4, y, MENU_W - 8, LINE_H)
            gfx.setImageDrawMode(gfx.kDrawModeInverted)
            gfx.drawText(label, MENU_X + 16, y + 4)
            gfx.setImageDrawMode(gfx.kDrawModeCopy)
        else
            gfx.drawText(label, MENU_X + 16, y + 4)
        end
    end

    -- Scroll indicators
    if self.scrollOffset > 0 then
        gfx.drawText("^", MENU_X + MENU_W - 20, startY)
    end
    if self.scrollOffset + MAX_VISIBLE < #self.mainOptions then
        gfx.drawText("v", MENU_X + MENU_W - 20, startY + (MAX_VISIBLE - 1) * LINE_H)
    end

    -- Footer hint
    gfx.drawText("A:Select  B:Close", MENU_X + 10, MENU_Y + MENU_H - 18)
end

function DebugMenu:drawSubMenu(startY)
    if self.subMenu == "speciesSelect" then
        gfx.drawText("Select Pokemon:", MENU_X + 10, startY)
        startY = startY + LINE_H
        for i = 1, math.min(MAX_VISIBLE - 1, #self.speciesList) do
            local idx = i + self.subScrollOffset
            if idx > #self.speciesList then break end
            local y = startY + (i - 1) * LINE_H
            local label = string.upper(self.speciesList[idx])
            if idx == self.subIndex then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(MENU_X + 4, y, MENU_W - 8, LINE_H)
                gfx.setImageDrawMode(gfx.kDrawModeInverted)
                gfx.drawText("> " .. label, MENU_X + 16, y + 4)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            else
                gfx.drawText("  " .. label, MENU_X + 16, y + 4)
            end
        end
        gfx.drawText("A:Select  B:Back", MENU_X + 10, MENU_Y + MENU_H - 18)

    elseif self.subMenu == "battleLevelPick" or self.subMenu == "levelPick" then
        local title = self.subMenu == "battleLevelPick"
            and ("Set level for " .. string.upper(self.selectedSpecies or "???") .. ":")
            or "Set player Pokemon level:"
        gfx.drawText(title, MENU_X + 10, startY)

        -- Big centered number
        local numStr = tostring(self.tempValue)
        local numW, _ = gfx.getTextSize(numStr)
        local cx = MENU_X + MENU_W / 2 - numW / 2
        local cy = startY + 50

        -- Up arrow
        gfx.drawText("^", cx + numW / 2 - 3, cy - 20)
        -- Number
        gfx.drawText("*Lv " .. numStr .. "*", cx - 10, cy)
        -- Down arrow
        gfx.drawText("v", cx + numW / 2 - 3, cy + 24)

        gfx.drawText("U/D:+/-1  L/R:+/-5  A:Confirm  B:Back", MENU_X + 10, MENU_Y + MENU_H - 18)

    elseif self.subMenu == "warpSelect" then
        gfx.drawText("Warp to:", MENU_X + 10, startY)
        startY = startY + LINE_H
        for i = 1, math.min(MAX_VISIBLE - 1, #self.warpPresets) do
            local idx = i + self.subScrollOffset
            if idx > #self.warpPresets then break end
            local y = startY + (i - 1) * LINE_H
            local label = self.warpPresets[idx].label
            if idx == self.subIndex then
                gfx.setColor(gfx.kColorBlack)
                gfx.fillRect(MENU_X + 4, y, MENU_W - 8, LINE_H)
                gfx.setImageDrawMode(gfx.kDrawModeInverted)
                gfx.drawText("> " .. label, MENU_X + 16, y + 4)
                gfx.setImageDrawMode(gfx.kDrawModeCopy)
            else
                gfx.drawText("  " .. label, MENU_X + 16, y + 4)
            end
        end
        gfx.drawText("A:Select  B:Back", MENU_X + 10, MENU_Y + MENU_H - 18)
    end
end

-- ============================================================
-- FPS & GRID OVERLAYS (called from main update loop)
-- ============================================================

function DebugMenu.drawOverlays()
    if DEBUG_FLAGS.showFPS then
        playdate.drawFPS(4, 4)
    end

    if DEBUG_FLAGS.showGrid then
        gfx.setColor(gfx.kColorXOR)
        local ts = TILE_SIZE
        local ox, oy = gfx.getDrawOffset()
        local tilesAcross = math.ceil(400 / ts) + 1
        local tilesDown = math.ceil(240 / ts) + 1
        local startTileX = math.floor(-ox / ts)
        local startTileY = math.floor(-oy / ts)
        for tx = startTileX, startTileX + tilesAcross do
            local px = tx * ts
            gfx.drawLine(px, startTileY * ts, px, (startTileY + tilesDown) * ts)
        end
        for ty = startTileY, startTileY + tilesDown do
            local py = ty * ts
            gfx.drawLine(startTileX * ts, py, (startTileX + tilesAcross) * ts, py)
        end
    end
end
