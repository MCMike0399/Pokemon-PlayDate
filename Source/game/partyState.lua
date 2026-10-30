local gfx <const> = playdate.graphics
Class("PartyState"):extends(State)

function PartyState:init(game)
    PartyState.super.init(self, "party")
    self.game, self.menu = game, BattleMenu()
    self.crank = CrankScroll()
end

function PartyState:enter(options)
    self.crank:reset()
    self.visit=(self.visit or 0)+1
    self.view=0;self.active=true;self.session=self.game.session
    self.options = options or {}
    self.selected, self.phase, self.swapFrom, self.message = 1, "list", nil, nil
    self.menu:hide()
end

function PartyState:exit()
    self.active=false;self.visit=(self.visit or 0)+1;self.view=(self.view or 0)+1;self.session=nil
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

function PartyState:fieldGuard(callback)
    local visit,view,session=self.visit,self.view,self.session
    return function(...)
        if self.active and self:isTop() and self.visit==visit and self.view==view and self.game.session==session then return callback(...) end
        return false,"stale-selection"
    end
end
function PartyState:actions()
    self.view=self.view+1
    self.phase = "actions"
    local mon = self.session:party():get(self.selected)
    local fields = FieldMoves and FieldMoves.known(mon) or {}
    if FieldTravel and self.game.machine:get("fieldTravel") then
        for _, key in ipairs(FieldTravel.known(mon)) do
            fields[#fields + 1] = key
        end
    end
    local options = {}
    for _, key in ipairs(fields) do options[#options + 1] = key:upper() end
    for _, label in ipairs({"STATS", "SWITCH", "ITEM", "CANCEL"}) do options[#options + 1] = label end
    self.actionCount = #options
    self.menu:show(options, self:fieldGuard(function(index)
        if index <= #fields then
            return FieldMoveState.open(self.game, self, mon, fields[index])
        end
        index = index - #fields
        if index == 1 then
            self.phase = "stats";self.view=self.view+1;self.menu:hide()
        elseif index == 2 then
            self.swapFrom, self.phase = self.selected, "swap";self.view=self.view+1
            self.menu:hide()
        elseif index==3 then self:heldActions()
        else self.phase = "list";self.view=self.view+1;self.menu:hide() end
    end), self:fieldGuard(function() self.phase = "list";self.view=self.view+1;self.menu:hide() end))
end
local function heldFailure(reason)
    return reason=="bag-full" and "There's no room in your bag for that item."
        or reason=="no-held-item" and "That POKEMON isn't holding an item."
        or reason=="already-holding" and "That POKEMON is already holding that item."
        or "That selection is no longer available."
end
function PartyState:heldMessage(text)
    self.phase,self.message="held-message",text;self.view=self.view+1;self.menu:hide()
end
function PartyState:heldActions()
    self.phase="held-actions";self.view=self.view+1
    self.menu:show({"GIVE", "TAKE", "BACK"},self:fieldGuard(function(index)
        if index==1 then self:giveHeld()
        elseif index==2 then
            local mon=self.session:party():get(self.selected)
            local ok,result=self.session:takeHeldItem(mon)
            if ok then self:heldMessage("Received "..ItemData.definitions[result.item].name.." from "..mon.name..".")
            else self:heldMessage(heldFailure(result)) end
        else self:actions() end
    end),self:fieldGuard(function() self:actions() end))
end
function PartyState:giveHeld()
    local mon=self.session:party():get(self.selected)
    if not mon then self:heldMessage(heldFailure("not-party-member"));return false end
    self.phase="held-wait";self.view=self.view+1;self.menu:hide()
    local visit,view,session=self.visit,self.view,self.session
    local options={mode="held",holder=mon}
    local function current()
        return self.active and self.visit==visit and self.view==view and self.session==session and self.game.session==session
    end
    options.trySelect=function(id)
        local bag=self.machine:get("bag")
        if not current() or self.machine:current()~=bag or not bag.active or bag.options~=options or bag.session~=session then return false,"stale-selection" end
        return session:giveHeldItem(mon,id)
    end
    options.onComplete=function(result)
        local bag=self.machine:get("bag")
        if not current() or not self:isTop() or type(result)~="table" or bag.heldReceipt~=result then return false,"stale-selection" end
        self.selected=result.partyIndex
        self:heldMessage(mon.name.." is holding "..ItemData.definitions[result.heldItem].name..".")
        return true
    end
    options.onCancel=function()
        if not current() or not self:isTop() then return false,"stale-selection" end
        self:heldActions();return true
    end
    local ok,reason=BagState.openHeld(self.game,options)
    if not ok then self:heldMessage(heldFailure(reason)) end
    return ok,reason
end
function PartyState:getInfoSnapshot()
    local mon=self.active and self.session and self.session:party():get(self.selected)
    return {page=self.phase,selected=self.selected,species=mon and mon.species or "",nature_id=mon and mon.natureId or 0,
        ability_id=mon and mon:ability() or 0,held_item=mon and mon.heldItem or "none"}
end

-- A forced pop need not call Bag's normal cancellation callback. Recover only
-- on the next top update, after same-call successful/cancel callbacks can finish.
function PartyState:update()
    if self.active and self:isTop() and self.game.session==self.session then
        if self.phase=="held-wait" then self:heldActions()
        elseif self.phase=="field-wait" then self:actions() end
    end
end

function PartyState:handleInput()
    if not self.active or self.game.session~=self.session then return end
    local party = self.game.session:party()
    local count = party:count()
    local scrolled = self.selected
    if self.phase == "list" then
        scrolled = self.crank:move(self.selected, count)
    end
    if self.phase == "actions" or self.phase=="held-actions" then self.menu:handleInput(); return end
    if self.phase=="held-message" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then self:heldActions() end
        return
    end
    if self.phase=="held-wait" or self.phase=="field-wait" then return end
    if self.phase == "stats" or self.phase=="info" then
        if playdate.buttonJustPressed(playdate.kButtonB) then self.phase="list";self.menu:hide()
        elseif playdate.buttonJustPressed(playdate.kButtonA) then self.phase=self.phase=="stats" and "info" or "stats" end
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
                        or reason == "trapped" and "Your POKEMON is trapped!"
                        or "That POKEMON can't be selected."
                end
            elseif self.options.onSelect then self:close(self.selected)
            else self:actions() end
        elseif self.phase == "list" then
            self.selected = scrolled
        end
    end
end

function PartyState:draw()
    if self.phase == "field-wait" then return end
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
        gfx.drawText("A: INFO   B: Back", 12, 222)
    elseif self.phase=="info" and mon then
        gfx.drawText(mon.name.."  Lv"..mon.level,12,10)
        gfx.drawText("NATURE  "..SpecimenData.natures[mon.natureId].name:upper(),12,54)
        gfx.drawText("ABILITY",12,90)
        gfx.drawTextInRect(SpecimenData.abilityNames[mon:ability()]:upper(),12,110,376,36)
        gfx.drawText("HELD ITEM",12,154)
        gfx.drawTextInRect(mon.heldItem=="none" and "NONE" or ItemData.definitions[mon.heldItem].name,12,174,376,36)
        gfx.drawText("A: STATS  B: Back",12,222)
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
        if self.phase=="actions" then self.menu:draw(210,222-(16+(self.actionCount or 4)*20),180,16+(self.actionCount or 4)*20)
        elseif self.phase=="held-actions" then self.menu:draw(210,146,180,76) end
        if self.phase=="held-message" then
            gfx.setColor(gfx.kColorWhite);gfx.fillRect(4,174,392,62)
            gfx.setColor(gfx.kColorBlack);gfx.drawRect(4,174,392,62)
            gfx.drawTextInRect(self.message,14,184,372,42)
        end
    end
    gfx.setDrawOffset(x, y)
end

function PartyState:resume()
    self.crank:reset()
    self.menu.crank:reset()
end
