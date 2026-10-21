RuntimeArtContracts={}
function RuntimeArtContracts.run()
    local tests={};local function test(name,fn)local ok,error=pcall(fn);tests[#tests+1]={name=name,ok=ok,error=not ok and tostring(error)or nil}end
    test("Comprehensive runtime art inventory includes all50 explicit unreviewed variants",function()
        local paths={};for _,item in ipairs(VisualCatalog.additionInventory().images)do paths[item.path]=true end
        local count=0;for name in pairs(CaptureAnimationData.assets)do
            for _,suffix in ipairs({"","__mask","__white","__black","__texture"})do assert(paths["capture_"..name..suffix..".png"]);count=count+1 end
        end
        for _,suffix in ipairs({"","__mask","__white","__black","__texture"})do assert(paths["jump_shadow"..suffix..".png"]);count=count+1 end
        assert(count==50)
    end)
    test("Actual Player jump uses the exact shared catalog shadow object",function()
        local old=currentZone;currentZone=assert(zoneRegistry.kanto_route1)
        local player=Player(4,4,currentZone.collision,NPCManager());player:setUpdatesEnabled(false)
        local ok,error=pcall(function()player:tryMove(0,1);assert(player.isJumping);assert(player.jumpShadow:getImage()==Player.getJumpShadowImage())end)
        player:remove();player.grassOverlay:remove();player.exitArrow:remove();currentZone=old;assert(ok,error)
    end)
    test("Compiled capture materialization raw and mask match actual native draw at every padded pixel",function()
        local gfx=playdate.graphics
        local function composite(image,color)
            local w,h=image:getSize();local target=gfx.image.new(w,h,color)
            gfx.pushContext(target);gfx.setDrawOffset(0,0);gfx.clearClipRect();gfx.clearStencil();gfx.setImageDrawMode(gfx.kDrawModeCopy)
            image:draw(0,0);gfx.popContext();return target
        end
        local checked,transparent=0,0
        for name,path in pairs(CaptureAnimationData.assets) do
            local original=assert(gfx.image.new(path));local width,height=original:getSize()
            gfx.pushContext();gfx.setDrawOffset(17,-13)
            local image=VisualCatalog.materializeCaptureImage(original)
            local x,y=gfx.getDrawOffset();gfx.popContext();assert(x==17 and y==-13,"materialization leaked draw offset")
            local w,h=image:getSize();assert(w==width and h==height,"logical image dimensions changed")
            local mask=assert(image:getMaskImage(),"capture transparency mask missing")
            local unmasked=image:copy();unmasked:removeMask()
            local white,black=composite(original,gfx.kColorWhite),composite(original,gfx.kColorBlack)
            for py=0,h-1 do for px=0,w-1 do
                local a,b=white:sample(px,py),black:sample(px,py)
                local opaque=a==b
                local expected=opaque and a or gfx.kColorClear
                assert(image:sample(px,py)==expected,name.." raw draw mismatch at "..px..","..py)
                assert(mask:sample(px,py)==(opaque and gfx.kColorWhite or gfx.kColorBlack),name.." mask draw mismatch at "..px..","..py)
                if not opaque then
                    transparent=transparent+1
                    assert(unmasked:sample(px,py)==gfx.kColorWhite,name.." invisible RGB must remain source white")
                end
            end end
            checked=checked+1
        end
        assert(checked==9 and transparent>0,"all nine assets and transparent padding must be tested")
    end)
    local passed=0;for _,row in ipairs(tests)do if row.ok then passed=passed+1 end end
    return {ok=passed==#tests,passed=passed,failed=#tests-passed,tests=tests}
end
