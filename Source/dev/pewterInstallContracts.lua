PewterInstallContracts={}
function PewterInstallContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local oldRegistry,oldList,oldZone=zoneRegistry,zoneList,currentZone
    local oldProvider=WorldDeltas.definitionProvider();local oldWorld=WorldDeltas.export()
    local oldStory,oldOwner,oldRng=Story.currentContext(),GameSession.activeRNGSession(),RulesRNG.toData()
    local globalIDs=WorldTiles:maxID();local sprites=playdate.graphics.sprite.spriteCount()
    local game,provider,view
    local ok,problem=pcall(function()
        game=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        assert(game:recruit(Pokemon("squirtle",5)));assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
        local previous=game.session;local registry=TileRegistry();provider=PewterWorld.createProvider(game,registry)
        zoneRegistry,zoneList={},{}
        for _,key in ipairs(oldList)do local zone=oldRegistry[key]
            if not oldProvider or not oldProvider:owns(zone)then zoneRegistry[key]=zone;zoneList[#zoneList+1]=key end
        end
        currentZone=oldZone
        WorldDeltas._withDefinitionProvider(provider,function()
            local flags=game.session:flags();local ids=registry:maxID();local owner=GameSession.activeRNGSession();local rng=RulesRNG.toData()
            local packet=assert(SessionCodec.encode(previous,{root="overworld",overworld="explore",settled=true}))
            packet.location={zone_id="pokered:ROUTE_2",x=8,y=71,facing="up"}
            packet.world.zones[#packet.world.zones+1]={schema=1,zone_id="pokered:ROUTE_2",definition_revision="af519899719f0754965776faac0e836a3b906e6d",tile_count=1,tiles={{x=8,y=70,key="adapter:pewter:void"}}}
            packet.world.zone_count=#packet.world.zones
            local candidate=assert(SessionCodec.decode(packet,game:getSessionDependencies()))
            assert(registry:maxID()==ids and #provider:snapshot().cached==0,"decode must not allocate native maps")
            game.machine:register("overworld",{enter=function()
                assert(currentZone.stableID=="pokered:ROUTE_2","target must materialize before controller entry")
                assert(currentZone.collision[71][9]==1,"candidate sparse delta must precede view")
                view=WorldView(currentZone,{attach=false})
                error("controlled native controller entry rejection")
            end,exit=function()if view then view:dispose()end end})
            local installed,reason=game:installSession(candidate)
            assert(not installed and reason:find("controlled native controller entry rejection",1,true),"real install must reject controller fault")
            assert(game.session==previous and currentZone==oldZone,"session and location owners must roll back")
            assert(registry:maxID()==ids and zoneRegistry.kanto_route2==nil and #provider:snapshot().cached==0,"rollback must remove new native IDs and Zone")
            assert(provider:export().zone_count==0,"rollback must remove candidate sparse ledger")
            assert(view and view.disposed,"rollback must dispose partially constructed native view")
            assert(GameSession.activeRNGSession()==owner,"RNG ownership changed after failure")
            local after=RulesRNG.toData();assert(after.seed==rng.seed and after.state==rng.state and after.rolls==rng.rolls,"RNG state changed after failure")
            assert(game.session:flags().quest.BADGE_BOULDER==flags.quest.BADGE_BOULDER,"quest owner changed")
        end)
    end)
    if view then view:dispose()end
    if game then game.npcManager:clear()end
    if provider then provider:disposeCache()end
    if game and GameSession.activeRNGSession()==game.session then game.session:deactivateRNG()end
    if oldOwner then oldOwner:activateRNG()else RulesRNG.restoreData(oldRng)end
    zoneRegistry,zoneList,currentZone=oldRegistry,oldList,oldZone;Story.bind(oldStory);WorldDeltas.apply(oldWorld)
    if WorldTiles:maxID()~=globalIDs or playdate.graphics.sprite.spriteCount()~=sprites then ok=false;problem="install contract leaked global native resources"end
    report.tests[1]={name="actual GameContext install controller failure rolls back native cache IDs session RNG and sparse ledger",ok=ok,error=not ok and tostring(problem)or nil}
    report.ok=ok;report.passed=ok and 1 or 0;report.failed=ok and 0 or 1
    return report
end
