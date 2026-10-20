CatalogContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
function CatalogContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Stable artifact names are reversible byte keys and reject oversized identities",function()
        eq(VisualCatalog.stableName("a/b"),"612f62");eq(VisualCatalog.stableName("a_b"),"615f62")
        eq(pcall(VisualCatalog.stableName,string.rep("x",101)),false)
    end)
    test("Registry allocation order cannot change imported artifact identity",function()
        local a,b=TileRegistry(),TileRegistry();local rows={};for i=1,16 do rows[i]=string.rep("#",16) end
        local function entry(key) return {key=key,grid=rows,collision=1,terrain={land_passable=false}} end
        a:registerBatch({entry("catalog:test-a"),entry("catalog:test-b")})
        b:registerBatch({entry("catalog:test-b"),entry("catalog:test-a")})
        assert(a:id("catalog:test-a")~=b:id("catalog:test-a"))
        local old=zoneRegistry;zoneRegistry={a={registry=a},b={registry=b}}
        local ok,inventory=pcall(VisualCatalog.additionInventory);zoneRegistry=old;assert(ok,inventory)
        local wanted="tile_imported_"..VisualCatalog.stableName("catalog:test-a")..".png";local count=0
        for _,image in ipairs(inventory.images) do if image.path==wanted then count=count+1 end end
        eq(count,1)
    end)
    test("Pinned source NPC inventory includes every authored frame and explicit mask/composites",function()
        if not SliceSprites then return end
        local data=assert(json.decodeFile("data/viridianSlice/sprites.json"));local count=0
        local inventory=VisualCatalog.additionInventory();local paths={}
        for _,image in ipairs(inventory.images) do assert(not paths[image.path]);paths[image.path]=true end
        for name,entry in pairs(data.sprites) do for frame in pairs(entry.frames) do
            count=count+1;local prefix="npc_source_"..VisualCatalog.stableName(name).."_frame_"..frame
            for _,suffix in ipairs({"","__mask","__white","__black","__texture"}) do assert(paths[prefix..suffix..".png"]) end
        end end
        eq(count,46)
    end)
    return report
end
