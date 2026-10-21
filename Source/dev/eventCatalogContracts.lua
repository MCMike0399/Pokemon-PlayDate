EventCatalogContracts={}
local function eq(a,b) assert(a==b,"expected "..tostring(b)..", got "..tostring(a)) end
function EventCatalogContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Event catalog export retains source identity phase and actual image ownership",function()
        local stand=SpriteFactory.npc.rival.down;local inventory=EventArt.catalogInventory();eq(#inventory,7)
        local ids={};for _,entry in ipairs(inventory) do assert(not ids[entry.source_id]);ids[entry.source_id]=true end
        local images=EventArt.catalogImages();eq(#images,7);local walk=EventArt.walking()
        eq(images[1].image,walk.down);eq(images[2].image,walk.up);eq(images[3].image,walk.left);eq(images[4].image,walk.right)
        for index,entry in ipairs(images) do
            local width,height=entry.image:getSize();eq(width,entry.width);eq(height,entry.height)
            eq(entry.phase_policy,index<=4 and "legacy-omitted" or "explicit-zero");assert(entry.image:getMaskImage())
        end
        eq(SpriteFactory.npc.rival.down,stand)
        inventory[1].source_id="tamper";assert(EventArt.catalogInventory()[1].source_id~="tamper")
    end)
    test("Comprehensive inventory lists exactly35 unreviewed event paths with masks and backgrounds",function()
        local inventory=VisualCatalog.additionInventory();local paths={};local count=0
        for _,entry in ipairs(inventory.images) do
            assert(not paths[entry.path]);paths[entry.path]=true
            if entry.path:sub(1,6)=="event_" then count=count+1 end
        end
        eq(count,35);eq(#inventory.event_art,7)
        for _,entry in ipairs(EventArt.catalogInventory()) do
            for _,suffix in ipairs({"","__mask","__white","__black","__texture"}) do assert(paths[entry.name..suffix..".png"]) end
        end
    end)
    return report
end
