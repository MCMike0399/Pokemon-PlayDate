-- Reusable immutable actor descriptor providers. Registration happens during
-- content install; validation only reads plain definitions and candidate state.
SourceActors={}
local providers={}
function SourceActors.register(name,describe)
    assert(type(name)=="string"and type(describe)=="function","named actor descriptor provider required")
    assert(not providers[name]or providers[name]==describe,"actor provider replaced")
    providers[name]=describe
end
function SourceActors.describe(zoneID,world,game)
    local found
    for _,describe in pairs(providers)do
        local descriptor=describe(zoneID,world,game)
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

-- Blue identifies pushable objects by movement byte 2, not by a terrain tile.
-- Their single fixed source frame always faces down; push direction is separate.
function SourceActors.isBoulderEvent(event)
    return event.sprite == "SPRITE_BOULDER"
        and event.range_or_facing == "BOULDER_MOVEMENT_BYTE_2"
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
    local function visibilityFor(game)
        local metadata = resolver.metadata and resolver.metadata(d, event, game) or {}
        local visibility = Party._primitive(metadata.visibility or {})
        if descriptor and descriptor.kind == "pickup" then
            visibility[#visibility + 1] = {group="quest", id=descriptor.flag, equals=false}
        end
        return visibility
    end
    local def = { gridX=event.x, gridY=event.y, name=trainer and trainer.name or event.text_id,
        sprite=key, source_event_id=event.id, source_sprite=event.sprite,
        source_boulder=SourceActors.isBoulderEvent(event),
        source_movement={kind=event.movement, range=event.range_or_facing},
        facing=({UP="up", DOWN="down", LEFT="left", RIGHT="right", LEFT_RIGHT="left"})[event.range_or_facing] or "down",
        dialog=function()
            assert(spec.status == "bound" and options.hasEvent(event.id), "unimplemented source interaction")
            return options.dispatch(event.id)
        end }
    def.appearsIf = function()
        for _, condition in ipairs(visibilityFor(options.runtimeGame)) do
            local value
            if condition.group == "quest" then value = options.questFlag(condition.id)
            else
                local reader = options.trainerFlag or options.sourceFlag
                assert(condition.group == "trainers" and reader, "explicit trainer flag reader required")
                value = reader(condition.id)
            end
            if (value == true) ~= condition.equals then return false end
        end
        return true
    end
    return def
end

-- Every ordinary manifest map uses this descriptor builder. Immutable content
-- resolvers supply art and exceptional visibility; geometry stays shared.
function SourceActors.describeSource(zoneID, world, game)
    local name = SourceMaps.nameForID(zoneID)
    if not name then return nil end
    local profile = SourceMaps.entry(name).profile
    if compatibility[profile] and not compatibility[profile].motion then return nil end
    local resolver = content(profile)
    local trainers = SourceEvents.trainerDefinitions()
    local provider=assert(WorldDeltas.definitionProvider(),"source actor surface provider missing")
    local surface=provider:surface(zoneID,world);local d=SourceMaps.padded(name)
    local rules=Party._primitive(d.directional_rules)
    local specList,protected,warps={},{},{}
    local function protect(x,y)if x>=0 and y>=0 and x<surface.width and y<surface.height then protected[y*surface.width+x+1]=true end end
    for _,warp in ipairs(d.events.warps)do
        protect(warp.x,warp.y)
        warps[warp.y*surface.width+warp.x+1] = true
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
        local boulder = SourceActors.isBoulderEvent(event)
        if trainer then
            assert(trainer.map_id == zoneID and trainer.sprite_source == event.sprite, "trainer differs from source object")
        end
        local strip=resolver.sprite(event.sprite);local faces={}
        for direction in pairs(strip.standing)do faces[direction]=true end
        if faces.left then faces.right=true end
        local facing=({UP="up",DOWN="down",LEFT="left",RIGHT="right",LEFT_RIGHT="left",UP_DOWN="down",NONE="down",ANY_DIR="down"})[event.range_or_facing]
        if boulder then
            assert(event.movement == "STAY" and strip.fixed, "source boulder must use fixed stationary art")
            facing = "down"
        end
        assert(facing and faces[facing],"source actor initial facing missing exact pose")
        local spec={id=event.id,order=event.source_index,x=event.x,y=event.y,role=boulder and "boulder" or trainer and "trainer"or item and "item"or "npc",
            movement=event.movement,selector=event.range_or_facing,sprite_source=event.sprite,content_profile=profile,faces=faces,facing=facing,
            random=not boulder and not trainer and not item,visibility={},script_positions={}}
        if trainer then
            local delta=({up={0,-1},down={0,1},left={-1,0},right={1,0}})[facing]
            for i=0,math.max(0,trainer.sight_range_cells-1)do spec.script_positions[(event.y+delta[2]*i)*surface.width+event.x+delta[1]*i+1]=true end
        end
        local positions = SourceEvents.actorPositions(event.id)
        for _,position in ipairs(positions) do
            assert(position.x < surface.width and position.y < surface.height, "script position outside source map")
            local cell = position.y * surface.width + position.x + 1
            -- The pinned guide route crosses the Mart arrival before its Gym
            -- departure. Both are leased route cells, never actual warps.
            local transit = (event.id == "pokered:PEWTER_CITY:objects:5"
                and position.y == 18 and (position.x == 16 or position.x == 23)
                or event.id == "pokered:SS_ANNE_2F:objects:2"
                and position.x == event.x and position.y == event.y+1)
                and protected[cell] and not warps[cell]
            assert(not protected[cell] or transit, "script position on protected warp/connection cell")
            if transit then
                spec.script_transit = spec.script_transit or {}
                spec.script_transit[cell] = true
            end
            spec.script_positions[cell] = true
        end
        local metadata = resolver.metadata and resolver.metadata(d, event, game) or {}
        spec.script_collision_positions = {}
        for _, position in ipairs(SourceEvents.actorCollisionPositions(event.id)) do
            local cell = position.y * surface.width + position.x + 1
            assert(spec.script_positions[cell] and not protected[cell], "collision exception outside source script positions")
            spec.script_collision_positions[cell] = true
        end
        spec.visibility = Party._primitive(metadata.visibility or {})
        -- Source objects may stand on a machine, counter or water tile that
        -- blocks the player. Only the original STAY home gets this permission;
        -- world deltas and script routes cannot create new blocked homes.
        local home = event.y * surface.width + event.x + 1
        spec.blocked_home = event.movement == "STAY" and not protected[home]
            and d.collision[event.y+1][event.x+1] == 1
            and surface.collision[event.y+1][event.x+1] == 1
        local descriptor = SourceEvents.descriptor(event.id)
        if profile ~= "pewter" and descriptor and descriptor.kind == "pickup" then
            spec.visibility[#spec.visibility + 1] = {group="quest", id=descriptor.flag, equals=false}
        end
        specList[#specList+1]=spec
    end
    local function canWander(spec,x,y,runtimeZone)
        if x<0 or y<0 or x>=surface.width or y>=surface.height or (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1]~=0 then return false end
        if spec.role == "boulder" then
            return false
        end
        if spec.role=="trainer"then return spec.script_positions[y*surface.width+x+1]==true end
        if spec.movement~="WALK"then return x==spec.x and y==spec.y end
        if math.abs(x-spec.x)>4 or math.abs(y-spec.y)>4 or protected[y*surface.width+x+1]then return false end
        if spec.selector=="UP_DOWN"and x~=spec.x or spec.selector=="LEFT_RIGHT"and y~=spec.y then return false end
        return true
    end
    local function canStand(spec,x,y,runtimeZone)
        local cell = y * surface.width + x + 1
        if spec.role == "boulder" then
            if x < 0 or y < 0 or x >= surface.width or y >= surface.height
                or protected[cell]
                or (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] ~= 0 then
                return false
            end
            local foot = runtimeZone and runtimeZone:terrainAt(x,y).foot_tile or surface.feet[y+1][x+1]
            return foot ~= 0x15 -- Blue explicitly forbids pushing onto stairs.
        end
        if spec.blocked_home and x == spec.x and y == spec.y
            and x >= 0 and y >= 0 and x < surface.width and y < surface.height
            and (runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] == 1 then return true end
        if spec.script_positions[cell] and (not protected[cell] or spec.script_transit and spec.script_transit[cell]) and x >= 0 and y >= 0 and x < surface.width and y < surface.height
            and ((runtimeZone and runtimeZone.collision or surface.collision)[y+1][x+1] == 0
                or spec.script_collision_positions[cell]) then return true end
        return canWander(spec,x,y,runtimeZone)
    end
    local function canStep(spec,x,y,tx,ty,runtimeZone)
        if not canStand(spec,x,y,runtimeZone)or not canStand(spec,tx,ty,runtimeZone)or math.abs(tx-x)+math.abs(ty-y)~=1 then return false end
        -- Standing at a pinned blocked home does not authorize entering it.
        -- Bill's separately declared script collision poses retain their policy.
        local target = ty * surface.width + tx + 1
        if (runtimeZone and runtimeZone.collision or surface.collision)[ty+1][tx+1] ~= 0
            and not spec.script_collision_positions[target] then return false end
        local a=runtimeZone and runtimeZone:terrainAt(x,y).foot_tile or surface.feet[y+1][x+1]
        local b=runtimeZone and runtimeZone:terrainAt(tx,ty).foot_tile or surface.feet[ty+1][tx+1]
        local direction=tx>x and "RIGHT"or tx<x and "LEFT"or ty>y and "DOWN"or "UP"
        for _,ledge in ipairs(rules.ledges)do if ledge.facing=="SPRITE_FACING_"..direction and ledge.standing_foot_tile==a and ledge.target_foot_tile==b then return false end end
        if spec.role ~= "boulder" then
            for _,pair in ipairs(rules.forbidden_tile_pairs)do if a==pair[1]and b==pair[2]or a==pair[2]and b==pair[1]then return false end end
        end
        return true
    end
    local function canPush(spec,px,py,x,y,tx,ty,runtimeZone)
        if spec.role ~= "boulder" or not canStep(spec,x,y,tx,ty,runtimeZone)
            or px ~= x - (tx-x) or py ~= y - (ty-y)
            or px < 0 or py < 0 or px >= surface.width or py >= surface.height then
            return false
        end
        -- Blue compares the player's current foot tile with the tile two steps
        -- ahead, not the boulder's current tile with its destination.
        local a = runtimeZone and runtimeZone:terrainAt(px,py).foot_tile or surface.feet[py+1][px+1]
        local b = runtimeZone and runtimeZone:terrainAt(tx,ty).foot_tile or surface.feet[ty+1][tx+1]
        for _, pair in ipairs(rules.forbidden_tile_pairs) do
            if a == pair[1] and b == pair[2] or a == pair[2] and b == pair[1] then
                return false
            end
        end
        return true
    end
    local function canWanderStep(spec,x,y,tx,ty,runtimeZone)
        return canWander(spec,x,y,runtimeZone) and canWander(spec,tx,ty,runtimeZone) and canStep(spec,x,y,tx,ty,runtimeZone)
    end
    return {zone_id=zoneID,revision=surface.revision,width=surface.width,height=surface.height,actors=specList,
        canStand=canStand,canStep=canStep,canPush=canPush,canWanderStep=canWanderStep,protected=protected}
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

-- Fixtures own an empty namespace, including on nested scopes. Restore the
-- exact production resolver table on both success and error.
function SourceActors._withContent(fn)
    local old = contentResolvers
    contentResolvers = {}
    local ok, result = pcall(fn)
    contentResolvers = old
    if not ok then error(result, 0) end
    return result
end

-- Cached Zones keep geometry, while runtime spawns refresh content predicates.
-- Isolated/catalog construction never receives this context or reads live Story.
function SourceActors.refresh(game, zone)
    local name = SourceMaps.nameForID(zone.stableID)
    if not name or SourceMaps.entry(name).profile ~= "source" then return end
    local d = SourceMaps.padded(name)
    local events = {}
    for _, event in ipairs(d.events.objects) do events[event.id] = event end
    local definitions = {}
    for _, def in ipairs(zone.npcDefs) do
        local event = events[def.source_event_id]
        if event then
            definitions[#definitions + 1] = SourceActors.objectDefinition(d, event,
                {status=SourceEvents.has(event.id) and "bound" or "blocked"}, {
                    runtimeGame=game, hasEvent=SourceEvents.has,
                    dispatch=function(id) return SourceEvents.dispatch(game,id) end,
                    questFlag=function(id) return game.session:questFlag(id) end,
                    trainerFlag=function(id) return game.session:trainerDefeated(id) end,
                })
        else definitions[#definitions + 1] = def end
    end
    zone.npcDefs = definitions
end
