-- Explicit development export. Isolated Zones/private palettes never enter the
-- provider LRU, global registry or session, including maps not visited in play.
PewterCatalog={}
local gfx <const> = playdate.graphics
local function sortedKeys(source)local out={};for k in pairs(source)do out[#out+1]=k end;table.sort(out);return out end
function PewterCatalog.write(output)
    assert(playdate.isSimulator and type(output)=="string" and output:sub(1,1)=="/" and output:sub(-1)=="/","absolute Simulator output directory required")
    local before={ids=WorldTiles:maxID(),zones=#zoneList,zone=currentZone,sprites=gfx.sprite.spriteCount(),rng=RulesRNG.snapshot()}
    local offsetX,offsetY=gfx.getDrawOffset()
    local report={schema=1,source_revision="af519899719f0754965776faac0e836a3b906e6d",images={},maps={},tiles={},missing={}}
    local function save(image,name,kind,extra)
        assert(image,"missing native image");playdate.simulator.writeToFile(image,output..name..".png")
        local w,h=image:getSize();local entry={path=name..".png",width=w,height=h,kind=kind}
        for key,value in pairs(extra or {})do entry[key]=value end
        report.images[#report.images+1]=entry;return entry
    end
    local source=assert(json.decodeFile("data/pewterSlice/sprites.json"))
    for _,name in ipairs(sortedKeys(source.sprites)) do
        local strip=source.sprites[name]
        for _,index in ipairs(sortedKeys(strip.frames)) do
            local image=SpriteFactory.makeSprite(strip.frames[index],{0,0})
            save(image,"pewter-sprite-"..name.."-"..index,"sprite",{source_id=strip.id,frame=index})
            save(assert(image:getMaskImage()),"pewter-mask-"..name.."-"..index,"mask",{source_id=strip.id,frame=index})
        end
    end
    local metadata=PewterSlice.compact()
    for index,key in ipairs(sortedKeys(metadata.tiles)) do
        local tile=PewterSlice.tile(key)
        local image = TileRegistry.renderImportedGrid(tile.grid, TileFactory.renderGrid)
        local entry = save(image, string.format("pewter-tile-%03d", index), "tile", {
            stable_key = key,
            collision = tile.collision,
            terrain = tile.terrain,
        })
        report.tiles[#report.tiles+1]={stable_key=key,path=entry.path}
    end
    for _,name in ipairs(PewterSlice.names()) do
        local zone=PewterWorld.isolated(name);local d=PewterSlice.descriptor(name)
        local view
        local ok,problem=pcall(function()
            view=WorldView(zone,{attach=false});local image=view:render()
            save(image,"pewter-"..name.."-terrain","terrain",{zone_id=d.id,source_width=d.source_width,padding=d.padding})
            local collision=gfx.image.new(zone.width*TILE_SIZE,zone.height*TILE_SIZE,gfx.kColorWhite)
            gfx.pushContext(collision);gfx.setDrawOffset(0,0);gfx.setColor(gfx.kColorBlack)
            for y,row in ipairs(zone.collision)do for x,value in ipairs(row)do if value==1 then gfx.fillRect((x-1)*TILE_SIZE,(y-1)*TILE_SIZE,TILE_SIZE,TILE_SIZE)end end end
            gfx.popContext();save(collision,"pewter-"..name.."-collision","collision",{zone_id=d.id})
            local actors=image:copy();gfx.pushContext(actors);gfx.setDrawOffset(0,0)
            for _,def in ipairs(zone.npcDefs)do
                if not def.appearsIf or def.appearsIf() then
                    local strip=PewterSlice.sprite(def.source_sprite)
                    local direction=def.facing;local index=strip.standing[direction=="right" and "left" or direction]
                    local sprite=SpriteFactory.makeSprite(assert(strip.frames[tostring(index)],"missing exact source direction"),{0,0})
                    if direction=="right"then sprite=SpriteFactory.flipped(sprite)end
                    sprite:draw(def.gridX*TILE_SIZE,def.gridY*TILE_SIZE-8)
                end
            end
            gfx.popContext();save(actors,"pewter-"..name.."-actors","actors",{zone_id=d.id})
            local definition=PewterSlice.padded(name);local specs=PewterSlice.specs(name,definition)
            local overlay=image:copy();local events={};local connections={}
            gfx.pushContext(overlay);gfx.setDrawOffset(0,0);gfx.setFont(gfx.getSystemFont());gfx.setLineWidth(1)
            for _,kind in ipairs({"objects","background_events","warps"})do
                for index,event in ipairs(definition.events[kind])do
                    local x,y=event.x*TILE_SIZE,event.y*TILE_SIZE
                    gfx.setColor(gfx.kColorWhite);gfx.fillRect(x+1,y+1,30,22)
                    gfx.setColor(gfx.kColorBlack);gfx.drawRect(x+1,y+1,30,22)
                    local mark=kind=="objects" and "O" or kind=="warps" and "W" or "B"
                    gfx.drawText(mark..tostring(index),x+3,y+3)
                    events[#events+1]={id=event.id,kind=kind,x=event.x,y=event.y,source_x=event.source_x,source_y=event.source_y,
                        status=specs[event.id].status,destination=event.destination,sprite=event.sprite}
                end
            end
            local hidden=assert(json.decodeFile("data/pewterSlice/hidden-events.json"))
            for index,event in ipairs(hidden.events)do if event.map_id==d.id then
                local x,y=(event.x+d.padding)*TILE_SIZE,event.y*TILE_SIZE
                gfx.setColor(gfx.kColorWhite);gfx.fillRect(x+1,y+1,30,22)
                gfx.setColor(gfx.kColorBlack);gfx.drawRect(x+1,y+1,30,22);gfx.drawText("H"..tostring(index),x+3,y+3)
                events[#events+1]={id=event.id,kind="hidden",x=event.x+d.padding,y=event.y,source_x=event.x,source_y=event.y,
                    status=PewterEvents.has(event.id) and "bound" or event.handler_source=="OpenPokemonCenterPC" and "requires-direct-PC-registration" or "blocked",
                    handler_source=event.handler_source,argument_source=event.argument_source}
            end end
            for _,connection in ipairs(definition.connections)do
                local direction=connection.direction;local width,height=zone.width*TILE_SIZE,zone.height*TILE_SIZE
                local x=direction=="west" and 0 or direction=="east" and width-32 or width//2-16
                local y=direction=="north" and 0 or direction=="south" and height-32 or height//2-16
                gfx.setColor(gfx.kColorWhite);gfx.fillRect(x,y,32,32);gfx.setColor(gfx.kColorBlack);gfx.drawRect(x,y,32,32)
                gfx.drawText(direction:sub(1,1):upper(),x+10,y+6)
                local id=direction..":"..connection.target_map
                connections[#connections+1]={id=id,direction=direction,target_map=connection.target_map,
                    entry_lateral_adjustment_cells=connection.entry_lateral_adjustment_cells,status=specs[id].status}
            end
            gfx.popContext();save(overlay,"pewter-"..name.."-events","events-warps-connections",{zone_id=d.id})
            report.maps[#report.maps+1]={name=name,zone_id=d.id,width=zone.width,height=zone.height,source_width=d.source_width,padding=d.padding,
                events=events,connections=connections,directional_rules=definition.directional_rules,issues=zone:getBindingIssues(),
                campaign_ready=zone:isCampaignReady(),slice_ready=zone:isSliceReady()}
        end)
        if view then view:dispose()end
        if not ok then gfx.setDrawOffset(offsetX,offsetY);error(problem,0)end
    end
    local shock=PewterSprites.exclamation()
    save(shock,"pewter-exclamation","sprite");save(shock:getMaskImage(),"pewter-exclamation-mask","mask")
    gfx.setDrawOffset(offsetX,offsetY)
    assert(WorldTiles:maxID()==before.ids and #zoneList==before.zones and currentZone==before.zone,"catalog mutated world ownership")
    assert(gfx.sprite.spriteCount()==before.sprites,"catalog leaked native sprites")
    local after=RulesRNG.snapshot()
    assert(after.algorithm==before.rng.algorithm and after.seed==before.rng.seed and after.state==before.rng.state and after.rolls==before.rng.rolls,"catalog consumed rules RNG")
    return report
end
