-- Explicit four-map slice. Source coordinates remain inspectable after padding.
KantoSlice = {}
local names={Route1=true,ViridianCity=true,ViridianMart=true,ViridianPokecenter=true}
local zoneKeys={Route1="kanto_route1",ViridianCity="kanto_viridian_city",ViridianMart="kanto_viridian_mart",ViridianPokecenter="kanto_viridian_center"}
local cache={}
local function copy(v) if type(v)~="table" then return v end;local r={};for k,x in pairs(v) do r[k]=copy(x) end;return r end
function KantoSlice.definition(name)
    assert(names[name],"map outside explicit slice")
    if not cache[name] then
        local d=assert(json.decodeFile("data/viridianSlice/"..name..".json"))
        assert(d.schema==1 and d.source_revision=="af519899719f0754965776faac0e836a3b906e6d","wrong source slice revision")
        cache[name]=d
    end
    return copy(cache[name])
end
function KantoSlice.padded(name)
    local d=KantoSlice.definition(name);local w,h=table.unpack(d.dimensions.cells)
    local pad=math.max(0,(13-w)//2);local width=math.max(w,13)
    d.source_dimensions=copy(d.dimensions);d.runtime_adapter.padding_cells={pad,0};d.runtime_adapter.source_name=name
    if width==w then return d end
    local grid={};for y=1,16 do grid[y]=string.rep("#",16) end
    local id=#d.grids+1
    d.grids[id]={id=id,stable_id="adapter:viridian-slice:void",grid=grid,terrain={foot_tile=-1,land_passable=false,grass=false,counter=false,warp_tile=false,water_candidate=false,adapter_padding=true}}
    for y=1,h do
        local tiles,collision={},{}
        for x=1,width do tiles[x]=id;collision[x]=1 end
        for x=1,w do tiles[x+pad]=d.tile_ids[y][x];collision[x+pad]=d.collision[y][x] end
        d.tile_ids[y],d.collision[y]=tiles,collision
    end
    for _,events in pairs(d.events) do for _,event in ipairs(events) do event.source_x,event.source_y=event.x,event.y;event.x=event.x+pad end end
    d.dimensions.cells={width,h};d.dimensions.playdate_pixels={width*32,h*32}
    return d
end
function KantoSlice.specs(name,definitions)
    local d=definitions[name];local specs={}
    for _,kind in ipairs({"objects","background_events","warps"}) do
        for _,event in ipairs(d.events[kind]) do
            local bound=kind~="warps" and SliceEvents.has(event.id)
            specs[event.id]={status=bound and "bound" or "blocked",reason=bound and nil or "source event outside implemented parcel handlers"}
            if kind=="warps" then
                local target,warpIndex
                if name=="ViridianCity" and event.source_index<=2 then target=event.source_index==1 and "ViridianPokecenter" or "ViridianMart";warpIndex=event.destination.warp_index
                elseif name=="ViridianMart" or name=="ViridianPokecenter" then
                    assert(event.destination.kind=="last_outdoor_map","unexpected source dynamic warp")
                    target="ViridianCity";warpIndex=event.destination.warp_index
                end
                if target then
                    local arrival=assert(definitions[target].events.warps[warpIndex],"source target warp missing")
                    local advance=target=="ViridianCity" and 1 or 0
                    specs[event.id]={status="bound",to=zoneKeys[target],toX=arrival.x,toY=arrival.y+advance,
                        facing=target=="ViridianCity" and "down" or "up",source_target_map=definitions[target].source_map_constant,
                        source_target_warp=warpIndex,source_target_x=arrival.x,source_target_y=arrival.y,
                        arrival_advance=advance,reason="explicit LAST_MAP resolves only to original Viridian exterior"}
                end
            end
        end
    end
    for _,connection in ipairs(d.connections) do
        local supported=(name=="Route1") or (name=="ViridianCity" and connection.direction=="south")
        specs[connection.direction..":"..connection.target_map]={status=supported and "bound" or "blocked",reason=supported and "explicit slice connection" or "source target outside slice"}
    end
    if #d.directional_rules.ledges>0 then specs["ledges:"..d.id]={status="bound"} end
    specs[d.script.source]={status=name=="ViridianCity" and "blocked" or "bound",reason="city gym, old-man tutorial and secondary state scripts remain enumerated gaps"}
    if d.encounters.grass.rate_byte>0 then specs[d.id]={status="bound"} end
    return specs
end
function KantoSlice.create(name,options)
    options=options or {};local definitions={}
    for n in pairs(names) do definitions[n]=KantoSlice.padded(n) end
    local config={};for k,v in pairs(options) do config[k]=v end
    local defaults={Route1={x=10,y=35,facing="up"},ViridianCity={x=20,y=35,facing="up"},ViridianMart={x=5,y=7,facing="up"},ViridianPokecenter={x=3,y=7,facing="up"}}
    config.spawn=config.spawn or defaults[name]
    config.sliceBindings=KantoSlice.specs(name,definitions)
    config.destinations={};for n,d in pairs(definitions) do config.destinations[zoneKeys[n]]=d end
    local zone=Zone.fromMapDefinition(definitions[name],options.registry or WorldTiles,config)
    return zone
end
function KantoSlice.connection(name,x,y,direction,intro)
    assert(intro=="done","original Pallet exit remains gated by completed intro")
    if name=="pallet_town" and direction=="up" and y==0 and (x==9 or x==10) then
        return {to=zoneKeys.Route1,x=x+1,y=35,facing="up",source="authored Pallet adaptation +1"}
    end
    if name=="Route1" and direction=="down" and y==35 and (x==10 or x==11) then
        return {to="pallet_town",x=x-1,y=0,facing="down",source="authored Pallet adaptation -1"}
    end
    if name=="Route1" and direction=="up" and y==0 then
        return {to=zoneKeys.ViridianCity,x=x+10,y=35,facing="up",source="Route1 header north offset -5 blocks"}
    end
    if name=="ViridianCity" and direction=="down" and y==35 and x>=10 and x<30 then
        return {to=zoneKeys.Route1,x=x-10,y=0,facing="down",source="ViridianCity header south offset +5 blocks"}
    end
    error("unimplemented or invalid source connection: "..tostring(name)..":"..tostring(direction))
end
