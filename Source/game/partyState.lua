local gfx <const> = playdate.graphics
Class("PartyState"):extends(State)

function PartyState:init(game)
    PartyState.super.init(self, "party")
    self.game, self.menu = game, BattleMenu()
end

function PartyState:enter(options)
    self.options = options or {}
    self.selected, self.phase, self.swapFrom, self.message = 1, "list", nil, nil
    self.menu:hide()
end

function PartyState:exit()
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.options = nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function PartyState:close(index)
    local callback = index and self.options.onSelect or self.options.onCancel
    self.machine:pop()
    if callback then callback(index) end
end

function PartyState:actions()
    self.phase = "actions"
    self.menu:show({"STATS", "SWITCH", "CANCEL"}, function(index)
        if index == 1 then
            self.phase = "stats"
        elseif index == 2 then
            self.swapFrom, self.phase = self.selected, "swap"
            self.menu:hide()
        else self.phase = "list"; self.menu:hide() end
    end, function() self.phase = "list"; self.menu:hide() end)
end

function PartyState:handleInput()
    local party = self.game.session:party()
    local count = party:count()
    if self.phase == "actions" then self.menu:handleInput(); return end
    if self.phase == "stats" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
            self.phase = "list"; self.menu:hide()
        end
        return
    end
    if playdate.buttonJustPressed(playdate.kButtonB) then
        if self.phase == "swap" then self.phase, self.swapFrom = "list", nil
        elseif self.options.allowCancel == false then self.message = "Choose a POKEMON to continue."
        elseif self.options.tryCancel then
            local ok = self.options.tryCancel()
            if ok then self:close() end
        else self:close() end
    elseif count > 0 then
        if playdate.buttonJustPressed(playdate.kButtonUp) then
            self.selected = (self.selected - 2) % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonDown) then
            self.selected = self.selected % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            if self.phase == "swap" then
                assert(party:swap(self.swapFrom, self.selected))
                -- The first conscious roster member leads field encounters.
                local lead = party:firstUsable()
                if lead then assert(party:switch(lead)) end
                self.phase, self.swapFrom = "list", nil
            elseif self.options.trySelect then
                local ok, reason = self.options.trySelect(self.selected)
                if ok then self:close(self.selected)
                else
                    self.message = reason == "fainted" and "That POKEMON has fainted."
                        or reason == "already-active" and "That POKEMON is already out!"
                        or "That POKEMON can't be selected."
                end
            elseif self.options.onSelect then self:close(self.selected)
            else self:actions() end
        end
    end
end

function PartyState:draw()
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    local party = self.game.session:party()
    local mon = party:get(self.selected)
    if self.phase == "stats" and mon then
        gfx.drawText(mon.name .. "  Lv" .. mon.level, 12, 10)
        gfx.drawText("HP " .. mon.hp .. "/" .. mon.maxHP .. "  " .. (mon.status or "OK"):upper(), 12, 34)
        gfx.drawText("ATTACK " .. mon.atk .. "   DEFENSE " .. mon.def, 12, 58)
        gfx.drawText("SP. ATK " .. mon.spa .. "   SP. DEF " .. mon.spd, 12, 82)
        gfx.drawText("SPEED " .. mon.spe .. "   EXP " .. mon.xp, 12, 106)
        for i, key in ipairs(mon.moves) do
            gfx.drawText(moveData[key].name, 12, 124 + i * 19)
            gfx.drawText("PP " .. mon.pp[key] .. "/" .. moveData[key].maxPP, 270, 124 + i * 19)
        end
        gfx.drawText("B: Back", 12, 222)
    else
        gfx.drawText("POKEMON", 12, 6)
        if party:count() == 0 then gfx.drawText("You have no POKEMON yet.", 16, 64) end
        for i, member in ipairs(party:members()) do
            local top = 30 + (i - 1) * 29
            gfx.drawText((i == self.selected and "> " or "  ") .. member.name, 8, top)
            gfx.drawText("Lv" .. member.level, 196, top)
            gfx.drawText(member.hp .. "/" .. member.maxHP, 256, top)
            local status = {poison="PSN",badPoison="PSN",burn="BRN",paralyze="PAR",sleep="SLP",freeze="FRZ"}
            gfx.drawText(member.hp == 0 and "FNT" or status[member.status] or "", 354, top)
            gfx.drawRect(30, top + 21, 140, 4)
            local fill = math.floor(138 * member.hp / member.maxHP)
            if fill > 0 then gfx.fillRect(31, top + 22, fill, 2) end
        end
        local prompt = self.phase == "swap" and "Move to which position?"
            or self.message or self.options.prompt or "Choose a POKEMON.  B: Back"
        gfx.drawText(prompt, 12, 216)
        if self.phase == "actions" then self.menu:draw(210, 146, 180, 76) end
    end
    gfx.setDrawOffset(x, y)
end
