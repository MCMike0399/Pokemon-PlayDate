-- Box transfers retain actual Pokemon identity and all persistent attributes.
local gfx <const> = playdate.graphics
local pcFont <const> = assert(gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold"),"existing battle font required")
Class("PCState"):extends(State)
local errors={
    ["box-full"]="Oops! This Box is full of POKEMON.",["party-full"]="You can't take any more POKEMON. Deposit POKEMON first.",
    ["last-member"]="You can't deposit the last POKEMON!",
    ["last-usable"]="Keep a POKEMON that can battle.",
    ["stale-selection"]="That selection has changed. Try again.",
    ["invalid-index"]="What? There are no POKEMON here!",
}
function PCState:init(game)
    PCState.super.init(self,"pc");self.game,self.menu=game,BattleMenu();self.font=pcFont
    self.epoch,self.serial,self.active,self.phase=0,0,false,"closed"
    self.crank = CrankScroll()
end
function PCState:live()
    return self.active and self:isTop() and self.game.session==self.session
end
function PCState:hideMenu()
    self.crank:reset()
    self.serial=self.serial+1;self.menu:hide();self.menu.onSelect,self.menu.onCancel=nil,nil
end
function PCState:showMenu(options,choose,cancel,selected)
    self:hideMenu();local epoch,serial=self.epoch,self.serial
    self.menu:show(options,function(index)
        if self:live() and self.epoch==epoch and self.serial==serial then choose(index) end
    end,function()
        if self:live() and self.epoch==epoch and self.serial==serial and cancel then cancel() end
    end)
    self.menu.selectedIndex=selected or 1
end
function PCState:enter(options)
    options=options or {};assert(options.onComplete==nil or type(options.onComplete)=="function","invalid PC completion")
    self.epoch=self.epoch+1;self.active=true;self.session=self.game.session
    self.onComplete,self.terminal_id=options.onComplete,options.terminal_id
    self.selected,self.box,self.result,self.selection=1,self.session:storage():activeBox(),nil,nil
    self:top()
end
function PCState:exit()
    self.active=false;self.epoch=self.epoch+1;self.phase="closed";self.onComplete=nil;self.selection=nil
    self:hideMenu();gfx.sprite.addDirtyRect(0,0,400,240)
end
function PCState:close()
    if not self:live() then return false end
    local callback=self.onComplete;self.onComplete=nil;self.machine:pop()
    if callback then callback() end;return true
end
function PCState:top()
    self.phase,self.result="top",nil
    local quest=self.session:flags().quest
    local options={quest.EVENT_MET_BILL and "BILL'S PC" or "SOMEONE'S PC","RED'S PC"}
    if quest.EVENT_GOT_POKEDEX then options[#options+1]="PROF.OAK'S PC" end
    options[#options+1]="LOG OFF"
    self:showMenu(options,function(index)
        if index==1 then self:storageMenu()
        elseif index==2 then assert(ItemPCState.open(self.game,{parent=self}))
        elseif index==#options then self:close()
        else self:showResult(false,"unavailable","That PC service is not available yet.","top") end
    end,function() self:close() end)
end
function PCState:storageMenu()
    self.phase,self.result,self.selection="storage",nil,nil
    self:showMenu({"WITHDRAW PKMN","DEPOSIT PKMN","RELEASE PKMN","CHANGE BOX","SEE YA!"},function(index)
        if index==5 then self:top()
        elseif index==4 then self:confirmBoxChange()
        else self.operation=({"withdraw","deposit","release"})[index];self.selected=1;self:list() end
    end,function() self:top() end)
end
function PCState:count()
    return self.operation=="deposit" and self.session:party():count() or self.session:storage():count()
end
function PCState:mon(index)
    if self.operation=="deposit" then return self.session:party():get(index) end
    return self.session:storage():get(index)
end
function PCState:list()
    self:hideMenu();self.phase,self.result,self.selection="list",nil,nil
    self.selected=math.max(1,math.min(self.selected,math.max(1,self:count())))
end
function PCState:showResult(ok,reason,message,back)
    self:hideMenu();self.phase="result";self.result={ok=ok,reason=reason,message=message or errors[reason] or "The operation could not be completed."}
    self.resultBack=back or "list"
end
function PCState:validSelection()
    local selection=self.selection
    return selection and selection.box==self.session:storage():activeBox() and self:mon(selection.index)==selection.mon
end
function PCState:commitSelection()
    if not self:validSelection() then self:showResult(false,"stale-selection");return end
    local selected=self.selection;local storage,party=self.session:storage(),self.session:party()
    local ok,reason
    if self.operation=="deposit" then ok,reason=storage:deposit(party,selected.index)
    elseif self.operation=="withdraw" then ok,reason=storage:withdraw(party,selected.index)
    else ok,reason=storage:release(selected.index,selected.mon) end
    if ok then
        local message=self.operation=="deposit" and (selected.mon.name.." was stored in Box "..storage:activeBox()..".")
            or self.operation=="withdraw" and (selected.mon.name.." is taken out. Got "..selected.mon.name..".") or (selected.mon.name.." was released outside. Bye "..selected.mon.name.."!")
        self:showResult(true,self.operation,message)
    else self:showResult(false,reason) end
end
function PCState:chooseMon()
    local mon=self:mon(self.selected);if not mon then return end
    self.selection={mon=mon,index=self.selected,box=self.session:storage():activeBox()}
    if self.operation=="release" then
        self.phase="release-confirm"
        self:showMenu({"YES","NO"},function(index)
            if index==1 then self:commitSelection() else self:list() end
        end,function() self:list() end,2)
    else
        self.phase="actions"
        self:showMenu({self.operation=="deposit" and "DEPOSIT" or "WITHDRAW","STATS","CANCEL"},function(index)
            if index==1 then self:commitSelection()
            elseif index==2 then self:hideMenu();self.phase="detail"
            else self:list() end
        end,function() self:list() end)
    end
end
function PCState:confirmBoxChange()
    self.phase="box-confirm"
    self:showMenu({"YES","NO"},function(index)
        if index==1 then self:hideMenu();self.phase="boxes";self.box=self.session:storage():activeBox()
        else self:storageMenu() end
    end,function() self:storageMenu() end,2)
end
function PCState:saveBox()
    local epoch=self.epoch
    local ok,metadata
    if self.game.saves then ok,metadata=self.game.saves:changeBoxFromPC(self,self.box,epoch)
    else ok,metadata=false,{reason="save-service-unavailable"} end
    if not self:live() or self.epoch~=epoch then return end
    self:showResult(ok,metadata and metadata.reason or (ok and "saved" or "save-failed"),
        ok and "The BOX was changed. Game saved." or "Save not confirmed. BOX selection restored.","storage")
end
function PCState:handleButton(button)
    if not self:live() then return end
    if self.menu.isActive then
        if button=="up" then self.menu.selectedIndex=(self.menu.selectedIndex-2)%#self.menu.options+1
        elseif button=="down" then self.menu.selectedIndex=self.menu.selectedIndex%#self.menu.options+1
        elseif button=="a" then if self.menu.onSelect then self.menu.onSelect(self.menu.selectedIndex) end
        elseif button=="b" then if self.menu.onCancel then self.menu.onCancel() end end
    elseif self.phase=="list" then
        if button=="b" then self:storageMenu()
        elseif self:count()>0 then
            if button=="up" then self.selected=(self.selected-2)%self:count()+1
            elseif button=="down" then self.selected=self.selected%self:count()+1
            elseif button=="a" then self:chooseMon() end
        end
    elseif self.phase=="detail" then
        if button=="a" or button=="b" then self:list() end
    elseif self.phase=="boxes" then
        if button=="b" then self:storageMenu()
        elseif button=="up" then self.box=(self.box-2)%Storage.BOX_COUNT+1
        elseif button=="down" then self.box=self.box%Storage.BOX_COUNT+1
        elseif button=="a" then self:saveBox() end
    elseif self.phase=="result" and (button=="a" or button=="b") then
        if self.resultBack=="top" then self:top()
        elseif self.resultBack=="storage" then self:storageMenu() else self:list() end
    end
end
function PCState:handleInput()
    for _,button in ipairs({"b","a","up","down"}) do
        local keys={b=playdate.kButtonB,a=playdate.kButtonA,up=playdate.kButtonUp,down=playdate.kButtonDown}
        if playdate.buttonJustPressed(keys[button]) then
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
        self.selected = self.crank:move(self.selected, self:count())
    elseif self.phase == "boxes" then
        self.box = self.crank:move(self.box, Storage.BOX_COUNT)
    end
end
function PCState:getSnapshot()
    if not self.active then return {phase="closed"} end
    local options={};for i,value in ipairs(self.menu.options) do options[i]=value end
    local result="none";if self.result then result={};for key,value in pairs(self.result) do result[key]=value end end
    local mon=self.phase=="list" and self:mon(self.selected) or self.selection and self.selection.mon
    return {phase=self.phase,selected=self.selected,box=self.phase=="boxes" and self.box or self.session:storage():activeBox(),
        index=self.selected,operation=self.operation or "none",pokemon=mon and mon.species or "none",result=result,
        menu={selected=self.menu.selectedIndex,active=self.menu.isActive,options=options}}
end
local function panel(x,y,w,h)
    gfx.setColor(gfx.kColorWhite);gfx.fillRect(x,y,w,h);gfx.setColor(gfx.kColorBlack);gfx.drawRect(x,y,w,h)
end
function PCState:rowHeight()
    gfx.pushContext();gfx.setFont(self.font);local _,height=gfx.getTextSize("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/");gfx.popContext()
    return math.max(height,self.font:getHeight())
end
function PCState:draw()
    if not self.active then return end
    gfx.pushContext();gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
    gfx.setFont(self.font);gfx.setLineWidth(1);panel(4,4,392,232)
    local storage=self.session:storage()
    gfx.drawText("POKEMON STORAGE",14,12);gfx.drawText("BOX "..storage:activeBox().."  "..storage:count().."/20",242,12)
    if self.phase=="top" then self.menu:draw(18,48,250,120)
    elseif self.phase=="storage" then self.menu:draw(18,42,256,140)
    elseif self.phase=="box-confirm" then
        gfx.drawTextInRect("When you change a POKEMON BOX, data will be saved. Is that okay?",20,58,220,100)
        self.menu:draw(270,70,108,60)
    elseif self.phase=="boxes" then
        for i=1,12 do local column=i>6 and 1 or 0;local y=50+((i-1)%6)*22
            gfx.drawText((i==self.box and "> " or "  ").."BOX "..i.."  "..storage:count(i).."/20",20+column*188,y) end
    elseif self.phase=="detail" and self.selection then
        local mon=self.selection.mon
        gfx.drawText(mon.name.."  Lv"..mon.level,18,38)
        gfx.drawText("HP "..mon.hp.."/"..mon.maxHP.." "..(mon.status or "OK"):upper(),220,38)
        gfx.drawText("ATK "..mon.atk.."  DEF "..mon.def.."  SPEED "..mon.spe,18,60)
        gfx.drawText("SP.ATK "..mon.spa.."  SP.DEF "..mon.spd,18,82)
        local rowHeight=self:rowHeight()
        for i,key in ipairs(mon.moves) do
            local top=188-(5-i)*rowHeight
            gfx.drawText(moveData[key].name,18,top);gfx.drawText("PP "..mon.pp[key].."/"..moveData[key].maxPP,274,top)
        end
    else
        local first=math.max(1,self.selected-5)
        panel(12,42,244,142)
        if self:count()==0 then gfx.drawTextInRect("What? There are no POKEMON here!",22,70,224,72) end
        for i=first,math.min(self:count(),first+5) do local mon=self:mon(i);local y=50+(i-first)*21
            gfx.drawText((i==self.selected and "> " or "  ")..mon.name,20,y);gfx.drawText("Lv"..mon.level,196,y) end
        local mon=self:mon(self.selected)
        if mon then
            gfx.drawText("HP "..mon.hp.."/"..mon.maxHP,268,50)
            gfx.drawText((mon.status or "OK"):upper(),268,74)
        end
        if self.phase=="actions" then self.menu:draw(264,102,122,82)
        elseif self.phase=="release-confirm" then self.menu:draw(270,110,108,60) end
    end
    panel(12,188,376,40)
    local prompt=self.phase=="release-confirm" and ("Once released, "..(self.selection and self.selection.mon.name or "POKEMON").." is gone forever. OK?")
        or self.result and self.result.message or self.phase=="boxes" and "Choose a POKEMON BOX.  B: Back" or "A: Choose   B: Back"
    gfx.drawTextInRect(prompt,20,194,360,32)
    gfx.popContext()
end

function PCState:resume()
    self.crank:reset()
    self.menu.crank:reset()
end
