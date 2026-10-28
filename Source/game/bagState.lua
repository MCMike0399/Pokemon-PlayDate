local gfx <const> = playdate.graphics
Class("BagState"):extends(State)

-- Registration and ordinary USE share these exact supported key-item actions.
local fieldKeyActions = {
    townMap = function(bag)
        return TownMapState.open(bag.game)
    end,
    bicycle = function(bag)
        if not FieldGearState then return false, "field-gear-state-not-installed" end
        return FieldGearState.open(bag.game, bag, "bicycle")
    end,
    oldRod = function(bag)
        if not FieldGearState then return false, "field-gear-state-not-installed" end
        return FieldGearState.open(bag.game, bag, "oldRod")
    end,
    goodRod = function(bag)
        if not FieldGearState then return false, "field-gear-state-not-installed" end
        return FieldGearState.open(bag.game, bag, "goodRod")
    end,
    superRod = function(bag)
        if not FieldGearState then return false, "field-gear-state-not-installed" end
        return FieldGearState.open(bag.game, bag, "superRod")
    end,
}

function BagState.canRegister(id)
    if (id == "bicycle" or id == "oldRod" or id == "goodRod" or id == "superRod")
        and not FieldGearState then
        return false
    end
    local item = ItemData.definitions[id]
    return item ~= nil and item.keyItem and fieldKeyActions[id] ~= nil
end

function BagState:fieldBag()
    return self.active and self:isTop() and self.game.session == self.session
        and not self.options.mode and not self.options.trySelect and not self.battle
end

function BagState:registerItem(id)
    if not self:fieldBag() or not BagState.canRegister(id)
        or (self.session:inventory():quantity(id) or 0) < 1 then
        return false, "unavailable-key-item"
    end
    local previous = GameOptions.registeredItem()
    local selected = previous ~= id and id or nil
    assert(GameOptions.setRegisteredItem(selected))
    if not GameOptions.save() then
        GameOptions.setRegisteredItem(previous)
        self:showMessage("Registration could not be saved.")
        return false, "save-failed"
    end
    self:showMessage(selected and (ItemData.definitions[id].name .. " registered. Use A+B in the field.")
        or "Key item registration cleared.")
    return true
end

function BagState.useRegistered(game)
    local world = game.machine:get("overworld")
    local player = game.player
    if game.machine:current() ~= world or game.machine:depth() ~= 1
        or not world or not world.sub:is("explore") or not player or player.isMoving
        or player.isJumping or player.stepJustFinished or player.pendingEdgeDoor or player.pendingConnection then
        return false, "field-only"
    end
    local id = GameOptions.registeredItem()
    if not id or not BagState.canRegister(id) or (game.session:inventory():quantity(id) or 0) < 1 then
        game.machine:push("dialog", {"Register a usable key item in your Bag first."})
        return false, "unavailable-key-item"
    end
    game.machine:push("bag", {registeredShortcut = true})
    return true
end

function BagState:sortBag()
    if not self:fieldBag() then
        return false, "field-only"
    end
    assert(self.session:inventory():sort())
    self.selected = 1
    self:showMessage("Bag sorted: key items first, then by name.")
    return true
end

function BagState:listCount()
    local count = #self:visibleSlots()
    if self.active and self.options and not self.options.mode and not self.options.trySelect and not self.battle and count > 1 then
        return count + 1
    end
    return count
end

function BagState:init(game)
    BagState.super.init(self, "bag")
    self.game, self.menu = game, BattleMenu()
    self.crank = CrankScroll()
end

-- Explicit field-only selection mode; validates before pushing any state.
function BagState.openHeld(game,options)
    assert(type(options)=="table" and getmetatable(options)==nil,"held bag options required")
    local allowed={mode=true,holder=true,trySelect=true,onComplete=true,onCancel=true}
    for key in pairs(options) do assert(allowed[key],"unknown held bag option") end
    assert(options.mode=="held" and type(options.trySelect)=="function","invalid held bag mode")
    assert(options.onComplete==nil or type(options.onComplete)=="function","invalid held completion")
    assert(options.onCancel==nil or type(options.onCancel)=="function","invalid held cancellation")
    local party=game.machine:get("party")
    if game.machine:current()~=party or not party.active or party.options.trySelect or party.options.onSelect then return false,"field-only" end
    if Party._owner(options.holder)~=game.session:party() then return false,"not-party-member" end
    game.machine:push("bag",options);return true
