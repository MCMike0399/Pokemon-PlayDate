import "game/gbFont"
local gfx <const> = playdate.graphics
Class("PauseState"):extends(State)

function PauseState:init(game)
    PauseState.super.init(self, "pause")
    self.game, self.menu = game, BattleMenu()
end

function PauseState:enter()
    self:releaseSaveScreen()
    self.phase = "menu"
    local hasDex = self.game.session:questFlag("EVENT_GOT_POKEDEX")
    local playerName = Story.playerName(self.game)
    -- draw_start_menu.asm DrawStartMenu / home/start_menu.asm DisplayStartMenu
    local options = TitleIdle.startMenu(hasDex, playerName)
    self.menu:show(options, function(index)
        local action = TitleIdle.startAction(hasDex, index)
        if action == "pokedex" or action == "pokemon" or action == "item" then
            self.machine:pop()
            self.machine:push(({pokedex="pokedex", pokemon="party", item="bag"})[action])
        elseif action == "option" then
            self.machine:push("options")
        elseif action == "trainer" then
            self.phase = "trainer"
        elseif action == "save" then
            self.phase = "save"
            self.menu:show({"YES", "NO"}, function(choice)
                if choice == 2 then self:enter(); return end
                self.machine:pop() -- Capture only the settled overworld.
                local ok, metadata = self.game.saves:save()
                self.lastSave = {ok = ok, reason = metadata and metadata.reason}
                self.game.lastSave = self.lastSave
                local lines
                if ok then
                    lines={Story.playerName(self.game) .. " saved the game!"}
                    if metadata and metadata.archived then lines[#lines+1]="Previous save files were kept as a backup." end
                else
                    lines={"Save failed. Your adventure is still in memory.","Restart to review available save recovery."}
                end
                self.machine:push("dialog", lines)
            end, function() self:enter() end)
        else
            self.machine:pop()
        end
    end, function() self.machine:pop() end)
end

function PauseState:exit()
    self:releaseSaveScreen()
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function PauseState:handleInput()
    if self.phase == "trainer" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then self:enter() end
    else
        self.menu:handleInput()
    end
end

function PauseState:draw()
    if self.phase == "menu" or self.phase == "save" then
        self:releaseTrainerScreen()
    end
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    if self.phase == "menu" then
        local hasDex = self.game.session:questFlag("EVENT_GOT_POKEDEX")
        GbFont.drawBox(TitleIdle.startMenuBox(hasDex))
        for index, cell in ipairs(TitleIdle.startMenuCells(self.menu.options)) do
            if index == self.menu.selectedIndex then
                GbFont.drawChar(TitleIdle.CURSOR, 11, cell.row)
            end
            GbFont.drawString(cell.label, 12, cell.row)
        end
    else
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(16, 24, 368, 192)
        gfx.setColor(gfx.kColorBlack); gfx.drawRect(16, 24, 368, 192)
        if self.phase == "save" then
            gfx.clear(gfx.kColorWhite)
            self:drawSave()
        else
            gfx.clear(gfx.kColorWhite)
            self:drawTrainer()
        end
    end
    gfx.setDrawOffset(x, y)
end

-- The trainer card is a standalone pdz. The badge tiles load with the card
-- and drop when it closes, so a boot that never opens it does not keep them.
function PauseState:drawTrainer()
    if not TrainerScreen then
        import "game/gbFont"
        if playdate ~= nil and playdate.file ~= nil and type(playdate.file.run) == "function" then
            playdate.file.run("game/trainerScreen")
        else
            dofile("Source/game/trainerScreen.lua")
        end
    end
    TrainerScreen.draw(self)
end

function PauseState:releaseTrainerScreen()
    if TrainerScreen == nil then return end
    if TrainerScreen.release then TrainerScreen.release() end
    TrainerScreen = nil
    collectgarbage("collect")
    collectgarbage("collect")
end

function PauseState:resume()
    self.menu.crank:reset()
end

-- The save page is a standalone pdz. It is not imported, so the rasterizer,
-- its images, and any font it touches stay out of a boot that never opens
-- SAVE. playdate.file.run loads it for this screen. releaseSaveScreen drops
-- the global and collects when the page closes.
function PauseState:drawSave()
    if not SaveScreen then
        if playdate ~= nil and playdate.file ~= nil and type(playdate.file.run) == "function" then
            playdate.file.run("game/saveScreen")
        else
            dofile("Source/game/saveScreen.lua")
        end
    end
    SaveScreen.draw(self)
end

function PauseState:releaseSaveScreen()
    if SaveScreen == nil then return end
    if SaveScreen.release then SaveScreen.release() end
    SaveScreen = nil
    collectgarbage("collect")
    collectgarbage("collect")
end
