-- One native SDK contract per new economic/game behavior. Setup uses the real
-- codec/collection owners; no fixture driver, fake catch or injected payout.
CeladonServicesContracts = {}
local GATE <const> = {root="overworld",overworld="explore",settled=true}
local function same(a,b)
    assert(FieldMoves.same(a,b), "Celadon owner value changed")
end
local function owned(coins)
    local game = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    assert(game:recruit(Pokemon("squirtle",20)))
    assert(game.session:setIntro({stage="done",starter="squirtle",rivalStarter="bulbasaur"}))
    assert(type(game.session.coins) == "function" and type(game.session.commitCeladonService) == "function",
        "root CoinWallet/Celadon transaction integration required")
    local wire = assert(SessionCodec.encode(game.session,GATE))
    wire.coins = coins or 0
    game.session = assert(SessionCodec.decode(wire,game:getSessionDependencies()))
    assert(game.session:activateRNG())
    return game
end
local function money(game,value)
    local bag = game.session:inventory()
    if bag:money() > value then assert(bag:spend(bag:money()-value))
    elseif bag:money() < value then assert(bag:credit(value-bag:money())) end
end
local function buy(game,operation)
    return game.session:commitCeladonService(operation,CeladonEconomy.observe(game.session))
end
local function fillBag(game,first,quantity,excluded)
    local bag = game.session:inventory()
    if first then assert(bag:add(first,quantity or 1)) end
    local ids = {}
    for id,item in pairs(ItemData.definitions) do
        if not item.keyItem and not excluded[id] and id ~= first then ids[#ids+1] = id end
    end
    table.sort(ids)
    for _,id in ipairs(ids) do
        if bag:count() == Inventory.CAPACITY then break end
        assert(bag:add(id,1))
    end
    assert(bag:count() == Inventory.CAPACITY)
end
function CeladonServicesContracts.run()
    local report = {ok=true,passed=0,failed=0,tests={}}
    local function test(name,body)
        local rng,owner = RulesRNG.snapshot(),GameSession.activeRNGSession()
        local sprites = playdate.graphics.sprite.getAllSprites()
        local ok,reason = pcall(body)
        playdate.graphics.sprite.removeAll()
        for _,sprite in ipairs(sprites) do sprite:add() end
        local active = GameSession.activeRNGSession()
        if active then assert(active:deactivateRNG()) end
        if owner then assert(owner:activateRNG()) end
        RulesRNG.restore(rng)
        report.tests[#report.tests+1] = {name=name,ok=ok,error=not ok and tostring(reason) or nil}
        if ok then report.passed = report.passed+1
        else report.failed,report.ok = report.failed+1,false end
    end
    test("Celadon vending preserves source prices, low-money BCD and full-bag retry",function()
        for index,drink in ipairs(CeladonServices.policy().drinks) do
            local game = owned(37)
            money(game,200)
            local before = RulesRNG.snapshot()
            assert(buy(game,{kind="vending",choice=index}))
            assert(game.session:inventory():quantity(drink.item) == 1)
            assert(game.session:inventory():money() == 0 and game.session:coins() == 37)
            same(RulesRNG.snapshot(),before)
        end
        local game = owned()
        money(game,199)
        local before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="vending",choice=1}))
        same(CeladonEconomy.observe(game.session),before)
        game = owned()
        fillBag(game,nil,nil,{freshWater=true})
        before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="vending",choice=1}))
        same(CeladonEconomy.observe(game.session),before)
        game = owned()
        local stale = CeladonEconomy.observe(game.session)
        assert(buy(game,{kind="vending",choice=3}))
        assert(not game.session:commitCeladonService({kind="vending",choice=3},stale))
        assert(game.session:inventory():quantity("lemonade") == 1)
    end)
    test("Celadon drink rewards consume once atomically including a full bag",function()
        local game = owned()
        fillBag(game,"freshWater",1,{tm13=true})
        assert(buy(game,{kind="drink-girl",choice=1}))
        assert(game.session:inventory():quantity("freshWater") == 0)
        assert(game.session:inventory():quantity("tm13") == 1 and game.session:questFlag("EVENT_GOT_TM13"))
        game = owned()
        fillBag(game,"freshWater",2,{tm13=true})
        local before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="drink-girl",choice=1}))
        same(CeladonEconomy.observe(game.session),before)
        assert(game.session:inventory():quantity("freshWater") == 2 and not game.session:questFlag("EVENT_GOT_TM13"))
        for index,drink in ipairs(CeladonServices.policy().drinks) do
            game = owned()
            assert(game.session:inventory():add(drink.item,2))
            assert(buy(game,{kind="drink-girl",choice=index}))
            assert(game.session:inventory():quantity(drink.item) == 1)
            assert(game.session:inventory():quantity(drink.tm) == 1 and game.session:questFlag(drink.flag))
            before = CeladonEconomy.observe(game.session)
            assert(not buy(game,{kind="drink-girl",choice=index}))
            same(CeladonEconomy.observe(game.session),before)
        end
    end)
    test("Game Corner coin exchange and gifts use the one capped wallet",function()
        local game = owned(9989)
        assert(game.session:inventory():add("coinCase",1))
        local initialMoney = game.session:inventory():money()
        assert(buy(game,{kind="coin-exchange"}))
        assert(game.session:coins() == 9999 and game.session:inventory():money() == initialMoney-1000)
        local before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="coin-exchange"}))
        same(CeladonEconomy.observe(game.session),before)
        -- The original Gentleman's equality check permits this capped gift.
        assert(buy(game,{kind="coin-gift",id="pokered:GAME_CORNER:objects:10"}))
        assert(game.session:coins() == 9999 and game.session:questFlag("EVENT_GOT_20_COINS"))
        before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="coin-gift",id="pokered:GAME_CORNER:objects:10"}))
        same(CeladonEconomy.observe(game.session),before)
        game = owned(0)
        before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="coin-exchange"}))
        same(CeladonEconomy.observe(game.session),before)
        assert(game.session:inventory():add("coinCase",1))
        for _,id in ipairs({"pokered:GAME_CORNER:objects:5","pokered:GAME_CORNER:objects:9","pokered:GAME_CORNER:objects:10"}) do
            assert(buy(game,{kind="coin-gift",id=id}))
        end
        assert(game.session:coins() == 50)
        local typo
        for _,hidden in ipairs(CeladonServices.policy().hidden_coins) do
            if hidden.coins == 40 then typo = hidden end
        end
        assert(buy(game,{kind="hidden-coins",id=assert(typo).id}))
        assert(game.session:coins() == 70)
        before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="hidden-coins",id=typo.id}))
        same(CeladonEconomy.observe(game.session),before)
        local wire = assert(SessionCodec.encode(game.session,GATE))
        local restored = assert(SessionCodec.decode(wire,game:getSessionDependencies()))
        assert(restored:coins() == 70 and SessionCodec.VERSION == 4)
    end)
    test("Blue coin prizes repeat with genuine Gen V specimens and capacity rollback",function()
        local game = owned(5000)
        assert(game.session:inventory():add("coinCase",1))
        local beforeRng = RulesRNG.snapshot()
        assert(buy(game,{kind="prize",window=1,choice=1}))
        local abra = game.session:party():get(2)
        assert(abra.species == "abra" and abra.level == 6 and game.session:coins() == 4880)
        assert(game.session:pokedex().owned.abra and RulesRNG.snapshot().rolls > beforeRng.rolls)
        assert(buy(game,{kind="prize",window=1,choice=1}))
        assert(game.session:party():get(3) ~= abra and game.session:coins() == 4760)
        game = owned(5000)
        assert(game.session:inventory():add("coinCase",1))
        while game.session:party():count() < Party.CAPACITY do assert(game:recruit(Pokemon("magikarp",1))) end
        assert(game.session:storage():selectBox(3))
        while game.session:storage():count() < Storage.BOX_CAPACITY do assert(game:recruit(Pokemon("magikarp",1))) end
        local before = CeladonEconomy.observe(game.session)
        beforeRng = RulesRNG.snapshot()
        assert(not buy(game,{kind="prize",window=2,choice=2}))
        same(CeladonEconomy.observe(game.session),before)
        same(RulesRNG.snapshot(),beforeRng)
        assert(not game.session:pokedex().owned.dratini)
        assert(game.session:storage():release(1,game.session:storage():get(1)))
        local accepted,result = buy(game,{kind="prize",window=2,choice=2})
        assert(accepted and result.destination == "storage" and result.box == 3)
        local dratini = game.session:storage():get(result.index)
        assert(dratini.species == "dratini" and dratini.level == 24 and game.session:coins() == 400)
        game = owned(5000)
        fillBag(game,"coinCase",1,{tm23=true})
        before = CeladonEconomy.observe(game.session)
        assert(not buy(game,{kind="prize",window=3,choice=1}))
        same(CeladonEconomy.observe(game.session),before)
    end)
    test("Blue slots derive outcomes from source reels, input timing and real RNG",function()
        assert(CeladonSlots.luckyIndex(7) == 0 and CeladonSlots.luckyIndex(0) == 1 and CeladonSlots.luckyIndex(255) == 31)
        local initial = CeladonSlots.open(1,1)
        same(initial.offsets,{0,0,0})
        assert(initial.chance == 250 and CeladonSlots.open(32,1).chance == 253)
        local seed
        for candidate = 1,10000 do
            local probe = RulesRNG.new(candidate)
            if probe:random(0,255) > 253 then seed = candidate; break end
        end
        assert(seed, "real slot mode seed required")
        local rng = RulesRNG.new(seed)
        local value = CeladonSlots.bet(initial,3,rng)
        assert(value.flags & 0x80 ~= 0 and value.rerolls == 4)
        value = CeladonSlots.start(value)
        for _ = 1,20 do value = CeladonSlots.tick(value,false,rng) end
        assert(value.phase == "spinning")
        same(value.offsets,{20,20,20})
        local frames = 0
        while value.phase ~= "result" do
            frames = frames+1
            assert(frames < 800, "source slot spin must terminate")
            local press = value.phase == "spinning" and (value.stopping == 0 or value.stopping < 3 and value.slips[value.stopping] == 0)
            value = CeladonSlots.tick(value,press,rng)
        end
        local rewards = {SLOTS7=300,SLOTSBAR=100,SLOTSCHERRY=8,SLOTSFISH=15,SLOTSBIRD=15,SLOTSMOUSE=15}
        assert(value.payout == (value.winner and rewards[value.winner] or 0))
        if value.winner then assert(CeladonSlots.match(value) == value.winner) end
        assert(not pcall(CeladonSlots.tick,value,true,rng))
        local again = CeladonSlots.again(value)
        same(again.offsets,value.offsets)
        local nextBet = CeladonSlots.bet(again,1,rng)
        assert(nextBet.rerolls == 4)
        -- Independent source row example: offsets 29 center 7 on all reels;
        -- offsets 1 match only the bottom 7 line, which a one-coin bet excludes.
        local example = CeladonSlots.open(1,1)
        example.offsets,example.bet = {29,29,29},1
        assert(CeladonSlots.match(example) == "SLOTS7")
        example.offsets = {1,1,1}
        assert(not CeladonSlots.match(example))
        example.bet = 2
        assert(CeladonSlots.match(example) == "SLOTS7")
    end)
    return report
end
