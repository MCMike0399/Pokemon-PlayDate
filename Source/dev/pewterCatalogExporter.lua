-- Explicit development export. Isolated Zones/private palettes never enter the
-- provider LRU, global registry or session, including maps not visited in play.
PewterCatalogExporter={}
local gfx <const> = playdate.graphics
local function sortedKeys(source)local out={};for k in pairs(source)do out[#out+1]=k end;table.sort(out);return out end
local function verified(path)
    local record=assert(json.decodeFile(path),"pinned Pewter source missing")
    assert(record.schema==1 and record.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified catalog source")
    return record
end
function PewterCatalogExporter.writer(sink)
    local report={schema=1,source_revision="af519899719f0754965776faac0e836a3b906e6d",images={},maps={},tiles={},missing={}}
    local function save(image,name,kind,extra)
        assert(image,"missing native image");sink.save(name,image,kind,kind=="mask")
        local w,h=image:getSize();local entry={path=name..".png",width=w,height=h,kind=kind}
        for key,value in pairs(extra or {})do entry[key]=value end
        report.images[#report.images+1]=entry;return entry
    end
    local source=verified("data/pewterSlice/sprites.json")
    for _,name in ipairs(sortedKeys(source.sprites)) do
        local strip=source.sprites[name]
        for _,index in ipairs(sortedKeys(strip.frames)) do
            local image=SpriteFactory.makeSprite(strip.frames[index],{0,0})
            save(image,"pewter-sprite-"..name.."-"..index,"sprite",{source_id=strip.id,frame=index})
            save(assert(image:getMaskImage()),"pewter-mask-"..name.."-"..index,"mask",{source_id=strip.id,frame=index})
        end
    end
    local metadata=PewterSlice.compact()
    local protected=assert(json.decodeFile("dev/catalogProtected.json"))
    for _,key in ipairs(sortedKeys(metadata.tiles)) do
        local prefix="tile_imported_"..VisualCatalog.stableName(key)
        if not protected.tiles[key] then
            local tile=PewterSlice.tile(key)
            sink.asset(prefix,TileFactory.renderGrid(tile.grid,nil,{0,0}),"imported-tile",false)
        end
        report.tiles[#report.tiles+1]={stable_key=key,path=prefix..".png",protected_shared=protected.tiles[key] or false}
    end
    for _,name in ipairs(PewterSlice.names()) do
        local zone=PewterWorld.isolated(name);local d=PewterSlice.descriptor(name)
        local view
        local ok,problem=pcall(function()
            view=WorldView(zone,{attach=false});local image=view:render()
            save(image,"pewter-"..name.."-terrain","terrain",{zone_id=d.id,source_width=d.source_width,padding=d.padding})
            local viewport=gfx.image.new(400,240,gfx.kColorWhite)
            local cx=math.max(0,math.min(zone.width*TILE_SIZE-400,zone.spawn.x*TILE_SIZE-200))
            local cy=math.max(0,math.min(zone.height*TILE_SIZE-240,zone.spawn.y*TILE_SIZE-120))
            gfx.pushContext(viewport);gfx.setDrawOffset(0,0);image:draw(-cx,-cy);gfx.popContext()
            save(viewport,"pewter-"..name.."-viewport","map-viewport",{zone_id=d.id})
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
        if not ok then error(problem,0)end
    end
    local shockSource=verified("data/pewterSlice/emote.json")
    local shock=SpriteFactory.makeSprite(shockSource.grid,{0,0})
    save(shock,"pewter-exclamation","sprite");save(shock:getMaskImage(),"pewter-exclamation-mask","mask")
    for _,bg in ipairs({"white","black","texture"}) do
        save(PewterCatalogExporter.background(shock,bg),"pewter-exclamation__"..bg,"sprite-background")
    end
    report.characters={}
    for _,entry in ipairs(PewterCatalogExporter.poses()) do
        local image=PewterSprites.frame(entry.source,entry.source_frame)
        if entry.flip_x then image=SpriteFactory.flipped(image) end
        sink.asset(entry.name,image,"pewter-character",true)
        report.characters[#report.characters+1]=entry
    end
    report.review_status="all added artifacts unreviewed; independent source and native review required"
    return report
end
local dirs={"down","up","left","right"}
function PewterCatalogExporter.poses()
    local source=verified("data/pewterSlice/sprites.json");local out={}
    for _,constant in ipairs(sortedKeys(source.mapping)) do
        local binding=source.mapping[constant];local strip=source.sprites[binding.name]
        for _,pose in ipairs({"stand","walk","alternate"}) do
            if pose=="stand" or next(strip.walking) then
                for _,direction in ipairs(dirs) do
                    local sourceDir=direction=="right" and "left" or direction
                    local index=(pose=="stand" and strip.standing or strip.walking)[sourceDir]
                    local fixed=strip.fixed and pose=="stand"
                    if fixed then index=assert(strip.standing.down) end
                    assert(index,"unsupported source direction")
                    local flip=not fixed and (direction=="right" or (pose=="alternate" and (direction=="up" or direction=="down"))) or false
                    local ticks=pose=="stand" and {1,4,5,8} or pose=="walk" and {2,3} or {6,7}
                    out[#out+1]={name="pewter-pose-"..binding.name.."-"..pose.."-"..direction,
                        source=constant,source_id=strip.id,source_path=strip.source,source_sha256=strip.sha256,
                        source_frame=index,flip_x=flip,pose=pose,direction=direction,native_ticks=ticks,
                        phase_policy="explicit-zero",walking_available=next(strip.walking)~=nil,
                        direction_policy=fixed and "fixed-down-image; actor has no directional frames" or "source-direction; mirrored-right"}
                end
            end
        end
    end
    return out
end
function PewterCatalogExporter.background(image,kind)
    local w,h=image:getSize();local output=gfx.image.new(w,h,kind=="black" and gfx.kColorBlack or gfx.kColorWhite)
    gfx.pushContext(output);gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy);gfx.setColor(gfx.kColorBlack)
    if kind=="texture" then for y=0,h-1,4 do for x=0,w-1,4 do if (x//4+y//4)%2==0 then gfx.fillRect(x,y,4,4) end end end end
    image:draw(0,0);gfx.popContext();return output
end
function PewterCatalogExporter.inventory()
    local out={images={},map_count=8,source_frame_count=64,directional_pose_count=120}
    local function add(name,w,h,category,mask)
        out.images[#out.images+1]={path=name..".png",width=w,height=h,category=category,mask=mask or false}
    end
    local function asset(name,w,h,category,backgrounds)
        add(name,w,h,category);add(name.."__mask",w,h,category,true)
        if backgrounds then for _,bg in ipairs({"white","black","texture"}) do add(name.."__"..bg,w,h,category.."-background") end end
    end
    local source=verified("data/pewterSlice/sprites.json")
    for _,name in ipairs(sortedKeys(source.sprites)) do
        for _,frame in ipairs(sortedKeys(source.sprites[name].frames)) do
            add("pewter-sprite-"..name.."-"..frame,32,32,"sprite")
            add("pewter-mask-"..name.."-"..frame,32,32,"mask",true)
        end
    end
    local protected=assert(json.decodeFile("dev/catalogProtected.json"));local tiles=PewterSlice.compact().tiles
    for _,key in ipairs(sortedKeys(tiles)) do if not protected.tiles[key] then
        asset("tile_imported_"..VisualCatalog.stableName(key),32,32,"imported-tile",false)
    end end
    for _,name in ipairs(PewterSlice.names()) do
        local d=PewterSlice.descriptor(name)
        for _,kind in ipairs({"terrain","collision","actors","events"}) do
            add("pewter-"..name.."-"..kind,d.width*32,d.height*32,kind=="events" and "events-warps-connections" or kind)
        end
        add("pewter-"..name.."-viewport",400,240,"map-viewport")
    end
    add("pewter-exclamation",32,32,"sprite");add("pewter-exclamation-mask",32,32,"mask",true)
    for _,bg in ipairs({"white","black","texture"}) do add("pewter-exclamation__"..bg,32,32,"sprite-background") end
    for _,entry in ipairs(PewterCatalogExporter.poses()) do asset(entry.name,32,32,"pewter-character",true) end
    table.sort(out.images,function(a,b)return a.path<b.path end)
    assert(#out.images==859,"explicit Pewter inventory changed")
    return out
end
function PewterCatalogExporter.register()
    local newNPC={pewterSuperNerd=true,pewterGramps=true,pewterLittleGirl=true,pewterCooltrainerF=true,pewterGymGuide=true,pewterPokeBall=true,pewterFairy=true}
    local tiles=PewterSlice.compact().tiles
    return VisualCatalog.registerExporter("pewter",{writer=PewterCatalogExporter.writer,inventory=PewterCatalogExporter.inventory,
        ownsZone=function(zone)local provider=WorldDeltas.definitionProvider();return provider and provider:owns(zone) or false end,
        ownsTile=function(key)return tiles[key]~=nil end,ownsNPC=function(key)return newNPC[key]==true end})
end
