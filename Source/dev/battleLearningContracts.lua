-- Production BattleScript -> LearningState -> same Battle contracts, real SDK.
BattleLearningContracts={}
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function sameRNG(a) local b=RulesRNG.snapshot();for _,k in ipairs({"seed","state","rolls"}) do eq(b[k],a[k],"RNG "..k) end end
local function own(mon,moves) mon.moves,mon.pp={},{};for i,key in ipairs(moves) do mon.moves[i]=key;mon.pp[key]=moveData[key].maxPP end end
local scenes = setmetatable({}, {__mode = "k"})
local function settle(b, stopMessage)
    local scene = assert(scenes[b], "learning fixture requires its production scene")
    for _ = 1, 10000 do
        scene:update()
        if b:phase() ~= "script" or b:getLearningSnapshot().pending then
            return
        end
        if not b.presentationRequest and not scene:isVitalsBlocking() then
            if stopMessage and b.message:find(stopMessage, 1, true) then
                return
            end
            if b.shiftChoice then
                assert(b:declineShift())
            else
                assert(b.machine:get("script"):advance())
            end
        end
    end
    error("script did not reach command/learning after presentation")
end
local function setup(species,level,moves,two,enemyLevel,enemySpecies)
    local game=GameContext();local mon=Pokemon(species or "squirtle",level or 6);assert(game:recruit(mon))
    if species and species~="squirtle" and species~="bulbasaur" and species~="charmander" then assert(game:recruit(Pokemon("charmander",5))) end
    local starter=({charmander=true,squirtle=true,bulbasaur=true})[mon.species] and mon.species or "charmander"
    local rival=({charmander="squirtle",squirtle="bulbasaur",bulbasaur="charmander"})[starter]
    assert(game.session:setIntro({stage="done",starter=starter,rivalStarter=rival,rivalOutcome=true}))
    if moves then own(mon,moves) end
    mon.xp=mon:xpForLevel(mon.level+1)-1
    local enemy=Pokemon(enemySpecies or "rattata",enemyLevel or 5);own(enemy,{"growl"})
    local enemies=Party();assert(enemies:add(enemy))
    local reserve=Pokemon("geodude",5);own(reserve,{"defenseCurl"});if two then assert(enemies:add(reserve)) end
    game.machine:register("overworld",State("overworld"));game.machine:register("learning",LearningState(game))
    local owner=BattleState(game);game.machine:register("battle",owner)
    game.machine:change("battle",mon,enemy,{name="LEARNING TEST",markInteracted=function(self) self.fixtureDefeated=true end},enemies)
    scenes[owner.battle] = owner.scene
    settle(owner.battle)
    return game,owner,mon,enemy,reserve
end
local function faint(owner)
    local b=owner.battle;b.enemy.hp=0
    b:runScript(function() local result=b:handleFaint("enemy");if result=="replacement" then return b:finishRound() end;return result end)
    settle(b);assert(b:getLearningSnapshot().pending,"expected real XP learning yield");return b
end
local function overlay(game,owner)
    assert(owner:openPendingLearning());eq(game.machine:getCurrent(),"learning");return game.machine:get("learning")
end
local function finishMessage(learning)
    eq(learning.phase,"message");learning:handleInput();assert(learning.dialog.onComplete)()
    learning:handleInput()
end
local function declineAll(game,learning)
    local count=0
    while game.machine:getCurrent()=="learning" do
        count=count+1;assert(count<100,"learning did not close")
        if learning.phase=="message" then finishMessage(learning)
        elseif learning.phase=="ask" then learning.menu.onSelect(2)
        elseif learning.phase=="stop" then learning.menu.onSelect(1)
        else error("unexpected learning phase "..learning.phase) end
    end
