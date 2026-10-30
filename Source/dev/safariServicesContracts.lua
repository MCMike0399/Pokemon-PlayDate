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
    end)
    test("Safari commands use separate ball supply and exact bait/rock/flee order, without ordinary battle fallback", function()
        local safari = assert(SafariGame.admit(SafariGame.empty(), 1000)).after
        local enemy = Pokemon("dratini", 15)
        local battle = assert(SafariBattle.begin(safari, enemy))
        local stream = RulesRNG.new(119)
        local globalBefore, before = RulesRNG.snapshot(), stream:snapshot()
        local result, reason = SafariBattle.plan(safari, battle, enemy, "ball", 0, stream)
        assert(not result and reason == "safari-capture-policy-not-installed")
        assert(FieldMoves.same(before, stream:snapshot()) and FieldMoves.same(globalBefore, RulesRNG.snapshot()))
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
