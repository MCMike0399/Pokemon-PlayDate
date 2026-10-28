-- Prepared actual SDK cases. Root alone executes in a private harness bundle.
NPCTradeContracts = {}
local GATE <const> = {root="overworld", overworld="explore", settled=true}
local function eq(a, b)
    assert(a == b, tostring(a) .. " ~= " .. tostring(b))
end
local function same(a, b)
    assert(NPCTrades.same(a, b), "different durable data")
end
local function wire(session)
    return assert(SessionCodec.encode(session, GATE))
end
local function fresh(offer, level)
    local g <const> = GameContext({sessionLocationPolicy=PewterWorld.locationPolicy()})
    assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
    local starter <const> = Pokemon("squirtle", 5)
    assert(g.session:recruit(starter))
    local mon <const> = Pokemon(offer.wanted, level or 15)
    assert(g.session:recruit(mon))
    assert(g.session:storage():deposit(g.session:party(), 1))
    assert(g.session:storage():release(1, starter))
    assert(g.session:activateRNG())
    return g, g.session, mon
end
local function prepare(g, offer, mon)
    return assert(NPCTrades.prepare(g.session, offer.sourceId, mon, g))
end
local function offers()
    local result <const> = {}
    for _, offer in pairs(NPCTrades.policy().trades) do
        result[#result + 1] = offer
    end
    table.sort(result, function(a, b) return a.index < b.index end)
    return result
end
local gfx <const> = playdate.graphics
local function drain(g)
    for _ = 1, 512 do
        if g.machine:getCurrent() ~= "dialog" then
            return
        end
        local state = g.machine:get("dialog")
        state.dialog:advance()
        state:handleInput()
    end
    error("NPC trade dialogue did not settle")
end
local function worldScene(name, entry, fn)
    local oldRegistry, oldList, oldZone = zoneRegistry, zoneList, currentZone
    local oldStory, oldRNG, oldOwner = Story.currentContext(), RulesRNG.toData(), GameSession.activeRNGSession()
    local oldWorld = WorldDeltas.export()
    local count, ids = gfx.sprite.spriteCount(), WorldTiles:maxID()
    local ox, oy = gfx.getDrawOffset()
    local screen, sprites, sets = gfx.getWorkingImage():copy(), {}, {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        sprites[sprite] = {visible = sprite:isVisible(), enabled = sprite:updatesEnabled()}
        sprite:setVisible(false)
        sprite:setUpdatesEnabled(false)
    end
    for key, value in pairs(SpriteFactory.npc) do
        sets[key] = value
    end
    local g = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()})
    local registry = TileRegistry()
    local provider = PewterWorld.createProvider(g, registry)
    zoneRegistry, zoneList = {}, {}
    local oldProvider = WorldDeltas.definitionProvider()
    for _, key in ipairs(oldList) do
        local zone = oldRegistry[key]
        if not oldProvider or not oldProvider:owns(zone) then
            zoneRegistry[key] = zone
            zoneList[#zoneList + 1] = key
        end
    end
    local ok, problem = pcall(function()
        WorldDeltas._withDefinitionProvider(provider, function()
            WorldView.withIsolation(function()
                assert(g:recruit(Pokemon("squirtle", 5)))
                assert(g:recruit(Pokemon("pidgey", 5)))
                assert(g.session:setIntro({stage="done", starter="squirtle", rivalStarter="bulbasaur"}))
                currentZone = provider:ensure(SourceMaps.entry(name).key)
                Story.bind(g)
                g.machine:register("overworld", OverworldState(g))
                g.machine:register("dialog", DialogState(g))
                g.machine:register("pause", PauseState(g))
                g.machine:register("tutorial-escort", TutorialEscortState(g))
                g.machine:change("overworld", {entry=entry})
                assert(g.session:activateRNG())
                local owner = g.machine:get("overworld")
                assert(owner:isTop(), "NPC trade fixture must own the root world")
                eq(owner.sub:getCurrent(), "explore", "NPC trade fixture substate")
                assert(g.player:updatesEnabled(), "NPC trade fixture Player callbacks must be enabled")
                fn(g, owner, provider)
            end)
        end)
    end)
    if g then
        while #g.machine.stack > 0 do
            local state = table.remove(g.machine.stack)
            pcall(state.exit, state)
        end
        g.npcManager:clear()
        if g.player then
            g.player:remove()
            g.player.grassOverlay:remove()
            g.player.exitArrow:remove()
            if g.player.jumpShadow then
                g.player.jumpShadow:remove()
            end
        end
    end
    provider:disposeCache()
    zoneRegistry, zoneList, currentZone = oldRegistry, oldList, oldZone
    Story.bind(oldStory)
    WorldDeltas.apply(oldWorld)
    local owner = GameSession.activeRNGSession()
    if owner ~= oldOwner then
        if owner then
            owner:deactivateRNG()
        end
        if oldOwner then
            oldOwner:activateRNG()
        end
    end
    RulesRNG.restoreData(oldRNG)
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        if not sprites[sprite] then
            sprite:remove()
        end
    end
    local present = {}
    for _, sprite in ipairs(gfx.sprite.getAllSprites()) do
        present[sprite] = true
    end
    for sprite, state in pairs(sprites) do
        if not present[sprite] then
            sprite:add()
        end
        sprite:setVisible(state.visible)
        sprite:setUpdatesEnabled(state.enabled)
    end
    for key in pairs(SpriteFactory.npc) do
        if not sets[key] then
            SpriteFactory.npc[key] = nil
        end
    end
    for key, value in pairs(sets) do
        SpriteFactory.npc[key] = value
    end
    gfx.setDrawOffset(0, 0)
    screen:draw(0, 0)
    gfx.setDrawOffset(ox, oy)
    eq(gfx.sprite.spriteCount(), count)
    eq(WorldTiles:maxID(), ids)
    if not ok then
        error(problem, 0)
    end
end

local invocation = 0
function NPCTradeContracts.run()
    local priorOwner <const> = GameSession.activeRNGSession()
    local priorRNG <const> = RulesRNG.toData()
    local report <const> = {ok=true, passed=0, failed=0, tests={}}
    local function test(name, fn)
        local ok, problem = pcall(fn)
        report.tests[#report.tests + 1] = {name=name, ok=ok, error=not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    for _, offer in ipairs(offers()) do
        test(offer.nickname .. " exact object, normal traits, OTID draw order, healthy last-member", function()
            local g, s, outgoing = fresh(offer, 37)
            outgoing.hp, outgoing.status = 0, "poison"
            outgoing.pp[outgoing.moves[1]] = 0
            outgoing.xp = outgoing.xp + 1
            local before <const> = s:rngData()
            local stream <const> = RulesRNG.new(1)
            stream:restoreData(before)
            local expectedID <const> = stream:random(0, 65535)
            local slot <const> = stream:random(1, 2) == 1 and "first" or "second"
            local nature <const> = stream:random(0, 24)
            local byte <const> = stream:random(0, 255)
            local ivs <const> = {}
            for _, key in ipairs({"hp", "atk", "def", "spa", "spd", "spe"}) do
                ivs[key] = stream:random(0, 31)
            end
            local expected <const> = Pokemon(offer.offered, 37, {abilitySlot=slot, natureId=nature,
                heldItem="none", sex=Specimen.sex(offer.offered, byte), ivs=ivs, evs=IndividualStats.zero()})
            local request <const> = prepare(g, offer, outgoing)
            same(before, s:rngData())
            eq(s:party():get(1), outgoing)
            local ok, result = s:resolveNPCTrade(request, g)
            assert(ok, result)
            local incoming <const> = result.pokemon
            eq(incoming, s:party():get(1))
            eq(s:party():count(), 1)
            eq(Party._owner(outgoing), nil)
            eq(Party._owner(incoming), s:party())
            eq(incoming.species, offer.offered)
            eq(incoming.name, offer.nickname)
            eq(incoming.level, 37)
            eq(incoming.xp, incoming:xpForLevel(37))
            eq(incoming.hp, incoming.maxHP)
            eq(incoming.status, nil)
            eq(incoming.heldItem, "none")
            eq(incoming.acquisition.otId, expectedID)
            eq(incoming.sexProvenance.origin, "npc-trade")
            eq(incoming.acquisition.otName, "TRAINER")
            eq(incoming.acquisition.tradeIndex, offer.index)
            for _, key in ipairs({"natureId", "abilitySlot", "sex"}) do
                eq(incoming[key], expected[key])
            end
            same(incoming.ivs, expected.ivs)
            same(incoming.evs, IndividualStats.zero())
            local moves <const> = {}
            for _, entry in ipairs(pokemonData[offer.offered].learnset) do
                if entry.level >= 1 and entry.level <= 37 then
                    local present = false
                    for _, key in ipairs(moves) do
                        if key == entry.move then
                            present = true
                        end
                    end
                    if not present then
                        if #moves == 4 then
                            table.remove(moves, 1)
                        end
                        moves[#moves + 1] = entry.move
                    end
                end
            end
            same(incoming.moves, moves)
            for _, key in ipairs(moves) do
                eq(incoming.pp[key], moveData[key].maxPP)
            end
            same(s:rngData(), stream:toData())
            assert(s:questFlag(offer.flag))
            assert(s:pokedex().seen[incoming.species])
            assert(s:pokedex().owned[incoming.species])
            assert(NPCTrades.isOutsider(incoming))
            local completed <const> = wire(s)
            eq(s:resolveNPCTrade(request, g), false)
            eq(NPCTrades.prepare(s, offer.sourceId, incoming, g), nil)
            same(completed, wire(s))
        end)
        test(offer.nickname .. " level1, starter-level and level100 use incoming thresholds and full PP", function()
            for _, level in ipairs({1, 5, 100}) do
                local g, s, mon = fresh(offer, level)
                local ok, result = s:resolveNPCTrade(prepare(g, offer, mon), g)
                assert(ok, result)
                eq(result.pokemon.level, level)
                eq(result.pokemon.xp, result.pokemon:xpForLevel(level))
                for _, move in ipairs(result.pokemon.moves) do
                    eq(result.pokemon.pp[move], moveData[move].maxPP)
                end
            end
        end)
        test(offer.nickname .. " every original source branch with measured UTF8 pages", function()
            for _, branch in ipairs({"WannaTrade", "NoTrade", "WrongMon", "Thanks", "AfterTrade"}) do
                local label <const> = "_" .. branch .. offer.dialogue .. "Text"
                local pages <const> = EventText.pagesFrom({label}, NPCTrades.text,
                    {wInGameTradeGiveMonName=offer.wantedName, wInGameTradeReceiveMonName=offer.offeredName})
                assert(#pages > 0)
                local lines <const> = {}
                for _, page in ipairs(pages) do
                    assert(utf8.len(page.text) and not page.text:find("wInGameTrade", 1, true))
                    lines[#lines + 1] = page.text
                end
                local dialog <const> = Dialog()
                dialog:show(lines)
                assert(#dialog.lines >= #pages)
            end
        end)
    end
    local currentScenes <const> = {
        {name="Route2TradeHouse", id="pokered:ROUTE_2_TRADE_HOUSE:objects:2"},
        {name="UndergroundPathRoute5", id="pokered:UNDERGROUND_PATH_ROUTE_5:objects:1"},
        {name="VermilionTradeHouse", id="pokered:VERMILION_TRADE_HOUSE:objects:1"},
        {name="Route11Gate2F", id="pokered:ROUTE_11_GATE_2F:objects:1"},
    }
    for _, scene in ipairs(currentScenes) do
        test(scene.name .. " actual picker cancellation, stale reentry, species/item guards and successful trade", function()
            worldScene(scene.name, nil, function(g)
                g.machine:register("event", NPCTradeState(g))
                g.machine:register("party", PartyState(g))
                local offer <const> = NPCTrades.offer(scene.id)
                local outgoing <const> = Pokemon(offer.wanted, 15)
                assert(g:recruit(outgoing))
                assert(g.session:captureTraversal({
                    location={zone_id=currentZone.stableID, x=g.player.gridX,
                        y=g.player.gridY, facing=g.player.facing},
                    world=WorldDeltas.export(), actors=g.npcManager.motion:snapshot(),
                }))
                local actors <const> = g.session:actorData()
                local fieldEpoch <const> = g.session:fieldWorldEpoch()
                local before <const> = wire(g.session)
                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                local event <const> = g.machine:get("event")
                eq(event.phase, "service-choice")
                event:handleButton("b")
                drain(g)
                same(before, wire(g.session))

                -- Close through PartyState so the guarded callback runs only
                -- after the event has regained the top of the real stack.
                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                event:handleButton("a")
                eq(g.machine:getCurrent(), "party")
                local picker <const> = g.machine:get("party")
                local staleSelect <const> = picker.options.onSelect
                local staleCancel <const> = picker.options.onCancel
                picker:close()
                eq(g.machine:getCurrent(), "dialog")
                eq(event.waiting, "_NoTrade" .. offer.dialogue .. "Text")
                eq(event.tradeRequest, nil)
                local cancelledSerial <const> = event.serial
                staleSelect(3)
                staleCancel()
                eq(event.serial, cancelledSerial)
                same(before, wire(g.session))
                drain(g)
                eq(g.machine:getCurrent(), "overworld")
                same(g.session:actorData(), actors)

                -- Reentry reuses this executor object. Old picker callbacks
                -- must remain inert even while that executor is top again.
                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                eq(event.phase, "service-choice")
                local reentryEpoch <const> = event.epoch
                local reentrySerial <const> = event.serial
                staleSelect(3)
                staleCancel()
                eq(event.epoch, reentryEpoch)
                eq(event.serial, reentrySerial)
                eq(event.phase, "service-choice")
                eq(g.machine:getCurrent(), "event")
                same(before, wire(g.session))
                event:handleButton("a")
                eq(g.machine:getCurrent(), "party")
                picker:close(1)
                eq(g.machine:getCurrent(), "dialog")
                eq(event.waiting, "_WrongMon" .. offer.dialogue .. "Text")
                eq(event.tradeRequest, nil)
                drain(g)
                eq(g.machine:getCurrent(), "overworld")
                same(before, wire(g.session))

                outgoing.heldItem = "lightBall"
                local held <const> = wire(g.session)
                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                event:handleButton("a")
                eq(g.machine:getCurrent(), "party")
                picker:close(3)
                eq(g.machine:getCurrent(), "dialog")
                eq(event.waiting, "trade-held-item")
                eq(event.tradeRequest, nil)
                same(held, wire(g.session))
                drain(g)
                eq(g.machine:getCurrent(), "overworld")
                eq(outgoing.heldItem, "lightBall")
                same(held, wire(g.session))
                outgoing.heldItem = "none"
                same(before, wire(g.session))

                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                event:handleButton("a")
                eq(g.machine:getCurrent(), "party")
                g.machine:get("party"):close(3)
                eq(event.phase, "service-choice")
                local duplicate <const> = event.menu.onSelect
                event:handleButton("a")
                drain(g)
                eq(g.machine:getCurrent(), "overworld")
                assert(g.session:questFlag(offer.flag))
                eq(Party._owner(outgoing), nil)
                same(g.session:actorData(), actors)
                assert(g.session:fieldWorldEpoch() ~= fieldEpoch)
                local complete <const> = wire(g.session)
                duplicate(1)
                same(complete, wire(g.session))
                assert(SourceEvents.dispatch(g, scene.id))
                drain(g)
                same(complete, wire(g.session))
            end)
        end)
    end
    local offer <const> = offers()[1]
    test("wrong species, non-party duplicate, held item excluded before confirmation", function()
        local g, s, mon = fresh(offer)
        local before <const> = wire(s)
        eq(NPCTrades.prepare(s, offer.sourceId, Pokemon(offer.wanted, 15), g), nil)
        local other <const> = Pokemon("mew", 15)
        assert(s:recruit(other))
        local request, reason = NPCTrades.prepare(s, offer.sourceId, other, g)
        eq(request, nil)
        eq(reason, "wrong-species")
        mon.heldItem = "lightBall"
        local held <const> = wire(s)
        request, reason = NPCTrades.prepare(s, offer.sourceId, mon, g)
        eq(request, nil)
        eq(reason, "take-held-item-first")
        same(held, wire(s))
        eq(mon.heldItem, "lightBall")
        assert(before.party.members[1].acquisition.kind == "neutral")
    end)
    test("full bag Take failure preserves offered item and trade exclusion", function()
        local g, s, mon = fresh(offer)
        mon.heldItem = "lightBall"
        local added = 0
        for id in pairs(ItemData.definitions) do
            if id ~= "lightBall" and added < Inventory.CAPACITY then
                if s:inventory():add(id, 1) then
                    added = added + 1
                end
            end
        end
        eq(s:inventory():count(), Inventory.CAPACITY)
        local before <const> = wire(s)
        eq(s:takeHeldItem(mon), false)
        eq(NPCTrades.prepare(s, offer.sourceId, mon, g), nil)
        eq(mon.heldItem, "lightBall")
        same(before, wire(s))
    end)
    test("cancel retires request without RNG or durable changes", function()
        local g, s, mon = fresh(offer)
        local before <const> = wire(s)
        local request <const> = prepare(g, offer, mon)
        assert(NPCTrades.cancel(request))
        eq(NPCTrades.cancel(request), false)
        eq(s:resolveNPCTrade(request, g), false)
        same(before, wire(s))
    end)
    local mutations <const> = {
        hp=function(g, s, mon)
            mon.hp = mon.hp - 1
        end,
        pp=function(g, s, mon)
            mon.pp[mon.moves[1]] = mon.pp[mon.moves[1]] - 1
        end,
        moves=function(g, s, mon)
            mon.moves[1], mon.moves[2] = mon.moves[2], mon.moves[1]
        end,
        held=function(g, s, mon)
            mon.heldItem = "lightBall"
        end,
        rng=function()
            RulesRNG.random(0, 255)
        end,
        roster=function(g, s)
            assert(s:recruit(Pokemon("mew", 5)))
        end,
        reorder=function(g, s)
            assert(s:party():swap(1, 2))
        end,
        field=function(g, s)
            s:invalidateFieldWorldContext()
        end,
        context=function(g)
            g.session = GameContext().session
        end,
    }
    for name, mutate in pairs(mutations) do
        test("terminal stale " .. name .. " preserves changed state and exact ownership", function()
            local g, s, mon = fresh(offer)
            assert(s:recruit(Pokemon("mew", 5)))
            local request <const> = prepare(g, offer, mon)
            mutate(g, s, mon)
            local before <const> = wire(s)
            eq(s:resolveNPCTrade(request, g), false)
            eq(s:resolveNPCTrade(request, g), false)
            same(before, wire(s))
            eq(Party._owner(mon), s:party())
            eq(s:questFlag(offer.flag), false)
        end)
    end
    test("full party all 240 PC slots, source append order and survivor active identity", function()
        local g, s, mon = fresh(offer)
        for _ = 2, 6 do
            assert(s:recruit(Pokemon("mew", 5)))
        end
        assert(s:party():switch(3))
        local members <const> = s:party():members()
        for box = 1, Storage.BOX_COUNT do
            assert(s:storage():selectBox(box))
            for _ = 1, Storage.BOX_CAPACITY do
                assert(s:recruit(Pokemon("mew", 5)))
            end
        end
        local storage <const> = wire(s).storage
        local request <const> = prepare(g, offer, mon)
        local ok, result = s:resolveNPCTrade(request, g)
        assert(ok, result)
        eq(s:party():count(), 6)
        eq(s:party():active(), members[3])
        for index = 1, 5 do
            eq(s:party():get(index), members[index + 1])
        end
        eq(s:party():get(6), result.pokemon)
        same(storage, wire(s).storage)
    end)
    test("last usable outgoing uses healthy appended replacement", function()
        local g, s, mon = fresh(offer)
        local fainted <const> = Pokemon("mew", 5)
        fainted.hp = 0
        assert(s:recruit(fainted))
        local ok, result = s:resolveNPCTrade(prepare(g, offer, mon), g)
        assert(ok, result)
        eq(s:party():active(), result.pokemon)
        eq(s:party():get(1), fainted)
        eq(s:party():allFainted(), false)
    end)
    test("legacy v7 codec migration preserves every attribute and RNG without outsider inference", function()
        local g, s, mon = fresh(offer)
        mon.name, mon.heldItem, mon.hp = "TRAINER", "lightBall", 1
        local record <const> = assert(PokemonCodec.encode(mon))
        record.acquisition = nil
        eq(PokemonCodec.decode(record), nil)
        record.version, record.acquisition = 7, nil
        local before <const> = s:rngData()
        local restored <const> = assert(PokemonCodec.decode(record))
        local migrated <const> = assert(PokemonCodec.encode(restored))
        eq(migrated.version, 8)
        eq(migrated.acquisition.kind, "neutral")
        migrated.version, migrated.acquisition = 7, nil
        same(record, migrated)
        same(before, s:rngData())
        eq(NPCTrades.isOutsider(restored), false)
    end)
    test("trade provenance survives ordinary evolution descendants and rejects forged history", function()
        local seelOffer
        for _, candidate in ipairs(offers()) do
            if candidate.offered == "seel" then
                seelOffer = candidate
            end
        end
        local g, s, mon = fresh(seelOffer, 37)
        local ok, result = s:resolveNPCTrade(prepare(g, seelOffer, mon), g)
        assert(ok, result)
        local evolved <const> = assert(PokemonCodec.encode(result.pokemon))
        evolved.species, evolved.hp = "dewgong", 1
        local loaded <const> = assert(PokemonCodec.decode(evolved))
        assert(NPCTrades.isOutsider(loaded))
        eq(loaded.name, "SAILOR")
        local bad <const> = assert(PokemonCodec.encode(loaded))
        bad.acquisition.tradeIndex = 2
        eq(PokemonCodec.decode(bad), nil)
        bad.acquisition.tradeIndex = seelOffer.index
        bad.species = "mew"
        eq(PokemonCodec.decode(bad), nil)
    end)
    test("local outsider Q12 post scaling ties and cap, independent of names and OTID inequality", function()
        -- Equal levels, yield 1/opponent level 5: z=1; scaled result=2.
        eq(Growth.battleAward(1, 5, 5, false, 1, false), 2)
        eq(Growth.battleAward(1, 5, 5, false, 1, true), 3)
        eq(Growth.battleAward(2, 5, 5, false, 1, true), 4)
        for _, vector in ipairs({{1, 1}, {2, 3}, {3, 4}, {66, 99}, {67, 100}, {99999, 100000}, {100001, 100000}}) do
            eq(Growth.outsiderAward(vector[1], true), vector[2])
        end
        eq(Growth.battleAward(395, 100, 100, true, 1, true), 0)
        local g, s, mon = fresh(offer)
        local ok, result = s:resolveNPCTrade(prepare(g, offer, mon), g)
        assert(ok, result)
        result.pokemon.name, result.pokemon.acquisition.otId = "RENAMED", 0
        assert(NPCTrades.isOutsider(result.pokemon))
        local localMon <const> = Pokemon(offer.offered, 15)
        localMon.name = offer.nickname
        eq(NPCTrades.isOutsider(localMon), false)
    end)
    test("all nine flags independent and schema3 real SaveStore rollback, retry and reload", function()
        assert(HarnessBuild and HarnessBuild.bundle_id:match("^com%.poc%.pokemon%.harness%."), "private harness required")
        invocation = invocation + 1
        local list <const> = offers()
        local g, s, mon = fresh(list[1])
        local deps <const> = g:getSessionDependencies()
        local fs <const> = SaveStore.sdkFilesystem()
        local prefix <const> = "npc-trades-" .. HarnessBuild.session_id .. "-" .. invocation
        local failRename = false
        local adapter <const> = {read=fs.read, write=fs.write, rename=function(from, to)
            if failRename then
                return false, "injected-publication-failure"
            end
            return fs.rename(from, to)
        end}
        local store <const> = SaveStore(prefix, function(data) return SessionCodec.validate(data, deps) end, adapter)
        local original <const> = wire(s)
        assert(store:save(original))
        for _, current in ipairs(list) do
            if current ~= list[1] then
                mon = Pokemon(current.wanted, 15)
                assert(s:recruit(mon))
                -- The selected object must be in-party, never PC overflow.
                if Party._owner(mon) ~= s:party() then
                    assert(s:storage():deposit(s:party(), 1))
                    assert(s:storage():withdraw(s:party(), s:storage():count() - 1))
                end
            end
            assert(s:resolveNPCTrade(prepare(g, current, mon), g))
        end
        local complete <const> = wire(s)
        eq(complete.version, 3)
        for _, current in ipairs(list) do
            assert(s:questFlag(current.flag))
        end
        failRename = true
        eq(store:save(complete), false)
        same(original, assert(store:load()))
        same(complete, wire(s))
        failRename = false
        -- A rename failure leaves a verified pending candidate. Exercise the
        -- existing explicit published-state recovery before retrying Save.
        assert(store:recover("published"))
        same(original, assert(store:load()))
        assert(store:save(complete))
        local reloaded <const> = assert(SessionCodec.decode(assert(store:load()), deps))
        same(complete, wire(reloaded))
        for _, current in ipairs(list) do
            assert(reloaded:questFlag(current.flag))
        end
    end)
    local active <const> = GameSession.activeRNGSession()
    if active then
        active:deactivateRNG()
    end
    if priorOwner then
        priorOwner:activateRNG()
    end
    RulesRNG.restoreData(priorRNG)
    return report
end
