-- Concrete adapter for the reviewed eight-map source slice. It shares Zone and
-- MapBindings movement rules, without retaining full raw definitions in NPC
-- closures or silently turning unimplemented source scripts into dialogue.
PewterBindings={}
local function copy(v) return GameSession._copy(v) end
local function integer(n) return type(n)=="number" and n%1==0 end
function PewterBindings.prepare(d,specs,options)
    local name=assert(PewterSlice.nameForID(d.id),"map outside reviewed Pewter definitions")
    local descriptor=PewterSlice.descriptor(name)
    assert(d.name==name and descriptor.id==d.id and d.source_revision=="af519899719f0754965776faac0e836a3b906e6d","unverified source map identity")
    assert(type(specs)=="table" and type(options.dispatch)=="function" and type(options.questFlag)=="function" and type(options.sourceFlag)=="function","explicit source event/flag dependencies required")
    assert(not options.isolatedCatalog or options.registry~=WorldTiles,"isolated catalog requires private tile registry")
    local expected,bound,npcs,doors={},{},{},{}
    local dispatch,quest,sourceFlag=options.dispatch,options.questFlag,options.sourceFlag
    local width,height=table.unpack(d.dimensions.cells)
    local function source(id,event)
        assert(type(id)=="string" and not expected[id],"duplicate source event binding")
        expected[id]=true
        if event then assert(integer(event.x) and integer(event.y) and event.x>=0 and event.y>=0 and event.x<width and event.y<height,"source event outside padded map") end
        local spec=assert(specs[id],"missing explicit source event binding")
        assert(spec.status=="bound" or spec.status=="blocked","invalid source binding status")
        if spec.status=="bound" then bound[id]=true end
        return spec
    end
    for _,event in ipairs(d.events.objects) do
        local spec=source(event.id,event);local key=PewterSprites.key(event.sprite)
        if not options.isolatedCatalog then assert(SpriteFactory.npc[key],"original source sprite must be installed") end
        local id,canInteract=event.id,spec.status=="bound"
        if canInteract then assert(PewterEvents.has(id),"missing implemented source object handler") end
        local trainer=PewterSlice.trainer(id)
        local def={gridX=event.x,gridY=event.y,name=trainer and trainer.name or event.text_id,sprite=key,source_event_id=id,source_sprite=event.sprite,
            source_movement={kind=event.movement,range=event.range_or_facing},dialog=function()assert(canInteract,"unimplemented source interaction");return dispatch(id)end}
        def.facing=({DOWN="down",UP="up",LEFT="left",RIGHT="right",NONE="down",UP_DOWN="down",LEFT_RIGHT="left"})[event.range_or_facing] or "down"
        if PewterEvents.isPickup(id) then
            local flag=PewterEvents.pickupFlag(id);def.appearsIf=function()return not quest(flag)end
        elseif name=="PewterCity" and event.source_index==5 then
            def.appearsIf=function()return not sourceFlag("EVENT_BEAT_BROCK")end
        end
        npcs[#npcs+1]=def
    end
    for _,event in ipairs(d.events.warps) do
        local spec=source(event.id,event)
        if spec.status=="bound" then
            local verified=PewterSlice.warpSpec(name,event)
            for _,field in ipairs({"to","toX","toY","preserveFacing","facing","target_name","target_warp","arrival_advance"}) do assert(spec[field]==verified[field],"warp differs from pinned source projection") end
            local interior=name~="Route2" and name~="ViridianForest" and name~="PewterCity"
            doors[#doors+1]={x=event.x,y=event.y,to=spec.to,toX=spec.toX,toY=spec.toY,facing=spec.facing,preserveFacing=spec.preserveFacing,
                source_event_id=event.id,edge=interior and event.y==height-1 and "down" or nil}
        end
    end
    for _,event in ipairs(d.events.background_events) do local spec=source(event.id,event);if spec.status=="bound" then assert(PewterEvents.has(event.id),"missing source sign handler") end end
    for _,c in ipairs(d.connections) do source(c.direction..":"..c.target_map) end
    if #d.directional_rules.ledges>0 then source("ledges:"..d.id) end
    source(d.script.source)
    if d.encounters.grass.rate_byte>0 then source(d.id) end
    for id in pairs(specs) do assert(expected[id],"unknown source binding record") end
    local encounters,total={},0
    for _,slot in ipairs(d.encounters.grass.slots) do
        assert(pokemonData[slot.species] and integer(slot.level) and slot.level>=1 and slot.level<=100 and integer(slot.weight_256) and slot.weight_256>0,"unresolved Blue source encounter")
        encounters[#encounters+1]={species=slot.species,minLevel=slot.level,maxLevel=slot.level,weight=slot.weight_256};total=total+slot.weight_256
    end
    assert(#encounters==0 and d.encounters.grass.rate_byte==0 or #encounters==10 and total==256,"invalid Blue encounter slot weights")
    return {bound=bound,npcs=npcs,doors=doors,specs=copy(specs),encounters=encounters,encounterRateByte=d.encounters.grass.rate_byte,
        source={dimensions=copy(d.dimensions),events=copy(d.events),directional_rules=copy(d.directional_rules)},sliceReady=true,
        scope="pewter-slice-only",scopeStatus="bounded Route2/Forest/Pewter slice; campaign and remaining source controls incomplete"}
end
