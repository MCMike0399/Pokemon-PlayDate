EvolutionContracts={}
local gfx <const> = playdate.graphics
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function same(a,b,path)
    path=path or "record";eq(type(a),type(b),path.." type")
    if type(a)~="table" then eq(a,b,path);return end
    for k,v in pairs(a) do same(v,b[k],path.."."..tostring(k)) end
    for k in pairs(b) do assert(a[k]~=nil,path.." unexpected "..tostring(k)) end
end
local function gameWith(mon)
    local game=GameContext();assert(game:recruit(mon))
    local counters={bulbasaur="charmander",charmander="squirtle",squirtle="bulbasaur"}
    local starter=counters[mon.species] and mon.species or "charmander"
    if not counters[mon.species] then
        -- Real fixture acquisition history, with the original starter retained
        -- as a second owned member. No raw dex or collection mutation.
        assert(game:recruit(Pokemon(starter,5)))
    end
    assert(game.session:setIntro({stage="done",starter=starter,rivalStarter=counters[starter],rivalOutcome=true}))
    assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
    return game
end
local function discardMoves(mon)
    while #mon:getPendingMoveChoices()>0 do mon:resolveMoveChoice(mon:getPendingMoveChoices()[1].id,"decline") end
end
local function leveled(species,from,to)
    local mon=Pokemon(species,from);local game=gameWith(mon)
    mon:gainXP(mon:xpForLevel(to)-mon.xp);return game,mon
end
local function pendingGame(species,from,to)
    local game,mon=leveled(species or "abra",from or 15,to or 16);discardMoves(mon);return game,mon
end
local function ui(game)
    game.machine:register("overworld",State("overworld"))
    game.machine:register("learning",LearningState(game));game.machine:register("evolution",EvolutionState(game))
    game.machine:change("overworld")
    return game.machine:get("evolution")
end
local function beginAnimation(state)
    assert(state.dialog.onComplete,"missing production intro callback");state.dialog.onComplete();eq(state.sub:getCurrent(),"animate")
end
local function runAnimation(game)
    for _=1,120 do game.machine:update() end
