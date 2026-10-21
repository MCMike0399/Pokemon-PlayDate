-- Native shop overlay. Session owns bag/money; Items owns every transaction.
local gfx <const> = playdate.graphics
Class("ShopState"):extends(State)
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
local messages={
    ["insufficient-money"]="You don't have enough money.",
    ["bag-full"]="You can't carry any more items.",
    ["unsellable-item"]="I can't put a price on that.",
    ["insufficient-items"]="You don't have that many items.",
    ["money-limit"]="You can't carry any more money.",
    ["unique-key-item"]="You already have that item.",
    ["not-stocked"]="That item isn't for sale here.",
}
function ShopState:init(game)
    ShopState.super.init(self,"shop")
    self.game,self.menu=game,BattleMenu()
    self.epoch,self.menuSerial=0,0
    self.active,self.phase,self.selected,self.quantity=false,"closed",1,1
end
function ShopState:inventory() return self.game.session:inventory() end
function ShopState:live() return self.active and self:isTop() end
function ShopState:hideMenu()
    self.menuSerial=self.menuSerial+1
    self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
end
function ShopState:showMenu(options,onSelect,onCancel)
    self:hideMenu()
    local epoch,serial=self.epoch,self.menuSerial
    self.menu:show(options,function(index)
        if self:live() and self.epoch==epoch and self.menuSerial==serial then onSelect(index) end
    end,function()
        if self:live() and self.epoch==epoch and self.menuSerial==serial and onCancel then onCancel() end
    end)