end
-- pokered LearnMove: NO on TryingToLearn returns carry to AbandonLearning.
-- YES (wCurrentMenuItem == 0) prints DidNotLearn and returns b=0, which ends
-- that move. The confirmation text is _AbandonLearningText ("Abandon learning"
-- plus the move name and "?"), not a later-generation "Stop learning" line.
local function dismissLearningMessage(game, learning)
    -- A finishes the typewriter. The complete page then stays up for 10
    -- frames, which is MESSAGE_MIN_FRAMES / WaitForTextScrollButtonPress,
    -- before a later A can turn it. Each wrapped page has to clear that hold.
    for _ = 1, 8 do
        if game.machine:getCurrent() ~= "learning" or learning.phase ~= "message" then
            return
        end
        eq(game.machine:getCurrent(), "learning")
        eq(learning.phase, "message")
        Autopilot.beginFrame()
        Autopilot.step({"press", "a"}, game)
        game.machine:handleInput()
        for _ = 1, 12 do
            if game.machine:getCurrent() ~= "learning" or learning.phase ~= "message" then
                return
            end
            Autopilot.beginFrame()
            game.machine:handleInput()
        end
        if game.machine:getCurrent() ~= "learning" or learning.phase ~= "message" then
            return
        end
        Autopilot.beginFrame()
        Autopilot.step({"press", "a"}, game)
        game.machine:handleInput()
    end
    if game.machine:getCurrent() ~= "learning" or learning.phase ~= "message" then
        return
    end
    error("learning message did not end")
