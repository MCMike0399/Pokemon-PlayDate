-- Eight reviewed source maps. Raw definitions are weakly cached, not eagerly
-- constructed/registered. Existing zoneRegistry remains the sole Zone owner.
PewterSlice={}
import "world/sourceMaps"
local names = {}
for _, name in ipairs(SourceMaps.names("pewter")) do names[name] = true end
local descriptors,trainerData,sprites,texts
local function copy(v) if type(v)~="table" then return v end;local out={};for k,x in pairs(v) do out[k]=copy(x) end;return out end
local function record(filename)
    return SourceMaps.record("data/pewterSlice/" .. filename .. ".json")
end
local function catalogue()
    if not descriptors then descriptors=record("descriptors").maps end
    return descriptors
end
function PewterSlice.names()
    local out={};for name in pairs(names) do out[#out+1]=name end;table.sort(out);return out
end
function PewterSlice.descriptor(name) assert(names[name],"map outside Pewter slice");return copy(assert(catalogue()[name])) end
function PewterSlice.definition(name)
    assert(names[name], "map outside Pewter slice")
    return SourceMaps.definition(name)
end
function PewterSlice.trainers()
    if not trainerData then
        trainerData={}
        local trainerMeta=record("trainerNames");local display=trainerMeta.names
        for _,d in ipairs(record("trainers").trainers) do
            assert(not trainerData[d.id] and type(d.payout)=="number" and d.payout>=0,"invalid source trainer identity")
            for _,mon in ipairs(d.party) do assert(pokemonData[mon.species] and mon.level>=1 and mon.level<=100,"unresolved trainer species") end
            d.name=assert(display[d.class_source],"unresolved original trainer name")
            d.sprite_source=assert(trainerMeta.sprites[d.id],"unresolved original trainer sprite")
            trainerData[d.id]=d
        end
    end
    return copy(trainerData)
end
function PewterSlice.trainer(id) return PewterSlice.trainers()[id] end
function PewterSlice.sprite(source)
    if not sprites then sprites=record("sprites") end
    local binding=assert(sprites.mapping[source],"unresolved original Pewter sprite constant")
    return copy(assert(sprites.sprites[binding.name])),binding.name
end
function PewterSlice.text(label)
    if not texts then texts=record("dialogue").texts end
    return copy(assert(texts[label],"missing original Pewter text: "..tostring(label)))
end
local compact,grids,doorLists
function PewterSlice.compact()
    if not compact then compact=record("compact") end
    return copy(compact)
end
function PewterSlice.cell(name,x,y)
    if not compact then compact=record("compact") end
    local d=assert(compact.maps[name],"unknown compact source map")
    assert(Party._integer(x,0,d.width-1) and Party._integer(y,0,d.height-1),"source cell outside map")
    local id=assert(tonumber(d.tile_rows[y+1]:sub(x*2+1,x*2+2),16))
    local key=assert(d.palette[id]);local cell=copy(assert(compact.tiles[key]))
    if d.blocked[tostring(y*d.width+x+1)] then cell.collision=1 end
    return cell
end
function PewterSlice.tile(key)
    if not grids then grids=record("tile-grids").tiles end
    return copy(assert(grids[key],"unresolved canonical imported tile"))
end
function PewterSlice.isDoor(name,x,y)
    if not doorLists then doorLists=record("doors").tilesets end
    local foot=PewterSlice.cell(name,x,y).terrain.foot_tile
    for _,id in ipairs(doorLists[PewterSlice.descriptor(name).tileset] or {}) do if foot==id then return true end end
    return false
end
function PewterSlice.padded(name)
    assert(names[name], "map outside Pewter slice")
    return SourceMaps.padded(name)
end
function PewterSlice.nameForID(id)
    return SourceMaps.nameForID(id, "pewter")
end
function PewterSlice.warpSpec(name,event)
    local destination=event.destination;local target=SourceMaps.nameForID("pokered:" .. tostring(destination.map), "pewter")
    if destination.kind=="last_outdoor_map" then target=(name=="ViridianForestSouthGate" or name=="ViridianForestNorthGate") and "Route2" or "PewterCity" end
    if not target then return {status="blocked",reason="original target map outside reviewed Pewter slice"} end
    local d=PewterSlice.descriptor(target);local arrival=assert(d.warps[destination.warp_index],"source target warp index absent")
    local advance=PewterSlice.isDoor(target,arrival.x,arrival.y) and 1 or 0
    local x,y=arrival.x,arrival.y+advance
    assert(y<d.height and PewterSlice.cell(target,x,y).collision==0,"original warp arrival is blocked")
    return {status="bound",to=d.key,toX=x,toY=y,facing=advance==1 and "down" or nil,preserveFacing=advance==0,
        target_name=target,target_warp=destination.warp_index,source_target_x=arrival.source_x,source_target_y=arrival.source_y,arrival_advance=advance}
end
function PewterSlice.specs(name,d)
    d=d or PewterSlice.padded(name);local specs={}
    for _,kind in ipairs({"objects","background_events","warps"}) do
        for _,event in ipairs(d.events[kind]) do
            specs[event.id]=kind=="warps" and PewterSlice.warpSpec(name,event) or {status=PewterEvents.has(event.id) and "bound" or "blocked",reason="source control outside implemented milestone"}
        end
    end
    for _,c in ipairs(d.connections) do specs[c.direction..":"..c.target_map]={status=c.target_map=="ROUTE_3" and "blocked" or "bound",reason="explicit bounded source connection"} end
    if #d.directional_rules.ledges>0 then specs["ledges:"..d.id]={status="bound"} end
    specs[d.script.source]={status=name=="PewterCity" and "blocked" or "bound",reason="source escorts/Route3 scripts remain explicit gaps"}
    if d.encounters.grass.rate_byte>0 then specs[d.id]={status="bound"} end
    return specs
end
