-- Prepared for the real SDK and real production owners. Not run by this worker.
-- Requires root-api.patch imports/provider metadata and the scoped registration.
FieldMoveContracts = {}
local gfx <const> = playdate.graphics
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function same(a,b) assert(FieldMoves.same(a,b),"values differ") end
local function wire(g)
    return assert(SessionCodec.encode(g.session,{root="overworld",overworld="explore",settled=true}))
end
local function snapshot(g)
    return {wire=wire(g), world=WorldDeltas.export(), rng=RulesRNG.toData(), actors=g.npcManager.motion:snapshot()}
end
local function fillBag(bag)
    for id, definition in pairs(ItemData.definitions) do
        if #bag:toData().slots >= Inventory.CAPACITY then break end
        if not definition.keyItem and bag:quantity(id)==0 then assert(bag:add(id,1)) end
    end
    eq(#bag:toData().slots,Inventory.CAPACITY)
end
local function scene(fn)
    local oldRegistry,oldList,oldZone = zoneRegistry,zoneList,currentZone
    local oldStory,oldRNG,oldOwner = Story.currentContext(),RulesRNG.toData(),GameSession.activeRNGSession()
    local oldWorld = WorldDeltas.export()
    local count, ids = gfx.sprite.spriteCount(),WorldTiles:maxID()
    local ox,oy = gfx.getDrawOffset()
    local screen, sprites, sets = gfx.getWorkingImage():copy(),{},{}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite]={visible=sprite:isVisible(),enabled=sprite:updatesEnabled()}
    end
    for key,value in pairs(SpriteFactory.npc) do sets[key]=value end
    local g = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    local registry = TileRegistry()
    local provider = PewterWorld.createProvider(g,registry)
    zoneRegistry,zoneList = {},{}
    local oldProvider = WorldDeltas.definitionProvider()
    for _, key in ipairs(oldList) do
        local zone = oldRegistry[key]
        if not oldProvider or not oldProvider:owns(zone) then zoneRegistry[key]=zone;zoneList[#zoneList+1]=key end
    end
    local ok,problem = pcall(function()
        WorldDeltas._withDefinitionProvider(provider,function()
          WorldView.withIsolation(function()
            local mon = Pokemon("bulbasaur",5)
            assert(g:recruit(mon))
            assert(g.session:setIntro({stage="done",starter="bulbasaur",rivalStarter="charmander"}))
            local bag = g.session:inventory()
            assert(bag:add("hm01",1)); assert(bag:add("hm05",1))
            assert(Teaching.complete(assert(Teaching.prepare(g.session,mon,"hm01")),"learn"))
            assert(Teaching.complete(assert(Teaching.prepare(g.session,mon,"hm05")),"learn"))
            assert(g.session:setQuestFlag("BADGE_CASCADE",true))
            assert(g.session:setQuestFlag("BADGE_BOULDER",true))
            currentZone = provider:ensure(SourceMaps.entry("Route2").key)
            Story.bind(g)
            g.machine:register("overworld",OverworldState(g))
            g.machine:register("party",PartyState(g))
            g.machine:register("fieldMove",FieldMoveState(g))
            g.machine:register("bag",BagState(g))
            g.machine:register("learning",LearningState(g))
            g.machine:change("overworld",{entry={x=5,y=9,facing="down"}})
            assert(g.session:captureTraversal({location={zone_id=currentZone.stableID,x=5,y=9,facing="down"},
                world=WorldDeltas.export(),actors=g.npcManager.motion:snapshot()}))
            g.machine:push("party")
            local party = g.machine:get("party")
            party:actions()
            fn(g,mon,party,provider)
          end)
        end)
    end)
    if g then
        while #g.machine.stack > 0 do local state=table.remove(g.machine.stack);pcall(state.exit,state) end
        g.npcManager:clear()
        if g.player then
            g.player:remove();g.player.grassOverlay:remove();g.player.exitArrow:remove()
            if g.player.jumpShadow then g.player.jumpShadow:remove() end
        end
    end
    provider:disposeCache()
    zoneRegistry,zoneList,currentZone = oldRegistry,oldList,oldZone
    Story.bind(oldStory)
    WorldDeltas.apply(oldWorld)
    local owner = GameSession.activeRNGSession()
    if owner ~= oldOwner then
        if owner then owner:deactivateRNG() end
        if oldOwner then oldOwner:activateRNG() end
    end
    RulesRNG.restoreData(oldRNG)
    for _,sprite in ipairs(gfx.sprite.getAllSprites()) do if not sprites[sprite] then sprite:remove() end end
    local present = {}
    for _,sprite in ipairs(gfx.sprite.getAllSprites()) do present[sprite]=true end
    for sprite,state in pairs(sprites) do
        if not present[sprite] then sprite:add() end
        sprite:setVisible(state.visible);sprite:setUpdatesEnabled(state.enabled)
    end
    for key in pairs(SpriteFactory.npc) do if not sets[key] then SpriteFactory.npc[key]=nil end end
    for key,value in pairs(sets) do SpriteFactory.npc[key]=value end
    gfx.setDrawOffset(0,0);screen:draw(0,0);gfx.setDrawOffset(ox,oy)
    eq(gfx.sprite.spriteCount(),count);eq(WorldTiles:maxID(),ids)
    if not ok then error(problem,0) end
end
local function open(g,party,mon,key)
    assert(FieldMoveState.open(g,party,mon,key or "cut"))
    return g.machine:get("fieldMove")
end
function FieldMoveContracts.run()
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        Autopilot.resetControls()
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(problem) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("HM01/HM05 real teaching keeps full bag, machine owners and compatibility",function()
        scene(function(g,mon,party)
            local bag = g.session:inventory()
            eq(bag:quantity("hm01"),1);eq(bag:quantity("hm05"),1)
            fillBag(bag)
            local other = Pokemon("bulbasaur",25)
            assert(g:recruit(other))
            local before = snapshot(g)
            local cancelled = assert(Teaching.prepare(g.session,other,"hm01"))
            assert(Teaching.cancel(cancelled));same(snapshot(g),before)
            assert(Teaching.complete(assert(Teaching.prepare(g.session,other,"hm01")),"learn",1))
            assert(Teaching.complete(assert(Teaching.prepare(g.session,other,"hm05")),"learn",2))
            eq(bag:quantity("hm01"),1);eq(bag:quantity("hm05"),1)
            eq(bag:count(),Inventory.CAPACITY)
            eq(Teaching.prepare(g.session,mon,"hm01"),nil)
            eq(MachineData.compatibility.caterpie.hm01,nil)
            assert(MachineData.compatibility.bulbasaur.hm01)
            assert(MachineData.compatibility.bulbasaur.hm05)
            local known = FieldMoves.known(mon);eq(#known,2)
        end)
    end)
    test("Full bag native machine teaching decline and replacement preserve reusable HMs",function()
        scene(function(g,mon,party)
            local other=Pokemon("bulbasaur",25);assert(g:recruit(other))
            fillBag(g.session:inventory())
            g.machine:pop();g.machine:push("bag")
            local bag,learning=g.machine:get("bag"),g.machine:get("learning")
            local before=snapshot(g)
            assert(bag:useMachine("hm01",2));eq(learning.phase,"ask")
            local retained=learning.menu.onSelect
            retained(2);eq(learning.phase,"stop");learning.menu.onSelect(1)
            eq(learning.messageKind,"declined");same(snapshot(g),before)
            g.machine:pop();retained(1);same(snapshot(g),before)
            assert(bag:useMachine("hm05",2));eq(learning.phase,"ask")
            learning.menu.onSelect(1);eq(learning.phase,"replace")
            learning.menu.onSelect(1);eq(learning.phase,"confirm")
            learning.menu.onSelect(1);eq(learning.messageKind,"learned")
            assert(other:hasMove("flash"))
            eq(g.session:inventory():quantity("hm01"),1)
            eq(g.session:inventory():quantity("hm05"),1)
            eq(g.session:inventory():count(),Inventory.CAPACITY)
        end)
    end)
    test("Full bag native confirmation cancel and retained callback have no effects",function()
        scene(function(g,mon,party)
            fillBag(g.session:inventory())
            local before = snapshot(g)
            local state = open(g,party,mon)
            local callback = state.menu.onSelect
            callback(1)
            eq(g.machine:current(),party)
            eq(callback(2),false)
            same(snapshot(g),before)
            eq(currentZone.collision[11][6],1)
        end)
    end)
    test("Cut requires Cascade and actual owned move, Boulder grants no Cut",function()
        scene(function(g,mon,party)
            assert(g.session:setQuestFlag("BADGE_CASCADE",false))
            local before = snapshot(g)
            local token,why = FieldMoves.prepare(g,party,mon,"cut")
            eq(token,nil);eq(why,"badge-required");same(snapshot(g),before)
            assert(g.session:setQuestFlag("BADGE_CASCADE",true))
            eq(FieldMoves.prepare(g,party,Pokemon("bulbasaur",5),"cut"),nil)
            local second = Pokemon("pidgey",5);assert(g:recruit(second))
            eq(FieldMoves.prepare(g,party,second,"cut"),nil)
        end)
    end)
    test("Source position, facing and terrain must match; protected Pallet is ineligible",function()
        scene(function(g,mon,party)
            g.player.facing="up";eq(FieldMoves.prepare(g,party,mon,"cut"),nil)
            g.player.facing="down"
            local old = currentZone;currentZone=zoneRegistry.pallet_town
            eq(FieldMoves.prepare(g,party,mon,"cut"),nil);currentZone=old
            g.player.isMoving=true;eq(FieldMoves.prepare(g,party,mon,"cut"),nil);g.player.isMoving=false
            g.player.pendingConnection={};eq(FieldMoves.prepare(g,party,mon,"cut"),nil);g.player.pendingConnection=nil
        end)
    end)
    test("Party switching, PP/context changes and forced overlay exit stale requests",function()
        scene(function(g,mon,party)
            assert(g:recruit(Pokemon("pidgey",5)))
            local state=open(g,party,mon);local token=state.token
            assert(g.session:party():swap(1,2))
            eq(FieldMoves.complete(token,state),false)
            g.machine:pop();party:update();party.selected=2;party:actions()
            state=open(g,party,mon);token=state.token
            mon.pp.cut=mon.pp.cut-1;eq(FieldMoves.complete(token,state),false)
            g.machine:pop();eq(FieldMoves.complete(token,state),false)
        end)
    end)
    test("Eight frames commit source block through real Zone/WorldDeltas/Session; no PP or item charge",function()
        scene(function(g,mon,party)
            mon.hp=0;mon.pp.cut=0 -- Original field permissions, independent of battle usability.
            local before = snapshot(g)
            local state = open(g,party,mon)
            state.menu.onSelect(2)
            Autopilot.step({"press","a"},g);state:handleInput();Autopilot.resetControls()
            eq(state.phase,"effect");eq(state.frame,0)
            for _=1,7 do state:draw();state:update();same(snapshot(g),before) end
            state:draw();state:update()
            assert(state.lastResult.ok,state.lastResult.reason)
            eq(g.machine:getCurrent(),"overworld")
            eq(currentZone.collision[11][6],0)
            eq(currentZone:terrainAt(5,10).land_passable,true)
            same(g.session:worldData(),WorldDeltas.export())
            same(g.session:inventory():toData(),before.wire.inventory)
            eq(mon.hp,0);eq(mon.pp.cut,0);same(RulesRNG.toData(),before.rng)
        end)
    end)
    test("Native view rejection rolls back collision registry ledger and session",function()
        scene(function(g,mon,party)
            local view=getOverworldView();local original=view.applyTiles
            local before=snapshot(g);local token=assert(FieldMoves.prepare(g,party,mon,"cut"))
            view.applyTiles=function() error("field-cut-native-view-rejection") end
            local called, accepted, reason = pcall(FieldMoves.complete,token)
            view.applyTiles=original
            assert(called);eq(accepted,false);assert(tostring(reason):find("field-cut-native-view-rejection",1,true))
            same(snapshot(g),before);eq(currentZone.collision[11][6],1)
        end)
    end)
    test("NPC reservation at changed source endpoint refuses Cut",function()
        scene(function(g,mon,party)
            local blocker={gridX=5,gridY=10}
            g.npcManager.npcs[#g.npcManager.npcs+1]=blocker
            local token,why=FieldMoves.prepare(g,party,mon,"cut")
            table.remove(g.npcManager.npcs)
            eq(token,nil);eq(why,"occupied-target")
        end)
    end)
    test("SaveCodec preserves actual cut delta; source reload removes only exact Cut block",function()
        scene(function(g,mon,party,provider)
            assert(FieldMoves.complete(assert(FieldMoves.prepare(g,party,mon,"cut"))))
            local payload=wire(g)
            local restored=assert(SessionCodec.decode(json.decode(json.encode(payload)),g:getSessionDependencies()))
            same(restored:worldData(),g.session:worldData())
            local reset=FieldMoves.reloadWorld(restored:worldData(),currentZone.stableID,0)
            assert(not FieldMoves.same(reset,restored:worldData()))
            WorldDeltas.apply(reset)
            eq(currentZone.collision[11][6],1)
            assert(restored:captureTraversal({world=reset,location=restored:location(),actors=restored:actorData()}))
            same(restored:worldData(),reset)
            WorldDeltas.reset();eq(currentZone.collision[11][6],1)
        end)
    end)
    test("Reload preserves the player on the exact restored source tree endpoint",function()
        scene(function(g,mon,party)
            assert(FieldMoves.complete(assert(FieldMoves.prepare(g,party,mon,"cut"))))
            local endpoint={zone_id=currentZone.stableID,x=5,y=10,facing="down"}
            assert(g.session:captureTraversal({world=WorldDeltas.export(),location=endpoint,actors=g.npcManager.motion:snapshot()}))
            local reset=FieldMoves.reloadWorld(g.session:worldData(),currentZone.stableID,0)
            local accepted=g.session:captureTraversal({world=reset,location=endpoint,actors=g.npcManager.motion:snapshot()})
            eq(accepted,true)
            same(g.session:worldData(),reset)
            same(g.session:location(),endpoint)
            -- The player-only resolver retains source position while normal
            -- collision and strict checkpoint/actor validation remain intact.
            eq(g.session:location().x,5);eq(g.session:location().y,10)
        end)
    end)
    test("Session validation rejection after native application rolls terrain and ledger back",function()
        scene(function(g,mon,party)
            local token=assert(FieldMoves.prepare(g,party,mon,"cut"))
            local before=snapshot(g)
            local deps=GameSession._state(g.session).deps
            local original=deps.validateActors
            deps.validateActors=function() error("field-cut-session-rejection") end
            local called,accepted,why=pcall(FieldMoves.complete,token)
            deps.validateActors=original
            assert(called);eq(accepted,false)
            assert(tostring(why):find("field-cut-session-rejection",1,true))
            same(snapshot(g),before);eq(currentZone.collision[11][6],1)
        end)
    end)
    test("Darkness input requires the pinned source map, offset and owner epoch",function()
        local input={zone_id="pokered:ROCK_TUNNEL_1F",source_revision=FieldMoves.data().source_revision,offset=6,epoch=1}
        assert(FieldMoves.validDarknessInput(input.zone_id,input))
        eq(FieldMoves.validDarknessInput("pokered:ROUTE_2",input),false)
        input.offset=0;eq(FieldMoves.validDarknessInput(input.zone_id,input),false)
        input.offset=6;input.epoch=nil;eq(FieldMoves.validDarknessInput(input.zone_id,input),false)
    end)
    test("New Game/installed replacement session cannot redeem earlier field intent",function()
        scene(function(g,mon,party)
            local token=assert(FieldMoves.prepare(g,party,mon,"cut"))
            local original=g.session
            local fresh=GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
            g.session=fresh.session
            eq(FieldMoves.complete(token),false)
            eq(fresh.session:worldData().zone_count,0)
            g.session=original;FieldMoves.cancel(token)
        end)
    end)
    test("Flash has original Boulder permission, no meaningful light use, no invented darkness owner",function()
        scene(function(g,mon,party)
            local before=snapshot(g)
            local token,why=FieldMoves.prepare(g,party,mon,"flash")
            eq(token,nil);eq(why,"darkness-not-installed");same(snapshot(g),before)
            assert(g.session:setQuestFlag("BADGE_BOULDER",false))
            token,why=FieldMoves.prepare(g,party,mon,"flash")
            eq(token,nil);eq(why,"badge-required")
        end)
    end)
    test("Battle HM data fails loudly under actual MoveSupport, never silent success",function()
        for _, key in ipairs({"cut","flash"}) do
            local a,b=Pokemon("bulbasaur",5),Pokemon("rattata",5)
            local battle=Battle(a,b)
            for _=1,30 do
                if battle:phase()~="script" then break end
                battle.machine:get("script"):advance()
            end
            battle:setDirection("player")
            local hp,acc=b.hp,b.statStages.acc
            local lines={}
            battle:runScript(function() battle:performMove(moveData[key]) end)
            for _=1,30 do
                if battle:phase()~="script" then break end
                lines[#lines+1]=battle.message;battle.machine:get("script"):advance()
            end
            assert(table.concat(lines,"|"):find("But it failed!",1,true))
            eq(b.hp,hp);eq(b.statStages.acc,acc)
        end
    end)
    return report
end
