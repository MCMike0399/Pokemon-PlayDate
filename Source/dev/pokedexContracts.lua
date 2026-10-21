PokedexContracts={}
local gfx <const> = playdate.graphics
local function eq(a,b,label) assert(a==b,(label or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function fresh()
    local game=GameContext()
    game.machine:register("base",State("base"));game.machine:register("pokedex",PokedexState(game));game.machine:change("base");game.machine:push("pokedex")
    return game.machine:current(),game
end
function PokedexContracts.run()
    local report={ok=true,passed=0,failed=0,tests={}}
    local function test(name,fn)
        local ok,why=pcall(fn);report.tests[#report.tests+1]={name=name,ok=ok,error=not ok and tostring(why) or nil}
        if ok then report.passed=report.passed+1 else report.failed=report.failed+1;report.ok=false end
    end
    test("All151 source records, art aliases and new default names fit authoritative codec",function()
        eq(#PokedexData,151);local seen={}
        for i,entry in ipairs(PokedexData) do
            eq(entry.dex,i);eq(pokemonData[entry.species].dex,i);assert(not seen[entry.species]);seen[entry.species]=true
            assert(#entry.category>0 and #entry.lines==7 and entry.heightInches<12 and entry.weightTenthsLb>0,"missing source entry metadata "..entry.species)
            local mon=Pokemon(entry.species,5);eq(mon.name,entry.name)
            assert(#mon.name<=10 and not mon.name:find("[^ -~]"),"non-ASCII name "..entry.species)
            local record,why=PokemonCodec.encode(mon);assert(record,entry.species..": "..tostring(why))
            local copy,why=PokemonCodec.decode(record);assert(copy,entry.species..": "..tostring(why));eq(copy.name,mon.name);eq(copy.species,entry.species)
            assert(gfx.image.new(PokemonArt.path(entry.species,"front")),"missing front "..entry.species)
        end
        eq(PokemonNames.mr,"MR. MIME");eq(PokemonNames.farfetchd,"FARFETCH'D");eq(PokemonNames.nidoranF,"NIDORAN F");eq(PokemonNames.nidoranM,"NIDORAN M")
    end)
    test("Pinned literal entry vectors retain original measurements and wording",function()
        local first,last=PokedexData[1],PokedexData[151]
        eq(first.category,"SEED");eq(first.heightFeet,2);eq(first.heightInches,4);eq(first.weightTenthsLb,150);eq(first.lines[1],"A strange seed was")
        eq(last.category,"NEW SPECIE");eq(last.weightTenthsLb,90);eq(last.lines[7],"seen it worldwide")
        eq(PokedexData[122].sourceName,"MR.MIME");eq(PokedexData[83].sourceInternalId,64)
    end)
    test("Unseen entries never reveal names, details or open data pages",function()
        local s= fresh();local v=s:entryView();eq(v.seen,false);eq(v.owned,false);eq(v.name,"----------");eq(v.details,nil)
        local ok,why=s:openEntry();eq(ok,false);eq(why,"unseen");eq(s.phase,"list")
        s:back();eq(s.phase,"closed")
    end)
    test("Seen-only and owned disclosure derives from actual session transitions",function()
        local s,g=fresh();assert(s:select(122));assert(g.session:markSeen("mr"));eq(s:entryView().name,"MR. MIME");eq(s:entryView().details,nil)
        assert(s:openEntry());eq(s.phase,"entry");s:back();eq(s.phase,"list")
        assert(g.session:recruit(Pokemon("mr",5)));eq(s:entryView().owned,true);eq(s:entryView().details.category,"BARRIER")
        assert(s:openEntry());local snap=s:getSnapshot();snap.owned=false;eq(s:getSnapshot().owned,true);s:back();s:back()
    end)
    test("Scroll/page boundaries clamp without wrap or corrupt selection",function()
        local s=fresh();assert(s:move(-1));eq(s.selected,1);assert(s:move(-8));eq(s.selected,1)
        assert(s:select(151));assert(s:move(1));eq(s.selected,151);assert(s:move(8));eq(s.selected,151)
        assert(s:move(-8));eq(s.selected,143);assert(s:move(8));eq(s.selected,151)
        for _,bad in ipairs({0,152,1.5,"1",false,math.huge,0/0}) do local old=s.selected;eq(s:select(bad),false);eq(s.selected,old) end
        eq(s:move(2),false);s:back()
    end)
    test("Real overlay lifecycle retains parent and reopens cleanly",function()
        local s,g=fresh();eq(g.machine:getCurrent(),"pokedex");assert(s:select(151));s:back();eq(g.machine:getCurrent(),"base");eq(s.phase,"closed")
        g.machine:push("pokedex");eq(s.selected,1);eq(s.phase,"list");s:back()
    end)
    test("Repeated native drawing preserves discovery, rules RNG and graphics context",function()
        local s,g=fresh();assert(g.session:recruit(Pokemon("bulbasaur",5)))
        local image=gfx.image.new(400,240,gfx.kColorWhite);local rng=RulesRNG.snapshot();local initial=s:getSnapshot()
        local previousX,previousY=gfx.getDrawOffset();local previousFont=gfx.getFont()
        gfx.pushContext(image);gfx.setDrawOffset(7,9)
        local ok,why=pcall(function() for _=1,5 do s:draw() end;assert(s:openEntry());for _=1,5 do s:draw() end end)
        local x,y=gfx.getDrawOffset();gfx.popContext();gfx.setDrawOffset(previousX,previousY)
        assert(ok,why);eq(x,7);eq(y,9);eq(gfx.getFont(),previousFont);eq(s.selected,initial.selected)
        eq(RulesRNG.snapshot().state,rng.state);eq(RulesRNG.snapshot().rolls,rng.rolls)
        eq(g.session:pokedex().owned.bulbasaur,true);eq(g.session:pokedex().seen.mew,nil);s:back();s:back()
    end)
    test("Codec preserves saved nicknames and legacy ASCII names without guessed migration",function()
        for _,name in ipairs({"MY MIME","MR","FARFETCHD"}) do
            local mon=Pokemon("mr",5);mon.name=name;local record=assert(PokemonCodec.encode(mon));local copy=assert(PokemonCodec.decode(record));eq(copy.name,name)
        end
        local mon=Pokemon("mr",5);mon.name="NIDORAN♀";eq(PokemonCodec.encode(mon),nil)
        mon.name="ELEVENCHARS";eq(PokemonCodec.encode(mon),nil)
    end)
    test("Existing starter names, moves and species stats are unchanged",function()
        for _,species in ipairs({"bulbasaur","charmander","squirtle"}) do
            local mon=Pokemon(species,5);eq(mon.name,pokemonData[species].name);eq(#mon.moves,2)
            eq(mon.moves[1],species=="charmander" and "scratch" or "tackle");eq(mon.maxHP,calcHP(pokemonData[species].baseHP,5));eq(mon.dex,pokemonData[species].dex)
        end
    end)
    test("Optional seen fixture validates whole dense roster before any reset",function()
        assert(HarnessFixtures.validate({pokedex_seen={"mr","mew"}}))
        assert(HarnessFixtures.validate({pokedex_seen={}}))
        local view,g=fresh();local original=g.session;local rng=RulesRNG.snapshot()
        for _,bad in ipairs({"mew",false,{"mr","unknown"},{species="mr"},{[1]="mr",[3]="mew"},{"mr","mr"},{"mr",3}}) do
            eq(pcall(function() HarnessFixtures.reset(g,{intro="skip",pokedex_seen=bad}) end),false)
            eq(g.session,original);eq(g.machine:getCurrent(),"pokedex");eq(view.selected,1)
            eq(RulesRNG.snapshot().state,rng.state);eq(RulesRNG.snapshot().rolls,rng.rolls)
            eq(g.session:pokedex().seen.mr,nil)
        end
        view:back()
    end)
    return report
end
