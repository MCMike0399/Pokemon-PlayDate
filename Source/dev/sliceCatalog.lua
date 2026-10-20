-- Actual SDK candidates. Terrain includes only explicit runtime padding.
SliceCatalog = {}
function SliceCatalog.write(output)
    assert(playdate.isSimulator and type(output)=="string" and output:sub(1,1)=="/" and output:sub(-1)=="/","absolute Simulator output directory required")
    local gfx=playdate.graphics;local report={images={}}
    local function save(image,name)
        playdate.simulator.writeToFile(image,output..name..".png")
        local w,h=image:getSize();report.images[#report.images+1]={path=name..".png",width=w,height=h}
    end
    local source=assert(json.decodeFile("data/viridianSlice/sprites.json"))
    for name,entry in pairs(source.sprites) do
        for frame,grid in pairs(entry.frames) do
            local image=SpriteFactory.makeSprite(grid, { 0, 0 })
            save(image,"slice-sprite-"..name.."-"..frame)
            save(image:getMaskImage(),"slice-mask-"..name.."-"..frame)
        end
    end
    for _,name in ipairs({"Route1","ViridianCity","ViridianMart","ViridianPokecenter"}) do
        local zone=KantoSlice.create(name,{registry=TileRegistry(),dispatch=function() error("catalog cannot execute event") end,questFlag=function() return false end})
        local view=WorldView(zone,{attach=false});local image=view:render()
        save(image,"slice-"..name.."-terrain")
        local actors=image:copy();gfx.pushContext(actors)
        for _,def in ipairs(zone.npcDefs) do
            if not def.appearsIf or def.appearsIf() then
                local frames=assert(SpriteFactory.npc[def.sprite]);local sprite=assert(frames[def.facing],"missing exact directional sprite")
                sprite:draw(def.gridX*TILE_SIZE,def.gridY*TILE_SIZE-8)
            end
        end
        gfx.popContext();save(actors,"slice-"..name.."-actors");view:dispose()
    end
    return report
end
