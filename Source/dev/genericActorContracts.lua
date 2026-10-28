-- Root-run real SDK witnesses. Synthetic actor metadata reuses pinned geometry
-- and SPRITE_YOUNGSTER art; it is never installed in campaign inventories.
GenericActorContracts = {}
local walkerID = "pokered:VIRIDIAN_SCHOOL_HOUSE:objects:1"
local trainerID = "pokered:VIRIDIAN_SCHOOL_HOUSE:objects:2"
local contentID = "generic-actor-contract"
local function eq(a, b) assert(a == b, "expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function same(a, b)
    eq(type(a), type(b))
    if type(a) ~= "table" then eq(a, b); return end
    for k, v in pairs(a) do same(v, b[k]) end
    for k in pairs(b) do assert(a[k] ~= nil, "unexpected field") end
end
local function rejects(fn) assert(not pcall(fn), "expected rejection") end

local function scene(fn)
    local oldZone, oldRegistry, oldList = currentZone, zoneRegistry, zoneList
    local oldStory, oldOwner, rng = Story.currentContext(), GameSession.activeRNGSession(), RulesRNG.toData()
    local sprites, tiles = playdate.graphics.sprite.spriteCount(), WorldTiles:maxID()
    local offsetX, offsetY = playdate.graphics.getDrawOffset()
    local g, provider
    local ok, problem = pcall(function()
        SourceActors._withContent(function()
            SourceEvents._withSources(function()
                local records = assert(json.decodeFile("dev/sourceMapFixture.json"))
                local fixture = assert(json.decodeFile("dev/genericActorFixture.json"))
                local d = records[fixture.record]
                for i, input in ipairs(fixture.objects) do
                    for key, value in pairs(input) do d.events.objects[i][key] = value end
                end
                SourceActors.registerContent("source", {sprite=PewterSlice.sprite, key=PewterSprites.key,
                    stepImage=PewterSprites.stepImage, install=PewterSprites.installFor})
                SourceEvents.registerEventSource(contentID, fixture.events)
                SourceEvents.registerTextSource(contentID, PewterSlice.text)
                SourceEvents.registerTrainerSource(contentID, function() return fixture.trainers end)
                fixture.trainers[trainerID].party[1].species = "caterpie" -- installed roster must stay immutable
                SourceMaps._withRecords(records, function()
                    g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
                    assert(g:recruit(Pokemon("squirtle", 5)))
                    assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
                    local deps = {dispatch=function(id) return SourceEvents.dispatch(g, id) end,
                        questFlag=function(id) return g.session:questFlag(id) end,
                        sourceFlag=function(id) return g.trainers:sourceFlag(id) end}
                    local profiles = SourceMaps.legacyProfiles(deps)
                    profiles.source = {options=function() return SourceBindings.options("source", deps) end,
                        prepare=SourceActors.installArt}
                    zoneRegistry, zoneList, currentZone = {}, {}, nil
                    -- The codec also validates the real Pallet healing checkpoint.
                    -- Keep authored locations available without importing the live
                    -- provider's cached source Zones into this isolated provider.
                    for _, key in ipairs(oldList) do
                        local zone = oldRegistry[key]
                        if not zone.imported then
                            zoneRegistry[key] = zone
                            zoneList[#zoneList + 1] = key
                        end
                    end
                    provider = SourceMaps.createProvider(profiles, TileRegistry())
                    WorldDeltas._withDefinitionProvider(provider, function()
                        same(WorldDeltas.resolveLocation(g.session:checkpoint(), provider:export(),
                            g.sessionLocationPolicy), g.session:checkpoint())
                        g.trainers = TrainerEvents(g)
                        currentZone = provider:ensure("fixture_ViridianSchoolHouse")
                        g.player = Player(3, 5, currentZone.collision, g.npcManager)
                        currentZone:spawnNPCs(g.npcManager)
                        local sub = StateMachine()
                        sub:register("explore", {}); sub:change("explore")
                        g.machine:register("overworld", {sub=sub})
                        g.machine:register("event", EventState(g))
                        g.machine:register("dialog", DialogState(g))
                        g.machine:register("pause", {})
                        g.machine:change("overworld")
                        g.npcManager.motion:attach(g, currentZone)
                        fn(g, g.npcManager.motion, provider)
                    end)
                end)
            end)
        end)
    end)
    if g then
        for i = #g.machine.stack, 1, -1 do g.machine.stack[i]:exit(); g.machine.stack[i] = nil end
        g.npcManager:clear()
        if g.player then g.player:remove(); g.player.grassOverlay:remove(); g.player.exitArrow:remove() end
        if GameSession.activeRNGSession() == g.session then g.session:deactivateRNG() end
    end
    if provider then provider:disposeCache() end
    currentZone, zoneRegistry, zoneList = oldZone, oldRegistry, oldList
    Story.bind(oldStory)
    if oldOwner then oldOwner:activateRNG() end
    RulesRNG.restoreData(rng)
    playdate.graphics.setDrawOffset(offsetX, offsetY)
    if not ok then error(problem, 0) end
    eq(playdate.graphics.sprite.spriteCount(), sprites)
    eq(WorldTiles:maxID(), tiles)
end

function GenericActorContracts.run()
    local report = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests+1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1; report.ok=false end
    end
    test("generic WALK uses explicit pinned art and round trips native midstep through SessionCodec", function()
        scene(function(g, motion)
            local rules = RulesRNG.toData()
            local npc = g.npcManager.npcs[1]
            motion:tick()
            local value = assert(motion:actor(npc))
            eq(value.phase, "moving"); eq(value.tick, 1); eq(value.x, 6)
            eq(g.npcManager:getNPCAt(5,5), npc); eq(g.npcManager:getNPCAt(6,5), npc)
            local image, x, y = npc:getImage(), npc.x, npc.y
            assert(g.session:captureTraversal({location={zone_id=currentZone.stableID,x=3,y=5,facing="up"},
                world=WorldDeltas.export(), actors=motion:snapshot()}))
            local wire = assert(SessionCodec.encode(g.session, {root="overworld",overworld="explore",settled=true}))
            same(wire.checkpoint, g.session:checkpoint())
            for _=1,7 do motion:tick() end
            local expected, worldRNG = motion:snapshot(), g.session:worldRngData()
            g.session = assert(SessionCodec.decode(wire, g:getSessionDependencies()))
            same(g.session:checkpoint(), wire.checkpoint)
            motion:attach(g, currentZone, g.session:actorData())
            eq(npc.x,x); eq(npc.y,y); eq(npc:getImage(),image)
            for _=1,7 do motion:tick() end
            same(motion:snapshot(),expected); same(g.session:worldRngData(),worldRNG); same(RulesRNG.toData(),rules)
        end)
    end)
    test("generic movement guards player collision warp cells and overlay RNG", function()
        scene(function(g, motion, provider)
            local descriptor = assert(SourceActors.describe(currentZone.stableID, provider:export()))
            local spec = descriptor.actors[1]
            -- Pinned source exits (2,7)/(3,7), padded by two columns.
            eq(descriptor.canStand(spec,4,7),false)
            eq(descriptor.canStand(spec,5,7),false)
            eq(descriptor.canStand(spec,6,7),true) -- adjacent ordinary floor
            eq(descriptor.canStand(spec,0,5),false) -- padded void
            g.player.gridX, g.player.gridY = 6,5
            motion:tick(); eq(motion:actor(g.npcManager.npcs[1]).phase,"delay")
            local before, rng = motion:snapshot(),g.session:worldRngData()
            g.machine:push("pause")
            for _=1,12 do motion:tick() end
            same(motion:snapshot(),before); same(g.session:worldRngData(),rng)
            g.machine:pop()
            local bad = Party._primitive(before)
            bad.actors[1].x, bad.actors[1].origin_x, bad.actors[1].target_x = 6,6,6
            rejects(function() motion:attach(g,currentZone,bad) end)
            same(motion:snapshot(),before)
            bad = Party._primitive(before)
            bad.actors[1].x,bad.actors[1].origin_x,bad.actors[1].target_x = 4,4,4
            bad.actors[1].y,bad.actors[1].origin_y,bad.actors[1].target_y = 7,7,7
            rejects(function() motion:attach(g,currentZone,bad) end)
            same(motion:snapshot(),before)
        end)
        scene(function(g,motion)
            currentZone.collision[6][7] = 1 -- block WALK target at 6,5
            motion:tick()
            eq(motion:actor(g.npcManager.npcs[1]).phase,"delay")
            eq(motion:actor(g.npcManager.npcs[1]).x,5)
        end)
    end)
    test("generic registered trainer sight dispatches real event and leases native approach", function()
        scene(function(g, motion)
            eq(PewterSlice.trainer(trainerID),nil)
            eq(g.trainers:definition(trainerID).party[1].species,"weedle")
            g.player.pendingConnection = {}
            eq(SourceActors.trySight(g),false)
            g.player.pendingConnection = nil
            eq(SourceActors.trySight(g),true)
            local event = g.machine:get("event")
            eq(event.trainerStep.id,trainerID)
            eq(event.phase,"trainer-notice")
            local npc = g.npcManager.npcs[2]
            local before = motion:actor(npc)
            -- Directly advance the actual trainer owner while the real Event
            -- owns its lease; no SDK/global/controller replacements.
            for tick=1,16 do
                local done, reason = g.trainers:updateApproach(event.trainerToken)
                eq(done,tick==16)
                if tick<16 then eq(reason,"moving") end
            end
            eq(npc.gridX,3); eq(npc.gridY,4)
            eq(motion:actor(npc).y,4)
            eq(before.y,2)
            assert(g.trainers:cancel(event.trainerToken))
            eq(motion:actor(npc).y,4)
            -- Completed cells survive cancellation; the lease is gone.
            g.machine:pop()
            local payload = motion:snapshot()
            WorldMotionData.normalize(payload,SourceActors.describe(currentZone.stableID,WorldDeltas.export()),
                {zone_id=currentZone.stableID,x=3,y=5,facing="up"},g.session:flags())
        end)
    end)
    test("generic encounter constructs the installed immutable trainer roster", function()
        scene(function(g)
            assert(g.session:activateRNG())
            assert(SourceActors.trySight(g))
            local event = g.machine:get("event")
            for _=1,16 do g.trainers:updateApproach(event.trainerToken) end
            local party = assert(g.trainers:launch(event.trainerToken))
            eq(party:count(),1)
            eq(party:active().species,"weedle")
            eq(party:active().level,6)
            assert(g.trainers:abortBattle(event.trainerToken))
        end)
    end)
    test("generic trainer sight rejects colliding approach cells and moving player", function()
        scene(function(g)
            local npc = g.npcManager.npcs[2]
            local before = currentZone.collision[4][4]
            currentZone.collision[4][4] = 1
            local steps, reason = g.trainers:approach(npc,"sight")
            eq(steps,nil); eq(reason,"blocked-trainer-approach")
            currentZone.collision[4][4] = before
            local walker = g.npcManager.npcs[1]
            local descriptor = SourceActors.describe(currentZone.stableID,WorldDeltas.export())
            eq(descriptor.protected[7*currentZone.width+4+1],true)
            eq(descriptor.protected[7*currentZone.width+5+1],true)
            eq(g.npcManager:getNPCAt(walker.gridX,walker.gridY),walker)
            g.player.isMoving = true
            local steps, reason = g.trainers:approach(npc,"sight")
            eq(steps,nil); eq(reason,"movement-active")
            g.player.isMoving = false
        end)
    end)
    test("generic moving actor interaction waits for settlement and restores facing", function()
        scene(function(g, motion)
            local npc = g.npcManager.npcs[1]
            motion:tick()
            eq(motion:actor(npc).phase, "moving")
            g.player.gridX, g.player.gridY, g.player.facing = 6, 6, "up"
            g.player:moveTo(6 * TILE_SIZE, 6 * TILE_SIZE - 8)
            assert(KantoWorld.tryInteract(g))
            eq(g.machine:getCurrent(), "overworld")
            eq(motion:actor(npc).tick, 1)
            for _ = 1, 7 do motion:tick() end
            eq(npc.gridX, 6)
            eq(npc.isMoving, false)
            eq(g.machine:getCurrent(), "overworld")
            local facing = motion:actor(npc).facing
            motion:tick()
            eq(g.machine:getCurrent(), "dialog")
            eq(npc.facing, "down")
            local dialog = g.machine:get("dialog")
            dialog.dialog.onComplete()
            dialog:handleInput()
            eq(g.machine:getCurrent(), "overworld")
            eq(npc.facing, facing)
            eq(motion:actor(npc).facing, facing)
        end)
    end)
    test("generic settled interaction restores its original facing without RNG", function()
        scene(function(g, motion)
            local npc = g.npcManager.npcs[1]
            local before = motion:actor(npc)
            local world, rules = g.session:worldRngData(), RulesRNG.toData()
            g.player.gridX, g.player.gridY, g.player.facing = 4, 5, "right"
            g.player:moveTo(4 * TILE_SIZE, 5 * TILE_SIZE - 8)
            assert(KantoWorld.tryInteract(g))
            eq(g.machine:getCurrent(), "dialog")
            eq(npc.facing, "left")
            local dialog = g.machine:get("dialog")
            dialog.dialog.onComplete()
            dialog:handleInput()
            eq(g.machine:getCurrent(), "overworld")
            same(motion:actor(npc), before)
            eq(npc.facing, before.facing)
            same(g.session:worldRngData(), world)
            same(RulesRNG.toData(), rules)
        end)
    end)
    test("the original twelve maps retain their legacy motion policy", function()
        local count, walkers, legacy = 0,0,0
        for _,name in ipairs(SourceMaps.names()) do
            local entry = SourceMaps.entry(name)
            local descriptor = SourceActors.describe(entry.id,WorldDeltas.export())
            if entry.profile == "viridian" then
                legacy = legacy + 1
                eq(descriptor,nil)
            elseif entry.profile == "pewter" then
                legacy = legacy + 1
                for _,spec in ipairs(assert(descriptor).actors) do
                    count=count+1
                    if spec.random and spec.movement=="WALK" then walkers=walkers+1 end
                end
            end
        end
        eq(legacy,12); eq(count,29); eq(walkers,3)
    end)
    return report
end
