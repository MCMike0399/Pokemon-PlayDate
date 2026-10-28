-- Executed by the real Playdate SDK against production scenes and images.
CaptureAnimationContracts={}
local gfx <const> = playdate.graphics
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function receipt(n,caught,critical,ball)
    return {displayShakes=n,caught=caught,critical=critical or false,ballId=ball or "pokeBall"}
end
local function snapshot(a)
    local s=a:getSnapshot();return table.concat({s.phase,s.frame,tostring(s.done),s.shake},"|")
end
local function scene(r)
    local b=Battle(Pokemon("charmander",5),Pokemon("rattata",5))
    local s=BattleScene(b);s.introPhase="ready";s.introDrawing=false;b.captureResult=r
    -- Isolate capture gating from the separate narration acknowledgement gate.
    s:syncMessage()
    s.messageDialog:advance()
    s.messageDialog:advance()
    return s,b
end
local function finish(a)
    for _=1,300 do if a.done then return end;a:update() end
    error("capture animation exceeded300 updates")
end
function CaptureAnimationContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local rng=RulesRNG.snapshot();local ox,oy=playdate.display.getOffset()
    local function test(name,fn)
        local ok,why=pcall(fn)
        report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    for _,spec in ipairs({{0,false,false},{1,false,false},{3,false,false},{3,true,false},{1,true,true},{1,false,true}}) do
        test("Receipt-driven visibility and exact shake poses: "..spec[1].."/"..tostring(spec[2]).."/"..tostring(spec[3]),function()
            local a=CaptureAnimation(receipt(spec[1],spec[2],spec[3]))
            local shakeTicks,absorbTicks,breakTicks=0,0,0
            eq(a.phase,"throw");eq(a:isEnemyVisible(),true)
            while not a.done do
                if a.phase=="shake" then shakeTicks=shakeTicks+1;eq(a:isEnemyVisible(),false) end
                if a.phase=="absorb" then absorbTicks=absorbTicks+1;eq(a:isEnemyVisible(),true) end
                if a.phase=="breakout" then breakTicks=breakTicks+1;eq(a:isEnemyVisible(),false) end
                a:update();assert(a.frame<300,"unbounded animation")
            end
            eq(shakeTicks,spec[1]*8,"shake ticks");eq(absorbTicks,12,"absorption ticks")
            eq(breakTicks,spec[2] and 0 or 12,"breakout ticks")
            eq(a:isEnemyVisible(),not spec[2]);eq(a.phase,spec[2] and "caught" or "escaped");eq(a.shake,spec[1])
            local final=snapshot(a);a:update();eq(snapshot(a),final,"finished update")
        end)
    end
    test("All ball paths retain source endpoints and original Ultra/Master flash",function()
        for _,ball in ipairs({"pokeBall","greatBall","ultraBall","masterBall"}) do
            local a=CaptureAnimation(receipt(3,true,false,ball));eq(a.x,105);eq(a.y,120)
            local flashed=false
            for _=1,a.throwTicks-1 do a:update();flashed=flashed or a.ballFrame=="closed-flash" end
            eq(a.x,340);eq(a.y,60);eq(flashed,ball=="ultraBall" or ball=="masterBall")
        end
    end)
    test("Invalid receipt rejected before any rules RNG",function()
        for _,r in ipairs({receipt(2,false),receipt(3,false,true),receipt(1,true,false,"safariBall")}) do
            local before=RulesRNG.snapshot();eq(pcall(function() CaptureAnimation(r) end),false)
            eq(RulesRNG.snapshot().rolls,before.rolls)
        end
    end)
    test("Scene starts pending receipt once and detached snapshots cannot mutate animation",function()
        local r=receipt(3,true);local s=scene(r)
        eq(s:getCaptureSnapshot().phase,"pending");eq(s:getCaptureSnapshot().done,false)
        s:update();eq(s:getCaptureSnapshot().frame,0)
        local detached=s:getCaptureSnapshot();detached.frame=999;eq(s:getCaptureSnapshot().frame,0)
        local original=s.captureAnimation
        for _=1,200 do s:update() end
        eq(s.captureAnimation,original);eq(s:getCaptureSnapshot().done,true)
        s.battle.captureResult=receipt(0,false);s:update();assert(s.captureAnimation~=original)
        s.battle.captureResult=r;s:update();assert(s.captureAnimation~=original,"old receipt replayed")
        s:exit()
    end)
    test("Pending and active animation block controller forwarding; completed result resumes",function()
        local s,b=scene(receipt(3,true));local calls=0
        b.handleInput=function() calls=calls+1 end
        s:handleInput();eq(calls,0,"pending input")
        s:update();s:handleInput();eq(calls,0,"active input")
        for _=1,200 do s:update() end
        s:handleInput();eq(calls,1,"completed input");s:exit()
    end)
    test("Repeated real scene rendering changes neither presentation nor battle/RNG",function()
        local s,b=scene(receipt(3,true));s:update()
        local canvas=gfx.image.new(400,240,gfx.kColorWhite)
        local before=snapshot(s.captureAnimation);local rules=RulesRNG.snapshot()
        local phase,message,hp,pp=b:phase(),b.message,b.player.hp,b.player.pp[b.player.moves[1]]
        gfx.pushContext(canvas)
        local ok,why=pcall(function() for _=1,17 do s:draw() end end)
        gfx.popContext();assert(ok,why)
        eq(snapshot(s.captureAnimation),before);eq(RulesRNG.snapshot().state,rules.state);eq(RulesRNG.snapshot().rolls,rules.rolls)
        eq(b:phase(),phase);eq(b.message,message);eq(b.player.hp,hp);eq(b.player.pp[b.player.moves[1]],pp)
        s:exit()
    end)
    test("Actual enemy sprite rendering suppressed on caught and restored on failed receipt",function()
        local canvas=gfx.image.new(400,240,gfx.kColorWhite)
        for _,caught in ipairs({true,false}) do
            local s=scene(receipt(0,caught));s:update();finish(s.captureAnimation)
            local fronts=0;local draw=s.drawPokemonSprite
            s.drawPokemonSprite=function(self,species,x,y,back) if not back then fronts=fronts+1 end;return draw(self,species,x,y,back) end
            gfx.pushContext(canvas);local ok,why=pcall(function() s:draw() end);gfx.popContext();assert(ok,why)
            eq(fronts,caught and 0 or 1,"enemy render count");s:exit()
        end
    end)
    test("Forced scene exit cancels motion, clears offset and cannot restart stale receipt",function()
        local s=scene(receipt(3,true));s:update();playdate.display.setOffset(4,-3);s:exit()
        local x,y=playdate.display.getOffset();eq(x,0);eq(y,0)
        eq(s.captureAnimation.done,true);eq(s.captureAnimation.phase,"cancelled");eq(s.captureAnimation:isEnemyVisible(),true)
        local before=snapshot(s.captureAnimation)
        s:update();s:draw();s:handleInput();eq(snapshot(s.captureAnimation),before);eq(s:getCaptureSnapshot().phase,"closed")
        eq(s:takeSelectionRequest(),nil)
    end)
    RulesRNG.restore(rng);playdate.display.setOffset(ox,oy)
    return report
end
