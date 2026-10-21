local gfx <const> = playdate.graphics
Class("BagState"):extends(State)

function BagState:init(game)
    BagState.super.init(self, "bag")
    self.game, self.menu = game, BattleMenu()
end

function BagState:enter(options)
    self.visit=(self.visit or 0)+1
    self.options = options or {}
    self.selected, self.phase, self.message = 1, "list", nil
    self.menu:hide()
    self.active = true
end

function BagState:exit()
    self.visit=(self.visit or 0)+1
    self.active = false
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.options = nil
    gfx.sprite.addDirtyRect(0, 0, 400, 240)
end

function BagState:showMessage(text)
    self.phase, self.message = "message", text
    self.menu:hide()
end

function BagState:use(id, index, moveSlot)
    local mon = self.game.session:party():get(index)
    local ok, result = Items.use(self.game.session:inventory(), id, mon, moveSlot)
    if ok then
        self:showMessage(ItemData.definitions[id].name .. " was used on " .. mon.name .. ".")
    elseif result == "no-effect" then
        self:showMessage("It won't have any effect.")
    else
        self:showMessage("That item can't be used here.")
    end
end

function BagState:useStone(id,index)
    local visit,session=self.visit,self.game.session
    local mon=self.game.session:party():get(index)
    local request,reason=Evolution.prepare(self.game.session,mon,{kind="stone",item=id})
    if not request then self:showMessage("It won't have any effect.");return false,reason end
    return EvolutionState.open(self.game,request,function(result)
        if not self.active or self.visit~=visit or self.game.session~=session then return end
        self.phase="list";self.menu:hide()
        if result.kind=="complete" then self.game:offerPartyProgression()
        else self:showMessage("That item could not be used.") end
    end)
end
function BagState:chooseTarget(id)
    local item = ItemData.definitions[id]
    if item.effect == "unsupported" and not Evolution.isStone(id) then self:showMessage("That item can't be used here."); return end
    if self.game.session:party():count() == 0 then self:showMessage("You have no POKEMON yet."); return end
    local visit=self.visit
    self.machine:push("party", {
        prompt = "Use on which POKEMON?",
        onSelect = function(index)
            if not self.active or self.visit~=visit then return end
            if Evolution.isStone(id) then self:useStone(id,index)
            elseif item.effect == "pp" and not item.allMoves then
                local mon = self.game.session:party():get(index)
                local options = {}
                for _, key in ipairs(mon.moves) do
                    options[#options + 1] = moveData[key].name .. "  " .. mon.pp[key] .. "/" .. moveData[key].maxPP
                end
                self.phase = "move"
                self.menu:show(options, function(slot) self:use(id, index, slot) end,
                    function() self.phase = "list"; self.menu:hide() end)
            else self:use(id, index) end
        end,
    })
end

function BagState:actions(id)
    self.phase = "actions"
    self.menu:show({"USE", "TOSS", "CANCEL"}, function(index)
        if index == 1 then
            self.phase = "list"; self.menu:hide()
            self:chooseTarget(id)
        elseif index == 2 then
            if ItemData.definitions[id].keyItem then self:showMessage("That's too important to toss."); return end
            self.phase = "toss"
            self.menu:show({"NO", "YES"}, function(choice)
                if choice == 2 then
                    local ok = self.game.session:inventory():consume(id, 1)
                    self:showMessage(ok and "Threw away one " .. ItemData.definitions[id].name .. "."
                        or "That item is no longer in your bag.")
                else self.phase = "list"; self.menu:hide() end
            end, function() self.phase = "list"; self.menu:hide() end)
        else self.phase = "list"; self.menu:hide() end
    end, function() self.phase = "list"; self.menu:hide() end)
end

function BagState:handleInput()
    if self.phase == "message" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
            self.phase = "list"
        end
        return
    end
    if self.phase ~= "list" then self.menu:handleInput(); return end
    local slots = self.game.session:inventory():slots()
    local count = #slots
    self.selected = math.max(1, math.min(self.selected, count))
    if playdate.buttonJustPressed(playdate.kButtonB) then
        if not self.options.tryCancel or self.options.tryCancel() then self.machine:pop() end
    elseif count > 0 then
        if playdate.buttonJustPressed(playdate.kButtonUp) then self.selected = (self.selected - 2) % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonDown) then self.selected = self.selected % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            local id = slots[self.selected].id
            if self.options.trySelect then
                local ok, reason = self.options.trySelect(id)
                if ok then self.machine:pop()
                else
                    self:showMessage(reason == "trainer-battle" and "You can't catch another TRAINER's POKEMON!"
                        or reason == "storage-full" and "Your party and current BOX are full."
                        or "That item can't be used here.")
                end
            else self:actions(id) end
        end
    end
end

function BagState:draw()
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText("ITEM", 12, 8)
    gfx.drawText("$" .. self.game.session:inventory():money(), 286, 8)
    local slots = self.game.session:inventory():slots()
    local first = math.max(1, self.selected - 7)
    if #slots == 0 then gfx.drawText("Your bag is empty.", 16, 64) end
    for i = first, math.min(#slots, first + 7) do
        local slot, top = slots[i], 36 + (i - first) * 21
        gfx.drawText((i == self.selected and "> " or "  ") .. ItemData.definitions[slot.id].name, 12, top)
        gfx.drawText("x" .. slot.quantity, 328, top)
    end
    gfx.drawText("A: Choose  B: Back", 12, 218)
    if self.phase == "message" then
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(4, 174, 392, 62)
        gfx.setColor(gfx.kColorBlack); gfx.drawRect(4, 174, 392, 62)
        gfx.drawTextInRect(self.message, 14, 184, 372, 42)
    elseif self.phase == "move" then self.menu:draw(12, 112, 376, 96)
    elseif self.phase == "toss" then
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(8, 112, 384, 40)
        gfx.setColor(gfx.kColorBlack); gfx.drawText("Throw away one item?", 18, 122)
        self.menu:draw(208, 152, 180, 60)
    elseif self.phase == "actions" then self.menu:draw(208, 144, 180, 76) end
    gfx.setDrawOffset(x, y)
end
