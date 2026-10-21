-- Original Red/Blue art/poses with Gen V receipt-driven shake counts.
-- Presentation only: no rules, RNG, timers, sprites or global display transforms.
import "data/captureAnimationData"
local gfx <const> = playdate.graphics
local images={}
local function assets()
    for name,path in pairs(CaptureAnimationData.assets) do
        if not images[name] then images[name]=assert(gfx.image.new(path),"missing original capture art: " .. path) end
    end
end
Class("CaptureAnimation")
local function position(point)
    -- Preserve the original path relative to its endpoints, mapped to the
    -- existing player-hand/target composition. No Pokemon art is transformed.
    return math.floor(105+(point[1]-40)*235/80+0.5),math.floor(120+(point[2]-88)*60/38+0.5)
end
function CaptureAnimation:init(receipt)
    assert(type(receipt)=="table" and type(receipt.caught)=="boolean" and type(receipt.critical)=="boolean","invalid capture presentation receipt")
    local ball=receipt.ballId
    assert(ball=="pokeBall" or ball=="greatBall" or ball=="ultraBall" or ball=="masterBall","unsupported capture presentation ball")
    local shakes=receipt.displayShakes
    assert(shakes==0 or shakes==1 or shakes==3,"invalid capture presentation shakes")
    assert(not receipt.critical or shakes==1,"critical capture must show one shake")
    self.caught,self.critical,self.ball,self.shakes=receipt.caught,receipt.critical,ball,shakes
    self.path=ball=="pokeBall" and "high" or (ball=="greatBall" and "middle" or "low")
    self.throwTicks=math.ceil(11*CaptureAnimationData.throwHold[self.path]/2)
    self.total=self.throwTicks+12+CaptureAnimationData.dropTicks+shakes*(CaptureAnimationData.shakePause+8)
        +(self.caught and CaptureAnimationData.caughtHold or 12)
    self.frame,self.done,self.cancelled=0,false,false
    assets()
    self:evaluate()
end
function CaptureAnimation:evaluate()
    local data=CaptureAnimationData
    self.enemyVisible,self.ballVisible,self.effect,self.shake=true,false,nil,0
    if self.cancelled then self.phase="cancelled";return end
    if self.done then
        self.phase=self.caught and "caught" or "escaped"
        self.enemyVisible=not self.caught;self.ballVisible=self.caught
        self.ballFrame,self.x,self.y="closed",340,70;self.shake=self.shakes
        return
    end
    local age=self.frame
    if age<self.throwTicks then
        self.phase="throw";self.ballVisible=true
        local step=math.min(11,age*2//data.throwHold[self.path]+1)
        self.x,self.y=position(data.paths[self.path][step])
        self.ballFrame=(self.ball=="ultraBall" or self.ball=="masterBall") and step%2==0 and "closed-flash" or "closed"
        return
    end
    age=age-self.throwTicks
    if age<12 then
        self.phase="absorb"
        self.effect=data.poof[age//2+1]
        return -- Original sequence hides the pic after the poof.
    end
    age=age-12;self.enemyVisible=false;self.ballVisible=true;self.ballFrame="closed";self.x,self.y=340,70
    if age<data.dropTicks then
        self.phase="drop";self.y=60+math.floor(10*(age+1)/data.dropTicks+0.5)
        return
    end
    age=age-data.dropTicks
    local cycle=data.shakePause+8
    if age<self.shakes*cycle then
        local current=age//cycle+1;local within=age%cycle
        if within<data.shakePause then
            self.phase="shake_wait";self.shake=current-1
        else
            self.phase="shake";self.shake=current
            self.ballFrame=data.shake[(within-data.shakePause)//2+1]
        end
        return
    end
    age=age-self.shakes*cycle;self.shake=self.shakes
    if self.caught then self.phase="caught"
    else
        self.phase="breakout";self.ballVisible=false
        self.effect=data.poof[math.min(6,age//2+1)]
    end
end
function CaptureAnimation:update()
    if self.done then return end
    self.frame=self.frame+1
    if self.frame>=self.total then self.done=true end
    self:evaluate()
end
function CaptureAnimation:cancel()
    self.cancelled,self.done=true,true
    self:evaluate()
end
function CaptureAnimation:isEnemyVisible() return self.enemyVisible end
function CaptureAnimation:getSnapshot()
    return {phase=self.phase,frame=self.frame,done=self.done,shake=self.shake}
end
function CaptureAnimation:draw()
    if self.ballVisible then
        local image=images[self.ballFrame];local w,h=image:getSize()
        image:draw(self.x-w//2,self.y-h//2)
    end
    if self.effect then
        local image=images[self.effect];local w,h=image:getSize()
        image:draw(340-w//2,70-h//2)
    end
end
