-- Native SDK witnesses. These deliberately require the composed imported maps,
-- registered Blue content and common lease APIs. No simulated SDK fallback.
CeruleanRoutesContracts = {}
local function eq(a,b) assert(a == b,"expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function find(g,id)
    for _, npc in ipairs(g.npcManager.npcs) do
        if npc.def and npc.def.source_event_id == id then return npc end
    end
end
local function fresh(starter)
    local g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    assert(g:recruit(Pokemon(starter or "squirtle",5)))
    local counters = {charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"}
    starter = starter or "squirtle"
    assert(g.session:setIntro({stage="done",starter=starter,rivalStarter=counters[starter]}))
    return g
end
function CeruleanRoutesContracts.withScene(name, options, fn)
    local oldZone, oldStory = currentZone, Story.currentContext()
    local owner, rng = GameSession.activeRNGSession(), RulesRNG.snapshot()
    local restoreTiles = WorldTiles:checkpointRuntime()
    local count = playdate.graphics.sprite.spriteCount()
    local g, zone
    local ok, problem = pcall(function()
        local entry = SourceMaps.entry(name)
        assert(entry.profile == "source", "actual imported Blue map required")
        g = fresh(options.starter)
        assert(CeruleanRoutes.initialize(g.session))
        for id, value in pairs(options.quest or {}) do assert(g.session:setQuestFlag(id,value)) end
        for id, value in pairs(options.trainers or {}) do assert(g.session:setTrainerDefeated(id,value)) end
        g.trainers = TrainerEvents(g)
        local profiles = SourceMaps.legacyProfiles({dispatch=function(id) return SourceEvents.dispatch(g,id) end,
            questFlag=function(id) return g.session:questFlag(id) end,
            sourceFlag=function(id) return g.trainers:sourceFlag(id) end})
        zone = SourceMaps.createZone(name,profiles.source,WorldTiles)
        currentZone = zone
        g.player = Player(options.x+entry.padding,options.y,zone.collision,g.npcManager)
        g.player.facing = options.facing or "up"
        g.player:updateSprite()
        local sub = StateMachine()
        sub:register("explore",{}); sub:change("explore")
        g.machine:register("overworld",{sub=sub})
        g.machine:register("event",CeruleanRoutesState(g))
        g.machine:register("dialog",DialogState(g))
        g.machine:change("overworld")
        zone:spawnNPCs(g.npcManager)
        g.npcManager.motion:attach(g,zone)
        assert(g.session:activateRNG())
        fn(g)
    end)
    if g then
        while g.machine:depth() > 0 do g.machine:pop() end
        g.npcManager:clear()
        if g.player then g.player:remove(); g.player.grassOverlay:remove(); g.player.exitArrow:remove() end
    end
    if zone then zone:disposeView() end
    restoreTiles()
    local active = GameSession.activeRNGSession()
    if active then active:deactivateRNG() end
    if owner then owner:activateRNG() end
    RulesRNG.restore(rng)
    currentZone = oldZone
    Story.bind(oldStory)
    assert(ok,problem)
    eq(playdate.graphics.sprite.spriteCount(),count)
end
local function drain(g)
    local generation = g.machine:get("dialog").generation
    for _=1,512 do
        if g.machine:get("dialog").generation ~= generation then return end
        if g.machine:getCurrent() ~= "dialog" then return end
        local dialog = g.machine:get("dialog")
        dialog.dialog:advance()
        dialog:handleInput()
    end
    error("source dialog did not settle")
end
local function ready(g,id)
    SourceEvents.dispatch(g,id)
    local event = g.machine:get("event")
    for _=1,512 do
        assert(event.phase ~= "failed",event.waiting)
        if g.machine:getCurrent() == "dialog" and event.trainerToken then
            -- Keep the real EventState lease and token; remove only this modal
            -- without firing its launch callback. The domain witness then owns
            -- the exact real battle and its terminal emission below.
            g.machine:pop()
            eq(g.trainers:snapshot().phase,"ready")
            return event,event.trainerToken
        end
        if g.machine:getCurrent() == "dialog" then drain(g) else g.machine:update() end
    end
    error("source trainer did not approach")
end
local function launch(g,event,token)
    local party = assert(g.trainers:launch(token))
    local npc = assert(find(g,event.id))
    local battle = Battle(g:getPlayerPokemon(),party:active(),npc.name,
        {party=g.session:party(),session=g.session,enemyParty=party})
    assert(g.trainers:attachBattle(token,battle))
    return party,battle
end
local function terminal(g,token,battle,party,won)
    local fainted = won and party or g.session:party()
    for _, mon in ipairs(fainted:members()) do mon:takeDamage(mon.maxHP) end
    local kind = won and "victory" or "defeat"
    battle:runScript(function() return kind end)
    local accepted,receipt
    battle:on("battleEnd",function(result,outcome)
        accepted,receipt = g.trainers:resolve(token,result,outcome)
    end)
    assert(battle:emitEnd())
    assert(accepted,receipt)
    return receipt
end
local function fill(session,except)
    local discard
    for id, definition in pairs(ItemData.definitions) do
        if not definition.keyItem and id ~= except and session:inventory():count() < Inventory.CAPACITY then
            assert(session:inventory():add(id,1)); discard = id
        end
    end
    eq(session:inventory():count(),Inventory.CAPACITY)
    return discard
end
local function roundTrip(g)
    local wire = assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
    return assert(SessionCodec.decode(wire,g:getSessionDependencies()))
end
function CeruleanRoutesContracts.run(withScene)
    withScene = withScene or CeruleanRoutesContracts.withScene
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,problem = pcall(fn)
        report.tests[#report.tests+1] = {name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1; report.ok=false end
    end
    for _, starter in ipairs({"charmander","squirtle","bulbasaur"}) do
        for _, name in ipairs({"route22","cerulean"}) do
            local selected, key = starter,name
            test(key .. " actual " .. selected .. " counter team uses token snapshot and fixed Blue IVs",function()
                local scene = CeruleanRoutes.scenes()
                local source = scene.rivals[key]
                local trigger = scene.triggers[key][1]
                withScene(key == "route22" and "Route22" or "CeruleanCity",
                    {starter=selected,x=trigger.x,y=trigger.y},function(g)
                    local definitions = CeruleanRoutes.trainers()
                    local expected = definitions[source.id].rival_parties[selected]
                    local before = RulesRNG.snapshot()
                    local d = g.trainers:definition(source.id)
                    d.party[1].level=100
                    eq(g.trainers:definition(source.id).party[1].level,expected.party[1].level)
                    eq(RulesRNG.snapshot().rolls,before.rolls)
                    local event,token = ready(g,source.id)
                    local enemies,battle = launch(g,event,token)
                    eq(enemies:count(),#expected.party)
                    for index,mon in ipairs(enemies:members()) do
                        eq(mon.species,expected.party[index].species)
                        eq(mon.level,expected.party[index].level)
                        local actual,blue = mon:individuals().ivs,IndividualStats.blueTrainer()
                        for stat,value in pairs(blue) do eq(actual[stat],value) end
                    end
                    local rolls = RulesRNG.snapshot().rolls
                    eq(g.trainers:launch(token),nil)
                    eq(RulesRNG.snapshot().rolls,rolls)
                    eq(g.trainers:resolve(token,true,"victory"),false)
                    local money = g.session:inventory():money()
                    local receipt = terminal(g,token,battle,enemies,true)
                    eq(receipt.payout,expected.payout)
                    eq(g.session:inventory():money(),money+expected.payout)
                    eq(g.session:trainerDefeated(source.id),true)
                    eq(g.session:questFlag(key == "route22" and "EVENT_BEAT_ROUTE22_RIVAL_1ST_BATTLE"
                        or "EVENT_BEAT_CERULEAN_RIVAL"),true)
                    eq(g.trainers:resolve(token,true,"victory"),false)
                    assert(g.trainers:peekReceipt(source.id))
                    SourceEvents.plan(source.id,EventState.observe(g,source.id))
                    assert(g.trainers:peekReceipt(source.id)) -- Read-only plans cannot consume it.
                    local restored = roundTrip(g)
                    eq(restored:trainerDefeated(source.id),true)
                    eq(restored:inventory():money(),money+expected.payout)
                    eq(g.trainers:prepare(find(g,source.id),"talk",event),nil)
                    battle:clearListeners()
                end)
            end)
        end
    end
    for _, name in ipairs({"route22","cerulean"}) do
        local key = name
        test(key .. " confirmed loss persists no reward and remains retryable",function()
            local scene = CeruleanRoutes.scenes()
            local id,point = scene.rivals[key].id,scene.triggers[key][2]
            withScene(key == "route22" and "Route22" or "CeruleanCity",{x=point.x,y=point.y},function(g)
                local event,token = ready(g,id)
                local enemies,battle = launch(g,event,token)
                local money = g.session:inventory():money()
                local receipt = terminal(g,token,battle,enemies,false)
                eq(receipt.payout,0); eq(g.session:inventory():money(),money)
                eq(g.session:trainerDefeated(id),false); eq(g.trainers:peekReceipt(id),nil)
                local restored = roundTrip(g)
                eq(restored:trainerDefeated(id),false)
                g.session:party():healAll()
                g.machine:pop()
                local retry = ready(g,id)
                assert(retry.trainerToken)
                battle:clearListeners()
            end)
        end)
    end
    test("native partial source path cancellation restores origin and rejects old lease",function()
        withScene("Route22",{x=29,y=4},function(g)
            local id = CeruleanRoutes.ROUTE
            local npc = assert(find(g,id))
            local x,y = npc.gridX,npc.gridY
            SourceEvents.dispatch(g,id)
            local event = g.machine:get("event")
            for _=1,41 do g.machine:update() end -- Notice, one complete cell and an interpolation.
            local lease = assert(event.npcLeases[id])
            local stale = event:guard(function() error("cancelled callback ran") end)
            g.machine:pop()
            stale()
            eq(npc.gridX,x); eq(npc.gridY,y); eq(npc.x,x*TILE_SIZE); eq(npc.isMoving,false)
            eq(g.npcManager.motion:startScriptStep(lease,"right"),false)
            eq(g.session:trainerDefeated(id),false)
            eq(g.trainers:snapshot().phase,"idle")
        end)
    end)
    test("Nugget full bag is atomic and a free slot retries one source gift",function()
        local g = fresh()
        local session = g.session
        local discard = fill(session,"nugget")
        local plan = assert(CeruleanRoutes.nuggetPlan(session))
        eq(session:transact(plan.expected,plan.changes),false)
        eq(session:questFlag("EVENT_GOT_NUGGET"),false)
        eq(session:inventory():quantity("nugget"),0)
        assert(session:inventory():consume(discard,1))
        assert(session:transact(plan.expected,plan.changes))
        eq(session:transact(plan.expected,plan.changes),false)
        eq(session:inventory():quantity("nugget"),1)
        eq(CeruleanRoutes.nuggetPlan(session),nil)
        local restored = roundTrip(g)
        eq(restored:questFlag("EVENT_GOT_NUGGET"),true)
        eq(restored:inventory():quantity("nugget"),1)
    end)
    test("full-bag source event backs off without a battle or payout",function()
        withScene("Route24",{x=10,y=15},function(g)
            local discard = fill(g.session,"nugget")
            local money = g.session:inventory():money()
            SourceEvents.dispatch(g,CeruleanRoutes.NUGGET)
            for _=1,512 do
                if g.machine:getCurrent() == "overworld" then break end
                if g.machine:getCurrent() == "dialog" then drain(g) else g.machine:update() end
            end
            eq(g.machine:getCurrent(),"overworld")
            eq(g.player.gridY,16)
            eq(g.session:questFlag("EVENT_GOT_NUGGET"),false)
            eq(g.session:trainerDefeated(CeruleanRoutes.NUGGET),false)
            eq(g.session:inventory():money(),money)
            eq(g.trainers:snapshot().phase,"idle")
            assert(g.session:inventory():consume(discard,1))
            g.player:tryMove(0,-1)
            for _=1,8 do g.player:update() end
            eq(g.player.gridY,15)
            eq(g.player.isMoving,false)
            local event,token = ready(g,CeruleanRoutes.NUGGET)
            eq(g.session:inventory():quantity("nugget"),1)
            local party,battle = launch(g,event,token)
            terminal(g,token,battle,party,true)
            eq(g.session:inventory():money(),money+450)
            eq(g.trainers:resolve(token,true,"victory"),false)
            eq(CeruleanRoutes.nuggetPlan(g.session),nil)
            eq(g.session:inventory():quantity("nugget"),1)
            battle:clearListeners()
        end)
    end)
    test("TM28 full-bag return waits for confirmed thief victory and cannot duplicate",function()
        withScene("CeruleanCity",{x=30,y=7,quest={EVENT_GOT_SS_TICKET=true}},function(g)
            local id = CeruleanRoutes.THIEF
            eq(g.trainers:rewardPlan(id),nil)
            local event,token = ready(g,id)
            local party,battle = launch(g,event,token)
            local receipt = terminal(g,token,battle,party,true)
            eq(receipt.payout,510)
            eq(g.session:questFlag("EVENT_BEAT_CERULEAN_ROCKET_THIEF"),true)
            local discard = fill(g.session,"tm28")
            local plan = assert(g.trainers:rewardPlan(id))
            eq(g.session:transact(plan.expected,plan.changes),false)
            eq(g.session:questFlag("TOGGLE_CERULEAN_ROCKET"),false)
            eq(g.session:inventory():quantity("tm28"),0)
            assert(g.session:inventory():consume(discard,1))
            assert(g.session:transact(plan.expected,plan.changes))
            eq(g.session:transact(plan.expected,plan.changes),false)
            eq(g.session:inventory():quantity("tm28"),1)
            eq(g.session:questFlag("EVENT_GOT_SS_TICKET"),true) -- No second Bill owner.
            local restored = roundTrip(g)
            eq(restored:questFlag("TOGGLE_CERULEAN_ROCKET"),true)
            eq(restored:inventory():quantity("tm28"),1)
            eq(g.trainers:rewardPlan(id),nil)
            battle:clearListeners()
        end)
    end)
    for _, won in ipairs({true,false}) do
        local victory = won
        test("Nugget gift precedes confirmed Rocket " .. (victory and "victory" or "loss") .. " exactly once",function()
            withScene("Route24",{x=10,y=15},function(g)
                local id = CeruleanRoutes.NUGGET
                local money = g.session:inventory():money()
                local event,token = ready(g,id)
                eq(g.session:inventory():quantity("nugget"),1)
                eq(g.session:questFlag("EVENT_GOT_NUGGET"),true)
                local party,battle = launch(g,event,token)
                local receipt = terminal(g,token,battle,party,victory)
                eq(receipt.payout,victory and 450 or 0)
                eq(g.session:inventory():money(),money+(victory and 450 or 0))
                eq(g.session:trainerDefeated(id),victory)
                eq(g.session:questFlag("EVENT_BEAT_ROUTE24_ROCKET"),victory)
                eq(g.trainers:resolve(token,victory,victory and "victory" or "defeat"),false)
                local restored = roundTrip(g)
                eq(restored:inventory():quantity("nugget"),1)
                eq(restored:trainerDefeated(id),victory)
                local observation = EventState.observe(g,id)
                local plan = SourceEvents.plan(id,observation)
                for _, step in ipairs(plan.steps) do assert(step.op ~= "trainer") end
                eq(CeruleanRoutes.nuggetPlan(g.session),nil)
                battle:clearListeners()
            end)
        end)
    end
    test("confirmed thief loss cannot grant TM28 or hide him",function()
        withScene("CeruleanCity",{x=30,y=9},function(g)
            local id = CeruleanRoutes.THIEF
            local event,token = ready(g,id)
            local party,battle = launch(g,event,token)
            local money = g.session:inventory():money()
            terminal(g,token,battle,party,false)
            eq(g.session:inventory():money(),money)
            eq(g.session:trainerDefeated(id),false)
            eq(g.session:questFlag("EVENT_BEAT_CERULEAN_ROCKET_THIEF"),false)
            eq(g.session:questFlag("TOGGLE_CERULEAN_ROCKET"),false)
            eq(g.trainers:rewardPlan(id),nil)
            eq(g.session:inventory():quantity("tm28"),0)
            battle:clearListeners()
        end)
    end)
    for _, key in ipairs({"route22","cerulean"}) do
        for index=1,2 do
            local name, branch = key,index
            test(name .. " branch " .. branch .. " confirmed receipt walks pinned departure without another payout",function()
                local scenes = CeruleanRoutes.scenes()
                local point,id = scenes.triggers[name][branch],scenes.rivals[name].id
                withScene(name == "route22" and "Route22" or "CeruleanCity",{x=point.x,y=point.y},function(g)
                    local event,token = ready(g,id)
                    local party,battle = launch(g,event,token)
                    terminal(g,token,battle,party,true)
                    local money = g.session:inventory():money()
                    g.machine:pop()
                    assert(g.trainers:peekReceipt(id))
                    SourceEvents.dispatch(g,id)
                    eq(g.trainers:peekReceipt(id),nil)
                    for _=1,1024 do
                        if g.machine:getCurrent() == "overworld" then break end
                        if g.machine:getCurrent() == "dialog" then drain(g) else g.machine:update() end
                        assert(g.machine:get("event").phase ~= "failed",g.machine:get("event").waiting)
                    end
                    eq(g.machine:getCurrent(),"overworld")
                    eq(find(g,id),nil)
                    eq(g.session:inventory():money(),money)
                    eq(g.trainers:snapshot().phase,"idle")
                    battle:clearListeners()
                end)
            end)
        end
    end
    test("Brock permanently closes optional first Route22 rival without a migration reroll",function()
        local g = fresh()
        assert(CeruleanRoutes.initialize(g.session))
        assert(g.session:setQuestFlag("BADGE_BOULDER",true))
        assert(g.session:setQuestFlag("EVENT_1ST_ROUTE22_RIVAL_BATTLE",false))
        assert(g.session:setQuestFlag("EVENT_ROUTE22_RIVAL_WANTS_BATTLE",false))
        assert(CeruleanRoutes.initialize(g.session))
        eq(g.session:questFlag("EVENT_ROUTE22_RIVAL_WANTS_BATTLE"),false)
    end)
    return report
end
