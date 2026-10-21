-- Source RLE/8px tile art, shown at original160x144 in the native UI.
TownMapData={}
local cached
local function raw()
    if not cached then
        local d=assert(json.decodeFile("data/townMap.json"),"missing pinned Town Map")
        assert(d.schema==1 and d.source_revision=="af519899719f0754965776faac0e836a3b906e6d"and d.width==20 and d.height==18,"invalid Town Map source")
        assert(#d.tiles==16 and #d.cells==360 and #d.order==47,"invalid Town Map inventory")
        for _,tile in ipairs(d.tiles)do for y=1,8 do assert(type(tile[y])=="string"and#tile[y]==8 and not tile[y]:find("[^.12#]"),"invalid map shade grid")end end
        for _,cell in ipairs(d.cells)do assert(type(cell)=="number"and cell%1==0 and cell>=0 and cell<16,"invalid map tile reference")end
        local seen={}
        for _,id in ipairs(d.order)do assert(d.locations[id]and not seen[id],"unknown/duplicate map selector entry");seen[id]=true end
        for _,entry in pairs(d.locations)do
            assert(type(entry.name)=="string"and#entry.name<=32 and type(entry.x)=="number"and entry.x%1==0 and entry.x>=0 and entry.x<=15
                and type(entry.y)=="number"and entry.y%1==0 and entry.y>=0 and entry.y<=15,"invalid map name/coordinate")
        end
        cached=d
    end
    return cached
end
function TownMapData.get()return Party._primitive(raw())end
function TownMapData.location(id)
    local d=raw();local key=d.aliases[id]or id:match("^pokered:(.+)$")
    if not(key and d.locations[key])then return nil end
    local result=Party._primitive(d.locations[key]);result.id=key;return result
end
local gfx <const> = playdate.graphics
Class("TownMapState"):extends(State)
function TownMapState:init(game)
    TownMapState.super.init(self,"townMap");self.game=game
end
function TownMapState.open(game)
    local top=game.machine:current();local world=game.machine:get("overworld");local p=game.player
    if not game.machine:get("townMap")then return false,"state-not-registered"end
    if game.machine:depth()~=2 or game.machine.stack[1]~=world or not(top==game.machine:get("bag")or top==game.machine:get("pause"))
        or world.sub:getCurrent()~="explore"or not p or p.isMoving or p.isJumping or p.pendingEdgeDoor or p.pendingConnection or p.stepJustFinished
        or (top==game.machine:get("bag")and(top.options.mode or top.options.trySelect or top.battle))then return false,"field-only"end
    if game.session:inventory():quantity("townMap")<1 then return false,"insufficient-items"end
    if not TownMapData.location(currentZone.stableID)then return false,"unknown-location"end
    game.machine:push("townMap");return true
end
local function color(code)
    if code=="1"then gfx.setPattern(Shade.LIGHT,0,0)
    elseif code=="2"then gfx.setPattern(Shade.DARK,0,0)
    else gfx.setColor(code=="#"and gfx.kColorBlack or gfx.kColorWhite)end
end
local function localCanvas()
    gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
end
local function nativeMarker(grid)
    -- One output pixel per source/grid cell. Reuse the established mask;
    -- integer cell sampling is exact, with no scaled-image resampling.
    gfx.pushContext();localCanvas()
    local expanded=SpriteFactory.makeSprite(grid,{0,0});local canonical=expanded:getMaskImage()
    local image=gfx.image.new(16,16,gfx.kColorWhite)
    local mask=gfx.image.new(16,16,gfx.kColorBlack)
    gfx.pushContext(image);localCanvas()
    for y=1,16 do for x=1,16 do color(grid[y]:sub(x,x));gfx.fillRect(x-1,y-1,1,1)end end
    Shade.reset();gfx.popContext();gfx.pushContext(mask);gfx.setColor(gfx.kColorWhite)
    for y=0,15 do for x=0,15 do if canonical:sample(x*2,y*2)==gfx.kColorWhite then gfx.fillRect(x,y,1,1)end end end
    gfx.popContext();image:setMaskImage(mask);gfx.popContext();return image
end
function TownMapState:enter()
    self.session=self.game.session;self.active=true;self.phase="browse";self.selected=1;self.browsing=false
    self.current=assert(TownMapData.location(currentZone.stableID));local d=raw()
    -- Original DisplayTownMap first shows the current map with source cursor
    -- counter0; the first UP then selects order entry1 (Lua index2/Route1).
    if not self.image then
        -- Eight-pixel tile offsets preserve the exact8px dither phase. Render
        -- each of the16source tiles once instead of repainting23040cells.
        local tiles={}
        for index,grid in ipairs(d.tiles)do
            local tile=gfx.image.new(8,8,gfx.kColorWhite);gfx.pushContext(tile);localCanvas()
            for y=1,8 do
                local x=1
                while x<=8 do
                    local c=grid[y]:sub(x,x);local last=x
                    while last<8 and grid[y]:sub(last+1,last+1)==c do last=last+1 end
                    color(c);gfx.fillRect(x-1,y-1,last-x+1,1);x=last+1
                end
            end
            Shade.reset();gfx.popContext();tiles[index]=tile
        end
        self.image=gfx.image.new(160,144,gfx.kColorWhite);gfx.pushContext(self.image);localCanvas()
        for cell,index in ipairs(d.cells)do tiles[index+1]:draw(((cell-1)%20)*8,((cell-1)//20)*8)end
        gfx.popContext()
        -- Actual source cursor grid; shared sprite mask/flip machinery retained.
        self.cursor=nativeMarker(d.cursor);self.marker=nativeMarker(SpriteFactory.grids.red.down)
    end
end
function TownMapState:exit()self.active=false;self.phase="closed";self.session=nil;gfx.sprite.addDirtyRect(0,0,400,240)end
function TownMapState:handleInput()
    if not self.active or self.game.session~=self.session then return end
    if playdate.buttonJustPressed(playdate.kButtonB)or playdate.buttonJustPressed(playdate.kButtonA)then self.machine:pop()
    elseif playdate.buttonJustPressed(playdate.kButtonUp)then self.browsing=true;self.selected=self.selected%#raw().order+1
    elseif playdate.buttonJustPressed(playdate.kButtonDown)then self.browsing=true;self.selected=(self.selected-2)%#raw().order+1 end
end
function TownMapState:getSnapshot()
    if not self.active then return {active=false,phase="closed",selected=self.selected or 0}end
    local d=raw();local key=self.browsing and d.order[self.selected or 1]or self.current.id
    return {active=self.active or false,phase=self.phase or"closed",selected=self.selected or 1,location=key,entry=Party._primitive(d.locations[key]),current=self.current and Party._primitive(self.current)or nil}
end
function TownMapState:draw()
    if not self.active then return end
    gfx.pushContext();localCanvas();gfx.clear(gfx.kColorWhite);gfx.setColor(gfx.kColorBlack)
    gfx.drawText("TOWN MAP",12,8);self.image:draw(12,48)
    local d=raw();local chosen=self.browsing and d.locations[d.order[self.selected]]or self.current
    self.cursor:draw(12+chosen.x*8+16,48+chosen.y*8+8)
    self.marker:draw(12+self.current.x*8+16,48+self.current.y*8+8)
    gfx.drawTextInRect("YOU ARE HERE\n"..self.current.name,190,48,198,58)
    gfx.drawTextInRect(chosen.name,190,120,198,40)
    gfx.drawText("UP/DOWN: Browse",190,172);gfx.drawText("A/B: Back",190,196)
    gfx.popContext()
end
