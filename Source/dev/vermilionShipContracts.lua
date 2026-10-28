-- Real SDK image/sprite/owner witnesses. No host Lua or simulated runtime.
VermilionShipContracts = {}

local gfx <const> = playdate.graphics
local PENDING <const> = "VERMILION_SCENE_V1_DEPARTURE_PENDING"

local function equal(actual, expected)
    assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local function same(actual, expected)
    equal(type(actual), type(expected))
    if type(actual) ~= "table" then
        equal(actual, expected)
        return
    end
    for key, value in pairs(actual) do
        same(value, expected[key])
    end
    for key in pairs(expected) do
        assert(actual[key] ~= nil, "unexpected field: " .. tostring(key))
    end
end

-- Independent native-bit oracle, with explicit-zero patterns pinned by the
-- shared imported-art contract. It never calls the renderer under test.
local function color(code, x, y)
    if code == "." then
        return gfx.kColorWhite
    end
    if code == "#" then
        return gfx.kColorBlack
    end
    local light <const> = {0xBB, 0xFF, 0xEE, 0xFF, 0xBB, 0xFF, 0xEE, 0xFF}
    local dark <const> = {0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA}
    assert(code == "1" or code == "2", "source shade required")
    local byte <const> = (code == "1" and light or dark)[y % 8 + 1]
    return byte & (0x80 >> (x % 8)) ~= 0 and gfx.kColorWhite or gfx.kColorBlack
end

local function samePixels(actual, expected)
    local width, height = actual:getSize()
    local expectedWidth, expectedHeight = expected:getSize()
    equal(width, expectedWidth)
    equal(height, expectedHeight)
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            equal(actual:sample(x, y), expected:sample(x, y))
        end
    end
end

local function start(game)
    SourceEvents.dispatch(game, VermilionStory.DOCK)
    local event <const> = game.machine:get("event")
    equal(event.phase, "vermilion-departure")
    return event, assert(event.vermilionShip)
end

