-- Additive pinned frames. Existing RED/BLUE/Oak sprite tables never change.
EventArt={}
local data,walk,pokedex,monitor,ball
local function isolated(factory)
    local gfx=playdate.graphics;gfx.pushContext();gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
    local ok,a,b=pcall(factory);gfx.popContext();assert(ok,a);return a,b
end
local function source()
    if not data then
        data=assert(json.decodeFile("data/event-art.json"))
        assert(data.schema==1 and data.source_revision=="af519899719f0754965776faac0e836a3b906e6d" and data.blue_pattern_phase=="legacy-omitted","unverified event art")
    end
    return data
end
function EventArt.walking()
    if not walk then
        walk=isolated(function()
            local images={}
            -- Protected BLUE stands use omitted SDK pattern phase. Keep stride
            -- on that exact raster policy rather than changing standing art.
            for dir,entry in pairs(source().blue_walk) do images[dir]=SpriteFactory.makeSprite(entry.grid) end
            images.right=SpriteFactory.flipped(images.left);return images
        end)
    end
    return walk
end
function EventArt.pokedex()
    if not pokedex then pokedex=isolated(function() return SpriteFactory.makeSprite(source().pokedex.grid,{0,0}) end) end
    return pokedex
end
local function small(first)
    local gfx=playdate.graphics;local rows={};local grid=source().heal_machine.grid
    for y=1,16 do rows[y]=(y<=8 and grid[first+y-1] or string.rep(".",8))..string.rep(".",8) end
    local full=SpriteFactory.makeSprite(rows,{0,0});local out=gfx.image.new(16,16,gfx.kColorClear)
    gfx.pushContext(out);gfx.setDrawOffset(0,0);full:draw(0,0);gfx.popContext();return out
end
function EventArt.healing()
    if not monitor then monitor,ball=isolated(function() return small(1),small(9) end) end
    return monitor,ball
end

-- Read-only catalog metadata; no image allocation or global factory mutation.
function EventArt.catalogInventory()
    local data=source();local result={}
    local function add(name,id,path,frame,phase,flip,width,height)
        result[#result+1]={name=name,path=name..".png",source_id=id,source_path=path,source_frame=frame,
            source_sha256=assert(data.source_files[path]),source_revision=data.source_revision,
            phase_policy=phase,flip_x=flip,width=width,height=height,
            mask_policy="4-connected source-white border flood-fill; 2x logical pixels"}
    end
    for _,row in ipairs({{"down",3},{"up",4},{"left",5},{"right",5}}) do
        add("event_blue_walk_"..row[1],"pokered:SPRITE_BLUE:frame:"..row[2]..(row[1]=="right" and ":flip-x" or ""),
            "gfx/sprites/blue.png",row[2],"legacy-omitted",row[1]=="right",32,32)
    end
    add("event_pokedex","pokered:SPRITE_POKEDEX:frame:0","gfx/sprites/pokedex.png",0,"explicit-zero",false,32,32)
    add("event_heal_monitor","pokered:heal_machine:tile:0","gfx/overworld/heal_machine.png",0,"explicit-zero",false,16,16)
    add("event_heal_ball","pokered:heal_machine:tile:1","gfx/overworld/heal_machine.png",1,"explicit-zero",false,16,16)
    return result
end
function EventArt.catalogImages()
    local result=EventArt.catalogInventory();local walk=EventArt.walking();local monitor,ball=EventArt.healing()
    local images={event_blue_walk_down=walk.down,event_blue_walk_up=walk.up,event_blue_walk_left=walk.left,
        event_blue_walk_right=walk.right,event_pokedex=EventArt.pokedex(),event_heal_monitor=monitor,event_heal_ball=ball}
    for _,entry in ipairs(result) do entry.image=assert(images[entry.name]) end
    return result
end
