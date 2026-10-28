-- Native overlay with a nested lifecycle machine; original images at integer2x.
import "domain/evolution"
local gfx <const> = playdate.graphics
local font <const> = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")
Class("EvolutionState"):extends(State)
function EvolutionState:init(game)
    EvolutionState.super.init(self,"evolution")
    self.game,self.dialog,self.active,self.visit=game,Dialog(),false,0
    self.sub=StateMachine()
    self.sub:register("closed",{})
    self.sub:register("announce",{
        enter=function()
            self.frame,self.showTarget=0,false
            self:message({"What? "..self.info.from_name.." is evolving!"},function() self.sub:change("animate") end)
        end,
        update=function() self.dialog:update() end,
        handleInput=function() self.dialog:handleInput() end,
    })
    self.sub:register("animate",{
        enter=function() self.dialog.isActive=false;self.frame,self.showTarget=0,false end,
        update=function()
            self.frame=self.frame+1
            local interval=math.max(2,12-self.frame//12)
            self.showTarget=(self.frame//interval)%2==1
            if self.frame>=120 then
                local ok,result=Evolution.complete(self.request)
                self.result=ok and {kind="complete",evolution=result} or {kind="failed",reason=result}
                self.showTarget=ok;self.sub:change("result")
            end
        end,
        handleInput=function()
            if playdate.buttonJustPressed(playdate.kButtonB) then self:cancel() end
        end,
    })
    self.sub:register("result",{
        enter=function()
            local line
            if self.result.kind=="complete" then line="Congratulations! "..self.info.from_name.." evolved into "..self.info.to_name.."!"
            elseif self.result.kind=="cancelled" then line="Huh? "..self.info.from_name.." stopped evolving!"
            else line="Evolution couldn't be completed." end
            self:message({line},function() self.closeRequested=true end)
        end,
        update=function() self.dialog:update() end,
        handleInput=function() self.dialog:handleInput() end,
    })
    self.sub:change("closed")
end
function EvolutionState.open(game,request,onComplete)
    local state=game.machine:get("evolution")
    assert(state,"EvolutionState must be registered")
    if state.active then return false,"evolution-active" end
    if not request or request:getSnapshot().status~="prepared" then return false,"invalid-request" end
    game.machine:push("evolution",request,onComplete);return true
end
function EvolutionState:message(lines,onComplete)
    local visit,phase=self.visit,self.sub:getCurrent()
    self.dialog:show(lines,function()
        if self.active and self.visit==visit and self:isTop() and self.sub:is(phase) then onComplete() end
    end)
end
function EvolutionState:enter(request,onComplete)
    assert(request and request:getSnapshot().status=="prepared","EvolutionState requires a prepared request")
    self.request,self.info,self.onComplete=request,request:getSnapshot(),onComplete
    self.active,self.closeRequested,self.result=true,false,nil
    self.visit=self.visit+1;self.images={}
    for _,species in ipairs({self.info.from,self.info.species}) do
        self.images[species]=assert(gfx.image.new(PokemonArt.path(species,"front")),"missing original evolution sprite: "..species)
    end
    self.sub:change("announce")
end
function EvolutionState:cancel()
    if not self.active or not self:isTop() or not self.sub:is("animate") then return false,"not-animating" end
    local ok,problem=Evolution.cancel(self.request)
    if not ok then return false,problem end
    self.result={kind="cancelled"};self.showTarget=false;self.sub:change("result");return true
end
function EvolutionState:finish()
    if not self.active or not self:isTop() or not self.sub:is("result") then return false end
    local callback,result=self.onComplete,self.result
    self.onComplete=nil;self.machine:pop()
    if callback then callback(result) end
    return true
end
function EvolutionState:exit()
    if self.request then Evolution.abort(self.request) end
    self.active=false;self.visit=self.visit+1
    self.dialog.isActive,self.dialog.onComplete=false,nil
    self.onComplete,self.request,self.info,self.images=nil,nil,nil,nil
    self.closeRequested,self.result,self.frame,self.showTarget=false,nil,0,false
    self.sub:change("closed")
    gfx.sprite.addDirtyRect(0,0,400,240)
end
function EvolutionState:update()
    if not self.active or not self:isTop() then return end
    self.sub:update()
    if self.closeRequested then self:finish() end
end
function EvolutionState:handleInput()
    if not self.active or not self:isTop() then return end
    self.sub:handleInput()
    if self.closeRequested then self:finish() end
end
function EvolutionState:getSnapshot()
    local phase=self.sub:getCurrent()
    local line=self.dialog.lines[self.dialog.currentLine]
    return {phase=phase,frame=self.frame or 0,done=phase=="result" or phase=="closed",
        from=self.info and self.info.from or "",species=self.info and self.info.species or "",
        kind=self.info and self.info.kind or "",can_cancel=self.info and self.info.can_cancel or false,
        showing=self.showTarget and "target" or "source",result=self.result and self.result.kind or "none",
        failure=self.result and self.result.reason or "",dialog_ready=self.dialog.isActive and line~=nil and self.dialog.charIndex>=#line}
end
function EvolutionState:draw()
    if not self.active then return end
    local x,y=gfx.getDrawOffset();local oldFont=gfx.getFont()
    gfx.setDrawOffset(0,0);gfx.setFont(font);gfx.clear(gfx.kColorWhite);gfx.setColor(gfx.kColorBlack)
    gfx.drawText("EVOLUTION",12,8)
    local species=self.showTarget and self.info.species or self.info.from
    local image=self.images[species];local w,h=image:getSize();image:drawScaled(200-w,100-h,2)
    if self.sub:is("animate") and self.info.can_cancel then gfx.drawText("B: Stop evolution",12,157) end
    self.dialog:draw()
    gfx.setFont(oldFont);gfx.setDrawOffset(x,y)
end
