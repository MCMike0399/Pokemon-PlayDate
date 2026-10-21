-- Production TrainerEvents on a native collision plane; no provider/world edits.
SpecimenTrainerContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function sameRNG(a) local b=RulesRNG.snapshot();for _,k in ipairs({"algorithm","seed","state","rolls"}) do eq(b[k],a[k],"RNG "..k) end end
local function actors(fn)
    local previous=currentZone;local game=GameContext();assert(game:recruit(Pokemon("squirtle",5)))
    assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    local id="pokered:VIRIDIAN_FOREST:objects:2";local def=PewterSlice.trainer(id);local tiles={}
    for y=1,8 do tiles[y]={};for x=1,13 do tiles[y][x]=25 end end
    currentZone=Zone({id=def.map_id,name="specimen trainer contract plane",tiles=tiles,width=13,height=8})
    game.player=Player(3,4,currentZone.collision,game.npcManager)
    local npc=NPC(4,4,def.name,{},nil,"rival","left");npc.def={source_event_id=id};game.npcManager:addNPC(npc)
    local owner=TrainerEvents(game);local token=assert(owner:prepare(npc,"talk"));assert(owner:updateApproach(token))
    local previousOwner,previousRNG=GameSession.activeRNGSession(),RulesRNG.snapshot()
    assert(game.session:activateRNG())
    local ok,why=pcall(fn,game,owner,token,id)
    local active=GameSession.activeRNGSession();if active then assert(active:deactivateRNG()) end
    if previousOwner then assert(previousOwner:activateRNG()) end
    RulesRNG.restore(previousRNG)
    game.npcManager:clear();game.player:remove();game.player.grassOverlay:remove();game.player.exitArrow:remove();currentZone=previous
    if not ok then error(why,0) end
end
function SpecimenTrainerContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local rng=RulesRNG.snapshot()
    local function test(name,fn) local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil};if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end end
    test("Actual source trainer creates both members through versioned normal factory",function()
        actors(function(game,owner,token,id)
            RulesRNG.seed(42);local player,bag=game.session:party(),game.session:inventory();local team=assert(owner:launch(token))
            eq(team:count(),2);eq(team:get(1).species,"weedle");eq(team:get(2).species,"caterpie")
            eq(team:get(1).abilitySlot,"second");eq(team:get(1).natureId,22);eq(team:get(2).abilitySlot,"first");eq(team:get(2).natureId,0)
            eq(RulesRNG.snapshot().rolls,6);eq(owner:snapshot().phase,"battle");eq(game.session:party(),player);eq(game.session:inventory(),bag)
            eq(game.session:trainerDefeated(id),false);assert(owner:abortBattle(token))
        end)
    end)
    test("Later trainer-member RNG exhaustion leaves global stream and ready encounter unchanged",function()
        actors(function(game,owner,token,id)
            local before=RulesRNG.new(42):snapshot();before.rolls=2147483644;RulesRNG.restore(before)
            local player=game.session:party():active();local hp,money=player.hp,game.session:inventory():money()
            local ok,why=pcall(owner.launch,owner,token);eq(ok,false);assert(tostring(why):find("exhausted",1,true),tostring(why))
            sameRNG(before);eq(owner:snapshot().phase,"ready");eq(game.session:party():active(),player);eq(player.hp,hp)
            eq(game.session:inventory():money(),money);eq(game.session:trainerDefeated(id),false)
            RulesRNG.seed(42);local team=assert(owner:launch(token));eq(team:count(),2);eq(RulesRNG.snapshot().rolls,6);assert(owner:abortBattle(token))
        end)
    end)
    test("Stale trainer session rejects before any team creation draws",function()
        actors(function(game,owner,token,id)
            local before=RulesRNG.snapshot();game.session=GameContext().session
            eq(owner:launch(token),nil);sameRNG(before);eq(game.session:trainerDefeated(id),false)
        end)
    end)
    test("Inactive or foreign trainer owner rejects with ready phase and no global draws",function()
        actors(function(game,owner,token,id)
            assert(game.session:deactivateRNG());local foreign=GameContext();assert(foreign.session:activateRNG())
            local before=RulesRNG.snapshot();local team,why=owner:launch(token)
            eq(team,nil);eq(why,"inactive-trainer-session");eq(owner:snapshot().phase,"ready");sameRNG(before)
            eq(game.session:trainerDefeated(id),false);eq(game.session:inventory():money(),3000)
        end)
    end)
    RulesRNG.restore(rng);return report
end
