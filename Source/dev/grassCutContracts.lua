-- Prepared real-SDK public-owner checks. Never executed by this worker.
GrassCutContracts = {}
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

local function scene(fn, entry)
    entry = entry or {x = 6, y = 14, facing = "right"}
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
                currentZone = provider:ensure(SourceMaps.entry("Route6").key)
                Story.bind(g)
                g.machine:register("overworld", OverworldState(g))
                g.machine:register("party", PartyState(g))
                g.machine:register("fieldMove", FieldMoveState(g))
                g.machine:register("bag", BagState(g))
                g.machine:register("learning", LearningState(g))
                g.machine:change("overworld", {entry = entry})
                assert(g.session:captureTraversal({
                    location = {zone_id = currentZone.stableID, x = entry.x, y = entry.y, facing = entry.facing},
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
    return {zone_id = currentZone.stableID, x = g.player.gridX, y = g.player.gridY, facing = g.player.facing}
end

local function snapshot(g)
    return {
        wire = wire(g), world = WorldDeltas.export(), rules = RulesRNG.toData(),
        actors = g.npcManager.motion:snapshot(), worldRng = g.session:worldRngData(),
        position = location(g), party = g.session:party():members()
    }
end

local function cut(g, party, mon)
    local token = assert(FieldMoves.prepare(g, party, mon, "cut"))
    local preview = assert(FieldMoves.preview(token))
    eq(preview.kind, "grass")
    assert(FieldMoves.complete(token))
    return preview
end

local function capture(g)
    assert(g.session:captureTraversal({world = WorldDeltas.export(), location = location(g),
        actors = g.npcManager.motion:snapshot()}))
end

local function step(g, dx, dy)
    g.player:tryMove(dx, dy)
    assert(g.player.isMoving, "actual Player must start step")
    for _ = 1, 8 do
        g.player:update()
    end
    eq(g.player.isMoving, false)
    g.player.stepJustFinished = false
end

local function findTile(world, x, y)
    for _, record in ipairs(world.zones) do
        if record.zone_id == currentZone.stableID then
            for _, tile in ipairs(record.tiles) do
                if tile.x == x and tile.y == y then
                    return tile.key
                end
            end
        end
    end
end

function GrassCutContracts.run()
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

    test("grass-cut: Route6 actual Zone replaces only the aligned source 2x2 block including player's grass", function()
        scene(function(g, mon, party)
            mon.hp, mon.pp.cut = 0, 0
            local before = snapshot(g)
            local preview = cut(g, party, mon)
            eq(#preview.cells, 4)
            eq(preview.target.x, 7)
            eq(preview.target.y, 14)
            for _, cell in ipairs(preview.cells) do
                assert(cell.x >= 6 and cell.x <= 7 and cell.y >= 14 and cell.y <= 15)
                eq(currentZone:isTallGrass(cell.x, cell.y), false)
                eq(currentZone:terrainAt(cell.x, cell.y).foot_tile, 0x2c)
                eq(currentZone.collision[cell.y + 1][cell.x + 1], 0)
            end
            eq(currentZone:isTallGrass(8, 14), true)
            eq(currentZone:isTallGrass(6, 16), true)
            same(g.session:worldData(), WorldDeltas.export())
            same(location(g), before.position)
            same(RulesRNG.toData(), before.rules)
            same(g.session:worldRngData(), before.worldRng)
            same(g.npcManager.motion:snapshot(), before.actors)
            eq(mon.hp, 0)
            eq(mon.pp.cut, 0)
            g.player:updateGrassOverlay()
            eq(g.player.grassOverlay:isVisible(), false)
            g.machine:pop()
            step(g, 0, 1)
            eq(g.player.grassOverlay:isVisible(), false)
            step(g, 0, 1)
            eq(g.player.grassOverlay:isVisible(), true)
        end)
    end)

    test("grass-cut: facing each quadrant selects one source block rather than player-centered area", function()
        for _, entry in ipairs({
            {x = 6, y = 14, facing = "right"}, {x = 7, y = 14, facing = "left"},
            {x = 6, y = 14, facing = "down"}, {x = 7, y = 15, facing = "up"}
        }) do
            scene(function(g)
                local plan = assert(FieldMoves.cutPlan(g))
                eq(plan.kind, "grass")
                eq(#plan.cells, 4)
                for _, cell in ipairs(plan.cells) do
                    assert(cell.x >= 6 and cell.x <= 7 and cell.y >= 14 and cell.y <= 15)
                end
            end, entry)
        end
    end)

    test("grass-cut: badge and actual owned move remain required; pending movement refuses", function()
        scene(function(g, mon, party)
            assert(g.session:setQuestFlag("BADGE_CASCADE", false))
            local before = snapshot(g)
            local token, reason = FieldMoves.prepare(g, party, mon, "cut")
            eq(token, nil)
            eq(reason, "badge-required")
            same(snapshot(g), before)
            assert(g.session:setQuestFlag("BADGE_CASCADE", true))
            eq(FieldMoves.prepare(g, party, Pokemon("bulbasaur", 5), "cut"), nil)
            local other = Pokemon("pidgey", 5)
            assert(g:recruit(other))
            eq(FieldMoves.prepare(g, party, other, "cut"), nil)
            g.player.pendingConnection = {}
            eq(FieldMoves.prepare(g, party, mon, "cut"), nil)
            g.player.pendingConnection = nil
        end)
    end)

    test("grass-cut: 16 native updates sample 32 source positions and commit once; cancellation and retained callbacks cannot mutate", function()
        scene(function(g, mon, party)
            local before = snapshot(g)
            assert(FieldMoveState.open(g, party, mon, "cut"))
            local state = g.machine:get("fieldMove")
            local callback = state.menu.onSelect
            callback(1)
            eq(callback(2), false)
            same(snapshot(g), before)
            assert(FieldMoveState.open(g, party, mon, "cut"))
            state.menu.onSelect(2)
            Autopilot.step({"press", "a"}, g)
            state:handleInput()
            Autopilot.resetControls()
            eq(state.phase, "effect")
            for nativeUpdate = 0, 14 do
                eq(state.frame, nativeUpdate)
                eq(FieldMoveState.grassSourceFrame(state.frame), nativeUpdate * 2 + 1)
                state:draw()
                state:update()
                same(snapshot(g), before)
            end
            eq(state.frame, 15)
            eq(FieldMoveState.grassSourceFrame(state.frame), 31)
            state:draw()
            local token = state.token
            state:update()
            assert(state.lastResult.ok, state.lastResult.reason)
            eq(g.machine:getCurrent(), "overworld")
            eq(FieldMoves.complete(token), false)
            local committed = snapshot(g)
            state:update()
            same(snapshot(g), committed)
            eq(currentZone:isTallGrass(6, 14), false)
        end)
    end)

    test("grass-cut: forced exit during leaf effect preserves terrain and all session owners", function()
        scene(function(g, mon, party)
            local before = snapshot(g)
            assert(FieldMoveState.open(g, party, mon, "cut"))
            local state = g.machine:get("fieldMove")
            state.menu.onSelect(2)
            Autopilot.step({"press", "a"}, g)
            state:handleInput()
            Autopilot.resetControls()
            for _ = 1, 15 do
                state:draw()
                state:update()
            end
            eq(state.frame, 15)
            eq(FieldMoveState.grassSourceFrame(state.frame), 31)
            state:draw()
            local token = state.token
            g.machine:pop()
            state:update()
            eq(FieldMoves.complete(token), false)
            same(snapshot(g), before)
        end)
    end)

    test("grass-cut: prepared production draw never warms art or changes the live action", function()
        scene(function(g, mon, party)
            assert(FieldMoveState.open(g, party, mon, "cut"))
            local state = g.machine:get("fieldMove")
            state.menu.onSelect(2)
            Autopilot.step({"press", "a"}, g)
            state:handleInput()
            Autopilot.resetControls()
            local token, presentation = state.token, state.grassPresentation
            local before = snapshot(g)
            local render, tile = TileFactory.renderGrid, FieldMoves.tile
            TileFactory.renderGrid = function()
                error("grass draw attempted renderer cache warm", 0)
            end
            FieldMoves.tile = function()
                error("grass draw attempted terrain cache read", 0)
            end
            local ok, problem = pcall(function()
                state:draw()
                state:draw()
            end)
            TileFactory.renderGrid, FieldMoves.tile = render, tile
            assert(ok, problem)
            eq(state.frame, 0)
            eq(state.phase, "effect")
            eq(state.token, token)
            eq(state.grassPresentation, presentation)
            assert(FieldMoves.isCurrent(token, state))
            same(snapshot(g), before)
            eq(pcall(FieldMoveState.grassSourceFrame, -1), false)
            eq(pcall(FieldMoveState.grassSourceFrame, 16), false)
        end)
    end)

    test("grass-cut: changed party record and actor occupancy stale opaque requests", function()
        scene(function(g, mon, party)
            local token = assert(FieldMoves.prepare(g, party, mon, "cut"))
            mon.pp.cut = mon.pp.cut - 1
            eq(FieldMoves.complete(token), false)
            FieldMoves.cancel(token)
            token = assert(FieldMoves.prepare(g, party, mon, "cut"))
            -- Use an actual existing Route6 NPC as the occupancy guard probe.
            local npc = assert(g.npcManager.npcs[1])
            local x, y = npc.gridX, npc.gridY
            npc.gridX, npc.gridY = 7, 15
            local accepted = FieldMoves.complete(token)
            npc.gridX, npc.gridY = x, y
            eq(accepted, false)
            eq(currentZone:isTallGrass(7, 15), true)
        end)
    end)

    test("grass-cut: source NPC surface protects the complete aligned grass block", function()
        scene(function(g, mon, party)
            local before = snapshot(g)
            local token, reason = FieldMoves.prepare(g, party, mon, "cut")
            eq(token, nil)
            eq(reason, "occupied-target")
            same(snapshot(g), before)
        end, {x = 1, y = 14, facing = "left"})
    end)

    test("grass-cut: map boundary and actual Underground Path warp cannot be mutation targets", function()
        for _, entry in ipairs({{x = 19, y = 28, facing = "right"}, {x = 17, y = 14, facing = "up"}}) do
            scene(function(g, mon, party)
                local before = snapshot(g)
                eq(FieldMoves.prepare(g, party, mon, "cut"), nil)
                same(snapshot(g), before)
            end, entry)
        end
    end)

    test("grass-cut: native view failure restores runtime ledger registry and session", function()
        scene(function(g, mon, party)
            local token = assert(FieldMoves.prepare(g, party, mon, "cut"))
            local before = snapshot(g)
            local view = getOverworldView()
            local original = view.applyTiles
            view.applyTiles = function()
                error("grass-cut injected native view rejection", 0)
            end
            local called, accepted, reason = pcall(FieldMoves.complete, token)
            view.applyTiles = original
            assert(called)
            eq(accepted, false)
            assert(tostring(reason):find("grass-cut injected native view rejection", 1, true))
            same(snapshot(g), before)
            eq(currentZone:isTallGrass(6, 14), true)
        end)
    end)

    test("grass-cut: session rejection after native apply rolls back terrain and saved world", function()
        scene(function(g, mon, party)
            local token = assert(FieldMoves.prepare(g, party, mon, "cut"))
            local before = snapshot(g)
            local deps = GameSession._state(g.session).deps
            local original = deps.validateActors
            local calls = 0
            deps.validateActors = function(...)
                calls = calls + 1
                if calls == 2 then
                    eq(currentZone:isTallGrass(6, 14), false)
                    error("grass-cut injected session rejection", 0)
                end
                return original(...)
            end
            local called, accepted, reason = pcall(FieldMoves.complete, token)
            deps.validateActors = original
            assert(called)
            eq(accepted, false)
            eq(calls, 2)
            assert(tostring(reason):find("grass-cut injected session rejection", 1, true))
            same(snapshot(g), before)
            eq(currentZone:isTallGrass(6, 14), true)
        end)
    end)

    test("grass-cut: real menu and battle return retain terrain; actual reload restores grass under Player", function()
        scene(function(g, mon, party)
            cut(g, party, mon)
            g.machine:pop()
            local before = WorldDeltas.export()
            local position = location(g)
            g.machine:push("party")
            g.machine:pop()
            same(WorldDeltas.export(), before)
            -- This is the public no-entry lifecycle invoked on battle return.
            g.machine:change("overworld")
            same(WorldDeltas.export(), before)
            eq(currentZone:isTallGrass(6, 14), false)
            g.machine:change("overworld", {fieldReloadReason = "reload"})
            same(location(g), position)
            same(g.session:location(), position)
            eq(currentZone:isTallGrass(6, 14), true)
            g.player:updateGrassOverlay()
            eq(g.player.grassOverlay:isVisible(), true)
            step(g, 0, 1)
            capture(g)
            eq(currentZone:isTallGrass(6, 15), true)
        end)
    end)

    test("grass-cut: actual BattleState terminal return retains the cut grass block", function()
        scene(function(g, mon, party)
            cut(g, party, mon)
            g.machine:pop()
            local before = WorldDeltas.export()
            local position = location(g)
            assert(g.session:activateRNG())
            local owner = BattleState(g)
            g.machine:register("battle", owner)
            assert(FieldBattle.start(g, mon, Pokemon("magikarp", 5)))
            local battle = owner.battle
            for _ = 1, 100 do
                if battle:phase() ~= "script" then
                    break
                end
                battle.machine:get("script"):advance()
            end
            assert(battle:phase() ~= "script", "actual battle intro must settle")
            -- Exercise the real terminal dispatcher/finish/OverworldState chain.
            -- Escape odds and battle rules remain the existing owner's suite.
            battle:runScript(function()
                return "run"
            end)
            eq(g.machine:getCurrent(), "overworld")
            eq(g.lastBattleOutcome.kind, "run")
            same(WorldDeltas.export(), before)
            same(location(g), position)
            eq(currentZone:isTallGrass(6, 14), false)
        end)
    end)

    test("grass-cut: saved terrain decodes then public Continue restores source grass and position", function()
        scene(function(g, mon, party)
            cut(g, party, mon)
            g.machine:pop()
            local prefix = "grass-cut-contract-" .. tostring(playdate.getCurrentTimeMilliseconds())
            local saves = GameSaves(g, prefix)
            local ok, problem = pcall(function()
                assert(saves:save())
                local saved = assert(saves.store:load())
                local decoded = assert(SessionCodec.decode(saved, g:getSessionDependencies()))
                same(decoded:worldData(), g.session:worldData())
                eq(findTile(decoded:worldData(), 6, 14), "pokered:OVERWORLD:cell:2c-2c-2c-2c")
                local rng, worldRng = RulesRNG.toData(), g.session:worldRngData()
                assert(saves:continueGame())
                same(g.session:location(), saved.location)
                same(location(g), saved.location)
                same(RulesRNG.toData(), rng)
                same(g.session:worldRngData(), worldRng)
                eq(currentZone:isTallGrass(6, 14), true)
                step(g, 0, 1)
            end)
            for _, suffix in ipairs({".a.json", ".b.json", ".candidate.json"}) do
                playdate.file.delete(prefix .. suffix)
            end
            assert(ok, problem)
        end)
    end)

    test("grass-cut: reset preserves unrelated deltas and rejects a partial changed source block", function()
        scene(function(g, mon, party)
            cut(g, party, mon)
            local world = WorldDeltas.export()
            local record
            for _, value in ipairs(world.zones) do
                if value.zone_id == currentZone.stableID then
                    record = value
                end
            end
            assert(record)
            record.tiles[#record.tiles + 1] = {x = 6, y = 12, key = "base:2"}
            record.tile_count = #record.tiles
            assert(FieldMoveWorld.commit(g, WorldDeltas.export(), world, location(g), g.npcManager.motion:snapshot()))
            local reset = FieldWorld.reloadWorld(WorldDeltas.export(), {currentZone.stableID})
            eq(findTile(reset, 6, 12), "base:2")
            eq(findTile(reset, 6, 14), nil)
            assert(FieldWorld.commit(g, WorldDeltas.export(), {world = reset, location = location(g),
                actors = g.npcManager.motion:snapshot()}))
            world = WorldDeltas.export()
            for _, value in ipairs(world.zones) do
                if value.zone_id == currentZone.stableID then
                    record = value
                end
            end
            record.tiles[#record.tiles + 1] = {x = 7, y = 15, key = "base:2"}
            record.tile_count = #record.tiles
            assert(FieldMoveWorld.commit(g, WorldDeltas.export(), world, location(g), g.npcManager.motion:snapshot()))
            local token, reason = FieldMoves.prepare(g, party, mon, "cut")
            eq(token, nil)
            eq(reason, "changed-source-block")
            local partial = WorldDeltas.export()
            same(FieldWorld.reloadWorld(partial, {currentZone.stableID}), partial)
        end)
    end)
    return report
end
