-- Personal item PC. Existing PCState continues to own Pokémon storage services.
local gfx <const> = playdate.graphics
Class("ItemPCState"):extends(State)
local messages={
    ["pc-full"]="No room to store items!",["bag-full"]="You can't carry any more items!",
    ["important-item"]="That's too important to toss!",["stale-selection"]="That selection has changed. Try again.",
    ["invalid-quantity"]="Choose a quantity from this item stack.",
}
function ItemPCState:init(game)
    ItemPCState.super.init(self,"itemPC");self.game,self.menu=game,BattleMenu();self.epoch=0;self.serial=0;self.phase="closed"
    self.font=assert(gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold"))
    self.crank = CrankScroll()
end
local function settled(game)
    local p=game.player;local world=game.machine:get("overworld")
    return world and world.sub and world.sub:getCurrent()=="explore"and p and not p.isMoving and not p.isJumping
        and not p.pendingEdgeDoor and not p.pendingConnection and not p.stepJustFinished
end
function ItemPCState.open(game,options)
    options=options or {};local machine=game.machine;local top=machine:current()
    if not machine:get("itemPC")or not settled(game)then return false,"field-only"end
    local parent=options.parent
    if parent then
        if machine:depth()~=2 or top~=parent or parent~=machine:get("pc")or not parent:live()or parent.phase~="top"then return false,"stale-pc-owner"end
    elseif machine:depth()~=1 or top~=machine:get("overworld")or currentZone~=zoneRegistry.reds_house_2f
        or game.player.gridX~=7 or game.player.gridY~=3 or game.player.facing~="up"then return false,"wrong-bedroom-terminal"end
    machine:push("itemPC",options);return true
end
function ItemPCState:live()
    return self.active and self:isTop()and self.game.session==self.session and self.game.player==self.player and currentZone==self.zone
        and self.player.gridX==self.x and self.player.gridY==self.y and settled(self.game)
end
function ItemPCState:hideMenu()
    self.crank:reset()
    self.serial=self.serial+1;self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
end
function ItemPCState:cancelSelection()
    if self.request then self.session:resolvePCItem(self.request,nil,"cancel")end
    self.request,self.selection=nil,nil
end
function ItemPCState:showMenu(options,choose,cancel)
    self:hideMenu();local epoch,serial=self.epoch,self.serial
    self.menu:show(options,function(index)if self:live()and self.epoch==epoch and self.serial==serial then choose(index)end end,
        function()if self:live()and self.epoch==epoch and self.serial==serial then cancel()end end)
end
function ItemPCState:enter(options)
    self.epoch=self.epoch+1;self.active=true;self.session=self.game.session;self.zone=currentZone;self.player=self.game.player
    self.x,self.y=self.player.gridX,self.player.gridY;self.parent=options and options.parent
    self.selected,self.quantity=1,1;self:mainMenu()
end
function ItemPCState:exit()
    self:cancelSelection();self.active=false;self.epoch=self.epoch+1;self.phase="closed";self:hideMenu()
    gfx.sprite.addDirtyRect(0,0,400,240)
end
function ItemPCState:close()if self:live()then self.machine:pop()end end
function ItemPCState:mainMenu()
    self:cancelSelection();self.phase,self.result="menu",nil
    self:showMenu({"WITHDRAW ITEM","DEPOSIT ITEM","TOSS ITEM","LOG OFF"},function(index)
        if index==4 then self:close();return end
        self.operation=({"withdraw","deposit","toss"})[index];self.selected=1;self:list()
    end,function()self:close()end)
end
function ItemPCState:slots()
    return self.operation=="deposit"and self.session:inventory():slots()or self.session:itemStorage():slots()
end
function ItemPCState:list()
    self:cancelSelection();self:hideMenu();self.phase,self.result="list",nil
    local count=#self:slots();self.selected=math.max(1,math.min(self.selected,math.max(1,count)))
    if count==0 then self:message(false,"empty",self.operation=="deposit"and "You have nothing to deposit."or "There are no items stored.","menu")end
end
function ItemPCState:message(ok,reason,text,back)
    self:hideMenu();self.phase="message";self.result={ok=ok,reason=reason,message=text or messages[reason]or "The item operation could not be completed."};self.back=back or "list"
end
function ItemPCState:selectItem()
    self:cancelSelection();local request,selection=self.session:selectPCItem(self.operation,self.selected)
    if not request then self:message(false,selection);return end
    self.request,self.selection,self.quantity=request,selection,1
    if selection.keyItem then self:commit()else self.phase="quantity"end
end
function ItemPCState:confirmQuantity()
    if self.operation~="toss"then self:commit();return end
    self.phase="confirm"
    self:showMenu({"YES","NO"},function(index)if index==1 then self:commit()else self:list()end end,function()self:list()end)
end
function ItemPCState:commit()
    if not self:live()then return false,"stale-pc-owner"end
    local ok,result=self.session:resolvePCItem(self.request,self.quantity,"confirm");self.request=nil
    if not ok then self:message(false,result);return false,result end
    local name=ItemData.definitions[result.id].name
    local text=result.operation=="deposit"and name.." was stored."or result.operation=="withdraw"and "Withdrew "..name.."."or "Threw away "..name.."."
    self:message(true,result.operation,text);return true
end
function ItemPCState:update()
    if self:isTop()and not self:live()then self.machine:pop()end
end
function ItemPCState:handleButton(button)
    if not self:live()then return end
    if self.menu.isActive then
        if button=="up"then self.menu.selectedIndex=(self.menu.selectedIndex-2)%#self.menu.options+1
        elseif button=="down"then self.menu.selectedIndex=self.menu.selectedIndex%#self.menu.options+1
        elseif button=="a"then self.menu.onSelect(self.menu.selectedIndex)
        elseif button=="b"then self.menu.onCancel()end
    elseif self.phase=="list"then
        if button=="b"then self:mainMenu()
        elseif button=="up"then self.selected=(self.selected-2)%#self:slots()+1
        elseif button=="down"then self.selected=self.selected%#self:slots()+1
        elseif button=="a"then self:selectItem()end
    elseif self.phase=="quantity"then
        if button=="b"then self:list()
        elseif button=="up"then self.quantity=self.quantity%self.selection.quantity+1
        elseif button=="down"then self.quantity=(self.quantity-2)%self.selection.quantity+1
        elseif button=="a"then self:confirmQuantity()end
    elseif self.phase=="message"and(button=="a"or button=="b")then if self.back=="menu"then self:mainMenu()else self:list()end end
end
function ItemPCState:handleInput()
    for _,button in ipairs({"b","a","up","down"})do
        if playdate.buttonJustPressed(({b=playdate.kButtonB,a=playdate.kButtonA,up=playdate.kButtonUp,down=playdate.kButtonDown})[button])then
            self.crank:reset()
            self.menu.crank:reset()
            self:handleButton(button)
            return
        end
    end
    if not self:live() then
        return
    end
    if self.menu.isActive then
        self.menu.selectedIndex = self.menu.crank:move(self.menu.selectedIndex, #self.menu.options)
    elseif self.phase == "list" then
        self.selected = self.crank:move(self.selected, #self:slots())
    end
end
function ItemPCState:getSnapshot()
    return {phase=self.phase or "closed",operation=self.operation or "none",selected=self.selected or 1,quantity=self.quantity or 1,
        item=self.selection and self.selection.id or "none",result=self.result or {ok=false,reason="none"},
        menu={active=self.menu.isActive,selected=self.menu.selectedIndex,options=Party._primitive(self.menu.options)}}
end
local function panel(x,y,w,h)gfx.setColor(gfx.kColorWhite);gfx.fillRect(x,y,w,h);gfx.setColor(gfx.kColorBlack);gfx.drawRect(x,y,w,h)end
function ItemPCState:draw()
    if not self.active then return end
    gfx.pushContext();gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.setFont(self.font);gfx.setLineWidth(1)
    panel(4,4,392,232);gfx.drawText("RED'S PC",16,12);gfx.drawText(self.session:itemStorage():count().."/50",310,12)
    if self.phase=="menu"then self.menu:draw(18,44,260,122)
    else
        gfx.drawText(({withdraw="WITHDRAW ITEM",deposit="DEPOSIT ITEM",toss="TOSS ITEM"})[self.operation]or "ITEM STORAGE",18,42)
        local slots=self:slots();local first=math.max(1,self.selected-4)
        for i=first,math.min(#slots,first+4)do local slot=slots[i];local y=66+(i-first)*22
            gfx.drawText((i==self.selected and "> "or "  ")..ItemData.definitions[slot.id].name,18,y);gfx.drawText("x"..slot.quantity,310,y)
        end
        if self.phase=="quantity"then panel(244,112,140,60);gfx.drawText("HOW MANY?",252,120);gfx.drawText("x"..self.quantity,300,144)
        elseif self.phase=="confirm"then self.menu:draw(262,112,120,60)end
    end
    panel(12,184,376,44)
    local text=self.result and self.result.message or self.phase=="confirm"and "Is it OK to throw away this item?"or "A: Choose   B: Back"
    gfx.drawTextInRect(text,20,190,360,36);gfx.popContext()
end

function ItemPCState:resume()
    self.crank:reset()
    self.menu.crank:reset()
end
