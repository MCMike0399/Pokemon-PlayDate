NPCMotionLegacyContracts={}
function NPCMotionLegacyContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem)or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("old1 trainer-home Continue chooses nearest pinned approach cell with no RNG or owner changes",function()
        local oldZone,oldStory=currentZone,Story.currentContext();local beforeRules=RulesRNG.toData()
        local sprites,ids=playdate.graphics.sprite.spriteCount(),WorldTiles:maxID();local g
        local ok,problem=pcall(function()
            g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()});assert(g:recruit(Pokemon("squirtle",5)))
            assert(g.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
            local location={zone_id="pokered:VIRIDIAN_FOREST",x=30,y=33,facing="left"}
            assert(g.session:captureTraversal({location=location,world=WorldDeltas.export()}))
            local wire=assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}));wire.worldMotion=nil
            g.session=assert(SessionCodec.decode(wire,g:getSessionDependencies()))
            local money=g.session:inventory():money();local flags=g.session:flags();local worldRng=g.session:worldRngData()
            currentZone=PewterWorld.isolated("ViridianForest");PewterSprites.installFor(PewterSlice.padded("ViridianForest"))
            g.player=Player(30,33,currentZone.collision,g.npcManager);g.player.facing="left";currentZone:spawnNPCs(g.npcManager)
            local motion=g.npcManager.motion;motion:attach(g,currentZone,g.session:actorData())
            local npc=g.npcManager.npcs[2];assert(npc.gridX==29 and npc.gridY==33,"nearest source approach ray cell must be29,33")
            assert(g.player.gridX==30 and g.player.gridY==33,"legacy migration must preserve saved player")
            local info=motion:migration();assert(info.kind=="legacy-empty-actor-record"and #info.placements==1)
            assert(info.placements[1].id=="pokered:VIRIDIAN_FOREST:objects:2")
            local d=SourceActors.describe(location.zone_id,WorldDeltas.export());local spec=d.actors[2]
            assert(spec.x==30 and spec.y==33 and spec.facing=="left"and d.canStep(spec,30,33,29,33),"pinned geometry/ray proof")
            assert(g.session:inventory():money()==money and next(g.session:flags().trainers)==next(flags.trainers))
            assert(g.session:worldRngData().rolls==worldRng.rolls and RulesRNG.toData().rolls==beforeRules.rolls)
            info.placements[1].x=99;assert(motion:migration().placements[1].x==29,"migration diagnostics defensive")
            local captured=motion:snapshot();assert(g.session:captureTraversal({location=location,world=WorldDeltas.export(),actors=captured}))
            local restored=assert(SessionCodec.decode(assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true})),g:getSessionDependencies()))
            motion:attach(g,currentZone,restored:actorData());assert(motion:migration()==nil and npc.gridX==29,"new full DTO must restore exactly without migration")
        end)
        if g then g.npcManager:clear();if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove()end end
        currentZone=oldZone;Story.bind(oldStory)
        assert(playdate.graphics.sprite.spriteCount()==sprites and WorldTiles:maxID()==ids,"legacy proof leaked resources")
        if not ok then error(problem,0)end
    end)
    test("full actor DTO overlap rejects rather than silently migrating",function()
        local world=WorldDeltas.export();local d=SourceActors.describe("pokered:VIRIDIAN_FOREST",world)
        local flags={quest={},trainers={}};local record=WorldMotionData.reconcile(nil,d,flags)
        local ok=pcall(WorldMotionData.normalize,record,d,{zone_id=d.zone_id,x=30,y=33,facing="up"},flags)
        assert(not ok,"full DTO overlap must fail closed")
    end)
    test("no legal legacy source-ray placement gives explicit reviewable diagnostic without random draw",function()
        local d=SourceActors.describe("pokered:VIRIDIAN_FOREST",WorldDeltas.export());local original=d.canStep
        d.canStep=function(spec,x,y,tx,ty)if spec.id=="pokered:VIRIDIAN_FOREST:objects:2"then return false end;return original(spec,x,y,tx,ty)end
        local before=RulesRNG.toData();local ok,problem=pcall(WorldMotionData.legacyInitial,d,{zone_id=d.zone_id,x=30,y=33,facing="up"},{quest={},trainers={}})
        assert(not ok and tostring(problem):find("legacy trainer overlap has no legal source-ray placement: pokered:VIRIDIAN_FOREST:objects:2",1,true))
        assert(RulesRNG.toData().rolls==before.rolls)
    end)
    return report
end
