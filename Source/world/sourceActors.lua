-- Reusable immutable actor descriptor providers. Registration happens during
-- content install; validation only reads plain definitions and candidate state.
SourceActors={}
local providers={}
function SourceActors.register(name,describe)
    assert(type(name)=="string"and type(describe)=="function","named actor descriptor provider required")
    assert(not providers[name]or providers[name]==describe,"actor provider replaced")
    providers[name]=describe
end
function SourceActors.describe(zoneID,world)
    local found
    for _,describe in pairs(providers)do
        local descriptor=describe(zoneID,world)
        if descriptor then assert(not found,"overlapping actor descriptor providers");found=descriptor end
    end
    return found
end
function SourceActors.validate(payload,world,location,flags)
    return WorldMotionData.normalize(payload,SourceActors.describe(location.zone_id,world),location,flags)
end
-- Initial installation adapter for the eight reviewed maps. New regions add a
-- provider; neither the DTO validator nor motion owner contains this whitelist.
function SourceActors.describePewter(zoneID,world)
    local name=PewterSlice.nameForID(zoneID)
    if not name then return nil end
    local provider=assert(WorldDeltas.definitionProvider(),"source actor surface provider missing")
    local surface=provider:surface(zoneID,world);local d=PewterSlice.padded(name)
    local rules=Party._primitive(d.directional_rules)
    local specList,protected={},{}
    local function protect(x,y)if x>=0 and y>=0 and x<surface.width and y<surface.height then protected[y*surface.width+x+1]=true end end
    for _,warp in ipairs(d.events.warps)do
        protect(warp.x,warp.y)
        if PewterSlice.isDoor(name,warp.x,warp.y)then protect(warp.x,warp.y+1)end
    end
    for _,connection in ipairs(d.connections)do
        if connection.direction=="north"or connection.direction=="south"then
            local y=connection.direction=="north"and 0 or surface.height-1
            for x=0,surface.width-1 do protect(x,y)end
        else local x=connection.direction=="west"and 0 or surface.width-1;for y=0,surface.height-1 do protect(x,y)end end
    end
    for _,event in ipairs(d.events.objects)do
        local trainer=PewterSlice.trainer(event.id);local item=event.kind=="item"
        local strip=PewterSlice.sprite(event.sprite);local faces={}
        for direction in pairs(strip.standing)do faces[direction]=true end
        if faces.left then faces.right=true end
        local facing=({UP="up",DOWN="down",LEFT="left",RIGHT="right",LEFT_RIGHT="left",UP_DOWN="down",NONE="down",ANY_DIR="down"})[event.range_or_facing]
        assert(facing and faces[facing],"source actor initial facing missing exact pose")
        local spec={id=event.id,order=event.source_index,x=event.x,y=event.y,role=trainer and "trainer"or item and "item"or "npc",
            movement=event.movement,selector=event.range_or_facing,sprite_source=event.sprite,faces=faces,facing=facing,
            random=not trainer and not item,visibility={},script_positions={}}
        if trainer then
            local delta=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[facing]
            for i=0,math.max(0,trainer.sight_range_cells-1)do spec.script_positions[(event.y+delta[2]*i)*surface.width+event.x+delta[1]*i+1]=true end
        end
        if PewterEvents.isPickup(event.id)then spec.visibility={{group="quest",id=PewterEvents.pickupFlag(event.id),equals=false}}
        elseif name=="PewterCity"and event.source_index==5 then spec.visibility={{group="trainers",id=TrainerEvents.BROCK,equals=false}}end
        specList[#specList+1]=spec
    end
    local function canStand(spec,x,y,runtimeZone)
        if x<0 or y<0 or x>=surface.width or y>=surface.height or (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1]~=0 then return false end
        if spec.role=="trainer"then return spec.script_positions[y*surface.width+x+1]==true end
        if spec.movement~="WALK"then return x==spec.x and y==spec.y end
        if math.abs(x-spec.x)>4 or math.abs(y-spec.y)>4 or protected[y*surface.width+x+1]then return false end
        if spec.selector=="UP_DOWN"and x~=spec.x or spec.selector=="LEFT_RIGHT"and y~=spec.y then return false end
        return true
    end
    local function canStep(spec,x,y,tx,ty,runtimeZone)
        if not canStand(spec,x,y,runtimeZone)or not canStand(spec,tx,ty,runtimeZone)or math.abs(tx-x)+math.abs(ty-y)~=1 then return false end
        local a=runtimeZone and runtimeZone:terrainAt(x,y).foot_tile or surface.feet[y+1][x+1]
        local b=runtimeZone and runtimeZone:terrainAt(tx,ty).foot_tile or surface.feet[ty+1][tx+1]
        local direction=tx>x and "RIGHT"or tx<x and "LEFT"or ty>y and "DOWN"or "UP"
        for _,ledge in ipairs(rules.ledges)do if ledge.facing=="SPRITE_FACING_"..direction and ledge.standing_foot_tile==a and ledge.target_foot_tile==b then return false end end
        for _,pair in ipairs(rules.forbidden_tile_pairs)do if a==pair[1]and b==pair[2]or a==pair[2]and b==pair[1]then return false end end
        return true
    end
    return {zone_id=zoneID,revision=surface.revision,width=surface.width,height=surface.height,actors=specList,canStand=canStand,canStep=canStep,protected=protected}
end