function VermilionShipContracts.run(withScene)
    assert(type(withScene) == "function", "actual provider-owned ship fixture required")
    local report = {ok = true, passed = 0, failed = 0, tests = {}}
    local function test(name, callback)
        local ok, problem = pcall(callback)
        report.tests[#report.tests + 1] = {name = name, ok = ok, error = not ok and tostring(problem) or nil}
        if ok then
            report.passed = report.passed + 1
        else
            report.failed = report.failed + 1
            report.ok = false
        end
    end
    local function dock(callback, quest)
        local options <const> = {
            x = 14,
            y = 1,
            quest = quest or {EVENT_GOT_HM01 = true, [PENDING] = true},
        }
        withScene("VermilionDock", options, callback)
    end

    test("source clock preserves waits, eight-frame scroll pixels and four-tile OAM wrap", function()
        equal(VermilionShipTimeline.at(0).phase, "smoke-load")
        equal(VermilionShipTimeline.at(4).phase, "initial-wait")
        equal(VermilionShipTimeline.at(124).phase, "background-transfer")
        local first <const> = VermilionShipTimeline.at(130)
        local held <const> = VermilionShipTimeline.at(137)
        local nextStep <const> = VermilionShipTimeline.at(138)
        equal(first.scroll_pixels, 0)
        equal(held.puff_oam_x, first.puff_oam_x)
        equal(first.puff_oam_x, 74)
        equal(nextStep.scroll_pixels, 1)
        equal(nextStep.puff_oam_x, 76)
        equal(VermilionShipTimeline.at(258).chunk, 2)
        equal(VermilionShipTimeline.at(258).puff_oam_x, 58)
        equal(VermilionShipTimeline.at(770).puff_visible, false)
        equal(VermilionShipTimeline.at(1153).scroll_pixels, 127)
        equal(VermilionShipTimeline.at(1154).phase, "erase-transfer")
        equal(VermilionShipTimeline.at(1156).phase, "final-wait")
        equal(VermilionShipTimeline.at(1276).phase, "player-reload")
        equal(VermilionShipTimeline.at(1279).complete, false)
        equal(VermilionShipTimeline.at(1280).phase, "walkout-delay")
        equal(VermilionShipTimeline.at(1282).complete, false)
        equal(VermilionShipTimeline.at(1283).complete, true)
    end)

    test("all hull pixels use original grids at explicit phase zero", function()
        local data <const> = VermilionShipArt.data()
        local hull <const> = VermilionShipArt.images().hull
        local width, height = hull:getSize()
        equal(width, 256)
        equal(height, 96)
        for cy, row in ipairs(data.hull.cells) do
            for cx, cell in ipairs(row) do
                for y = 0, 31 do
                    for x = 0, 31 do
                        local code <const> = cell.grid[y // 2 + 1]:sub(x // 2 + 1, x // 2 + 1)
                        equal(hull:sample((cx - 1) * 32 + x, (cy - 1) * 32 + y), color(code, x, y))
                    end
                end
            end
        end
    end)

    test("OBP1 zero leaves index-zero transparent and all original nonzero smoke white", function()
        local data <const> = VermilionShipArt.data()
        local smoke <const> = VermilionShipArt.images().smoke
        local mask <const> = assert(smoke:getMaskImage())
        for y = 0, 31 do
            for x = 0, 31 do
                local index <const> = data.smoke.source_indices[(y // 2) % 8 + 1][(x // 2) % 8 + 1]
                equal(mask:sample(x, y), index == 0 and gfx.kColorBlack or gfx.kColorWhite)
                if index ~= 0 then
                    equal(smoke:sample(x, y), gfx.kColorWhite)
                end
            end
        end
    end)

    test("render clock draw and cue observation preserve both RNG streams and durable owners", function()
        dock(function(game)
            local flags <const> = game.session:flags()
            local world <const> = WorldDeltas.export()
            local rules <const> = RulesRNG.toData()
            local worldRNG <const> = game.session:worldRngData()
            local playerX, playerY = game.player.gridX, game.player.gridY
            local event, ship = start(game)
            for _ = 1, 80 do
                game.machine:update()
                event:draw()
                ship:snapshot()
            end
            equal(ship:snapshot().phase, "scroll")
            equal(ship:snapshot().cues[3].symbol, "SFX_SS_ANNE_HORN")
            equal(ship:snapshot().cues[3].source_frame, 130)
            equal(ship:snapshot().audio_status, "cue-only-unaccepted")
            same(game.session:flags(), flags)
            same(WorldDeltas.export(), world)
            same(RulesRNG.toData(), rules)
            same(game.session:worldRngData(), worldRNG)
            equal(game.player.gridX, playerX)
            equal(game.player.gridY, playerY)
        end)
    end)

    test("audio seam emits pinned cues once during owned updates, never during draw or after cancel", function()
        local received = {}
        VermilionShip.setAudioSink(function(cue)
            received[#received + 1] = cue
        end)
        local ok, problem = pcall(function()
            dock(function(game)
                local event, ship = start(game)
                equal(#received, 2)
                for _ = 1, 65 do
                    game.machine:update()
                end
                equal(#received, 3)
                equal(received[3].source_frame, 130)
                for _ = 1, 8 do
                    event:draw()
                    ship:snapshot()
                end
                equal(#received, 3)
                game.machine:change("overworld")
                equal(ship:update(), false)
                equal(#received, 3)
            end)
        end)
        VermilionShip.setAudioSink(nil)
        assert(ok, problem)
    end)

    test("movement holds seven source frames then moves one pixel with original smoke drift", function()
        local image <const> = gfx.image.new(896, 96, gfx.kColorWhite)
        VermilionShipArt.render(image, VermilionShipTimeline.at(130))
        local first <const> = image:copy()
        VermilionShipArt.render(image, VermilionShipTimeline.at(137))
        samePixels(image, first)
        VermilionShipArt.render(image, VermilionShipTimeline.at(138))
        local changed = false
        for y = 0, 95 do
            for x = 0, 895 do
                if image:sample(x, y) ~= first:sample(x, y) then
                    changed = true
                end
            end
        end
        assert(changed, "native ship scroll did not change pixels")
    end)

    test("cancellation in moving hull restores native map and rejects old presentation/callback", function()
        dock(function(game)
            local world <const> = WorldDeltas.export()
            local event, ship = start(game)
            for _ = 1, 200 do
                game.machine:update()
            end
            equal(ship:snapshot().phase, "scroll")
            local callback <const> = event:guard(function()
                error("cancelled ship callback executed")
            end)
            game.machine:change("overworld")
            callback()
            equal(ship.closed, true)
            equal(VermilionShip.current(game), nil)
            equal(ship:update(), false)
            equal(game.session:questFlag("EVENT_SS_ANNE_LEFT"), false)
            equal(game.session:questFlag(PENDING), true)
            same(WorldDeltas.export(), world)
        end)
    end)

    test("early advance cannot commit hull erasure before the full presentation", function()
        dock(function(game)
            local world <const> = WorldDeltas.export()
            local event, ship = start(game)
            event:advance()
            equal(event.phase, "failed")
            equal(event.waiting, "ship-presentation-incomplete")
            equal(ship.closed, true)
            equal(game.session:questFlag("EVENT_SS_ANNE_LEFT"), false)
            same(WorldDeltas.export(), world)
        end)
    end)

    test("scene commit follows final horn wait/reload and retained water survives overlay pop", function()
        dock(function(game)
            local world <const> = WorldDeltas.export()
            local event, ship = start(game)
            for _ = 1, 641 do
                game.machine:update()
            end
            equal(ship:snapshot().source_frame, 1282)
            equal(ship:snapshot().phase, "walkout-delay")
            equal(game.session:questFlag("EVENT_SS_ANNE_LEFT"), false)
            same(WorldDeltas.export(), world)
            game.machine:update()
            equal(ship:snapshot().complete, true)
            equal(game.session:questFlag("EVENT_SS_ANNE_LEFT"), true)
            equal(ship.retained, true)
            equal(ship.closed, false)
            equal(#ship:snapshot().cues, 4)
            equal(ship:snapshot().cues[4].source_frame, 1156)
            -- The event can pop into DoorWarp without revealing its unchanged
            -- upper source hull. Only actual world exit releases the band.
            game.machine:change("overworld")
            equal(ship.closed, false)
            equal(VermilionShip.current(game), ship)
            VermilionShip.onLeave(game, "pokered:VERMILION_CITY")
            equal(ship.closed, true)
            equal(VermilionShip.current(game), nil)
        end)
    end)

    test("session/player/zone/epoch replacement rejects stale presentation without advancing graphics", function()
        for _, kind in ipairs({"session", "epoch", "player", "zone"}) do
            dock(function(game)
                local event, ship = start(game)
                local session, player, epoch, zone = game.session, game.player, event.epoch, currentZone
                if kind == "session" then
                    game.session = GameContext({sessionLocationPolicy = PewterWorld.locationPolicy()}).session
                elseif kind == "epoch" then
                    event.epoch = epoch + 1
                elseif kind == "zone" then
                    currentZone = WorldDeltas.ensureZone(SourceMaps.entry("VermilionCity").key)
                else
                    game.player = nil
                end
                local frame <const> = ship:snapshot().source_frame
                equal(ship:update(), false)
                equal(ship:snapshot().source_frame, frame)
                if kind == "zone" then
                    VermilionShip.beforeSpawn(game)
                    equal(ship.closed, true)
                end
                game.session, game.player, event.epoch, currentZone = session, player, epoch, zone
                equal(session:questFlag("EVENT_SS_ANNE_LEFT"), false)
            end)
        end
    end)

    test("missing actual exit intent cannot construct any ship presentation", function()
        dock(function(game)
            SourceEvents.dispatch(game, VermilionStory.DOCK)
            local event <const> = game.machine:get("event")
            local count <const> = gfx.sprite.spriteCount()
            equal(pcall(function()
                VermilionShip(event)
            end), false)
            equal(gfx.sprite.spriteCount(), count)
            equal(game.session:questFlag("EVENT_SS_ANNE_LEFT"), false)
        end, {EVENT_GOT_HM01 = true})
    end)
    return report
end
