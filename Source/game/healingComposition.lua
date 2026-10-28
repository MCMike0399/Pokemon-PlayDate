-- Source OAM composition over the actual map. Raw EventArt stays unchanged.
HealingComposition={}
local gfx <const> = playdate.graphics
local offsets={{-8,14,false},{8,14,true},{-8,24,false},{8,24,true},{-8,34,false},{8,34,true}}
function HealingComposition.layout(zone)
    assert(zone, "explicit healing-machine map required")
    if zone.stableID ~= "pokered:VIRIDIAN_POKECENTER" and zone.stableID ~= "pokered:PEWTER_POKECENTER" then
        local name = SourceMaps.nameForID(zone.stableID)
        local definition = name and SourceMaps.definition(name)
        assert(definition and definition.tileset.constant == "POKECENTER"
            and definition.dimensions.cells[1] == 14 and definition.dimensions.cells[2] == 8
            and SourceMaps.entry(name).padding == 0, "explicit healing-machine map required")
    end
    assert(TILE_SIZE==32,"healing OAM composition requires native2x source tiles")
    -- Standard pinned Centers share 112 source cells and machine geometry.
    -- Source monitor cavity is world pixels29..34,6..8. Its8x8 OAM tile
    -- begins at28,4, i.e. source mapcell1,0 plus12,4 logical pixels.
    local result={monitor={x=TILE_SIZE+24,y=8},balls={}}
    for i,row in ipairs(offsets) do result.balls[i]={x=result.monitor.x+row[1],y=result.monitor.y+row[2],flip_x=row[3]} end
    return result
end
function HealingComposition.draw(zone,count,clock,camera)
    assert(type(count)=="number" and count%1==0 and count>=1 and count<=6,"bounded real party count required")
    assert(type(clock)=="number" and clock%1==0 and clock>=0,"bounded animation tick required")
    local layout=HealingComposition.layout(zone)
    local monitor,ball=EventArt.healing()
    gfx.pushContext();camera:apply();gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
    monitor:draw(layout.monitor.x,layout.monitor.y)
    local visible=math.min(count,clock//15+1)
    -- Existing visibility approximation retained explicitly. Original E0 XOR28
    -- changes the OAM palette (including monitor), not visibility; see handoff.
    local flashing=clock>=15*count and clock<15*count+40
    if not flashing or ((clock-15*count)//5)%2==0 then
        for index=1,visible do local position=layout.balls[index]
            ball:draw(position.x,position.y,position.flip_x and gfx.kImageFlippedX or gfx.kImageUnflipped)
        end
    end
    gfx.popContext()
end
