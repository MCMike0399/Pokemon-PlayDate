import "game/gbFont"
local gfx <const> = playdate.graphics
Class("PauseState"):extends(State)

function PauseState:init(game)
    PauseState.super.init(self, "pause")
    self.game, self.menu = game, BattleMenu()
end

function PauseState:enter()
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
            gfx.drawText("Would you like to SAVE the game?", 28, 40)
            self.menu:draw(200, 112, 172, 60)
        else
            -- start_sub_menus.asm TrainerInfo_NameMoneyTimeText.
            -- DrawBadges is tile art this screen does not have, so the
            -- badge count is the text stand-in for that box.
            local session = self.game.session
            local clock = session:playTime()
            local flags = {}
            for _, id in ipairs(TitleIdle.BADGE_FLAGS) do
                flags[id] = session:questFlag(id) == true
            end
            gfx.drawText("NAME/" .. Story.playerName(self.game), 32, 42)
            gfx.drawText("MONEY/$" .. session:inventory():money(), 32, 72)
            gfx.drawText("TIME/" .. TitleIdle.playTimeText(clock.hours, clock.minutes), 32, 102)
            gfx.drawText("BADGES  " .. TitleIdle.countFlags(flags), 32, 132)
            gfx.drawText("A / B: Back", 32, 178)
        end
    end
    gfx.setDrawOffset(x, y)
end

function PauseState:resume()
    self.menu.crank:reset()
end
