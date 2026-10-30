-- One case for each new behavior; existing real-map helper, no driver fixtures.
SafariServicesContracts = {}
function SafariServicesContracts.run()
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, fn)
        local ok, reason = pcall(fn)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(reason) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    test("Safari admission couples fee, source flags and resources; steps/Continue/exit retain provenance", function()
        VermilionStoryFixture.withScene("SafariZoneGate", {x = 4, y = 2}, function(game)
            local session = game.session
            assert(session:captureTraversal({world = WorldDeltas.export(), actors = game.npcManager.motion:snapshot(),
                location = {zone_id = currentZone.stableID, x = game.player.gridX, y = game.player.gridY, facing = game.player.facing}}))
            assert(session:coins() == 0 and CoinWallet.limit() == 9999)
            assert(not pcall(CoinWallet.normalize, 10000))
            local money = session:inventory():money()
            assert(session:inventory():credit(1000))
            money = money + 1000
            local epoch = session:fieldWorldEpoch()
            local admission = assert(SafariGame.admit(session:safariData(), money))
            assert(session:commitSafari(admission, epoch))
            assert(session:inventory():money() == money - 500)
            assert(session:safariData().steps == 502 and session:safariData().balls == 30)
            assert(session:questFlag("EVENT_IN_SAFARI_ZONE") and not session:questFlag("EVENT_SAFARI_GAME_OVER"))
            assert(not session:commitSafari(admission, epoch))
            assert(not SafariGame.admit(session:safariData(), money))
            local wire = assert(SessionCodec.encode(session, {root = "overworld", overworld = "explore", settled = true}))
            local loaded = assert(SessionCodec.decode(wire, game:getSessionDependencies()))
            assert(FieldMoves.same(loaded:safariData(), session:safariData()) and loaded:coins() == 0)
            local escape = assert(SafariGame.escape(session:safariData()))
            assert(not escape.after.active and escape.after.balls == 0)
            assert(session:safariData().active and session:safariData().balls == 30)
            for _ = 1, 502 do
                local step = assert(SafariGame.step(session:safariData()))
                assert(session:commitSafari(step, session:fieldWorldEpoch()))
            end
            assert(session:safariData().steps == 0 and session:safariData().ending == "none")
            assert(session:commitSafari(assert(SafariGame.step(session:safariData())), session:fieldWorldEpoch()))
            assert(session:safariData().ending == "steps" and session:questFlag("EVENT_SAFARI_GAME_OVER"))
            assert(session:commitSafari(assert(SafariGame.leave(session:safariData(), false)), session:fieldWorldEpoch()))
            assert(not session:safariData().active and session:safariData().balls == 0)
            assert(not session:questFlag("EVENT_IN_SAFARI_ZONE") and not session:questFlag("EVENT_SAFARI_GAME_OVER"))
            assert(not SafariGame.admit(SafariGame.empty(), 499))
            assert(not pcall(SafariGame.normalize, {version = 1, active = true, steps = 503, balls = 30, ending = "none"}))
        end)
        VermilionStoryFixture.withScene("SafariZoneGate", {x = 4, y = 2}, function(game)
            local session = game.session
            assert(session:captureTraversal({world = WorldDeltas.export(), actors = game.npcManager.motion:snapshot(),
                location = {zone_id = currentZone.stableID, x = game.player.gridX, y = game.player.gridY, facing = game.player.facing}}))
            local oldView = getOverworldView()
            if oldView and oldView.zone == currentZone then currentZone:detachView(oldView) end
            WorldView.withIsolation(function()
                setupOverworld()
                local world = game.machine:get("overworld")
                world.game, world.builtZone, world.builtSession = game, currentZone, session
                world._beginPresentationVisit = OverworldState._beginPresentationVisit
                world._ownsPresentation = OverworldState._ownsPresentation
                world:_beginPresentationVisit(getOverworldView())
                game.machine:register("safariPassage", SafariPassageState(game))
                local money = session:inventory():money()
                local admission = assert(SafariGame.admit(session:safariData(), money))
                local player, zone, view = game.player, currentZone, getOverworldView()
                local token = assert(SafariPassage.prepare(game, "admission", admission))
                assert(SafariPassageState.open(game, token))
                game.machine:current():update()
                game.machine:pop()
                assert(game.player == player and currentZone == zone and getOverworldView() == view)
                assert(session:inventory():money() == money and not session:safariData().active)
                token = assert(SafariPassage.prepare(game, "admission", admission))
                assert(SafariPassageState.open(game, token))
                local stagedTicks = 0
                while game.machine:current().phase ~= "after" do
                    stagedTicks = stagedTicks + 1
                    assert(stagedTicks < 80, "Safari destination did not stage")
                    game.machine:current():update()
                end
                game.machine:pop()
                assert(game.player == player and currentZone == zone and getOverworldView() == view)
                assert(view.sprite:isVisible() and session:inventory():money() == money)
                assert(not session:safariData().active)
                token = assert(SafariPassage.prepare(game, "admission", admission))
                assert(SafariPassageState.open(game, token))
                local elapsed = 0
                while game.machine:getCurrent() == "safariPassage" do
                    elapsed = elapsed + 1
                    assert(elapsed < 100, "Safari admission did not settle")
                    game.machine:current():update()
                end
                assert(currentZone.stableID == "pokered:SAFARI_ZONE_CENTER")
                assert(game.player.gridX == 15 and game.player.gridY == 24)
                assert(session:safariData().steps == 499 and session:inventory():money() == money - 500)
                for _ = 1, 500 do
                    assert(session:commitSafari(assert(SafariGame.step(session:safariData())), session:fieldWorldEpoch()))
                end
                assert(SafariRuntime.check(game))
                local passage = game.machine:current()
                while passage.dialog.isActive do passage.dialog:advance() end
                elapsed = 0
                while game.machine:getCurrent() == "safariPassage" do
                    elapsed = elapsed + 1
                    assert(elapsed < 100, "Safari forced return did not settle")
                    game.machine:current():update()
                end
                local gate = SourceMaps.entry("SafariZoneGate")
                assert(currentZone.stableID == gate.id and game.player.gridX == 3 + gate.padding and game.player.gridY == 3)
                assert(not session:safariData().active and session:safariData().balls == 0)
            end)
            if oldView and not oldView.disposed and oldView.zone == currentZone then currentZone:attachView(oldView) end
        end)
    end)
    test("Safari commands use separate ball supply and exact bait/rock/flee order, without ordinary battle fallback", function()
        local safari = assert(SafariGame.admit(SafariGame.empty(), 1000)).after
        local enemy = Pokemon("dratini", 15)
        local battle = assert(SafariBattle.begin(safari, enemy))
        local stream = RulesRNG.new(119)
        local globalBefore, before = RulesRNG.snapshot(), stream:snapshot()
        local parameters = assert(Capture.safariParameters(enemy, 45, 0))
        assert(parameters.safari and parameters.modifiedRate4096 == 92160)
        assert(Capture.safariParameters(enemy, 0, 0).shakeThreshold == 0)
        assert(not Capture.safariParameters(enemy, 256, 0))
        assert(not Capture.parameters({pokemon = enemy, wild = true}, "safariBall", 0))
        local result = assert(SafariBattle.plan(safari, battle, enemy, "ball", 0, stream))
        assert(result.after.balls == 29 and result.receipt.capture.ballId == "safariBall")
        assert(FieldMoves.same(globalBefore, RulesRNG.snapshot()))
        stream:restore(before)
        local run = assert(SafariBattle.plan(safari, battle, enemy, "run", 0, stream))
        assert(run.battle.outcome == "run" and run.after.balls == 30)
        assert(FieldMoves.same(before, stream:snapshot()))
        local fast = Pokemon("pikachu", 80)
        assert(fast.spe % 256 >= 128)
        local fastBattle = assert(SafariBattle.begin(safari, fast))
        local bait = assert(SafariBattle.plan(safari, fastBattle, fast, "bait", 0, stream))
        assert(bait.battle.catchRate == fastBattle.baseRate // 2)
        assert(bait.battle.outcome == "fled" and bait.receipt.forcedFlee and bait.receipt.fleeRoll == nil)
        assert(bait.after.balls == 30 and FieldMoves.same(globalBefore, RulesRNG.snapshot()))
        assert(not SafariBattle.plan(safari, battle, enemy, "fight", 0, stream))
        local ball = assert(SafariGame.ball(safari))
        assert(ball.after.balls == 29 and safari.balls == 30)
        local last = SafariGame.normalize({version = 1, active = true, steps = 10, balls = 1, ending = "none"})
        last = assert(SafariGame.ball(last)).after
        assert(last.ending == "none")
        assert(SafariGame.check(last).after.ending == "balls")
    end)
    test("Warden source handoff frees a full-bag slot atomically and never repeats HM04", function()
        VermilionStoryFixture.withScene("WardensHouse", {x = 2, y = 4}, function(game)
            local session = game.session
            assert(session:inventory():add("goldTeeth", 1))
            local ids = {}
            for id in pairs(ItemData.definitions) do
                if id ~= "goldTeeth" and id ~= "hm04" then
                    ids[#ids + 1] = id
                end
            end
            table.sort(ids)
            for _, id in ipairs(ids) do
                if #session:inventory():slots() == Inventory.CAPACITY then
                    break
                end
                session:inventory():add(id, 1)
            end
            assert(#session:inventory():slots() == Inventory.CAPACITY)
            local before = session:inventory():toData()
            local plan = MidgameServices.warden({flags = session:flags().quest,
                items = {goldTeeth = 1, hm04 = 0}, can_add = {hm04 = false}})
            assert(FieldMoves.same(before, session:inventory():toData()))
            assert(plan.changes.items[1].op == "handoff" and plan.changes.items[2].id == "hm04")
            assert(session:transact(plan.expected, plan.changes))
            assert(session:inventory():quantity("goldTeeth") == 0 and session:inventory():quantity("hm04") == 1)
            assert(session:questFlag("EVENT_GAVE_GOLD_TEETH") and session:questFlag("EVENT_GOT_HM04"))
            assert(not session:transact(plan.expected, plan.changes))
            local complete = MidgameServices.warden({flags = session:flags().quest, items = {}, can_add = {}})
            assert(complete.status == "already-complete" and not complete.expected)
        end)
    end)
    return report
end
