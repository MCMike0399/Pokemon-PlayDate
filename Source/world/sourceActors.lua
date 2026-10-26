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
-- Legacy Viridian keeps its reviewed static sprites and empty motion envelope.
-- This is a compatibility policy, not the default for newly decoded maps.
local compatibility = { viridian = { motion = false } }
local contentResolvers = {}

function SourceActors.registerContent(profile, resolver)
    assert(profile == "source", "reviewed actor content cannot be replaced")
    for _, key in ipairs({ "sprite", "key", "stepImage", "install" }) do
        assert(type(resolver[key]) == "function", "explicit immutable actor art resolver required: " .. key)
    end
    assert(not contentResolvers[profile], "actor content resolver replaced")
    -- Copy the interface so later caller table edits cannot replace a resolver.
    contentResolvers[profile] = {}
    for key, value in pairs(resolver) do contentResolvers[profile][key] = value end
end

local function content(profile)
    if profile == "pewter" then
        return { sprite = PewterSlice.sprite, key = PewterSprites.key, stepImage = PewterSprites.stepImage,
            install = PewterSprites.installFor,
            metadata = function(d, event)
                if PewterEvents.isPickup(event.id) then
                    return { visibility = {{group="quest", id=PewterEvents.pickupFlag(event.id), equals=false}} }
                elseif d.name == "PewterCity" and event.source_index == 5 then
                    return { visibility = {{group="trainers", id=TrainerEvents.BROCK, equals=false}} }
                end
                return {}
            end }
    end
    return assert(contentResolvers[profile], "source actor content resolver missing: " .. tostring(profile))
end

function SourceActors.installArt(name, definition)
    return content(SourceMaps.entry(name).profile).install(definition)
end

function SourceActors.stepImage(source, facing, tick, profile)
    return content(profile or "pewter").stepImage(source, facing, tick)
end

