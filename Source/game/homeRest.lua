-- Authored MOM geometry/art are preserved. Source RedsHouse1F script gates
-- rest on starter acquisition, heals under white fade, never sets blackout map.
local gfx <const> = playdate.graphics
HomeRest={}
Class("HomeRestState"):extends(State)
function HomeRestState:init(game)HomeRestState.super.init(self,"homeRest");self.game=game;self.epoch=0 end
function HomeRest.tryInteract(game)
    local p=game.player;local world=game.machine:get("overworld")
    if not p or currentZone~=zoneRegistry.reds_house or game.machine:current()~=world or game.machine:depth()~=1
        or p.isMoving or p.isJumping or p.pendingEdgeDoor or p.pendingConnection then return false end
    local x,y=p:getFacingTile();local npc=game.npcManager:getNPCAt(x,y)
    if not npc or npc.name~="MOM"then return false end
    assert(game.machine:get("homeRest"),"Mom rest state must be registered")
    npc:faceTowards(p.gridX,p.gridY);game.machine:push("homeRest",npc);return true
end
function HomeRestState:valid()
    return self.active and self.game.session==self.session and currentZone==self.zone and self.game.player==self.player
        and self.game.machine.stack[1]==self.game.machine:get("overworld") and self.zone==zoneRegistry.reds_house
end
function HomeRestState:say(lines,nextPhase)
    self.phase="dialog";local epoch=self.epoch
    self.machine:push("dialog",lines,function()
        if self.epoch~=epoch or not self:valid()or not self:isTop()then return end
        if nextPhase then self.phase=nextPhase;self.tick=0 else self.machine:pop()end
    end)
end
function HomeRestState:enter(npc)
    self.epoch=self.epoch+1;self.active=true;self.session=self.game.session;self.zone=currentZone;self.player=self.game.player
    self.tick=0;self.healed=false;self.npc=npc
    if not self.session:getIntro().starter then
        self:say({"MOM: Right. All boys leave home some day. It said so on TV.","PROF.OAK, next door, is looking for you."})
    else self:say({"MOM: RED! You should take a quick rest."},"fade-out")end
end
function HomeRestState:update()
    if not self:isTop()then return end
    if not self:valid()then self.machine:pop();return end
    if self.phase=="dialog"then return end
    self.tick=self.tick+1
    if self.phase=="fade-out"and self.tick>=12 then
        -- One non-yielding commit. The saved checkpoint and both streams stay owned
        -- by their existing session owners; rest never captures traversal.
        assert(self.session:party():healAll());self.healed=true;self.phase="white";self.tick=0
    elseif self.phase=="white"and self.tick>=12 then self.phase="fade-in";self.tick=0
    elseif self.phase=="fade-in"and self.tick>=12 then
        self:say({"MOM: Oh good! You and your POKEMON are looking great! Take care now!"})
    end
end
function HomeRestState:draw()
    if self.phase=="dialog"then return end
    -- Clear the previous white overlay before each bounded fade sample. Reuse
    -- the existing draw-only SDK bridge; callbacks/actor clocks never advance.
    gfx.sprite.addDirtyRect(0,0,400,240)
    EventState.redrawSprites()
    self.game.camera:reset()
    local t=self.phase=="fade-out"and self.tick/12 or self.phase=="fade-in"and 1-self.tick/12 or 1
    gfx.setColor(gfx.kColorWhite)
    if t>=1 then gfx.fillRect(0,0,400,240)
    elseif t>0 then
        -- Original palette-fade ordering expressed in native 1-bit shade steps.
        -- White patterned overlay: transparent background keeps the settled world.
        local pattern=t<1/3 and 0.25 or t<2/3 and 0.5 or 0.75
        self.white=self.white or gfx.image.new(400,240,gfx.kColorWhite)
        self.white:drawFaded(0,0,pattern,gfx.image.kDitherTypeBayer8x8)
    end
    Shade.reset();self.game.camera:apply()
end
function HomeRestState:exit()
    self.epoch=self.epoch+1;self.active=false;self.phase="closed";self.white=nil
end
function HomeRestState:getSnapshot()return {phase=self.phase or "closed",tick=self.tick or 0,healed=self.healed or false}end