end
function BagState:visibleSlots()
    local slots=(self.options and self.options.mode=="held" and self.session or self.game.session):inventory():slots()
    if not self.options or self.options.mode~="held" then return slots end
    local filtered={}
    for _,slot in ipairs(slots) do if SpecimenData.holdable[slot.id] then filtered[#filtered+1]=slot end end
    return filtered
end
function BagState:getHeldSnapshot()
    local held=self.active and self.options and self.options.mode=="held"
    local slots=held and self:visibleSlots() or {}
    return {mode=held and "held" or "normal",holder=held and self.options.holder.species or "",count=#slots,
        selected_id=slots[self.selected] and slots[self.selected].id or "none",quantity=slots[self.selected] and slots[self.selected].quantity or 0}
end
function BagState:selectHeld(id)
    if not self.active or not self:isTop() or self.game.session~=self.session or not self.options or self.options.mode~="held" then return false,"stale-selection" end
    local options=self.options
    local ok,result=options.trySelect(id)
    if ok then
        self.heldReceipt=result
        self.machine:pop()
        if options.onComplete then options.onComplete(result) end
    else
        self:showMessage(result=="bag-full" and "There's no room for the returned item."
            or result=="insufficient-items" and "That item is no longer in your bag."
            or result=="already-holding" and "That POKEMON is already holding that item."
            or "That item can't be held.")
    end
    return ok,result
end

function BagState:enter(options)
    self.visit=(self.visit or 0)+1
    self.heldReceipt=nil
    self.options = options or {}
    self.shortcutPending = self.options.registeredShortcut == true
    self.shortcutOpened = false
    self.crank:reset()
    self.selected, self.phase, self.message = 1, "list", nil
    self.menu:hide()
    self.active = true
    self.session,self.battle=self.game.session,self.options.battle
    self.battleSerial=(self.battleSerial or 0)+1
    if self.shortcutPending then
        self:update()
    end
end

function BagState:update()
    if not self.active or not self:isTop() or not self.shortcutPending then
        return
    end
    self.shortcutPending = false
    local id = GameOptions.registeredItem()
    if self.game.session ~= self.session or not id or not BagState.canRegister(id)
        or (self.session:inventory():quantity(id) or 0) < 1 then
        self:showMessage("That registered item is no longer available.")
        return
    end
    self.shortcutOpened = true
    self:chooseTarget(id)
end

function BagState:resume()
    self.crank:reset()
    self.menu.crank:reset()
    if self.options and self.options.registeredShortcut and self.shortcutOpened then
        self.machine:pop()
    end
end

function BagState:exit()
    if self.fieldRequest then FieldItems.cancel(self.fieldRequest);self.fieldRequest=nil end
    self.visit=(self.visit or 0)+1
    self.active = false
    self.phase = "closed"
    self.menu:hide()
    self.menu.onSelect, self.menu.onCancel = nil, nil
    self.options = nil
    self.session,self.battle=nil,nil
    self.battleSerial=(self.battleSerial or 0)+1
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
function BagState:useMachine(id,index)
    if not self.active or not self:isTop() or self.game.session~=self.session then return false,"stale-selection" end
    local request,why=Teaching.prepare(self.session,self.session:party():get(index),id)
    if not request then
        self:showMessage(why=="already-known" and "That POKEMON already knows that move."
            or why=="incompatible" and "That POKEMON can't learn this move."
            or why=="progression-pending" and "Finish learning or evolving first."
            or "That machine can't be used here.")
        return false,why
    end
    local visit,session=self.visit,self.session
    local ok,problem=LearningState.openTeaching(self.game,request,function()
        if self.active and self.visit==visit and self.game.session==session then
            self.phase="list";self.menu:hide()
        end
    end)
    if not ok then Teaching.cancel(request);self:showMessage("That machine can't be used here.") end
    return ok,problem
end
function BagState:chooseTarget(id)
    local item = ItemData.definitions[id]
    if not self.active or not self:isTop() or self.game.session ~= self.session
        or not item or (self.session:inventory():quantity(id) or 0) < 1 then
        self:showMessage("That item is no longer in your bag.")
        return false, "unavailable-item"
    end
    if id=="escapeRope"then return FieldItems.confirmEscape(self) end
    if fieldKeyActions[id] then
        local ok, reason = fieldKeyActions[id](self)
        if not ok then
            self:showMessage("That item can't be used here.")
        end
        return ok, reason
    end
    if item.effect == "unsupported" and not Evolution.isStone(id) and not Teaching.isMachine(id) then self:showMessage("That item can't be used here."); return end
    if self.game.session:party():count() == 0 then self:showMessage("You have no POKEMON yet."); return end
    local visit,session=self.visit,self.session
    local members=session:party():members()
    self.machine:push("party", {
        prompt = "Use on which POKEMON?",
        onSelect = function(index)
            if not self.active or self.visit~=visit or self.session~=session or self.game.session~=session then return end
            if session:party():get(index)~=members[index] then self:showMessage("That selection has changed. Try again.");return end
            if Teaching.isMachine(id) then self:useMachine(id,index)
            elseif Evolution.isStone(id) then self:useStone(id,index)
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
    local options = {"USE", "TOSS"}
    if self:fieldBag() and BagState.canRegister(id) then
        options[#options + 1] = GameOptions.registeredItem() == id and "UNREGISTER" or "REGISTER"
    end
    options[#options + 1] = "CANCEL"
    local visit, session = self.visit, self.session
    self.menu:show(options, function(index)
        if not self.active or not self:isTop() or self.visit ~= visit or self.session ~= session
            or self.game.session ~= session then
            return
        end
        local action = options[index]
        if action == "USE" then
            self.phase = "list"
            self.menu:hide()
            self:chooseTarget(id)
        elseif action == "REGISTER" or action == "UNREGISTER" then
            self:registerItem(id)
        elseif action == "TOSS" then
            if ItemData.definitions[id].keyItem then
                self:showMessage("That's too important to toss.")
                return
            end
            self.phase = "toss"
            self.menu:show({"NO", "YES"}, function(choice)
                if not self.active or not self:isTop() or self.visit ~= visit or self.game.session ~= session then
                    return
                end
                if choice == 2 then
                    local ok = session:inventory():consume(id, 1)
                    self:showMessage(ok and "Threw away one " .. ItemData.definitions[id].name .. "."
                        or "That item is no longer in your bag.")
                else
                    self.phase = "list"
                    self.menu:hide()
                end
            end, function()
                self.phase = "list"
                self.menu:hide()
            end)
        else
            self.phase = "list"
            self.menu:hide()
            self.crank:reset()
        end
    end, function()
        self.phase = "list"
        self.menu:hide()
        self.crank:reset()
    end)
end

function BagState:handleInput()
    if not self.active then return end
    if self.options.mode=="held" and self.game.session~=self.session then return end
    if self.phase == "message" then
        if playdate.buttonJustPressed(playdate.kButtonA) or playdate.buttonJustPressed(playdate.kButtonB) then
            if self.options.registeredShortcut then
                self.machine:pop()
            else
                self.phase = "list"
                self.crank:reset()
            end
        end
        return
    end
    if self.phase ~= "list" then self.menu:handleInput(); return end
    local slots = self:visibleSlots()
    local count = self:listCount()
    self.selected = math.max(1, math.min(self.selected, math.max(1, count)))
    local scrolled = self.crank:move(self.selected, count)
    if playdate.buttonJustPressed(playdate.kButtonB) then
        if self.options.mode=="held" then
            local callback=self.options.onCancel;self.machine:pop();if callback then callback() end
        elseif not self.options.tryCancel or self.options.tryCancel() then self.machine:pop() end
    elseif count > 0 then
        if playdate.buttonJustPressed(playdate.kButtonUp) then self.selected = (self.selected - 2) % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonDown) then self.selected = self.selected % count + 1
        elseif playdate.buttonJustPressed(playdate.kButtonA) then
            if self.selected > #slots then
                self:sortBag()
                return
            end
            local id = slots[self.selected].id
            if self.options.mode=="held" then self:selectHeld(id)
            elseif self.options.trySelect then
                local item=ItemData.definitions[id]
                local medicine={heal=true,fullRestore=true,cure=true,revive=true,pp=true}
                if self.battle and medicine[item.effect] then self:chooseBattleTarget(id);return end
                local ok, reason = self.options.trySelect(id)
                if ok then self.machine:pop()
                else
                    self:showMessage(reason == "trainer-battle" and "You can't catch another TRAINER's POKEMON!"
                        or reason == "storage-full" and "Your party and current BOX are full."
                        or "That item can't be used here.")
                end
            else self:actions(id) end
        else
            self.selected = scrolled
        end
    end
end

function BagState:draw()
    if self.phase == "field-wait" then
        return
    end
    local x, y = gfx.getDrawOffset()
    gfx.setDrawOffset(0, 0)
    gfx.clear(gfx.kColorWhite)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawText(self.options and self.options.mode=="held" and ("GIVE: "..self.options.holder.name) or "ITEM", 12, 8)
    gfx.drawText("$" .. self.game.session:inventory():money(), 286, 8)
    local slots = self:visibleSlots()
    local first = math.max(1, self.selected - 6)
    if not self.options.mode then
        local id = GameOptions.registeredItem()
        local item = id and ItemData.definitions[id]
        local label = item and item.name or "NONE"
        if item and (self.game.session:inventory():quantity(id) or 0) < 1 then
            label = label .. " (missing)"
        end
        gfx.drawText("Registered: " .. label, 12, 27)
    end
    if #slots == 0 then gfx.drawText(self.options and self.options.mode=="held" and "No holdable items in your bag." or "Your bag is empty.", 16, 64) end
    for i = first, math.min(self:listCount(), first + 6) do
        local slot = slots[i]
        local top = 50 + (i - first) * 21
        local prefix = i == self.selected and "> " or "  "
        if slot then
            gfx.drawText(prefix .. ItemData.definitions[slot.id].name, 12, top)
            gfx.drawText("x" .. slot.quantity, 328, top)
        else
            gfx.drawText(prefix .. "SORT BAG", 12, top)
        end
    end
    local hint = self.options.mode == "held" and "A: Give  B: Back" or "A: Choose  B: Back"
    if GameOptions.crankScrolling() and self:listCount() >= 5 then
        hint = hint .. "  Crank: Scroll"
    end
    gfx.drawText(hint, 12, 218)
    if self.phase == "message" then
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(4, 174, 392, 62)
        gfx.setColor(gfx.kColorBlack); gfx.drawRect(4, 174, 392, 62)
        gfx.drawTextInRect(self.message, 14, 184, 372, 42)
    elseif self.phase == "move" then self.menu:draw(12, 112, 376, 96)
    elseif self.phase == "field-confirm" then
        gfx.setColor(gfx.kColorWhite);gfx.fillRect(8,112,384,40)
        gfx.setColor(gfx.kColorBlack);gfx.drawText("Use ESCAPE ROPE?",18,122)
        self.menu:draw(208,152,180,60)
    elseif self.phase == "toss" then
        gfx.setColor(gfx.kColorWhite); gfx.fillRect(8, 112, 384, 40)
        gfx.setColor(gfx.kColorBlack); gfx.drawText("Throw away one item?", 18, 122)
        self.menu:draw(208, 152, 180, 60)
    elseif self.phase == "actions" then self.menu:draw(208, 120, 180, 16 + #self.menu.options * 20) end
    gfx.setDrawOffset(x, y)
end

-- Battle medicine uses the controller's guarded command capability. These
-- callbacks retain identities/visit; neither party nor move preview commits.
function BagState:guardBattle(callback)
    self.battleSerial=(self.battleSerial or 0)+1
    local serial,visit,session,battle,options=self.battleSerial,self.visit,self.session,self.battle,self.options
    return function(...)
        if self.active and self:isTop() and self.battleSerial==serial and self.visit==visit
            and self.game.session==session and self.session==session and self.battle==battle
            and self.options==options and battle and battle.session==session and battle.party==session:party() then
            return callback(...)
        end
        return false,"stale-selection"
    end
end
function BagState:battleMessage(reason)
    self.battleSerial=(self.battleSerial or 0)+1
    self:showMessage(reason=="no-effect" and "It won't have any effect."
        or reason=="insufficient-items" and "That item is no longer in your bag."
        or reason=="stale-selection" and "That selection has changed. Try again."
        or "That item can't be used here.")
    self.menu.onSelect,self.menu.onCancel=nil,nil
end
function BagState:battleUse(id,index,slot,mon,moveKey)
    if not self.active or not self:isTop() or not self.session or not self.options then return false,"stale-selection" end
    if self.game.session~=self.session or self.session:party():get(index)~=mon
        or (slot and mon.moves[slot]~=moveKey) then self:battleMessage("stale-selection");return false,"stale-selection" end
    local ok,result=self.options.trySelect(id,index,slot)
    if ok then self.machine:pop() else self:battleMessage(result) end
    return ok,result
end
function BagState:chooseBattleTarget(id)
    if self.battle:needsForcedSwitch() or not self.battle:isAwaitingCommand() then self:battleMessage("wrong-phase");return end
    local item=ItemData.definitions[id]
    local members=self.session:party():members()
    self.phase="battle-target"
    local selected=self:guardBattle(function(index)
        local mon=members[index]
        if not mon or self.session:party():get(index)~=mon then self:battleMessage("stale-selection");return end
        if item.effect=="pp" and not item.allMoves then
            local moves,options={},{}
            for slot,key in ipairs(mon.moves) do
                moves[slot]=key;options[slot]=moveData[key].name.."  "..mon.pp[key].."/"..moveData[key].maxPP
            end
            self.phase="move"
            local choose=self:guardBattle(function(slot)
                return self:battleUse(id,index,slot,mon,moves[slot])
            end)
            local visit,session,battle,serial=self.visit,self.session,self.battle,self.battleSerial
            self.menu:show(options,choose,function()
                if self.active and self:isTop() and self.visit==visit and self.game.session==session and self.battle==battle and self.battleSerial==serial then
                    self.battleSerial=self.battleSerial+1;self.phase="list";self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
                end
            end)
        else return self:battleUse(id,index,nil,mon) end
    end)
    local visit,session,battle,serial=self.visit,self.session,self.battle,self.battleSerial
    self.machine:push("party",{prompt="Use on which POKEMON?",onSelect=selected,onCancel=function()
        if self.active and self:isTop() and self.visit==visit and self.game.session==session and self.battle==battle and self.battleSerial==serial then
            self.battleSerial=self.battleSerial+1;self.phase="list"
        end
    end})
end