end
local function declineByButtons(game, learning, seen)
    eq(learning.phase, "ask")
    local id, move = learning.choiceId, learning.pendingMove
    assert(not seen[id], "declined choice " .. tostring(id) .. " reopened")
    seen[id] = move
    local before = #learning.pokemon:getPendingMoveChoices()
    Autopilot.beginFrame()
    Autopilot.step({"press", "down"}, game)
    game.machine:handleInput()
    eq(learning.phase, "ask")
    eq(learning.menu.selectedIndex, 2)
    Autopilot.beginFrame()
    Autopilot.step({"press", "a"}, game)
    game.machine:handleInput()
    eq(learning.phase, "stop")
    eq(learning.choiceId, id)
    assert(learning.prompt:find("Abandon learning", 1, true), learning.prompt)
    assert(learning.prompt:find(moveData[move].name, 1, true), learning.prompt)
    eq(learning.menu.selectedIndex, 1)
    Autopilot.beginFrame()
    Autopilot.step({"press", "a"}, game)
    game.machine:handleInput()
    eq(learning.phase, "message")
    eq(learning.messageKind, "declined")
    -- The 18-column box wraps after "did". Both words and the move name stay.
    local text = table.concat(learning.dialog.lines, " "):gsub("%s+", " ")
    assert(text:find("did not learn", 1, true), text)
    assert(text:find(moveData[move].name, 1, true), text)
    eq(#learning.pokemon:getPendingMoveChoices(), before - 1)
    for _, choice in ipairs(learning.pokemon:getPendingMoveChoices()) do
        eq(choice.id == id, false, "declined choice still pending")
        eq(choice.move == move, false, "declined move was queued again")
    end
    dismissLearningMessage(game, learning)
    if game.machine:getCurrent() == "learning" then
        eq(learning.choiceId == id, false, "same choice reopened")
        eq(learning.pendingMove == move, false, "same move prompt reopened")
    end
end
function BattleLearningContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}};local saved=RulesRNG.snapshot()
    local function test(name,fn)
        local ok,why=pcall(fn);Autopilot.resetControls();report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("Typed learning yield freezes same coroutine before replacement with no RNG",function()
        local game,owner,p,e,reserve=setup(nil,nil,nil,true);local b=faint(owner);local co=b.machine:get("script").co
        local xp,rng,timer=p.xp,RulesRNG.snapshot(),b.machine:get("script").messageTimer
        for _=1,40 do b:update();eq(b.machine:get("script"):advance(),false) end
        eq(b.enemy,e);eq(b.outcome,nil);eq(b.machine:get("script").co,co);eq(p.xp,xp);eq(b.machine:get("script").messageTimer,timer);sameRNG(rng)
        eq(b:selectMove(1),false);eq(b:tryRun(),false);assert(b.enemy~=reserve,"replacement must wait")
    end)
    test("Receipts claim once and reject malformed foreign unclaimed or incomplete resume",function()
        local game,owner,p=setup();local b=faint(owner);local rng=RulesRNG.snapshot();local raw=b.pendingLearning
        eq(b:resumeLearning(raw),false);eq(b:resumeLearning({}),false)
        local receipt,mon=b:takeLearningRequest();eq(mon,p);eq(b:takeLearningRequest(),nil);eq(b:resumeLearning(receipt),false)
        local other=Battle(Pokemon("charmander",5),Pokemon("rattata",5));eq(other:resumeLearning(receipt),false)
        eq(b.pendingLearning,receipt);sameRNG(rng)
    end)
    test("Real controller auto-learns Bubble then same battle uses it against enemy2",function()
        local game,owner,p,e,reserve=setup(nil,nil,nil,true);local b=owner.battle
        e.hp=1;assert(b:selectMove(1));settle(b);assert(b:getLearningSnapshot().pending)
        local xp,co=p.xp,b.machine:get("script").co;local learning=overlay(game,owner)
        eq(learning.phase,"message");eq(p:hasMove("bubble"),true);eq(p.pp.bubble,30);eq(b.enemy,e)
        local rng=RulesRNG.snapshot();for _=1,20 do game.machine:update();game.machine:draw() end;sameRNG(rng)
        finishMessage(learning);eq(game.machine:getCurrent(),"battle");eq(owner.battle,b);eq(b.machine:get("script").co,co)
        settle(b);eq(b.enemy,reserve);eq(p.xp,xp);eq(b:phase(),"command")
        local index;for i,key in ipairs(p.moves) do if key=="bubble" then index=i end end
        assert(b:selectMove(index));settle(b);eq(p.pp.bubble,29)
    end)
    test("Learned Bubble stays in the battle text box over the scene", function()
        local game, owner = setup()
        faint(owner)
        local learning = overlay(game, owner)
        eq(learning.phase, "message")
        local line = learning.dialog.lines[1]
        assert(line:find("learned", 1, true), line)
        assert(line:find(moveData[learning.pendingMove].name, 1, true), line)
        assert(not line:find("MOVE LEARNING", 1, true), line)
        learning.dialog.charIndex = #line
        local image = playdate.graphics.image.new(400, 240, playdate.graphics.kColorWhite)
        playdate.graphics.pushContext(image)
        game.machine:draw()
        playdate.graphics.popContext()
        local gfx = playdate.graphics
        local function blackIn(x0, y0, x1, y1)
            local count = 0
            for y = y0, y1 do
                for x = x0, x1 do
                    if image:sample(x, y) == gfx.kColorBlack then count = count + 1 end
                end
            end
            return count
        end
        -- The fainted enemy's panel is gone. The player platform is not on the
        -- old white "MOVE LEARNING" page, and that title is not at the top.
        eq(image:sample(20, 150), gfx.kColorBlack)
        assert(blackIn(16, 4, 220, 22) < 10, "no MOVE LEARNING title")
        assert(blackIn(14, 190, 280, 230) > 15, "learned line in the text box")
    end)
    test("A full moveset uses the Blue trying-to-learn and forget prompts", function()
        local game, owner, p = setup(nil, nil, {"tackle", "tailWhip", "withdraw", "waterGun"})
        faint(owner)
        local learning = overlay(game, owner)
        eq(learning.phase, "ask")
        eq(learning.menu.options[1], "YES")
        eq(learning.menu.options[2], "NO")
        assert(learning.prompt:find("trying to learn", 1, true))
        assert(learning.prompt:find("can't learn more", 1, true))
        assert(learning.prompt:find("than 4 moves", 1, true))
        local image = playdate.graphics.image.new(400, 240, playdate.graphics.kColorWhite)
        playdate.graphics.pushContext(image)
        game.machine:draw()
        playdate.graphics.popContext()
        eq(image:sample(20, 150), playdate.graphics.kColorBlack)
        learning.menu.onSelect(1)
        eq(learning.phase, "replace")
        assert(learning.prompt:find("Which move should", 1, true))
        assert(learning.prompt:find("be forgotten?", 1, true))
        learning.menu.onCancel()
        eq(learning.phase, "ask")
        learning.menu.onSelect(2)
        eq(learning.phase, "stop")
        assert(learning.prompt:find("Abandon learning", 1, true))
        assert(learning.prompt:find(moveData[learning.pendingMove].name, 1, true))
        learning.menu.onSelect(2)
        eq(learning.phase, "ask")
        eq(p:hasMove("bubble"), false)
    end)
    test("Full moveset back and refusal preserve all old moves and PP",function()
        local game,owner,p=setup(nil,nil,{"tackle","tailWhip","withdraw","waterGun"});p.pp.tackle=3
        local b=faint(owner);local learning=overlay(game,owner);eq(learning.phase,"ask")
        local rng=RulesRNG.snapshot();learning.menu.onSelect(1);eq(learning.phase,"replace")
        learning.menu.onCancel();eq(learning.phase,"ask");learning.menu.onCancel();eq(learning.phase,"stop")
        learning.menu.onCancel();eq(learning.phase,"ask");eq(p:hasMove("bubble"),false);eq(p.pp.tackle,3)
        learning.menu.onSelect(2);learning.menu.onSelect(1);eq(learning.phase,"message");eq(p:hasMove("bubble"),false)
        finishMessage(learning);eq(game.machine:getCurrent(),"battle");eq(p.moves[1],"tackle");eq(p.pp.tackle,3);sameRNG(rng)
        settle(b);eq(b:phase(),"ended")
    end)
    test("Explicit replacement confirmation learns only selected slot at full PP",function()
        local game,owner,p=setup(nil,nil,{"tackle","tailWhip","withdraw","waterGun"});p.pp.tackle=3;p.pp.waterGun=2
        faint(owner);local learning=overlay(game,owner)
        learning.menu.onSelect(1);learning.menu.onSelect(4);eq(learning.phase,"confirm")
        learning.menu.onCancel();eq(learning.phase,"replace");eq(p.moves[4],"waterGun");eq(p.pp.waterGun,2)
        learning.menu.onSelect(4);learning.menu.onSelect(1);eq(p.moves[4],"bubble");eq(p.pp.bubble,30);eq(p.pp.waterGun,nil);eq(p.pp.tackle,3)
        finishMessage(learning);eq(game.machine:getCurrent(),"battle")
    end)
    test("All actual participating recipients resolve sequentially before enemy2",function()
        local game,owner,p,e,reserve=setup(nil,nil,nil,true);local bench=Pokemon("charmander",6)
        bench.xp=bench:xpForLevel(7)-1;assert(game:recruit(bench))
        local b=owner.battle;assert(b:chooseParty(2));settle(b);eq(b.player,bench)
        faint(owner);local first=overlay(game,owner);eq(first.pokemon,p);eq(b.enemy,e)
        finishMessage(first);settle(b);eq(b:getLearningSnapshot().species,"charmander");eq(b.enemy,e)
        local second=overlay(game,owner);eq(second.pokemon,bench);finishMessage(second);settle(b)
        eq(b.enemy,reserve);eq(p:hasMove("bubble"),true);eq(bench:hasMove("ember"),true)
    end)
    test("Multiple level choices use one real overlay and no turn progression",function()
        local game,owner,p=setup("charmander",6,{"scratch","growl","tackle","tailWhip"},true,50)
        local b=owner.battle;b.enemy.hp=0
        b:runScript(function() local result=b:handleFaint("enemy");if result=="replacement" then return b:finishRound() end;return result end);settle(b)
        assert(#p:getPendingMoveChoices()>1);local xp,rng=p.xp,RulesRNG.snapshot();local learning=overlay(game,owner)
        declineAll(game,learning);eq(p.xp,xp);sameRNG(rng);eq(#p:getPendingMoveChoices(),0);settle(b);eq(b.enemy.species,"geodude")
    end)
    test("Final enemy cannot end battle or emit until learning completes; XP once",function()
        local game,owner,p=setup();local b=faint(owner);local count=0;b:on("battleEnd",function() count=count+1 end)
        local xp=p.xp;eq(b:emitEnd(),false);eq(count,0)
        local learning=overlay(game,owner);finishMessage(learning);settle(b)
        eq(b:phase(),"ended");eq(b.outcome,"victory");eq(count,0);eq(p.xp,xp)
        -- The owner remains installed; avoid world return in this isolated case.
        b:clearListeners();assert(b:emitEnd());eq(b:emitEnd(),false);eq(p.xp,xp)
    end)
    test("Forced controller exit invalidates receipt and stale overlay callback",function()
        local game,owner,p=setup();local b=faint(owner);local learning=overlay(game,owner)
        local callback=learning.onComplete;local receipt=owner.learningRequest;local xp=p.xp
        game.machine:change("overworld");eq(owner.battle,nil);eq(b:getLearningSnapshot().pending,false)
        callback();eq(b:resumeLearning(receipt),false);eq(b.machine:get("script"):advance(),false);eq(p.xp,xp)
        eq(game.machine:getCurrent(),"overworld")
    end)
    test("Session replacement cannot resume old battle even when callback fires",function()
        local game,owner,p=setup();local b=faint(owner);local learning=overlay(game,owner)
        local callback,receipt=learning.onComplete,owner.learningRequest
        game.session=GameContext().session;game.machine:pop();callback()
        eq(b:resumeLearning(receipt),false);eq(b:getLearningSnapshot().pending,false);eq(b.machine:get("script"):advance(),false)
    end)
    test("Duplicate completed callback cannot advance narration or award XP twice",function()
        local game,owner,p=setup(nil,nil,nil,true);local b=faint(owner);local learning=overlay(game,owner)
        local callback=learning.onComplete;finishMessage(learning);local message,xp,rng=b.message,p.xp,RulesRNG.snapshot()
        callback();eq(b.message,message);eq(p.xp,xp);sameRNG(rng)
        -- Duplicate callback is stale, never starts another script.
        eq(b:getLearningSnapshot().pending,false)
    end)
    test("Replacing a suspended script rejects the old receipt without deleting choices",function()
        local game,owner,p=setup();local b=faint(owner);local receipt=b:takeLearningRequest();local count=#p:getPendingMoveChoices()
        b:runScript(function() b:say("Replacement script") end)
        eq(b:resumeLearning(receipt),false);eq(#p:getPendingMoveChoices(),count);eq(b.message,"Replacement script")
    end)
    test("Update-opened overlay blocks entry A held A B until released and a new press",function()
        local game,owner,p=setup(nil,nil,{"tackle","tailWhip","withdraw","waterGun"});local b=faint(owner)
        Autopilot.step({"hold","a"},game);game.machine:update();game.machine:handleInput()
        local learning=game.machine:get("learning");eq(learning.phase,"ask");eq(learning:getSnapshot().input_blocked,true)
        local rng=RulesRNG.snapshot();local count=#p:getPendingMoveChoices()
        for _=1,3 do Autopilot.beginFrame();game.machine:update();game.machine:handleInput() end
        eq(learning.phase,"ask");eq(#p:getPendingMoveChoices(),count)
        Autopilot.step({"release","a"},game);Autopilot.step({"hold","b"},game);game.machine:handleInput();eq(learning.phase,"ask")
        Autopilot.step({"release","b"},game);Autopilot.beginFrame();game.machine:handleInput();eq(learning:getSnapshot().input_blocked,false)
        Autopilot.step({"press","a"},game);game.machine:handleInput();eq(learning.phase,"replace");eq(#p:getPendingMoveChoices(),count);sameRNG(rng)
    end)
    test("Input-opened overlay never receives the A that advances the level message",function()
        local game,owner,p=setup(nil,nil,{"tackle","tailWhip","withdraw","waterGun"});local b=owner.battle;b.enemy.hp=0
        b:runScript(function() return b:handleFaint("enemy") end)
        settle(b, "grew to")
        -- Present the complete level page; the tested A acknowledges it rather
        -- than being the earlier press that only reveals its remaining text.
        owner.scene:syncMessage()
        owner.scene.messageDialog:advance()
        b.machine:get("script").messageTimer=11;owner.scene.introPhase="ready";owner.scene.introDrawing=false
        -- The A that leaves "grew to" opens the stats box. It must not also
        -- confirm the move-learning prompt that follows the box.
        Autopilot.step({"hold","a"},game);game.machine:handleInput();eq(game.machine:getCurrent(),"battle")
        eq(b.levelStats.attack, p.atk);eq(b:getLearningSnapshot().pending, false)
        Autopilot.beginFrame();game.machine:handleInput();eq(b.levelStats ~= nil, true)
        Autopilot.step({"release","a"},game);b.machine:get("script").messageTimer=11
        Autopilot.step({"press","a"},game);game.machine:handleInput();eq(game.machine:getCurrent(),"learning")
        local learning=game.machine:get("learning");eq(learning.phase,"ask");Autopilot.beginFrame();game.machine:handleInput();eq(learning.phase,"ask")
        eq(p:hasMove("bubble"),false);eq(#p:getPendingMoveChoices(),1)
    end)
    test("Opening options preflight rejects before stack queue or input gate changes",function()
        local game,owner,p=setup();faint(owner);local generation=game.machine._generation
        for _,options in ipairs({true,{unknown=true},{waitForRelease="yes"}}) do
            eq(pcall(function() LearningState.open(game,p,nil,options) end),false);eq(game.machine._generation,generation);eq(game.machine:getCurrent(),"battle")
        end
        eq(#p:getPendingMoveChoices(),1)
    end)
    test("Legacy learning caller retains immediate input behavior without an option",function()
        local game,owner,p=setup(nil,nil,{"tackle","tailWhip","withdraw","waterGun"});faint(owner)
        assert(LearningState.open(game,p));local learning=game.machine:get("learning");eq(learning:getSnapshot().input_blocked,false)
        Autopilot.step({"press","a"},game);game.machine:handleInput();eq(learning.phase,"replace")
    end)
    test("Synthetic trainer team fixture preflights all mon PP HP status and array entries",function()
        local game,owner,p=setup();local battle=owner.battle;local session,stack,rng=game.session,game.machine:current(),RulesRNG.snapshot()
        local valid={intro="skip",opening=false,player_pokemon={species="squirtle",level=6},grant_xp={amount=56},
            trainer_name="LEARNING TEST",enemy_party={{species="rattata",level=5},{species="geodude",level=5}}}
        assert(HarnessFixtures.validate(valid));sameRNG(rng)
        local badEntries={{species="missing",level=5},{species="geodude",level=0},{species="geodude",level=5,hp=0},
            {species="geodude",level=5,pp={bubble=1}},{species="geodude",level=5,status="unknown"},
            {species="geodude",level=5,status="sleep",status_turns=3,sleep_duration=1},
            {species="geodude",level=5,status="burn",status_turns=1},
            {species="geodude",level=5,status="sleep",status_turns=0,sleep_duration=0}}
        for _,bad in ipairs(badEntries) do
            valid.enemy_party[2]=bad
            eq(pcall(function() HarnessFixtures.reset(game,valid) end),false)
            eq(game.session,session);eq(game.machine:current(),stack);eq(owner.battle,battle);sameRNG(rng)
        end
        valid.enemy_party={[1]={species="rattata",level=5},[3]={species="geodude",level=5}}
        eq(pcall(function() HarnessFixtures.reset(game,valid) end),false);eq(game.session,session);eq(game.machine:current(),stack);sameRNG(rng)
    end)
    test("Squirtle B2W2 Bubble is the ordered level7 move not constructor level6",function()
        local p=Pokemon("squirtle",6);eq(p:hasMove("bubble"),false);local found=0
        for _,entry in ipairs(pokemonData.squirtle.learnset) do if entry.move=="bubble" then eq(entry.level,7);eq(entry.id,145);found=found+1 end end
        eq(found,1);p:gainXP(p:xpForLevel(7)-p.xp);eq(p:getPendingMoveChoices()[1].move,"bubble");eq(p:hasMove("bubble"),false)
    end)
    test("Level 50 Articuno decline then YES ends that move and the win can emit", function()
        -- Seafoam B4F Articuno is level 50. A full moveset must be able to
        -- refuse every new move and still reach the battleEnd that saves the win.
        local game, owner, p = setup("charmander", 6, {"scratch", "growl", "tackle", "tailWhip"}, false, 50, "articuno")
        local b = faint(owner)
        eq(b.enemy.species, "articuno")
        eq(b.enemy.level, 50)
        local initial = #p:getPendingMoveChoices()
        assert(initial > 1, "expected more than one move from the level 50 award")
        local learning = overlay(game, owner)
        eq(learning:getSnapshot().input_blocked, true)
        Autopilot.resetControls()
        Autopilot.beginFrame()
        game.machine:handleInput()
        eq(learning:getSnapshot().input_blocked, false)
        local seen, steps = {}, 0
        while game.machine:getCurrent() == "learning" do
            steps = steps + 1
            assert(steps <= initial, "learn prompt reopened after every queued move was declined")
            declineByButtons(game, learning, seen)
        end
        eq(steps, initial)
        eq(#p:getPendingMoveChoices(), 0)
        for _, key in ipairs({"scratch", "growl", "tackle", "tailWhip"}) do eq(p:hasMove(key), true) end
        settle(b)
        eq(b:phase(), "ended")
        eq(b.outcome, "victory")
        local saved = false
        b:clearListeners()
        b:on("battleEnd", function(won, kind) saved = won == true and kind == "victory" end)
        assert(b:emitEnd())
        eq(saved, true)
        eq(b:emitEnd(), false)
    end)
    RulesRNG.restore(saved);return report
end
