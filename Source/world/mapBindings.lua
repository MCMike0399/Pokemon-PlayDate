MapBindings = {}
import "world/sourceBindings"
local function integer(v) return type(v)=="number" and v%1==0 end
-- Immutable Viridian NPC content and the two Pokédex visibility predicates.
function MapBindings.object(definition, event, spec, options)
    local key = SliceSprites.key(event.sprite)
    if not options.isolatedCatalog then
        assert(SpriteFactory.npc[key], "original sprite must be installed before source binding: " .. key)
    end
    local id, canInteract = event.id, spec.status == "bound"
    if canInteract then assert(SliceEvents.has(id), "unimplemented bound source event") end
    local def = {
        gridX = event.x, gridY = event.y, name = event.text_id, sprite = key, source_event_id = id,
        source_movement = { kind = event.movement, range = event.range_or_facing },
        dialog = function()
            assert(canInteract, "unimplemented source event: " .. id)
            return options.dispatch(id)
        end,
    }
    local facing = { DOWN = "down", UP = "up", LEFT = "left", RIGHT = "right", NONE = "down" }
    def.facing = facing[event.range_or_facing] or "down"
    if definition.source_map_constant == "VIRIDIAN_CITY" and event.source_index == 5 then
        def.appearsIf = function() return not options.questFlag("EVENT_GOT_POKEDEX") end
    end
    if definition.source_map_constant == "VIRIDIAN_CITY" and event.source_index == 7 then
        def.appearsIf = function() return options.questFlag("EVENT_GOT_POKEDEX") end
    end
    return def
end
function MapBindings.prepare(d,specs,options)
    return SourceBindings.prepare(d,specs,SourceBindings.options("viridian",options))
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
