WorldViewRollbackContracts={}
local function captureCoverage(view)
    local present, result = {}, {}
    for _, sprite in ipairs(playdate.graphics.sprite.getAllSprites()) do
        present[sprite] = true
    end
    for y = 1, view.zone.height do
        result[y] = {}
        for x = 1, view.zone.width do
            result[y][x] = present[view.walls[y][x]] == true
        end
    end
    return result
end

local function assertCoverage(view, expected, outside)
    for y = 1, view.zone.height do
        for x = 1, view.zone.width do
            local found = false
            local hits = playdate.graphics.sprite.querySpritesAtPoint((x - 0.5) * TILE_SIZE, (y - 0.5) * TILE_SIZE)
            for _, sprite in ipairs(hits) do
                if not outside[sprite] then
                    found = true
                end
            end
            assert(found == expected[y][x], "native wall coverage differs at " .. x .. "," .. y)
        end
    end
end

function WorldViewRollbackContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("native wall rollback preserves exact detached unchanged and replaced memberships",function()
        local gfx=playdate.graphics;local count=gfx.sprite.spriteCount();local view
        local function present(sprite)for _,s in ipairs(gfx.sprite.getAllSprites())do if s==sprite then return true end end;return false end
        local outside = {}
        for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
            outside[sprite] = true
        end
        local ok,problem=pcall(function()
            local zone=PewterWorld.isolated("PewterMart");view=WorldView(zone)
            local expected = captureCoverage(view)
            for y = 1, zone.height do
                for x = 1, zone.width do
                    assert(expected[y][x] == (zone.collision[y][x] == 1), "initial wall coverage differs from source")
                end
            end
            assertCoverage(view, expected, outside)
            local x,y,wall
            for row,values in ipairs(view.walls)do for column,s in pairs(values)do x,y,wall=column-1,row-1,s;break end;if wall then break end end
            assert(wall and present(wall));local original=view:tileAt(x,y);local originalImages=view.images;local originalImage=view:imageAt(x,y)
            expected[y+1][x+1] = false
            local restore = view:applyTiles({{x=x,y=y,id=2,collision=0}})
            assert(not present(wall))
            assertCoverage(view, expected, outside)
            restore()
            expected[y+1][x+1] = true
            assertCoverage(view, expected, outside)
            assert(present(wall) and view:tileAt(x,y)==original and view.walls[y+1][x+1]==wall
                and view.images==originalImages and view:imageAt(x,y)==originalImage)
            wall:setVisible(false)
            restore=view:applyTiles({{x=x,y=y,id=2,collision=0}});restore()
            assert(present(wall)and not wall:isVisible(),"visibility must not substitute for registration")
            wall:remove();local before=gfx.sprite.spriteCount()
            restore=view:applyTiles({{x=x,y=y,id=original,collision=1}});restore()
            assert(not present(wall)and gfx.sprite.spriteCount()==before,"no-op rollback resurrected detached native wall")
            restore=view:applyTiles({{x=x,y=y,id=2,collision=0}});restore()
            assert(not present(wall)and gfx.sprite.spriteCount()==before,"replaced-wall rollback resurrected detached native wall")
            view:dispose();view=WorldView(PewterWorld.isolated("PewterMart"),{attach=false})
            x,y,wall=nil,nil,nil
            for row,values in ipairs(view.walls)do for column,s in pairs(values)do x,y,wall=column-1,row-1,s;break end;if wall then break end end
            original=view:tileAt(x,y);assert(not present(wall))
            restore=view:applyTiles({{x=x,y=y,id=2,collision=0}});restore();assert(not present(wall))
            wall:add()
            expected = captureCoverage(view)
            expected[y+1][x+1] = false
            restore = view:applyTiles({{x=x,y=y,id=2,collision=0}})
            assertCoverage(view, expected, outside)
            restore()
            expected[y+1][x+1] = true
            assertCoverage(view, expected, outside)
            assert(present(wall)and view.walls[y+1][x+1]==wall,"detached-view policy must preserve manually registered prior wall")
        end)
        if view then view:dispose()end
        assert(gfx.sprite.spriteCount()==count,"native wall rollback leaked display sprites")
        if not ok then error(problem,0)end
    end)
    return report
end
