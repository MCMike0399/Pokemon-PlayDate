-- Encyclopedia overlay: session discovery is authoritative; rendering is read-only.
import "data/pokedexData"
local gfx <const> = playdate.graphics
local font <const> = gfx.font.new("/System/Fonts/Asheville-Sans-14-Bold")
Class("PokedexState"):extends(State)
function PokedexState:init(game)
    PokedexState.super.init(self,"pokedex")
    self.game,self.selected,self.phase=game,1,"closed"
    self.fronts={}
end
function PokedexState:enter()
    self.selected,self.phase=1,"list"
end
function PokedexState:exit()
    self.phase="closed"
    gfx.sprite.addDirtyRect(0,0,400,240)
end
function PokedexState:select(index)
    if self.phase~="list" then return false,"not-list" end
    if type(index)~="number" or index~=math.floor(index) or index<1 or index>151 then return false,"invalid-index" end
    self.selected=index;return true
end
function PokedexState:move(delta)
    if self.phase~="list" then return false,"not-list" end
    if delta~=1 and delta~=-1 and delta~=8 and delta~=-8 then return false,"invalid-step" end
    return self:select(math.max(1,math.min(151,self.selected+delta)))
end
function PokedexState:entryView()
    local entry=PokedexData[self.selected]
    local dex=self.game.session:pokedex()
    local seen,owned=dex.seen[entry.species]==true,dex.owned[entry.species]==true
    -- No undiscovered name/flavor escapes the view consumed by the UI.
    return {dex=entry.dex,species=entry.species,seen=seen,owned=owned,
        name=seen and entry.name or "----------",details=owned and entry or nil}
end
function PokedexState:openEntry()
    if self.phase~="list" then return false,"not-list" end
    if not self:entryView().seen then return false,"unseen" end
    self.phase="entry";return true
end
function PokedexState:back()
    if self.phase=="entry" then self.phase="list";return true end
    if self.phase=="list" then self.machine:pop();return true end
    return false,"closed"
end
function PokedexState:handleInput()
    if self.phase=="closed" then return end
    if playdate.buttonJustPressed(playdate.kButtonB) then self:back()
    elseif playdate.buttonJustPressed(playdate.kButtonA) then self:openEntry()
    elseif playdate.buttonJustPressed(playdate.kButtonUp) then self:move(-1)
    elseif playdate.buttonJustPressed(playdate.kButtonDown) then self:move(1)
    elseif playdate.buttonJustPressed(playdate.kButtonLeft) then self:move(-8)
    elseif playdate.buttonJustPressed(playdate.kButtonRight) then self:move(8) end
end
function PokedexState:getSnapshot()
    local view=self:entryView()
    return {phase=self.phase,selected=self.selected,species=view.species,seen=view.seen,owned=view.owned}
end
function PokedexState:drawFront(species,cx,cy)
    local image=self.fronts[species]
    if not image then image=assert(gfx.image.new(PokemonArt.path(species,"front")),"missing Pokedex front: "..species);self.fronts[species]=image end
    local w,h=image:getSize()
    -- Every original pixel is an integer 2x2 block; never fit to a fractional scale.
    image:drawScaled(cx-w,cy-h,2)
end
function PokedexState:draw()
    if self.phase=="closed" then return end
    local x,y=gfx.getDrawOffset();local previousFont=gfx.getFont()
    gfx.setDrawOffset(0,0);gfx.setFont(font);gfx.clear(gfx.kColorWhite);gfx.setColor(gfx.kColorBlack)
    local view=self:entryView()
    if self.phase=="list" then
        local dex=self.game.session:pokedex();local seen,owned=0,0
        for _,entry in ipairs(PokedexData) do if dex.seen[entry.species] then seen=seen+1 end;if dex.owned[entry.species] then owned=owned+1 end end
        gfx.drawText("POKEDEX",12,6);gfx.drawText("SEEN "..seen.."  OWN "..owned,196,6)
        gfx.drawLine(216,31,216,211)
        local top=math.max(1,math.min(144,self.selected-3))
        for i=top,math.min(151,top+7) do
            local e=PokedexData[i];local row=34+(i-top)*22
            gfx.drawText(i==self.selected and ">" or " ",8,row)
            gfx.drawText(string.format("%03d",i),24,row)
            gfx.drawText(dex.seen[e.species] and e.name or "----------",65,row)
            if dex.owned[e.species] then gfx.fillCircleAtPoint(204,row+8,3) end
        end
        gfx.drawText(string.format("No.%03d",view.dex),244,39)
        gfx.drawText(view.name,232,62)
        if view.seen then self:drawFront(view.species,306,143) else gfx.drawText("?",300,133) end
        gfx.drawText("A: Data",250,202)
        gfx.drawText("UP/DOWN: Scroll  LEFT/RIGHT: Page",12,219)
        gfx.drawText("B: Back",315,219)
    else
        gfx.drawText(string.format("No.%03d  %s",view.dex,view.name),12,6)
        self:drawFront(view.species,330,80)
        if view.details then
            local e=view.details
            gfx.drawText(e.category.." POKEMON",12,32)
            gfx.drawText(string.format("HT %d'%02d\"",e.heightFeet,e.heightInches),12,55)
            gfx.drawText(string.format("WT %d.%d lb",e.weightTenthsLb//10,e.weightTenthsLb%10),12,78)
            for i,line in ipairs(e.lines) do gfx.drawText(line,12,104+(i-1)*16) end
        else
            gfx.drawText("NOT YET OWNED",12,55)
            gfx.drawText("Catch this POKEMON to record",12,146)
            gfx.drawText("its full encyclopedia entry.",12,168)
        end
        gfx.drawText("B: Back",12,221)
    end
    gfx.setFont(previousFont);gfx.setDrawOffset(x,y)
end
