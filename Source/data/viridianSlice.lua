-- Explicit four-map slice. Source coordinates remain inspectable after padding.
KantoSlice = {}
import "world/sourceMapProvider"
local names, zoneKeys = {}, {}
for _, name in ipairs(SourceMaps.names("viridian")) do
    names[name] = true
    zoneKeys[name] = SourceMaps.entry(name).key
end
function KantoSlice.definition(name)
    assert(names[name], "map outside explicit slice")
    return SourceMaps.definition(name)
end
function KantoSlice.padded(name)
    assert(names[name], "map outside explicit slice")
    return SourceMaps.padded(name)
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
    assert(names[name], "map outside explicit slice")
    options = options or {}
    local function definitions(current, definition)
        local result = {}
        for target in pairs(names) do result[target] = SourceMaps.destination(target) end
        if current then result[current] = definition end
        return result
    end
    local adapter = {
        specs = function(current, definition) return KantoSlice.specs(current, definitions(current, definition)) end,
        options = function()
            local config = {}
            for key, value in pairs(options) do config[key] = value end
            config.destinations = {}
            for target, definition in pairs(definitions()) do config.destinations[zoneKeys[target]] = definition end
            return config
        end,
    }
    return SourceMaps.createZone(name, adapter, options.registry or WorldTiles)
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