end
function ShopState:enter(options)
    options=options or {}
    local stock=ItemData.marts[options.martId]
    assert(type(stock)=="table" and #stock>0,"known martId required")
    assert(options.onComplete==nil or type(options.onComplete)=="function","invalid shop completion callback")
    for _,id in ipairs(stock) do assert(ItemData.definitions[id],"unknown stocked item") end
    self.epoch=self.epoch+1;self.active=true
    self.martId,self.onComplete=options.martId,options.onComplete
    self.selected,self.quantity,self.item,self.result=1,1,nil,nil
    self:mode()
end
function ShopState:exit()
    self.epoch=self.epoch+1;self.active=false;self.phase="closed";self.onComplete=nil
    self:hideMenu();gfx.sprite.addDirtyRect(0,0,400,240)
end
function ShopState:close()
    if not self:live() then return false end
    local callback,martId=self.onComplete,self.martId
    self.onComplete=nil
    self.machine:pop()
    if callback then callback({martId=martId,reason="closed"}) end
    return true
end
function ShopState:mode()
    self.phase,self.item,self.result="mode",nil,nil
    self:showMenu({"BUY","SELL","QUIT"},function(index)
        if index==3 then self:close() else self.trade=index==1 and "buy" or "sell";self.selected=1;self:browse() end
    end,function() self:close() end)
end
function ShopState:rows()
    local rows={}
    if self.trade=="buy" then
        for _,id in ipairs(ItemData.marts[self.martId]) do rows[#rows+1]={id=id,quantity=self:inventory():quantity(id)} end
    else rows=self:inventory():slots() end
    return rows
end
function ShopState:browse()
    self:hideMenu();self.phase,self.item,self.result="browse",nil,nil
    self.selected=clamp(self.selected,1,math.max(1,#self:rows()))
end
function ShopState:price()
    local data=assert(ItemData.definitions[self.item])
    return self.trade=="buy" and data.price or data.sellPrice
end
function ShopState:showResult(ok,reason,total)
    self:hideMenu();self.phase="result"
    self.result={ok=ok,reason=reason,total=total or 0,
        message=ok and (self.trade=="buy" and "Here you are! Thank you!" or "Thank you!")
            or messages[reason] or "That transaction couldn't be completed."}
end
function ShopState:chooseItem()
    local row=self:rows()[self.selected]
    if not row then return end
    self.item,self.quantity=row.id,1
    local data=ItemData.definitions[row.id]
    if self.trade=="sell" and (data.keyItem or data.category=="hm" or data.sellPrice==nil) then
        self:showResult(false,"unsellable-item");return
    end
    self:hideMenu();self.phase="quantity"
end
function ShopState:confirm()
    self.phase="confirm"
    self:showMenu({"YES","NO"},function(index)
        if index==2 then self:hideMenu();self.phase="quantity";return end
        -- Revalidate against the CURRENT authoritative inventory on YES.
        -- Neither previews nor retained callbacks can commit a stale amount.
        local ok,result
        if self.trade=="buy" then ok,result=Items.buy(self:inventory(),self.martId,self.item,self.quantity)
        else ok,result=Items.sell(self:inventory(),self.item,self.quantity) end
        if ok then self:showResult(true,result.kind,result.total)
        else self:showResult(false,result) end
    end,function() self:hideMenu();self.phase="quantity" end)
end
-- Shared input seam: production SDK keys and contracts use the same dispatcher.
function ShopState:handleButton(button)
    if not self:live() then return end
    if self.phase=="mode" or self.phase=="confirm" then
        if button=="up" then self.menu.selectedIndex=(self.menu.selectedIndex-2)%#self.menu.options+1
        elseif button=="down" then self.menu.selectedIndex=self.menu.selectedIndex%#self.menu.options+1
        elseif button=="a" then if self.menu.onSelect then self.menu.onSelect(self.menu.selectedIndex) end
        elseif button=="b" then if self.menu.onCancel then self.menu.onCancel() end end
    elseif self.phase=="browse" then
        local count=#self:rows()
        if button=="b" then self:mode()
        elseif count>0 then
            self.selected=clamp(self.selected,1,count)
            if button=="up" then self.selected=(self.selected-2)%count+1
            elseif button=="down" then self.selected=self.selected%count+1
            elseif button=="a" then self:chooseItem() end
        end
    elseif self.phase=="quantity" then
        if button=="b" then self:browse()
        elseif button=="a" then self:confirm()
        else
            local delta=({up=1,down=-1,left=-10,right=10})[button]
            if delta then
                local max=self.trade=="buy" and 99 or math.min(99,self:inventory():quantity(self.item) or 0)
                self.quantity=clamp(self.quantity+delta,1,math.max(1,max))
            end
        end
    elseif self.phase=="result" and (button=="a" or button=="b") then self:browse() end
end
function ShopState:handleInput()
    for _,button in ipairs({"b","a","up","down","left","right"}) do
        local key=({b=playdate.kButtonB,a=playdate.kButtonA,up=playdate.kButtonUp,down=playdate.kButtonDown,left=playdate.kButtonLeft,right=playdate.kButtonRight})[button]
        if playdate.buttonJustPressed(key) then self:handleButton(button);return end
    end
end
function ShopState:getSnapshot()
    local result="none"
    if self.result then result={};for key,value in pairs(self.result) do result[key]=value end end
    local options={};for i,value in ipairs(self.menu.options) do options[i]=value end
    local row=self.phase=="browse" and self:rows()[self.selected] or nil
    return {phase=self.phase,selected=self.selected,item=(row and row.id or self.item) or "none",quantity=self.quantity,result=result,
        menu={selected=self.menu.selectedIndex,active=self.menu.isActive,options=options}}
end
local function right(text,x,y) local w=gfx.getTextSize(text);gfx.drawText(text,x-w,y) end
local function box(x,y,w,h)
    gfx.setColor(gfx.kColorWhite);gfx.fillRect(x,y,w,h)
    gfx.setColor(gfx.kColorBlack);gfx.drawRect(x,y,w,h)
end
function ShopState:draw()
    if not self.active then return end
    gfx.pushContext();gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil()
    gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.setFont(gfx.getSystemFont());gfx.setLineWidth(1)
    box(4,4,392,232)
    gfx.drawText("POKE MART"..(self.phase~="mode" and (self.trade=="buy" and " - BUY" or " - SELL") or ""),16,14)
    right("$"..self:inventory():money(),382,14)
    if self.phase=="mode" then
        gfx.drawTextInRect("Hi there!\nMay I help you?",20,64,216,52)
        self.menu:draw(248,52,132,80)
        gfx.drawText("A: Choose   B: Leave",20,208)
    elseif self.phase=="browse" or self.phase=="result" then
        local rows=self:rows();local selected=clamp(self.selected,1,math.max(1,#rows))
        local first=math.max(1,selected-5)
        box(12,44,376,136)
        if #rows==0 then gfx.drawTextInRect("You don't have anything to sell.",24,82,344,52) end
        for i=first,math.min(#rows,first+5) do
            local row=rows[i];local item=ItemData.definitions[row.id];local y=52+(i-first)*20
            gfx.drawText((i==selected and "> " or "  ")..item.name,20,y)
            local price=self.trade=="buy" and item.price or item.sellPrice
            right(self.trade=="sell" and ("x"..row.quantity.."  "..(price~=nil and "$"..price or "--")) or "$"..price,366,y)
        end
        if first>1 then gfx.drawText("^",376,46) end
        if first+5<#rows then gfx.drawText("v",376,162) end
        if self.phase=="result" then
            box(12,184,376,44);gfx.drawTextInRect(self.result.message,22,190,356,34)
        else gfx.drawText("A: Choose   B: Back",20,204) end
    else
        local item=ItemData.definitions[self.item];local price=self:price()
        gfx.drawText(item.name,20,54);right("IN BAG x"..self:inventory():quantity(self.item),380,54)
        gfx.drawText("EACH",20,84);right("$"..price,380,84)
        gfx.drawText("QUANTITY",20,116);right("x"..self.quantity,380,116)
        gfx.drawText("TOTAL",20,146);right("$"..(price*self.quantity),380,146)
        if self.phase=="confirm" then
            gfx.drawText(self.trade=="buy" and "That will be\n$"..(price*self.quantity)..". OK?" or "I can pay you\n$"..(price*self.quantity).." for that.",20,182)
            self.menu:draw(244,172,140,56)
        else
            gfx.drawText("UP/DOWN: 1   LEFT/RIGHT: 10",20,182)
            gfx.drawText("A: Confirm   B: Back",20,208)
        end
    end
    gfx.popContext()
end
