-- Bounded explicit source bindings for the four-map parcel slice.
MapBindings = {}
local allowed = { ROUTE_1=true, VIRIDIAN_CITY=true, VIRIDIAN_MART=true, VIRIDIAN_POKECENTER=true }
local function copy(v) if type(v) ~= "table" then return v end; local r={}; for k,x in pairs(v) do r[k]=copy(x) end; return r end
local function integer(v) return type(v)=="number" and v%1==0 end
function MapBindings.prepare(definition, specs, options)
    assert(allowed[definition.source_map_constant], "map outside explicit slice")
    assert(type(specs)=="table" and type(options.dispatch)=="function" and type(options.questFlag)=="function", "explicit slice event dispatcher and flag reader required")
    local expected, objects, doors, bound = {}, {}, {}, {}
    local function source(id, kind, event)
        assert(type(id)=="string" and #id>0 and not expected[id], "duplicate/invalid source binding ID"); expected[id]=kind
        if event then
            local width,height=table.unpack(definition.dimensions.cells)
            assert(integer(event.x) and integer(event.y) and event.x>=0 and event.y>=0 and event.x<width and event.y<height,"source binding coordinate outside map")
        end
        local spec=assert(specs[id], "missing explicit source binding: "..id)
        assert(type(spec)=="table" and (spec.status=="bound" or spec.status=="blocked"), "invalid explicit binding status")
        if spec.status=="bound" then bound[id]=true end
        return spec
    end
    for _,event in ipairs(definition.events.objects) do
        local spec=source(event.id,"objects",event)
        local key=SliceSprites.key(event.sprite)
        if not options.isolatedCatalog then assert(SpriteFactory.npc[key], "original sprite must be installed before source binding: "..key) end
        if spec.status=="bound" then assert(SliceEvents.has(event.id), "unimplemented bound source event") end
        local id, canInteract=event.id, spec.status=="bound"
        local def={ gridX=event.x,gridY=event.y,name=event.text_id,sprite=key,source_event_id=id,
            source_movement={kind=event.movement,range=event.range_or_facing},
            dialog=function() assert(canInteract, "unimplemented source event: "..id); return options.dispatch(id) end }
        local facing={DOWN="down",UP="up",LEFT="left",RIGHT="right",NONE="down"}
        def.facing=facing[event.range_or_facing] or "down"
        if definition.source_map_constant=="VIRIDIAN_CITY" and event.source_index==5 then def.appearsIf=function() return not options.questFlag("EVENT_GOT_POKEDEX") end end
        if definition.source_map_constant=="VIRIDIAN_CITY" and event.source_index==7 then def.appearsIf=function() return options.questFlag("EVENT_GOT_POKEDEX") end end
        objects[#objects+1]=def
    end
    for _,event in ipairs(definition.events.warps) do
        local spec=source(event.id,"warps",event)
        if spec.status=="bound" then
            assert(type(spec.to)=="string" and integer(spec.toX) and integer(spec.toY) and spec.toX>=0 and spec.toY>=0, "explicit resolved warp destination required")
            assert(spec.facing=="up" or spec.facing=="down", "explicit source warp arrival facing required")
            local target=assert(options.destinations and options.destinations[spec.to], "unknown explicit warp map")
            local arrival=assert(target.events.warps[event.destination.warp_index], "target source warp missing")
            assert(spec.source_target_map==target.source_map_constant and spec.source_target_warp==event.destination.warp_index, "warp source identity mismatch")
            assert(event.destination.kind=="last_outdoor_map" and target.source_map_constant=="VIRIDIAN_CITY" or event.destination.map==target.source_map_constant, "wrong source warp map binding")
            local advance=target.source_map_constant=="VIRIDIAN_CITY" and 1 or 0
            assert(spec.toX==arrival.x and spec.toY==arrival.y+advance, "warp binding disagrees with exact source arrival")
            assert(spec.toX<target.dimensions.cells[1] and spec.toY<target.dimensions.cells[2] and target.collision[spec.toY+1][spec.toX+1]==0, "source warp arrival blocked/outside map")
            doors[#doors+1]={x=event.x,y=event.y,to=spec.to,toX=spec.toX,toY=spec.toY,facing=spec.facing,source_event_id=event.id,
                edge=event.y==definition.dimensions.cells[2]-1 and "down" or nil}
        end
    end
    for _,event in ipairs(definition.events.background_events) do
        local spec=source(event.id,"background_events",event)
        if spec.status=="bound" then assert(SliceEvents.has(event.id),"unimplemented bound background event") end
    end
    for _,connection in ipairs(definition.connections) do source(connection.direction..":"..connection.target_map,"connection") end
    if #definition.directional_rules.ledges>0 then source("ledges:"..definition.id,"directional_rules") end
    source(definition.script.source,"script")
    if definition.encounters.grass.rate_byte>0 then source(definition.id,"encounter_policy") end
    for id in pairs(specs) do assert(expected[id],"unknown source binding ID: "..tostring(id)) end
    local encounters={}
    for _,slot in ipairs(definition.encounters.grass.slots) do
        assert((slot.species=="pidgey" or slot.species=="rattata") and slot.level>=1 and slot.level<=100 and slot.weight_256>0,"invalid canonical Blue encounter binding")
        encounters[#encounters+1]={species=slot.species,minLevel=slot.level,maxLevel=slot.level,weight=slot.weight_256}
    end
    return {bound=bound,npcs=objects,doors=doors,specs=copy(specs),encounters=encounters,encounterRateByte=definition.encounters.grass.rate_byte,
        source=copy(definition),sliceReady=true,dispatch=options.dispatch}
end
function MapBindings.movement(definition,x,y,direction,zone)
    local dirs={up={0,-1,"SPRITE_FACING_UP","PAD_UP"},down={0,1,"SPRITE_FACING_DOWN","PAD_DOWN"},left={-1,0,"SPRITE_FACING_LEFT","PAD_LEFT"},right={1,0,"SPRITE_FACING_RIGHT","PAD_RIGHT"}}
    local d=assert(dirs[direction],"invalid movement direction");local width,height=table.unpack(definition.dimensions.cells)
    assert(integer(x) and integer(y) and x>=0 and y>=0 and x<width and y<height,"movement origin outside map")
    local nx,ny=x+d[1],y+d[2]
    if nx<0 or ny<0 or nx>=width or ny>=height then return {kind="connection",direction=direction,x=nx,y=ny} end
    local a=zone and zone:terrainAt(x,y).foot_tile or definition.grids[definition.tile_ids[y+1][x+1]].terrain.foot_tile
    local b=zone and zone:terrainAt(nx,ny).foot_tile or definition.grids[definition.tile_ids[ny+1][nx+1]].terrain.foot_tile
    local collision=zone and zone.collision or definition.collision
    for _,rule in ipairs(definition.directional_rules.ledges) do
        if rule.facing==d[3] and rule.input==d[4] and a==rule.standing_foot_tile and b==rule.target_foot_tile then
            local lx,ly=x+d[1]*2,y+d[2]*2
            if lx<0 or ly<0 or lx>=width or ly>=height or collision[ly+1][lx+1]~=0 then return {kind="blocked",reason="ledge-landing"} end
            return {kind="ledge",direction=direction,x=lx,y=ly,cells=2,source="engine/overworld/ledges.asm"}
        end
    end
    for _,pair in ipairs(definition.directional_rules.forbidden_tile_pairs) do
        if (a==pair[1] and b==pair[2]) or (a==pair[2] and b==pair[1]) then return {kind="blocked",reason="source-pair-collision"} end
    end
    return {kind=collision[ny+1][nx+1]==0 and "walk" or "blocked",x=nx,y=ny}
end