function SourceActors.objectDefinition(d, event, spec, options)
    local profile = SourceMaps.entry(d.name).profile
    local resolver = content(profile)
    local key = resolver.key(event.sprite)
    if not options.isolatedCatalog then assert(SpriteFactory.npc[key], "source actor art not installed") end
    local trainer = SourceEvents.trainerDefinitions()[event.id]
    local descriptor = SourceEvents.descriptor(event.id)
    local metadata = resolver.metadata and resolver.metadata(d, event) or {}
    local visibility = Party._primitive(metadata.visibility or {})
    if descriptor and descriptor.kind == "pickup" then
        visibility[#visibility + 1] = {group="quest", id=descriptor.flag, equals=false}
    end
    local def = { gridX=event.x, gridY=event.y, name=trainer and trainer.name or event.text_id,
        sprite=key, source_event_id=event.id, source_sprite=event.sprite,
        source_movement={kind=event.movement, range=event.range_or_facing},
        facing=({UP="up", DOWN="down", LEFT="left", RIGHT="right", LEFT_RIGHT="left"})[event.range_or_facing] or "down",
        dialog=function()
            assert(spec.status == "bound" and options.hasEvent(event.id), "unimplemented source interaction")
            return options.dispatch(event.id)
        end }
    if #visibility > 0 then
        def.appearsIf = function()
            for _, condition in ipairs(visibility) do
                local value
                if condition.group == "quest" then value = options.questFlag(condition.id)
                else
                    assert(condition.group == "trainers" and options.trainerFlag, "explicit trainer flag reader required")
                    value = options.trainerFlag(condition.id)
                end
                if (value == true) ~= condition.equals then return false end
            end
            return true
        end
    end
    return def
end

-- Every ordinary manifest map uses this descriptor builder. Immutable content
-- resolvers supply art and exceptional visibility; geometry stays shared.
function SourceActors.describeSource(zoneID, world)
    local name = SourceMaps.nameForID(zoneID)
    if not name then return nil end
    local profile = SourceMaps.entry(name).profile
    if compatibility[profile] and not compatibility[profile].motion then return nil end
    local resolver = content(profile)
    local trainers = SourceEvents.trainerDefinitions()
    local provider=assert(WorldDeltas.definitionProvider(),"source actor surface provider missing")
    local surface=provider:surface(zoneID,world);local d=SourceMaps.padded(name)
    local rules=Party._primitive(d.directional_rules)
    local specList,protected={},{}
    local function protect(x,y)if x>=0 and y>=0 and x<surface.width and y<surface.height then protected[y*surface.width+x+1]=true end end
    for _,warp in ipairs(d.events.warps)do
        protect(warp.x,warp.y)
        if SourceMaps.isDoor(name,warp.x,warp.y)then protect(warp.x,warp.y+1)end
    end
    for _,connection in ipairs(d.connections)do
        if connection.direction=="north"or connection.direction=="south"then
            local y=connection.direction=="north"and 0 or surface.height-1
            for x=0,surface.width-1 do protect(x,y)end
        else local x=connection.direction=="west"and 0 or surface.width-1;for y=0,surface.height-1 do protect(x,y)end end
    end
    for _,event in ipairs(d.events.objects)do
        local trainer=trainers[event.id];local item=event.kind=="item"
        if trainer then
            assert(trainer.map_id == zoneID and trainer.sprite_source == event.sprite, "trainer differs from source object")
        end
        local strip=resolver.sprite(event.sprite);local faces={}
        for direction in pairs(strip.standing)do faces[direction]=true end
        if faces.left then faces.right=true end
        local facing=({UP="up",DOWN="down",LEFT="left",RIGHT="right",LEFT_RIGHT="left",UP_DOWN="down",NONE="down",ANY_DIR="down"})[event.range_or_facing]
        assert(facing and faces[facing],"source actor initial facing missing exact pose")
        local spec={id=event.id,order=event.source_index,x=event.x,y=event.y,role=trainer and "trainer"or item and "item"or "npc",
            movement=event.movement,selector=event.range_or_facing,sprite_source=event.sprite,content_profile=profile,faces=faces,facing=facing,
            random=not trainer and not item,visibility={},script_positions={}}
        if trainer then
            local delta=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[facing]
            for i=0,math.max(0,trainer.sight_range_cells-1)do spec.script_positions[(event.y+delta[2]*i)*surface.width+event.x+delta[1]*i+1]=true end
        end
        local positions = SourceEvents.actorPositions(event.id)
        for _,position in ipairs(positions) do
            assert(position.x < surface.width and position.y < surface.height, "script position outside source map")
            local cell = position.y * surface.width + position.x + 1
            assert(not protected[cell], "script position on protected warp/connection cell")
            spec.script_positions[cell] = true
        end
        local metadata = resolver.metadata and resolver.metadata(d, event) or {}
        spec.visibility = Party._primitive(metadata.visibility or {})
        local descriptor = SourceEvents.descriptor(event.id)
        if profile ~= "pewter" and descriptor and descriptor.kind == "pickup" then
            spec.visibility[#spec.visibility + 1] = {group="quest", id=descriptor.flag, equals=false}
        end
        specList[#specList+1]=spec
    end
    local function canWander(spec,x,y,runtimeZone)
        if x<0 or y<0 or x>=surface.width or y>=surface.height or (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1]~=0 then return false end
        if spec.role=="trainer"then return spec.script_positions[y*surface.width+x+1]==true end
        if spec.movement~="WALK"then return x==spec.x and y==spec.y end
        if math.abs(x-spec.x)>4 or math.abs(y-spec.y)>4 or protected[y*surface.width+x+1]then return false end
        if spec.selector=="UP_DOWN"and x~=spec.x or spec.selector=="LEFT_RIGHT"and y~=spec.y then return false end
        return true
    end
    local function canStand(spec,x,y,runtimeZone)
        local cell = y * surface.width + x + 1
        if spec.script_positions[cell] and not protected[cell] and x >= 0 and y >= 0 and x < surface.width and y < surface.height
            and (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] == 0 then return true end
        return canWander(spec,x,y,runtimeZone)
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
    local function canWanderStep(spec,x,y,tx,ty,runtimeZone)
        return canWander(spec,x,y,runtimeZone) and canWander(spec,tx,ty,runtimeZone) and canStep(spec,x,y,tx,ty,runtimeZone)
    end
    return {zone_id=zoneID,revision=surface.revision,width=surface.width,height=surface.height,actors=specList,
        canStand=canStand,canStep=canStep,canWanderStep=canWanderStep,protected=protected}
end

-- Existing installation calls keep their provider identity while covering new
-- manifest maps. Root may rename the registration without installing two owners.
SourceActors.describePewter = SourceActors.describeSource

-- Settling and facing belong to NPCMotion for every tracked source actor.
function SourceActors.interact(game, npc, id)
    if game.npcManager.motion:requestInteraction(npc, id) then
        return true
    end
    npc:faceTowards(game.player.gridX, game.player.gridY)
    return SourceEvents.dispatch(game, id)
end

function SourceActors.trySight(game)
    local player = game.player
    if not game.trainers or not player or not currentZone
        or game.machine:getCurrent() ~= "overworld" or game.machine:depth() ~= 1
        or player.isMoving or player.pendingEdgeDoor or player.pendingConnection
        or game.session:getIntro().stage ~= "done" then return false end
    local name = SourceMaps.nameForID(currentZone.stableID)
    if not name then return false end
    local profile = SourceMaps.entry(name).profile
    if compatibility[profile] and not compatibility[profile].motion then return false end
    for _, npc in ipairs(game.npcManager.npcs) do
        local id = npc.def and npc.def.source_event_id
        local trainer = id and game.trainers:definition(id)
        if trainer and trainer.map_id == currentZone.stableID and SourceEvents.has(id)
            and not game.session:trainerDefeated(id) then
            local steps, reason = game.trainers:approach(npc, "sight")
            if steps then
                SourceEvents.dispatch(game, id, {mode="sight"})
                return true
            end
            if reason == "occupied-trainer-approach" or reason == "blocked-trainer-approach"
                or reason == "blocked-trainer-pair" or reason == "protected-trainer-approach" then
                player.lastTraversalBlock = {kind="trainer", id=reason}
            end
        end
    end
    return false
end

function SourceActors._withContent(fn)
    local old = contentResolvers
    contentResolvers = {}
    for profile, resolver in pairs(old) do contentResolvers[profile] = resolver end
    local ok, result = pcall(fn)
    contentResolvers = old
    if not ok then error(result, 0) end
    return result
end
