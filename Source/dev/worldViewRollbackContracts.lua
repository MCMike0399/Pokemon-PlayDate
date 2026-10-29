WorldViewRollbackContracts = {}

local function present(sprite)
    for _, candidate in ipairs(playdate.graphics.sprite.getAllSprites()) do
        if candidate == sprite then
            return true
        end
    end
    return false
end

local function assertGrid(view)
    for y = 1, view.zone.height do
        for x = 1, view.zone.width do
            assert(view:hasWallAt(x - 1, y - 1) == (view.zone.collision[y][x] == 1),
                "wall lookup differs from Zone collision grid")
            assert(view:tileAt(x - 1, y - 1) == view.zone.tiles[y][x],
                "native tilemap differs from Zone tiles")
        end
    end
    assert(not view:hasWallAt(-1, 0) and not view:hasWallAt(view.zone.width, 0))
    assert(not view:hasWallAt(0, -1) and not view:hasWallAt(0, view.zone.height))
end

function WorldViewRollbackContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    test("Zone grid authority and native tilemap rollback preserve attachment and images", function()
        local gfx = playdate.graphics
        local count = gfx.sprite.spriteCount()
        local view
        local ok, problem = pcall(function()
            for _, attached in ipairs({true, false}) do
                local registry = TileRegistry()
                local zone = Zone({id = "contract:view-rollback", tileRows = {"IW Fo Wt Fl"}, registry = registry})
                view = WorldView(zone, {attach = attached})
                assert(present(view.sprite) == attached)
                assert(gfx.sprite.spriteCount() == count + (attached and 1 or 0),
                    "WorldView must register only its tilemap sprite")
                assertGrid(view)
                local originalImages = view.images
                local originalCount = view.imageCount
                local originalImage = view:imageAt(0, 0)
                local restore = view:applyTiles({{x = 0, y = 0, id = 25, collision = 0}})
                assert(view:tileAt(0, 0) == 25 and view:hasWallAt(0, 0),
                    "view-only changes must not replace Zone collision authority")
                restore()
                assertGrid(view)
                assert(view.images == originalImages and view:imageAt(0, 0) == originalImage)

                local entry = registry:entry(25)
                restore = zone:_commitTiles({{x = 0, y = 0, id = 25, collision = 0, terrain = entry.terrain}})
                assert(not view:hasWallAt(0, 0) and zone.collision[1][1] == 0)
                assertGrid(view)
                restore()
                assert(view:hasWallAt(0, 0) and zone.collision[1][1] == 1)
                assertGrid(view)

                zone:setTile(1, 0, "base:26")
                assert(view:hasWallAt(1, 0))
                assertGrid(view)
                zone:resetDeltas()
                assert(not view:hasWallAt(1, 0))
                assertGrid(view)

                for _ = 1, 20 do
                    view:updateAnimations()
                end
                local tick, step = view.animTick, view.animStep
                local animated = {}
                for _, id in ipairs({4, 12, 11}) do
                    animated[id] = view.images:getImage(id)
                end
                local grid = {}
                for row = 1, 16 do
                    grid[row] = "................"
                end
                local ids = registry:registerBatch({{key = "contract:view-palette", grid = grid,
                    collision = 0, terrain = {land_passable = true}}})
                restore = zone:_commitTiles({{x = 0, y = 0, id = ids[1], collision = 0,
                    terrain = registry:entry(ids[1]).terrain}})
                assert(view.images ~= originalImages and view.imageCount == registry:maxID())
                assert(not view:hasWallAt(0, 0))
                assertGrid(view)
                for _, id in ipairs({4, 12, 11}) do
                    assert(view.images:getImage(id) == animated[id], "palette growth reset animation phase")
                end
                restore()
                assertGrid(view)
                assert(view.images == originalImages and view.imageCount == originalCount)
                assert(view:imageAt(0, 0) == originalImage)
                assert(view.animTick == tick and view.animStep == step)
                assert(present(view.sprite) == attached)

                view.sprite:remove()
                restore = zone:_commitTiles({{x = 0, y = 0, id = 25, collision = 0, terrain = entry.terrain}})
                restore()
                assert(not present(view.sprite), "rollback registered a detached tilemap sprite")
                assertGrid(view)
                view:dispose()
                view = nil
                assert(gfx.sprite.spriteCount() == count, "view disposal leaked display sprites")
            end
        end)
        if view then
            view:dispose()
        end
        assert(gfx.sprite.spriteCount() == count, "native tilemap rollback leaked display sprites")
        if not ok then
            error(problem, 0)
        end
    end)
    return report
end
