-- Source-backed extensions only. Existing seven shared sprite mappings are
-- reused byte-for-byte; imported frames request explicit reviewed phase0.
PewterSprites={}
local names={super_nerd="pewterSuperNerd",gramps="pewterGramps",little_girl="pewterLittleGirl",cooltrainer_f="pewterCooltrainerF",gym_guide="pewterGymGuide",poke_ball="pewterPokeBall",fairy="pewterFairy"}
local shared={SPRITE_YOUNGSTER=true,SPRITE_GIRL=true,SPRITE_CLERK=true,SPRITE_COOLTRAINER_M=true,SPRITE_NURSE=true,SPRITE_GENTLEMAN=true,SPRITE_LINK_RECEPTIONIST=true}
local rendered={}
function PewterSprites.key(source)
    if shared[source] then return SliceSprites.key(source) end
    local _,name=PewterSlice.sprite(source)
    return assert(names[name],"unmapped original Pewter sprite")
end
function PewterSprites.frame(source,index)
    local strip=PewterSlice.sprite(source)
    assert(type(index)=="number" and index%1==0,"integer original frame required")
    return SpriteFactory.makeSprite(assert(strip.frames[tostring(index)],"missing original Pewter frame"),{0,0})
end
function PewterSprites.installFor(definition)
    assert(type(definition)=="table" and definition.source_revision=="af519899719f0754965776faac0e836a3b906e6d","verified source map required")
    local selected = {}
    local sharedSources = {}
    for _,event in ipairs(definition.events.objects) do
        local key=PewterSprites.key(event.sprite)
        if shared[event.sprite] then
            sharedSources[#sharedSources + 1] = event.sprite
        else
            assert(SpriteFactory.npc[key]==nil or SpriteFactory.npc[key]==rendered[key],"conflicting imported Pewter sprite key")
            selected[event.sprite]=key
        end
    end
    SliceSprites.install(sharedSources)
    for source,key in pairs(selected) do
        if not rendered[key] then
            local strip=PewterSlice.sprite(source);local images={}
            for direction,index in pairs(strip.standing) do images[direction]=PewterSprites.frame(source,index) end
            if images.left then images.right=SpriteFactory.flipped(images.left) end
            rendered[key]=images
        end
    end
    for _,key in pairs(selected) do SpriteFactory.npc[key]=rendered[key] end
end
local walks={}
function PewterSprites.stepImage(source,facing,tick)
    local frames=walks[source]
    if not frames then
        local strip=PewterSlice.sprite(source);local standing=assert(SpriteFactory.npc[PewterSprites.key(source)],"trainer standing art not installed")
        frames={standing=standing,walking={},alternate={}}
        for direction,index in pairs(strip.walking) do
            frames.walking[direction]=PewterSprites.frame(source,index)
            frames.alternate[direction]=(direction=="down" or direction=="up") and SpriteFactory.flipped(frames.walking[direction]) or frames.walking[direction]
        end
        assert(frames.walking.left,"source trainer has no original walking frames")
        frames.walking.right=SpriteFactory.flipped(frames.walking.left);frames.alternate.right=frames.walking.right
        walks[source]=frames
    end
    assert(Party._integer(tick,1,8),"bounded native source animation tick required")
    -- Original16ticks/framecounter changes every4: sample at2source ticks
    -- per native30FPS update. Preserve the protected RED8frame path separately.
    local phase=(tick//2)%4
    if phase==1 then return assert(frames.walking[facing])
    elseif phase==3 then return assert(frames.alternate[facing])
    else return assert(frames.standing[facing]) end
end
local shock
function PewterSprites.exclamation()
    if not shock then
        local d=assert(json.decodeFile("data/pewterSlice/emote.json"))
        assert(d.schema==1 and d.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified original emote")
        shock=SpriteFactory.makeSprite(d.grid,{0,0})
    end
    return shock
end
