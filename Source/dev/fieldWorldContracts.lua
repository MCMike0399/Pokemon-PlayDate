-- Prepared real-SDK public-owner checks. Never executed by this worker.
FieldWorldContracts = {}
local gfx <const> = playdate.graphics
local function eq(a, b)
    assert(a == b, tostring(a) .. " ~= " .. tostring(b))
end

local function same(a, b)
    assert(FieldMoves.same(a, b), "values differ")
end

local function wire(g)
    return assert(SessionCodec.encode(g.session, {root = "overworld", overworld = "explore", settled = true}))
end

local function scene(fn)
    local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
    local oldStory, oldRNG, oldOwner = Story.currentContext(), RulesRNG.toData(), GameSession.activeRNGSession()
    local oldWorld = WorldDeltas.export()
    local count, ids = gfx.sprite.spriteCount(), WorldTiles:maxID()
    local ox, oy = gfx.getDrawOffset()
    local screen, sprites, sets = gfx.getWorkingImage():copy(), {}, {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite] = {visible = sprite:isVisible(), enabled = sprite:updatesEnabled()}
    end
    for key, value in pairs(SpriteFactory.npc) do
        sets[key] = value
    end
    local g = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()})
    local registry = TileRegistry()
    local provider = PewterWorld.createProvider(g, registry)
    zoneRegistry, zoneList = {}, {}
    local oldProvider = WorldDeltas.definitionProvider()
    for _, key in ipairs(oldList) do
        local zone = oldRegistry[key]
        if not oldProvider or not oldProvider:owns(zone) then
            zoneRegistry[key] = zone
            zoneList[#zoneList + 1] = key
        end
    end
    local liveView = getOverworldView()
    if liveView then liveView.zone:detachView(liveView) end
    local ok, problem = pcall(function()
        WorldDeltas._withDefinitionProvider(provider, function()
            WorldView.withIsolation(function()
                local mon = Pokemon("bulbasaur", 5)
                local flashMon <const> = Pokemon("pikachu", 5)
                assert(g:recruit(mon))
                assert(g:recruit(flashMon))
                assert(g.session:setIntro({stage = "done", starter = "bulbasaur", rivalStarter = "charmander"}))
                local bag = g.session:inventory()
                assert(bag:add("hm01", 1))
                assert(bag:add("hm05", 1))
                assert(Teaching.complete(assert(Teaching.prepare(g.session, mon, "hm01")), "learn"))
                assert(Teaching.complete(assert(Teaching.prepare(g.session, flashMon, "hm05")), "learn"))
                assert(g.session:setQuestFlag("BADGE_CASCADE", true))
                assert(g.session:setQuestFlag("BADGE_BOULDER", true))
                currentZone = provider:ensure(SourceMaps.entry("Route2").key)
                Story.bind(g)
                g.machine:register("overworld", OverworldState(g))
                g.machine:register("party", PartyState(g))
                g.machine:register("fieldMove", FieldMoveState(g))
                g.machine:register("bag", BagState(g))
                g.machine:register("learning", LearningState(g))
                g.machine:change("overworld", {entry = {x = 5, y = 9, facing = "down"}})
                assert(g.session:captureTraversal({
                    location = {zone_id = currentZone.stableID, x = 5, y = 9, facing = "down"},
                    world = WorldDeltas.export(),
                    actors = g.npcManager.motion:snapshot()
                }))
                g.machine:push("party")
                local party = g.machine:get("party")
                party:actions()
                fn(g, mon, party, provider)
            end)
        end)
    end)
    if liveView then
        liveView.zone:attachView(liveView)
        eq(getOverworldView(), liveView)
        assert(not liveView.disposed)
    end
    if g then
        while #g.machine.stack > 0 do
            local state = table.remove(g.machine.stack)
            pcall(state.exit, state)
        end
        g.npcManager:clear()
        if g.player then
            g.player:remove()
            g.player.grassOverlay:remove()
            g.player.exitArrow:remove()
            if g.player.jumpShadow then
                g.player.jumpShadow:remove()
            end
        end
    end
    provider:disposeCache()
    zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
    Story.bind(oldStory)
    WorldDeltas.apply(oldWorld)
    local owner = GameSession.activeRNGSession()
    if owner ~= oldOwner then
        if owner then
            owner:deactivateRNG()
        end
        if oldOwner then
            oldOwner:activateRNG()
        end
    end
    RulesRNG.restoreData(oldRNG)
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        if not sprites[sprite] then
            sprite:remove()
        end
    end
    local present = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        present[sprite] = true
    end
    for sprite, state in pairs(sprites) do
        if not present[sprite] then
            sprite:add()
        end
        sprite:setVisible(state.visible)
        sprite:setUpdatesEnabled(state.enabled)
    end
    for key in pairs(SpriteFactory.npc) do
        if not sets[key] then
            SpriteFactory.npc[key] = nil
        end
    end
    for key, value in pairs(sets) do
        SpriteFactory.npc[key] = value
    end
    gfx.setDrawOffset(0, 0)
    screen:draw(0, 0)
    gfx.setDrawOffset(ox, oy)
    eq(gfx.sprite.spriteCount(), count)
    eq(WorldTiles:maxID(), ids)
    if not ok then
        error(problem, 0)
    end
end

local function location(g)
    return {
        zone_id = currentZone.stableID,
        x = g.player.gridX,
        y = g.player.gridY,
        facing = g.player.facing
    }
end

local function capture(g)
    assert(g.session:captureTraversal({
        world = WorldDeltas.export(),
        location = location(g),
        actors = g.npcManager.motion:snapshot()
    }))
end

local function cut(g)
    local plan = assert(FieldMoves.cutPlan(g))
    assert(FieldMoveWorld.commit(g, plan.before, plan.after, location(g), g.npcManager.motion:snapshot()))
    return plan
end

local function step(g, dx, dy)
    g.player:tryMove(dx, dy)
    assert(g.player.isMoving, "real player must start step")
    for _ = 1, 8 do
        g.player:update()
    end
    assert(not g.player.isMoving, "real player must finish step")
end

local function reload(g)
    local before = WorldDeltas.export()
    local world = FieldWorld.reloadWorld(before, {currentZone.stableID})
    return FieldWorld.commit(g, before, {world = world, location = location(g), actors = g.npcManager.motion:snapshot()})
end

function FieldWorldContracts.run()
    local report <const> = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        Autopilot.resetControls()
        report.tests[#report.tests + 1] = {
            name = name,
            ok = ok,
            error = not ok and tostring(problem) or nil
        }
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end

    test("field-world: lifecycle invalidation rejects a retained scene RNG intent", function()
        scene(function(g)
            local before = wire(g)
            local runtime = WorldDeltas.export()
            local rng = RulesRNG.toData()
            local stream, token = g.session:forkWorldRNG()
            same(stream:toData(), g.session:worldRngData())
            g.session:invalidateFieldWorldContext()
            local accepted, reason = g.session:transactScene({}, {}, {
                token = token,
                beforeWorld = runtime,
                world = runtime,
                beforeRng = stream:toData(),
                rng = stream:toData(),
                location = g.session:location(),
            })
            eq(accepted, false)
            eq(reason, "stale-scene-intent")
            same(wire(g), before)
            same(WorldDeltas.export(), runtime)
            same(RulesRNG.toData(), rng)
        end)
    end)

    test("field-world: Cut reload under player preserves position and allows real step off", function()
        scene(function(g)
            g.machine:pop()
            cut(g)
            step(g, 0, 1)
            capture(g)
            local before = location(g)
            assert(reload(g))
            same(location(g), before)
            same(g.session:location(), before)
            eq(currentZone.collision[before.y + 1][before.x + 1], 1)
            -- A checkpoint cannot exploit the player-only allowance.
            assert(not pcall(WorldDeltas.resolveLocation, before, WorldDeltas.export(), g.sessionLocationPolicy))
            step(g, 0, -1)
            local x, y = g.player.gridX, g.player.gridY
            g.player:tryMove(0, 1)
            eq(g.player.isMoving, false)
            eq(g.player.gridX, x)
            eq(g.player.gridY, y)
        end)
    end)

    test("field-world: Save Continue resets Cut under tree with old position and unrelated delta", function()
        scene(function(g)
            g.machine:pop()
            cut(g)
            step(g, 0, 1)
            capture(g)
            local saved = wire(g)
            local candidate = assert(SessionCodec.decode(saved, g:getSessionDependencies()))
            assert(FieldWorld.prepareContinue(candidate))
            same(candidate:location(), saved.location)
            same(candidate:fieldWorldData(), saved.fieldWorld)
            assert(not FieldMoves.same(candidate:worldData(), saved.world))
            local recoded = assert(SessionCodec.encode(candidate, {root = "overworld", overworld = "explore", settled = true}))
            assert(SessionCodec.decode(recoded, g:getSessionDependencies()))
            -- Projection never rewrites a disjoint tile delta.
            local d = WorldDeltas.definitionProvider():descriptor(currentZone.stableID)
            local world = WorldDeltas.export()
            local record = world.zones[1]
            record.tiles[#record.tiles + 1] = {x = 1, y = 1, key = "base:2"}
            record.tile_count = #record.tiles
            local valid, normalized = pcall(WorldDeltas.validate, world)
            assert(valid, normalized)
            local reset = FieldWorld.reloadWorld(normalized, {d.id})
            local found = false
            for _, zone in ipairs(reset.zones) do
                for _, tile in ipairs(zone.tiles) do
                    if tile.x == 1 and tile.y == 1 and tile.key == "base:2" then
                        found = true
                    end
                end
            end
            assert(found)
        end)
    end)

    test("field-world: public GameSaves saves and Continues under restored tree", function()
        scene(function(g)
            g.machine:pop()
            cut(g)
            step(g, 0, 1)
            g.player.stepJustFinished = false
            g.fieldWorld = FieldWorld
            local prefix = "field-world-contract-" .. tostring(playdate.getCurrentTimeMilliseconds())
            local saves = GameSaves(g, prefix)
            local ok, problem = pcall(function()
                assert(saves:save())
                local saved = assert(saves.store:load())
                assert(saves:continueGame())
                same(g.session:location(), saved.location)
                eq(currentZone.collision[saved.location.y + 1][saved.location.x + 1], 1)
                step(g, 0, -1)
            end)
            for _, suffix in ipairs({".a.json", ".b.json", ".candidate.json"}) do
                playdate.file.delete(prefix .. suffix)
            end
            if not ok then
                error(problem, 0)
            end
        end)
    end)

    test("field-world: session rejection rolls runtime terrain back without actor/location/RNG changes", function()
        scene(function(g)
            cut(g)
            local before = wire(g)
            local runtime = WorldDeltas.export()
            local rng = RulesRNG.toData()
            local actors = g.npcManager.motion:snapshot()
            local candidate = FieldWorld.reloadWorld(runtime, {currentZone.stableID})
            local accepted = FieldWorld.commit(g, runtime, {
                world = candidate,
                location = {zone_id = currentZone.stableID, x = 0, y = 0, facing = "up"},
                actors = actors,
                fieldWorld = {version = 1, mapPalOffset = 9}
            })
            eq(accepted, false)
            same(wire(g), before)
            same(WorldDeltas.export(), runtime)
            same(g.npcManager.motion:snapshot(), actors)
            same(RulesRNG.toData(), rng)
        end)
    end)

    test("field-world: native view rejection restores runtime and session", function()
        scene(function(g)
            cut(g)
            local before = wire(g)
            local world = WorldDeltas.export()
            local view = getOverworldView()
            local apply = view.applyTiles
            view.applyTiles = function()
                error("injected native-view rejection", 0)
            end
            local accepted = reload(g)
            view.applyTiles = apply
            eq(accepted, false)
            same(wire(g), before)
            same(WorldDeltas.export(), world)
        end)
    end)

    test("field-world: menus and ordinary battle reentry retain Cut, genuine reload resets", function()
        scene(function(g)
            g.machine:pop()
            cut(g)
            g.fieldWorld = FieldWorld
            local before = WorldDeltas.export()
            local position = location(g)
            g.machine:push("party")
            g.machine:pop()
            same(WorldDeltas.export(), before)
            -- Public lifecycle return used by battle, with no new map entry.
            g.machine:change("overworld")
            same(WorldDeltas.export(), before)
            same(location(g), position)
            g.machine:change("overworld", {fieldReloadReason = "reload"})
            assert(not FieldMoves.same(WorldDeltas.export(), before))
            same(location(g), position)
        end)
    end)

    test("field-world: New Game clears offset and invalidates old epoch", function()
        scene(function(g)
            capture(g)
            assert(g.session:captureTraversal({
                world = g.session:worldData(),
                location = g.session:location(),
                actors = g.session:actorData(),
                fieldWorld = {version = 1, mapPalOffset = 6}
            }))
            local epoch = g.session:fieldWorldEpoch()
            g.fieldWorld = FieldWorld
            assert(g:beginNewSession(17))
            eq(g.session:fieldWorldData().mapPalOffset, 0)
            eq(g.session:clearFieldDarkness(epoch), false)
        end)
    end)

    test("field-world: every other blocked source cell stays invalid for players", function()
        scene(function(g)
            local world = WorldDeltas.export()
            local d = WorldDeltas.definitionProvider():descriptor(currentZone.stableID)
            local allowed = {}
            for _, site in ipairs(FieldMoves.data().maps[d.id].sites) do
                for _, cell in ipairs(site.cells) do
                    if cell.before ~= cell.after and FieldMoves.tile(cell.before).collision == 1
                        and FieldMoves.tile(cell.after).collision == 0 then
                        allowed[cell.y * d.width + cell.x + d.padding + 1] = true
                    end
                end
            end
            local checked = 0
            for y = 0, d.height - 1 do
                for x = 0, d.width - 1 do
                    local pos = {zone_id = d.id, x = x, y = y, facing = "up"}
                    local normal = pcall(WorldDeltas.resolveLocation, pos, world, g.sessionLocationPolicy)
                    if not normal and not allowed[y * d.width + x + 1] then
                        eq(pcall(WorldDeltas.resolvePlayerLocation, pos, world, g.sessionLocationPolicy), false)
                        checked = checked + 1
                    end
                end
            end
            assert(checked>0)
        end)
    end)

    test("field-world: stale runtime guard refuses transaction", function()
        scene(function(g)
            local old = WorldDeltas.export()
            cut(g)
            local saved = wire(g)
            eq(FieldWorld.commit(g, old, {world = old, location = location(g)}), false)
            same(wire(g), saved)
        end)
    end)

    test("field-world: Flash offset persists, CAS is one shot and reads consume no RNG", function()
        scene(function(g)
            capture(g)
            assert(g.session:captureTraversal({
                world = g.session:worldData(),
                location = g.session:location(),
                actors = g.session:actorData(),
                fieldWorld = {version = 1, mapPalOffset = 6}
            }))
            local rng = RulesRNG.toData()
            local epoch = g.session:fieldWorldEpoch()
            local saved = wire(g)
            local candidate = assert(SessionCodec.decode(saved, g:getSessionDependencies()))
            eq(candidate:fieldWorldData().mapPalOffset, 6)
            assert(FieldWorld.prepareContinue(candidate))
            eq(candidate:fieldWorldData().mapPalOffset, 6)
            eq(g.session:fieldWorldEpoch(), epoch)
            eq(FieldWorld.darknessAdapter():read(g), nil) -- Rock Tunnel absent.
            assert(g.session:clearFieldDarkness(epoch))
            eq(g.session:fieldWorldData().mapPalOffset, 0)
            eq(g.session:clearFieldDarkness(epoch), false)
            same(RulesRNG.toData(), rng)
            local previous = g.session:fieldWorldEpoch()
            capture(g)
            eq(g.session:clearFieldDarkness(previous), false)
        end)
    end)

    test("field-world: declared future dark-map adapter CAS/floor/save contract without geometry", function()
        scene(function(g)
            local first, lower = "pokered:ROCK_TUNNEL_1F", "pokered:ROCK_TUNNEL_B1F"
            local revision = "af519899719f0754965776faac0e836a3b906e6d"
            -- This is the declared 5.5 metadata boundary, not an installed map:
            -- no Zone, collision grid, renderer or SDK global is synthesized.
            local function declared(id)
                if id == first or id == lower then
                    return {id = id, revision = revision}
                end
            end
            local deps = g:getSessionDependencies()
            local strict = deps.resolveLocation
            deps.resolveLocation = function(pos, world)
                if declared(pos.zone_id) then
                    assert(pos.x == 0 and pos.y == 0, "declared metadata anchor only")
                    return GameSession._copy(pos)
                end
                return strict(pos, world)
            end
            deps.resolvePlayerLocation = deps.resolveLocation
            local session = GameSession.newSession(deps, {
                location = {zone_id = first, x = 0, y = 0, facing = "down"},
                checkpoint = g.session:checkpoint(),
                world = WorldDeltas.export(),
                seed = 31
            })
            local context = {session = session}
            local adapter = FieldWorld.darknessAdapter(declared)
            local oldZone = currentZone
            local ok, problem = pcall(function()
                currentZone = {stableID = first} -- map identity only, no geometry.
                assert(session:captureTraversal({
                    world = session:worldData(),
                    location = session:location(),
                    fieldWorld = {version = 1, mapPalOffset = 6}
                }))
                local rng = RulesRNG.toData()
                local input = assert(adapter:read(context))
                same(adapter:read(context), input)
                local saved = assert(SessionCodec.encode(session, {root = "overworld", overworld = "explore", settled = true}))
                context.session = assert(SessionCodec.decode(saved, deps))
                eq(context.session:fieldWorldData().mapPalOffset, 6)
                eq(adapter:clear(context, input), false) -- replaced session epoch.
                input = assert(adapter:read(context))
                assert(adapter:clear(context, input))
                eq(adapter:clear(context, input), false)
                eq(context.session:fieldWorldData().mapPalOffset, 0)
                local lit = assert(adapter:read(context))
                assert(context.session:captureTraversal({
                    world = context.session:worldData(),
                    location = {zone_id = lower, x = 0, y = 0, facing = "down"}
                }))
                currentZone = {stableID = lower}
                eq(adapter:clear(context, lit), false)
                eq(adapter:read(context).offset, 0)
                local wrong = FieldWorld.darknessAdapter(function(id)
                    return {id = id, revision = "wrong"}
                end)
                eq(wrong:read(context), nil)
                same(RulesRNG.toData(), rng)
            end)
            currentZone = oldZone
            if not ok then
                error(problem, 0)
            end
        end)
    end)

    test("field-world: primary Rock Tunnel entry/floors/reentry/escape/blackout policy", function()
        local a, b = "pokered:ROCK_TUNNEL_1F", "pokered:ROCK_TUNNEL_B1F"
        local function eligible(id)
            return id == a or id == b
        end
        eq(FieldWorld.transitionOffset(0, "outside", a, "map", eligible), 6)
        eq(FieldWorld.transitionOffset(6, a, b, "map", eligible), 6)
        eq(FieldWorld.transitionOffset(0, b, a, "map", eligible), 0)
        eq(FieldWorld.transitionOffset(6, a, "outside", "map", eligible), 0)
        eq(FieldWorld.transitionOffset(6, a, b, "escape", eligible), 0)
        eq(FieldWorld.transitionOffset(6, a, a, "blackout", eligible), 0)
        eq(FieldWorld.transitionOffset(0, a, a, "reload", eligible), 0)
        assert(not pcall(FieldWorld.transitionOffset, 0, "outside", b, "map", eligible))
    end)

    test("field-world: v1 migration, v2 required data and invalid fields", function()
        scene(function(g)
            local saved = wire(g)
            eq(saved.version, SessionCodec.VERSION)
            same(saved.fieldWorld, {version = 1, mapPalOffset = 0})
            local old = SessionFixture.forVersion(saved, 1)
            old.fieldWorld = nil
            old.daycare = nil
            local migrated = assert(SessionCodec.decode(old, g:getSessionDependencies()))
            same(migrated:fieldWorldData(), {version = 1, mapPalOffset = 0})
            assert(migrated:fieldWorldEpoch() ~= g.session:fieldWorldEpoch())
            for _, invalid in ipairs({
                {version = 2, mapPalOffset = 0},
                {version = 1, mapPalOffset = 1},
                {version = 1, mapPalOffset = 6, extra = true},
                {version = 1, mapPalOffset = "6"}
            }) do
                local data = GameSession._copy(saved)
                data.fieldWorld = invalid
                eq(SessionCodec.validate(data, g:getSessionDependencies()), false)
            end
            saved.fieldWorld = nil
            eq(SessionCodec.validate(saved, g:getSessionDependencies()), false)
            old.fieldWorld = {version = 1, mapPalOffset = 0}
            eq(SessionCodec.validate(old, g:getSessionDependencies()), false)
        end)
    end)
    return report
end
