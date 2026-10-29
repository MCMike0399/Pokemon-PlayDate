-- Plain, versioned current-map actor values. No graphics, Zone, RNG draws or
-- mutable world registries are used by validation; descriptors are injected.
WorldMotionData={VERSION=1}
local function copy(value)return Party._primitive(value)end
local function integer(n,low,high)return Party._integer(n,low,high)end
local function object(value,fields)
    assert(type(value)=="table"and getmetatable(value)==nil,"plain actor record required")
    for key in pairs(value)do assert(fields[key],"unknown actor field: "..tostring(key))end
end
local function array(value,count)
    assert(integer(count,0,64)and Party._array(value,64)and #value==count,"invalid bounded actor collection")
end
local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
function WorldMotionData.empty()return {version=1,zone_id="none",definition_revision="none",count=0,actors={}}end
function WorldMotionData.visible(spec,flags)
    for _,condition in ipairs(spec.visibility or {})do
        local values=assert(flags[condition.group],"actor visibility flag group required")
        if (values[condition.id]or false)~=condition.equals then return false end
    end
    return true
end
function WorldMotionData.initial(spec)
    -- Boulders are settled static actors. A new map visit calls initial; a
    -- current-map Save/Continue or battle return retains the captured pose.
    return {id=spec.id,x=spec.x,y=spec.y,facing=spec.facing,phase=spec.random and "ready"or "static",
        origin_x=spec.x,origin_y=spec.y,target_x=spec.x,target_y=spec.y,tick=0,delay_raw=0,delay_left=0}
end
function WorldMotionData.direction(selector,byte)
    assert(integer(byte,0,255),"world direction byte required")
    if selector=="DOWN"or selector=="UP"or selector=="LEFT"or selector=="RIGHT"then return selector:lower()end
    assert(selector=="NONE"or selector=="ANY_DIR"or selector=="UP_DOWN"or selector=="LEFT_RIGHT","unknown source direction selector")
    if selector=="UP_DOWN"then return (byte<64 or byte>=192)and "down"or "up"end
    if selector=="LEFT_RIGHT"then return (byte<64 or byte>=128 and byte<192)and "left"or "right"end
    return byte<64 and "down"or byte<128 and "up"or byte<192 and "left"or "right"
end
function WorldMotionData.delay(byte)
    assert(integer(byte,0,127),"source delay byte required")
    return byte==0 and 128 or (byte+1)//2
end
function WorldMotionData.newWorldRNG(rulesData)
    local probe=RulesRNG.new(1);probe:restoreData(copy(rulesData))
    return RulesRNG.new(assert(DecimalInteger.decode(probe:toData().seed,1,2147483646)))
end
local fields={id=true,x=true,y=true,facing=true,phase=true,origin_x=true,origin_y=true,target_x=true,target_y=true,tick=true,delay_raw=true,delay_left=true}
function WorldMotionData.normalize(payload,descriptor,location,flags)
    object(payload,{version=true,zone_id=true,definition_revision=true,count=true,actors=true})
    assert(payload.version==1,"unsupported actor snapshot version");array(payload.actors,payload.count)
    if payload.zone_id=="none"then
        assert(payload.definition_revision=="none"and payload.count==0,"invalid empty legacy actor marker")
        return WorldMotionData.empty()
    end
    assert(descriptor and descriptor.zone_id==payload.zone_id and location.zone_id==payload.zone_id,"actor map differs from candidate location")
    assert(payload.definition_revision==descriptor.revision,"wrong source actor definition revision")
    local specs,seen,reserved={}, {}, {}
    for _,spec in ipairs(descriptor.actors)do
        assert(not specs[spec.id],"duplicate source actor descriptor");specs[spec.id]=spec
    end
    local result={version=1,zone_id=payload.zone_id,definition_revision=payload.definition_revision,count=payload.count,actors={}}
    local function inside(x,y)return integer(x,0,descriptor.width-1)and integer(y,0,descriptor.height-1)end
    local function reserve(x,y,id)
        local cell=y*descriptor.width+x+1
        assert(not reserved[cell]or reserved[cell]==id,"overlapping actor reservations")
        assert(x~=location.x or y~=location.y,"actor overlaps candidate player")
        reserved[cell]=id
    end
    for _,value in ipairs(payload.actors)do
        object(value,fields);local spec=assert(specs[value.id],"unknown stable source actor ID")
        assert(not seen[value.id]and WorldMotionData.visible(spec,flags),"duplicate or hidden source actor")
        seen[value.id]=true
        assert(inside(value.x,value.y)and inside(value.origin_x,value.origin_y)and inside(value.target_x,value.target_y),"actor coordinates outside source map")
        assert(spec.faces[value.facing],"unavailable original actor facing")
        assert(integer(value.tick,0,7)and integer(value.delay_raw,0,127)and integer(value.delay_left,0,128),"invalid actor timer/step")
        assert(value.phase=="static"or value.phase=="ready"or value.phase=="delay"or value.phase=="moving","unknown actor phase")
        if value.phase=="moving"then
            assert(spec.movement=="WALK"and spec.random,"stationary source actor cannot translate")
            local d=assert(directions[value.facing]);assert(value.target_x==value.origin_x+d[1]and value.target_y==value.origin_y+d[2],"actor step must match one source cell/facing")
            assert(value.x==value.target_x and value.y==value.target_y,"moving actor logical cell must be reserved destination")
            assert(value.delay_left==0 and value.delay_raw==0,"moving actor cannot have delay")
            assert(descriptor.canStep(spec,value.origin_x,value.origin_y,value.target_x,value.target_y),"illegal source actor step")
            reserve(value.origin_x,value.origin_y,value.id);reserve(value.target_x,value.target_y,value.id)
        else
            assert(value.tick==0 and value.origin_x==value.x and value.origin_y==value.y and value.target_x==value.x and value.target_y==value.y,"stationary actor has stale motion")
            if value.phase=="delay"then assert(spec.random and value.delay_left>=1 and value.delay_left<=WorldMotionData.delay(value.delay_raw),"invalid source actor delay")
            else assert(value.delay_raw==0 and value.delay_left==0,"ready/static actor has stale delay")end
            assert((value.phase=="static")== (not spec.random),"wrong stationary actor policy")
            assert(descriptor.canStand(spec,value.x,value.y),"actor outside source movement/allowed surface")
            reserve(value.x,value.y,value.id)
        end
        result.actors[#result.actors+1]=copy(value)
    end
    for id,spec in pairs(specs)do assert(not WorldMotionData.visible(spec,flags)or seen[id],"missing visible source actor")end
    table.sort(result.actors,function(a,b)return a.id<b.id end)
    return result
end
-- Explicit transition reconciliation only. Decode always uses strict normalize.
function WorldMotionData.reconcile(payload,descriptor,flags)
    local indexed={};for _,actor in ipairs(payload and payload.actors or {})do indexed[actor.id]=actor end
    local result={version=1,zone_id=descriptor.zone_id,definition_revision=descriptor.revision,count=0,actors={}}
    for _,spec in ipairs(descriptor.actors)do if WorldMotionData.visible(spec,flags)then
        result.actors[#result.actors+1]=copy(indexed[spec.id]or WorldMotionData.initial(spec))
    end end
    result.count=#result.actors;return result
end

-- Compatibility for a supported old save with no actor DTO. This is a chosen
-- source-legal placement, never a reconstruction of historical actor position.
function WorldMotionData.legacyInitial(descriptor,location,flags)
    local result=WorldMotionData.reconcile(nil,descriptor,flags)
    local occupied,specs={},{}
    for _,spec in ipairs(descriptor.actors)do specs[spec.id]=spec end
    for _,value in ipairs(result.actors)do occupied[value.y*descriptor.width+value.x+1]=value.id end
    local provenance={kind="legacy-empty-actor-record",placements={}}
    for _,value in ipairs(result.actors)do
        if value.x==location.x and value.y==location.y then
            local spec=specs[value.id]
            assert(spec.role ~= "boulder", "legacy boulder overlaps saved player; source pose record required")
            assert(spec.role=="trainer","legacy actor overlap needs review: "..value.id)
            local delta=assert(directions[spec.facing]);local px,py=spec.x,spec.y;local chosen
            for distance=1,math.max(descriptor.width,descriptor.height)do
                local x,y=spec.x+delta[1]*distance,spec.y+delta[2]*distance
                if not descriptor.canStep(spec,px,py,x,y)then break end
                local cell=y*descriptor.width+x+1
                if occupied[cell]and occupied[cell]~=value.id then break end
                if x==location.x and y==location.y then break end
                if not descriptor.protected[cell]then chosen={x=x,y=y};break end
                px,py=x,y
            end
            assert(chosen,"legacy trainer overlap has no legal source-ray placement: "..value.id)
            occupied[value.y*descriptor.width+value.x+1]=nil
            provenance.placements[#provenance.placements+1]={id=value.id,from_x=value.x,from_y=value.y,x=chosen.x,y=chosen.y,
                policy="nearest-clear-source-approach-ray"}
            value.x,value.origin_x,value.target_x=chosen.x,chosen.x,chosen.x
            value.y,value.origin_y,value.target_y=chosen.y,chosen.y,chosen.y
            occupied[value.y*descriptor.width+value.x+1]=value.id
        end
    end
    return WorldMotionData.normalize(result,descriptor,location,flags),provenance
end