end
local function record(mon) return assert(PokemonCodec.encode(mon)) end
function EvolutionContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local rng=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Pinned original graph has52level16stone4trade edges, same growth and real art",function()
        local count,methods={level=0,stone=0,trade=0},0
        for species,rules in pairs(EvolutionData.rules) do
            methods=methods+1;assert(pokemonData[species],species)
            for _,rule in ipairs(rules) do
                count[rule.trigger]=count[rule.trigger]+1;assert(pokemonData[rule.to].dex<=151)
                eq(xpForLevel(100,species),xpForLevel(100,rule.to),"growth family "..species)
                assert(gfx.image.new(PokemonArt.path(rule.to,"front")),"missing original art "..rule.to)
            end
        end
        eq(methods,151);eq(count.level,52);eq(count.stone,16);eq(count.trade,4)
        eq(EvolutionData.rules.bulbasaur[1].minimum,16);eq(EvolutionData.rules.kadabra[1].to,"alakazam")
        eq(#EvolutionData.rules.golbat,0);eq(#EvolutionData.rules.onix,0);eq(#EvolutionData.rules.eevee,3)
    end)
    test("All52 level rules transform same owned identities only after actual level events",function()
        for species,rules in pairs(EvolutionData.rules) do
            for _,rule in ipairs(rules) do if rule.trigger=="level" then
                local game,mon=pendingGame(species,rule.minimum-1,rule.minimum);local identity,owner=mon,game.session:party()
                local xp,pp,bag=mon.xp,Party._primitive(mon.pp),game.session:inventory()
                local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(Evolution.complete(request))
                eq(game.session:party():get(1),identity,species.." identity");eq(Party._owner(mon),owner)
                eq(mon.species,rule.to);eq(mon.type,pokemonData[rule.to].type);eq(mon.type2,pokemonData[rule.to].type2);eq(mon.xp,xp);same(mon.pp,pp);eq(game.session:inventory(),bag)
                eq(game.session:pokedex().owned[species],true);eq(game.session:pokedex().owned[rule.to],true)
                local seen={};for _,choice in ipairs(mon:getPendingMoveChoices()) do assert(not seen[choice.move]);seen[choice.move]=true;eq(choice.reason,"evolution") end
                assert(PokemonCodec.validate(record(mon)))
            end end
        end
    end)
    test("All16 original stone rules consume one with no replacement identity",function()
        for species,rules in pairs(EvolutionData.rules) do for _,rule in ipairs(rules) do if rule.trigger=="stone" then
            local mon=Pokemon(species,5);local game=gameWith(mon);local bag=game.session:inventory();assert(bag:add(rule.item,2))
            local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item=rule.item}));assert(Evolution.complete(request))
            eq(mon.species,rule.to);eq(game.session:party():get(1),mon);eq(game.session:inventory(),bag);eq(bag:quantity(rule.item),1)
        end end end
    end)
    test("Constructor high levels and level100 do not infer historical evolution",function()
        local mon=Pokemon("caterpie",100);local game=gameWith(mon);eq(mon.pendingEvolution,nil)
        local request,why=Evolution.prepare(game.session,mon,{kind="level"});eq(request,nil);eq(why,"no-level-event")
        eq(mon:gainXP(2147483647),false);eq(mon.pendingEvolution,nil)
    end)
    test("Multi-level gain creates one final-level event and cannot chain a second evolution",function()
        local game,mon=pendingGame("caterpie",5,10);eq(mon.pendingEvolution.level,10)
        local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(Evolution.complete(request))
        eq(mon.species,"metapod");eq(mon.pendingEvolution,nil)
        local again,why=Evolution.prepare(game.session,mon,{kind="level"});eq(again,nil);eq(why,"no-level-event")
    end)
    test("Old-species level learning resolves before evolution; learned move and PP survive",function()
        local game,mon=leveled("charmander",15,16);local choices=mon:getPendingMoveChoices();eq(#choices,1);eq(choices[1].move,"dragonRage")
        local request,why=Evolution.prepare(game.session,mon,{kind="level"});eq(request,nil);eq(why,"learning-pending")
        mon:resolveMoveChoice(choices[1].id,"learn",2);mon.pp.dragonRage=3
        request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(Evolution.complete(request))
        eq(mon.species,"charmeleon");eq(mon.moves[2],"dragonRage");eq(mon.pp.dragonRage,3);eq(#mon:getPendingMoveChoices(),0)
    end)
    test("Abra16 becomes Kadabra and queues exactly current-level Confusion, never Kinesis1",function()
        local game,mon=pendingGame();mon.pp.teleport=0
        assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="level"}))))
        local choices=mon:getPendingMoveChoices();eq(#choices,1);eq(choices[1].move,"confusion");eq(choices[1].level,16);eq(choices[1].reason,"evolution");eq(mon.pp.teleport,0)
        mon:resolveMoveChoice(choices[1].id,"learn");eq(mon.pp.confusion,moveData.confusion.maxPP);eq(mon:hasMove("kinesis"),false)
    end)
    test("Level cancellation consumes only that event; a later level can retry",function()
        local game,mon=pendingGame();local before=record(mon);before.pendingEvolution=nil
        local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(Evolution.cancel(request));same(record(mon),before)
        eq(Evolution.complete(request),false);eq(Evolution.prepare(game.session,mon,{kind="level"}),nil)
        mon:gainXP(mon:xpForLevel(17)-mon.xp);discardMoves(mon)
        assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="level"}))));eq(mon.species,"kadabra")
        eq(#mon:getPendingMoveChoices(),0,"late evolution does not backfill Confusion16")
    end)
    test("Stone cannot be B-cancelled; force abort consumes nothing and stale completion fails",function()
        local mon=Pokemon("eevee",5);local game=gameWith(mon);local bag=game.session:inventory();assert(bag:add("waterStone",1));local before=record(mon)
        local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}))
        local ok,why=Evolution.cancel(request);eq(ok,false);eq(why,"cannot-cancel");same(record(mon),before);eq(bag:quantity("waterStone"),1)
        assert(Evolution.abort(request));eq(Evolution.complete(request),false);eq(bag:quantity("waterStone"),1);same(record(mon),before)
    end)
    test("Wrong stone target, unknown stone, foreign owner and missing stock reject unchanged",function()
        local mon=Pokemon("squirtle",5);local game=gameWith(mon);assert(game.session:inventory():add("fireStone",1));local before=record(mon);local bag=game.session:inventory():toData()
        for _,trigger in ipairs({{kind="stone",item="fireStone"},{kind="stone",item="linkCable"},{kind="level",item="fireStone"},{kind="unknown"}}) do eq(Evolution.prepare(game.session,mon,trigger),nil) end
        local other=GameContext();eq(Evolution.prepare(other.session,mon,{kind="stone",item="waterStone"}),nil)
        same(record(mon),before);same(game.session:inventory():toData(),bag)
        local eevee=Pokemon("eevee",5);assert(game:recruit(eevee));local request,why=Evolution.prepare(game.session,eevee,{kind="stone",item="waterStone"});eq(request,nil);eq(why,"insufficient-items")
    end)
    test("Stone completion replans current bag and succeeds once after party reorder",function()
        local mon=Pokemon("eevee",5);local game=gameWith(mon);local reserve=assert(game.session:party():get(2));local party=game.session:party();local bag=game.session:inventory()
        assert(bag:add("waterStone",1));local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}))
        assert(party:swap(1,2));assert(bag:add("potion",2));assert(bag:credit(50));local money=bag:money()
        assert(Evolution.complete(request));eq(party:get(2),mon);eq(party:get(1),reserve);eq(mon.species,"vaporeon");eq(bag:quantity("potion"),2);eq(bag:money(),money);eq(bag:quantity("waterStone"),0)
        eq(Evolution.complete(request),false);eq(bag:quantity("potion"),2)
    end)
    test("Missing stone at completion and foreign session commit are transactional",function()
        local mon=Pokemon("eevee",5);local game=gameWith(mon);local bag=game.session:inventory();assert(bag:add("waterStone",1));local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}));local before=record(mon)
        eq(GameContext().session:evolvePokemon(request),false);same(record(mon),before)
        assert(bag:consume("waterStone",1));eq(Evolution.complete(request),false);same(record(mon),before);eq(game.session:pokedex().owned.vaporeon,nil)
    end)
    test("Choice counter MAX rejects stone before any mon bag or dex mutation",function()
        local mon=Pokemon("poliwhirl",32);mon.nextMoveChoiceId=2147483647;local game=gameWith(mon);local bag=game.session:inventory();assert(bag:add("waterStone",1));local before=record(mon)
        local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}));local ok,why=Evolution.complete(request);eq(ok,false);eq(why,"move-choice-id-exhausted")
        same(record(mon),before);eq(bag:quantity("waterStone"),1);eq(game.session:pokedex().owned.poliwrath,nil)
    end)
    test("Same-owned evolution replaces stale derived type pair including target nil field",function()
        local mon=Pokemon("eevee",5);local game=gameWith(mon)
        -- Controlled derived-field residue; durable species/record remains Eevee.
        mon.type,mon.type2="ghost","poison"
        assert(game.session:inventory():add("waterStone",1))
        assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}))))
        eq(mon.type,"water");eq(mon.type2,nil);eq(mon.status,nil);eq(game.session:party():get(1),mon)
    end)
    test("Nickname/default, injured HP delta, sleep and chosen PP are preserved",function()
        for _,custom in ipairs({false,true}) do
            local game,mon=pendingGame();mon.name=custom and "SPOON" or "ABRA";mon.hp=1;mon.status,mon.statusTurns,mon.sleepDuration="sleep",2,3;mon.pp.teleport=0
            eq(mon.maxHP,34);local xp=mon.xp;assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="level"}))))
            eq(mon.maxHP,38);eq(mon.hp,5);eq(mon.name,custom and "SPOON" or "KADABRA");eq(mon.xp,xp);eq(mon.status,"sleep");eq(mon.statusTurns,2);eq(mon.sleepDuration,3);eq(mon.pp.teleport,0)
        end
    end)
    test("Stone on fainted target preserves0 HP and bad poison; full HP gains exact delta",function()
        for _,fainted in ipairs({false,true}) do
            local mon=Pokemon("eevee",5);eq(mon.maxHP,20);if fainted then mon.hp=0 end;mon.status="badPoison";mon.pp.tackle=0
            local game=gameWith(mon);assert(game.session:inventory():add("waterStone",1));assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}))))
            eq(mon.maxHP,28);eq(mon.hp,fainted and 0 or 28);eq(mon.status,"badPoison");eq(mon.pp.tackle,0)
        end
    end)
    test("Codec5 supports exact legacy3 names XP sleep PP and no inferred pending event",function()
        local mon=Pokemon("abra",16);mon.name="OLD NAME";mon.status,mon.statusTurns,mon.sleepDuration="sleep",1,3;mon.pp.teleport=2;mon.nextMoveChoiceId=2147483647
        local legacy=record(mon);legacy.version=3;legacy.natureId,legacy.abilitySlot,legacy.heldItem=nil,nil,nil;local restored=assert(PokemonCodec.decode(legacy));eq(restored.pendingEvolution,nil)
        local expected=Party._primitive(legacy);expected.version=5;expected.natureId,expected.abilitySlot,expected.heldItem=0,"first","none";same(record(restored),expected)
        for _,version in ipairs({1,2}) do local bad=Party._primitive(legacy);bad.version=version;eq(PokemonCodec.decode(bad),nil) end
        legacy.pendingEvolution={species="abra",level=16};eq(PokemonCodec.decode(legacy),nil)
    end)
    test("Pending evolution survives actual session JSON roundtrip without auto-transform",function()
        local game,mon=pendingGame("bulbasaur",15,16);assert(game.session:setIntro({stage="done",starter="bulbasaur",rivalStarter="charmander",rivalOutcome=true}))
        local wire=assert(SessionCodec.encode(game.session,{root="overworld",overworld="explore",settled=true}))
        local restored=assert(SessionCodec.decode(json.decode(json.encode(wire)),game:getSessionDependencies()));local copy=restored:party():get(1)
        eq(copy.species,"bulbasaur");same(copy.pendingEvolution,{species="bulbasaur",level=16})
        assert(Evolution.complete(assert(Evolution.prepare(restored,copy,{kind="level"}))));eq(copy.species,"ivysaur")
    end)
    test("Malformed pending records reject and evolution learning uses its own source reason",function()
        local game,mon=pendingGame();local valid=record(mon)
        for _,pending in ipairs({{species="kadabra",level=16},{species="abra",level=15},{species="abra",level=16,extra=true},{species="abra",level=16.5}}) do local bad=Party._primitive(valid);bad.pendingEvolution=pending;eq(PokemonCodec.validate(bad),false) end
        assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="level"}))));local evolved=record(mon);assert(PokemonCodec.validate(evolved));eq(evolved.pendingMoveChoices[1].reason,"evolution")
        evolved.version=3;evolved.natureId,evolved.abilitySlot,evolved.heldItem=nil,nil,nil;eq(PokemonCodec.validate(evolved),false)
    end)
    test("Trade requires explicit external policy hook; four targets stay original roster",function()
        for _,species in ipairs({"kadabra","machoke","graveler","haunter"}) do
            local mon=Pokemon(species,30);local game=gameWith(mon);local target=EvolutionData.rules[species][1].to
            local request,why=Evolution.prepare(game.session,mon,{kind="trade"});eq(request,nil);eq(why,"trade-hook-required")
            eq(Evolution.prepareTrade(game.session,mon,function() return false end),nil)
            request=assert(Evolution.prepareTrade(game.session,mon,function(s,p,to) eq(s,game.session);eq(p,mon);eq(to,target);return true end))
            assert(Evolution.complete(request));eq(mon.species,target);eq(game.session:party():get(1),mon)
        end
    end)
    test("Victory run caught retain real level events including HP0; defeat discards",function()
        for _,kind in ipairs({"victory","run","caught","defeat"}) do
            local game,mon=pendingGame();mon.hp=0;assert(Evolution.afterBattle(game.session,kind))
            eq(mon.pendingEvolution~=nil,kind~="defeat")
            if kind~="defeat" then assert(Evolution.complete(assert(Evolution.prepare(game.session,mon,{kind="level"}))));eq(mon.hp,0) end
        end
    end)
    test("Actual BattleState campaign win plus blackout heals before pending evolution without losing event",function()
        local zone=getCurrentZoneKey()
        local ok,why=pcall(function()
        local game,mon=pendingGame("bulbasaur",15,16);ui(game);local state=BattleState(game);game.machine:register("battle",state)
        local enemy=Pokemon("rattata",5);mon.hp,enemy.hp=0,0;state.battle=Battle(mon,enemy,nil,{session=game.session});state:finish(true,"victory")
        eq(game.lastBattleOutcome.blackout,true);eq(game.lastBattleOutcome.player_hp,0);eq(game.lastBattleOutcome.enemy_hp,0);eq(game.lastBattleOutcome.kind,"victory")
        eq(game.machine:getCurrent(),"evolution");eq(mon.hp,mon.maxHP);eq(mon.species,"bulbasaur")
        beginAnimation(game.machine:current());runAnimation(game);eq(mon.species,"ivysaur");eq(mon.hp,45)
        game.machine:current():finish()
        end)
        switchZone(zone);assert(ok,why)
    end)
    test("Native HSM animation commits once after120 updates; repeated drawing advances neither frame nor RNG",function()
        local game,mon=pendingGame();local state=ui(game);local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(EvolutionState.open(game,request));beginAnimation(state)
        local canvas=gfx.image.new(400,240,gfx.kColorWhite);local before=state:getSnapshot();local rules=RulesRNG.snapshot();gfx.pushContext(canvas)
        local ok,why=pcall(function() for _=1,12 do state:draw() end end);gfx.popContext();assert(ok,why)
        same(state:getSnapshot(),before);eq(RulesRNG.snapshot().state,rules.state);eq(RulesRNG.snapshot().rolls,rules.rolls)
        for _=1,119 do game.machine:update() end;eq(mon.species,"abra");game.machine:update();eq(mon.species,"kadabra");eq(state:getSnapshot().result,"complete")
        for _=1,20 do game.machine:update() end;eq(#mon:getPendingMoveChoices(),1);eq(Evolution.complete(request),false);state:finish()
    end)
    test("Native level cancellation and forced pause/exit preserve correct event and stale callbacks are inert",function()
        local game,mon=pendingGame();local state=ui(game);local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(EvolutionState.open(game,request));local stale=state.dialog.onComplete
        game.machine:pop();eq(request:getSnapshot().status,"aborted");assert(mon.pendingEvolution)
        local nextRequest=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(EvolutionState.open(game,nextRequest));stale();eq(state.sub:getCurrent(),"announce")
        beginAnimation(state);game.machine:update();local frame=state.frame;game.machine:register("cover",State("cover"));game.machine:push("cover")
        for _=1,10 do game.machine:update() end;eq(state.frame,frame);game.machine:pop();game.machine:update();eq(state.frame,frame+1)
        assert(state:cancel());eq(mon.species,"abra");eq(mon.pendingEvolution,nil);eq(state:getSnapshot().result,"cancelled");state:finish();eq(state:getSnapshot().phase,"closed")
    end)
    test("Native stone overlay cannot cancel and forced exit leaves same inventory and Pokemon",function()
        local mon=Pokemon("eevee",5);local game=gameWith(mon);local state=ui(game);local bag=game.session:inventory();assert(bag:add("waterStone",1));local before=record(mon)
        local request=assert(Evolution.prepare(game.session,mon,{kind="stone",item="waterStone"}));assert(EvolutionState.open(game,request));beginAnimation(state)
        local ok,why=state:cancel();eq(ok,false);eq(why,"cannot-cancel");game.machine:pop();eq(bag:quantity("waterStone"),1);same(record(mon),before);eq(request:getSnapshot().status,"aborted")
    end)
    test("Progression owner drains learning then evolution then evolved learning before final callback",function()
        local game,mon=pendingGame();local state=ui(game);local completed=0
        assert(game:offerPartyLearning(function() completed=completed+1 end));eq(game.machine:getCurrent(),"evolution")
        beginAnimation(state);runAnimation(game);state:finish();eq(game.machine:getCurrent(),"learning");eq(mon:hasMove("confusion"),true);eq(completed,0)
        local learning=game.machine:current();learning.dialog.onComplete();learning:handleInput();eq(completed,1);eq(game.machine:getCurrent(),"overworld")
    end)
    test("Retained same-visit intro callback cannot restart active animation or completed result",function()
        local game,mon=pendingGame();local state=ui(game)
        local request=assert(Evolution.prepare(game.session,mon,{kind="level"}));assert(EvolutionState.open(game,request))
        local introCallback=state.dialog.onComplete;beginAnimation(state);game.machine:update();eq(state.frame,1)
        introCallback();eq(state.sub:getCurrent(),"animate");eq(state.frame,1,"stale intro reset")
        for _=1,119 do game.machine:update() end;eq(mon.species,"kadabra");eq(state.sub:getCurrent(),"result")
        introCallback();eq(state.sub:getCurrent(),"result");eq(state.frame,120);eq(#mon:getPendingMoveChoices(),1)
        state:finish()
    end)
    RulesRNG.restore(rng);return report
end
