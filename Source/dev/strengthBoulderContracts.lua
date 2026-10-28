-- One root-run behavior witness using the existing real-map scene helper.
-- No synthetic map, actor, RNG or codec implementation belongs here.
StrengthBoulderContracts = {}

function StrengthBoulderContracts.run()
    local ok, problem = pcall(function()
        VermilionStoryFixture.withScene("WardensHouse", {x=7, y=4, facing="right"}, function(game)
            local motion = game.npcManager.motion
            local boulder
            for _, npc in ipairs(game.npcManager.npcs) do
                if npc.def and npc.def.source_event_id == "pokered:WARDENS_HOUSE:objects:3" then
                    boulder = npc
                end
            end
            assert(boulder and motion:isBoulder(boulder), "real source Warden boulder missing")
            assert(boulder.def.source_boulder and boulder.facing == "down")
            local descriptor = SourceActors.describe(currentZone.stableID, WorldDeltas.export(), game)
            local spec
            for _, value in ipairs(descriptor.actors) do
                if value.id == boulder.def.source_event_id then
                    spec = value
                end
            end
            assert(spec.role == "boulder" and not spec.random and spec.selector == "BOULDER_MOVEMENT_BYTE_2")
            for cell in pairs(descriptor.protected) do
                local x = (cell - 1) % descriptor.width
                local y = (cell - 1) // descriptor.width
                assert(not descriptor.canStand(spec, x, y, currentZone), "boulder may block a protected exit")
            end
            local rules = game.session:rngData()
            local worldRNG = game.session:worldRngData()
            local initial = motion:snapshot()
            local x, y = boulder.gridX, boulder.gridY
            local image = boulder:getImage()
            local owner = {game=game, session=game.session, zone=currentZone, epoch=1}
            function owner:valid()
                return self.session == game.session and self.zone == currentZone
            end
            function owner:isTop()
                return game.machine:getCurrent() == "overworld"
            end
            local intent = assert(motion:previewBoulderPush(boulder, "right"))
            assert(intent.x == x and intent.toX == x + 1 and intent.y == y and intent.toY == y)
            local token = assert(motion:beginBoulderPush(boulder, "right", owner))
            assert(motion:occupantAt(x, y) == boulder and motion:occupantAt(x + 1, y) == boulder)
            for tick = 1, 3 do
                local complete, reason = motion:updateBoulderPush(token)
                assert(complete == false and reason == "moving")
                assert(boulder.x == (x + tick / 8) * TILE_SIZE and boulder.y == y * TILE_SIZE - 8)
                assert(boulder:getImage() == image and boulder.facing == "down")
                game.player:tryMove(1, 0)
                assert(not game.player.isMoving, "player entered reserved boulder origin")
            end
            assert(motion:cancelBoulderPush(token))
            assert(boulder.x == x * TILE_SIZE and boulder.gridX == x and not boulder.isMoving)
            assert(motion:occupantAt(x + 1, y) == nil)
            assert(CatalogRuntime.same(initial, motion:snapshot()), "cancel changed settled actor values")
            token = assert(motion:beginBoulderPush(boulder, "right", owner))
            for tick = 1, 8 do
                local complete, reason = motion:updateBoulderPush(token)
                assert(complete == (tick == 8))
                assert(reason == (tick == 8 and "complete" or "moving"))
            end
            assert(boulder.gridX == x + 1 and boulder.x == (x + 1) * TILE_SIZE)
            assert(not motion:isScriptOwner(token, owner) and motion:occupantAt(x, y) == nil)
            game.player:tryMove(1, 0)
            assert(game.player.isMoving, "vacated boulder cell did not open")
            for _ = 1, 8 do
                game.player:update()
            end
            assert(game.player.gridX == x and not game.player.isMoving)
            local preview, reason = motion:previewBoulderPush(boulder, "right")
            assert(preview == nil and reason == "blocked-boulder-surface", "pushed through source map boundary")
            local location = {zone_id=currentZone.stableID, x=game.player.gridX, y=game.player.gridY, facing=game.player.facing}
            local expected = motion:snapshot()
            assert(game.session:captureTraversal({location=location, world=WorldDeltas.export(), actors=expected}))
            local wire = assert(SessionCodec.encode(game.session, {root="overworld", overworld="explore", settled=true}))
            local restored = assert(SessionCodec.decode(wire, game:getSessionDependencies()))
            game.session = restored
            motion:attach(game, currentZone, restored:actorData())
            assert(CatalogRuntime.same(expected, motion:snapshot()), "Continue lost pushed boulder")
            local migrated, failure = pcall(WorldMotionData.legacyInitial, descriptor, location, game.session:flags())
            assert(not migrated and tostring(failure):find("legacy boulder overlaps saved player", 1, true),
                "missing legacy pose silently relocated the boulder or player")
            game.player:tryMove(-1, 0)
            for _ = 1, 8 do
                game.player:update()
            end
            motion:attach(game, currentZone)
            assert(boulder.gridX == x and boulder.gridY == y, "fresh visit did not reset source position")
            assert(CatalogRuntime.same(rules, game.session:rngData()))
            assert(CatalogRuntime.same(worldRNG, game.session:worldRngData()), "boulder consumed world RNG")
            owner.session = game.session
            token = assert(motion:beginBoulderPush(boulder, "right", owner))
            assert(motion:updateBoulderPush(token) == false)
            owner.epoch = owner.epoch + 1
            local complete, stale = motion:updateBoulderPush(token)
            assert(complete == nil and stale == "stale-script-token")
            assert(boulder.x == x * TILE_SIZE and motion:occupantAt(x + 1, y) == nil)
        end)
    end)
    return {ok=ok, passed=ok and 1 or 0, failed=ok and 0 or 1, tests={{
        name="real Warden boulder reserves eight frames, cancels, persists through codec and resets on fresh entry",
        ok=ok, error=not ok and tostring(problem) or nil
    }}}
end
