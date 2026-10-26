-- Actual shared provider + production actor/session/event owners. This is not a
-- substitute Zone, Lua interpreter, battle engine or motion owner.
VermilionStoryFixture = {}
function VermilionStoryFixture.withScene(name,options,fn)
    local oldZone,oldStory=currentZone,Story.currentContext()
    local oldOwner,oldRules=GameSession.activeRNGSession(),RulesRNG.snapshot()
    local oldWorld=WorldDeltas.export()
    local restoreRuntime=WorldDeltas.checkpointRuntime()
    local count=playdate.graphics.sprite.spriteCount()
    local drawX,drawY=playdate.graphics.getDrawOffset()
    local priorDefinitions={}
    for _,zone in pairs(zoneRegistry) do priorDefinitions[zone]=zone.npcDefs end
    local g
    local ok,problem=pcall(function()
        local entry=SourceMaps.entry(name) -- Absent maps fail, never skip.
        assert(entry.profile=="source","actual imported Vermilion map required")
        WorldDeltas.reset()
        g=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
        local starter=options.starter or "squirtle"
        local counter={charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"}
        assert(g:recruit(Pokemon(starter,5)))
        assert(g.session:setIntro({stage="done",starter=starter,rivalStarter=counter[starter]}))
        for id,value in pairs(options.quest or {}) do assert(g.session:setQuestFlag(id,value)) end
        for id,value in pairs(options.trainers or {}) do assert(g.session:setTrainerDefeated(id,value)) end
        g.trainers=TrainerEvents(g)
        Story.bind(g)
        assert(g.session:activateRNG())
        local sub=StateMachine();sub:register("explore",{});sub:change("explore")
        g.machine:register("overworld",{sub=sub})
        g.machine:register("event",VermilionStoryState(g))
        g.machine:register("dialog",DialogState(g))
        switchZone(entry.key)
        assert(WorldDeltas.definitionProvider():owns(currentZone),"provider-owned live zone required")
        SourceActors.refresh(g,currentZone)
        g.player=Player(options.x+entry.padding,options.y,currentZone.collision,g.npcManager)
        g.player.facing=options.facing or "up";g.player:updateSprite()
        g.machine:change("overworld")
        SourceEvents.worldHook("beforeSpawn",g,{})
        currentZone:spawnNPCs(g.npcManager)
        g.npcManager.motion:attach(g,currentZone)
        fn(g)
    end)
    local cleaned,cleanupProblem=pcall(function()
        if g then
            while g.machine:depth()>0 do g.machine:pop() end
            g.npcManager:clear()
            if g.player then g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove() end
        end
        WorldDeltas.apply(oldWorld)
        restoreRuntime()
        for zone,definitions in pairs(priorDefinitions) do zone.npcDefs=definitions end
        local owner=GameSession.activeRNGSession()
        if owner then owner:deactivateRNG() end
        if oldOwner then oldOwner:activateRNG() end
        RulesRNG.restore(oldRules)
        currentZone=oldZone;Story.bind(oldStory)
        playdate.graphics.setDrawOffset(drawX,drawY)
    end)
    assert(cleaned,cleanupProblem)
    assert(ok,problem)
    assert(playdate.graphics.sprite.spriteCount()==count,"Vermilion fixture leaked sprites")
end
