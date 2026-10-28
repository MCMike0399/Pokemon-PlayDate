-- Delegation only. Root keeps its existing MidgameServices/SourceEvents chain.
CeladonServicesController = {}
local gfx <const> = playdate.graphics
local function finishText(state, labels)
    state:source(labels, function()
        state:finish()
    end)
end
local function menu(state, options, selected, cancelled)
    state.phase, state.waiting = "celadon-menu", state.plan.service
    local choose = state:guard(function(index)
        state.menu:hide()
        state.menu.onSelect, state.menu.onCancel = nil, nil
        state.phase = "celadon-running"
        if index then
            selected(index)
        else
            cancelled()
        end
    end)
    state.menu:show(options, choose, function()
        choose(nil)
    end)
end
local function yesNo(state, selected, cancelled)
    menu(state, { "YES", "NO" }, function(index)
        if index == 1 then
            selected()
        else
            cancelled()
        end
    end, cancelled)
end
local function observe(state)
    if type(state.session.commitCeladonService) ~= "function" or type(state.session.coins) ~= "function" then
        state:fail("Celadon-economy-owner-not-installed")
        return nil
    end
    return CeladonEconomy.observe(state.session)
end
local function commit(state, observation, operation)
    local accepted, result = state.session:commitCeladonService(operation, observation)
    if accepted then
        state.committed = true
    end
    return accepted, result
end
local function vending(state)
    state:source({ "_VendingMachineText1" }, function()
        local observation = observe(state)
        if not observation then
            return
        end
        local drinks = CeladonServices.policy().drinks
        local options = {}
        for _, drink in ipairs(drinks) do
            options[#options + 1] = ItemData.definitions[drink.item].name .. "  ¥" .. drink.price
        end
        options[#options + 1] = "CANCEL"
        local function cancel()
            finishText(state, { "_VendingMachineText7" })
        end
        menu(state, options, function(index)
            if index == #options then
                cancel()
                return
            end
            local accepted, result = commit(state, observation, { kind = "vending", choice = index })
            if accepted then
                state.plan.ram = { wStringBuffer = ItemData.definitions[drinks[index].item].name }
                finishText(state, { "_VendingMachineText5" })
            elseif result == "insufficient-money" then
                finishText(state, { "_VendingMachineText4" })
            elseif result == "bag-full" then
                finishText(state, { "_VendingMachineText6" })
            else
                state:fail(result)
            end
        end, cancel)
    end)
end
local function drinks(state)
    local policy = CeladonServices.policy()
    local available, options = {}, {}
    for index, drink in ipairs(policy.drinks) do
        if state.session:inventory():quantity(drink.item) > 0 then
            available[#available + 1] = index
            options[#options + 1] = ItemData.definitions[drink.item].name
        end
    end
    if #available == 0 then
        finishText(state, { "_CeladonMartRoofLittleGirlImThirstyText" })
        return
    end
    state:source({ "_CeladonMartRoofLittleGirlGiveHerADrinkText" }, function()
        yesNo(state, function()
            state:source({ "_CeladonMartRoofLittleGirlGiveHerWhichDrinkText" }, function()
                local observation = observe(state)
                if not observation then
                    return
                end
                menu(state, options, function(selected)
                    local index = available[selected]
                    local drink = policy.drinks[index]
                    if state.session:questFlag(drink.flag) then
                        finishText(state, { "_CeladonMartRoofLittleGirlImNotThirstyText" })
                        return
                    end
                    local accepted, reason =
                        commit(state, observation, { kind = "drink-girl", choice = index })
                    if not accepted then
                        if reason == "bag-full" then
                            finishText(state, { "_CeladonMartRoofLittleGirlNoRoomText" })
                        elseif reason == "already-gave-drink" then
                            finishText(state, { "_CeladonMartRoofLittleGirlImNotThirstyText" })
                        else
                            state:fail(reason)
                        end
                        return
                    end
                    state.plan.ram = { wStringBuffer = ItemData.definitions[drink.tm].name }
                    local number = drink.tm:sub(3)
                    finishText(
                        state,
                        {
                            "_CeladonMartRoofLittleGirlYay" .. drink.source_name .. "Text",
                            "_CeladonMartRoofLittleGirlReceivedTM" .. number .. "Text",
                            "_CeladonMartRoofLittleGirlTM" .. number .. "ExplanationText",
                        }
                    )
                end, function()
                    state:finish()
                end)
            end)
        end, function()
            state:finish()
        end)
    end)
end
local function eevee(state)
    local gift = CeladonServices.policy().eevee
    if state.session:questFlag(gift.flag) then
        state:finish()
        return
    end
    local accepted, result = state.session:purchaseGiftPokemon(
        { species = gift.species, level = gift.level, price = 0, flag = gift.flag },
        state.session:inventory():money()
    )
    if not accepted then
        if result == "box-full" then
            finishText(state, { "_BoxIsFullText" })
        else
            state:fail(result)
        end
        return
    end
    state.committed = true
    state.plan.ram =
        { wNameBuffer = "EEVEE", wBoxMonNicks = "EEVEE", wStringBuffer = tostring(result.box or 1) }
    local labels = { "_GotMonText" }
    if result.destination == "storage" then
        labels[#labels + 1] = "_SentToBoxText"
    end
    state:source(labels, function()
        CeladonServices.reconcileActors(state.game)
        state:finish()
    end)
end
local function coins(state)
    local prefix = "_GameCornerClerk1"
    state:source({ prefix .. "DoYouNeedSomeGameCoinsText" }, function()
        local observation = observe(state)
        if not observation then
            return
        end
        local function cancel()
            finishText(state, { prefix .. "PleaseComePlaySometimeText" })
        end
        yesNo(state, function()
            local accepted, result = commit(state, observation, { kind = "coin-exchange" })
            if accepted then
                finishText(state, { prefix .. "ThanksHereAre50CoinsText" })
            elseif result == "no-coin-case" then
                finishText(state, { prefix .. "DontHaveCoinCaseText" })
            elseif result == "coin-case-full" then
                finishText(state, { prefix .. "CoinCaseIsFullText" })
            elseif result == "insufficient-money" then
                finishText(state, { prefix .. "CantAffordTheCoinsText" })
            else
                state:fail(result)
            end
        end, cancel)
    end)
end
local function coinGift(state)
    local gift = assert(CeladonServices.coinGift(state.id))
    if state.session:questFlag(gift.flag) then
        finishText(state, { gift.prefix .. gift.after })
        return
    end
    state:source({ gift.prefix .. gift.before }, function()
        local observation = observe(state)
        if not observation then
            return
        end
        local accepted, reason = commit(state, observation, { kind = "coin-gift", id = state.id })
        if accepted then
            finishText(state, { gift.prefix .. gift.received })
        elseif reason == "no-coin-case" then
            finishText(state, { "_GameCornerOopsForgotCoinCaseText" })
        elseif reason == "coin-case-full" then
            finishText(state, { gift.prefix .. gift.full })
        elseif reason == "already-complete" then
            finishText(state, { gift.prefix .. gift.after })
        else
            state:fail(reason)
        end
    end)
end
local function prizes(state)
    if state.session:inventory():quantity("coinCase") == 0 then
        finishText(state, { "_RequireCoinCaseText" })
        return
    end
    state:source({ "_ExchangeCoinsForPrizesText", "_WhichPrizeText" }, function()
        local observation = observe(state)
        if not observation then
            return
        end
        local window = assert(CeladonServices.policy().prizes[state.plan.window])
        local options = {}
        for _, prize in ipairs(window) do
            local name = prize.item and ItemData.definitions[prize.item].name or prize.species:upper()
            options[#options + 1] = name .. "  " .. prize.price
        end
        options[#options + 1] = "NO THANKS"
        menu(state, options, function(index)
            if index == #options then
                state:finish()
                return
            end
            local prize = window[index]
            state.plan.ram = {
                wNameBuffer = prize.item and ItemData.definitions[prize.item].name or prize.species:upper(),
            }
            state:source({ "_SoYouWantPrizeText" }, function()
                yesNo(state, function()
                    local accepted, result = commit(
                        state,
                        observation,
                        { kind = "prize", window = state.plan.window, choice = index }
                    )
                    if not accepted then
                        if result == "insufficient-coins" then
                            finishText(state, { "_SorryNeedMoreCoinsText" })
                        elseif result == "bag-full" then
                            finishText(state, { "_OopsYouDontHaveEnoughRoomText" })
                        elseif result == "box-full" then
                            finishText(state, { "_BoxIsFullText" })
                        elseif result == "no-coin-case" then
                            finishText(state, { "_RequireCoinCaseText" })
                        else
                            state:fail(result)
                        end
                        return
                    end
                    if prize.item then
                        state:finish()
                        return
                    end
                    state.plan.ram = {
                        wNameBuffer = prize.species:upper(),
                        wBoxMonNicks = prize.species:upper(),
                        wStringBuffer = tostring(result.box or 1),
                    }
                    local labels = { "_GotMonText" }
                    if result.destination == "storage" then
                        labels[#labels + 1] = "_SentToBoxText"
                    end
                    finishText(state, labels)
                end, function()
                    finishText(state, { "_OhFineThenText" })
                end)
            end)
        end, function()
            state:finish()
        end)
    end)
end
local function hiddenCoins(state)
    local hidden = assert(CeladonServices.hiddenCoin(state.id))
    local observation = observe(state)
    if not observation then
        return
    end
    local accepted, result = commit(state, observation, { kind = "hidden-coins", id = state.id })
    if not accepted then
        if result == "already-complete" or result == "no-coin-case" then
            state:finish()
        else
            state:fail(result)
        end
        return
    end
    state.plan.ram = { hCoins = result.received, wStringBuffer = tostring(result.received) }
    finishText(
        state,
        result.dropped and { "_FoundHiddenCoins2Text", "_DroppedHiddenCoinsText" }
            or { "_FoundHiddenCoinsText" }
    )
end
local function elevator(state)
    state:source({ "_WhichFloorText" }, function()
        menu(state, { "1F", "2F", "3F", "4F", "5F" }, function(index)
            local accepted, reason = CeladonServices.selectFloor(state.session, index)
            if accepted then
                state:finish()
            else
                state:fail(reason)
            end
        end, function()
            state:finish()
        end)
    end)
end
local function closeSlots(state)
    if state.celadonSlotToken then
        state.celadonSlotSession:closeCeladonSlots(state.celadonSlotToken)
        state.celadonSlotToken, state.celadonSlotView, state.celadonSlotSession = nil, nil, nil
    end
end
local betMenu
local function slotResult(state)
    local view = state.celadonSlotView
    state.plan.ram = { wStringBuffer = tostring(view.payout) }
    local labels = view.payout == 0 and { "_NotThisTimeText" }
        or view.winner == "SLOTS7" and { "_YeahText", "_LinedUpText" }
        or { "_LinedUpText" }
    state:source(labels, function()
        if state.session:coins() == 0 then
            state:source({ "_OutOfCoinsSlotMachineText" }, function()
                closeSlots(state)
                state:finish()
            end)
            return
        end
        state:source({ "_OneMoreGoSlotMachineText" }, function()
            yesNo(state, function()
                local accepted, result = state.session:againCeladonSlots(state.celadonSlotToken)
                if not accepted then
                    state:fail(result)
                    return
                end
                state.celadonSlotView = result
                betMenu(state)
            end, function()
                closeSlots(state)
                state:finish()
            end)
        end)
    end)
end
betMenu = function(state)
    state:source({ "_BetHowManySlotMachineText" }, function()
        menu(state, { "×3", "×2", "×1" }, function(index)
            local accepted, result = state.session:betCeladonSlots(state.celadonSlotToken, 4 - index)
            if not accepted then
                if result == "insufficient-coins" then
                    state:source({ "_NotEnoughCoinsSlotMachineText" }, function()
                        betMenu(state)
                    end)
                else
                    state:fail(result)
                end
                return
            end
            state.celadonSlotView = result
            state:source({ "_StartSlotMachineText" }, function()
                accepted, result = state.session:startCeladonSpin(state.celadonSlotToken)
                if not accepted then
                    state:fail(result)
                    return
                end
                state.celadonSlotView = result
                state.celadonFirstReelView = false
                state.phase, state.waiting = "celadon-slots", "reels"
            end)
        end, function()
            closeSlots(state)
            state:finish()
        end)
    end)
end
local function slots(state)
    if state.session:inventory():quantity("coinCase") == 0 then
        finishText(state, { "_GameCornerCoinCaseText" })
        return
    end
    if type(state.session.coins) ~= "function" or type(state.session.openCeladonSlots) ~= "function" then
        state:fail("slot-owner-not-installed")
        return
    end
    if state.session:coins() == 0 then
        finishText(state, { "_GameCornerNoCoinsText" })
        return
    end
    state:source({ "_PlaySlotMachineText" }, function()
        yesNo(state, function()
            local token, result = state.session:openCeladonSlots(state, state.id)
            if not token then
                state:fail(result)
                return
            end
            state.celadonSlotToken, state.celadonSlotView, state.celadonSlotSession =
                token, result, state.session
            state.celadonFirstReelView = true
            betMenu(state)
        end, function()
            state:finish()
        end)
    end)
end
local symbolImages = {}
local function symbolImage(symbol)
    if not symbolImages[symbol] then
        symbolImages[symbol] =
            TileRegistry.renderImportedGrid(CeladonServiceData.symbol(symbol), TileFactory.renderGrid)
    end
    return symbolImages[symbol]
end
local function drawSlots(state)
    local view = state.celadonSlotView
    -- LoadSlotMachineTiles drew offset 28 before the source clears offsets.
    -- Keep that opening picture separate from the actual zeroed reel value.
    local display = state.celadonFirstReelView and { offsets = { 29, 29, 29 } } or view
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(0, 0, 400, 240)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(4, 4, 392, 168)
    gfx.drawText("COIN " .. state.session:coins() .. "    PAYOUT " .. view.payout, 12, 12)
    gfx.drawText("BET " .. view.bet, 310, 12)
    for wheel = 1, 3 do
        local x = 72 + (wheel - 1) * 62
        gfx.drawRect(x - 3, 45, 38, 102)
        gfx.setClipRect(x, 48, 32, 96)
        local rows = CeladonSlots.rows(display, wheel)
        local shift = display.offsets[wheel] % 2 == 0 and -16 or 0
        for row = 1, 3 do
            symbolImage(rows[row]):draw(x, 48 + (3 - row) * 32 + shift)
        end
        if shift ~= 0 then
            symbolImage(CeladonSlots.previousSymbol(display, wheel)):draw(x, 128)
        end
        gfx.clearClipRect()
    end
    gfx.drawText(view.phase == "result" and "" or "A: STOP", 72, 151)
    if view.phase == "result" and view.winner then
        symbolImage(view.winner):draw(310, 110)
    end
end
function CeladonServicesController.enter(state)
    closeSlots(state)
    state.celadonStarted = false
    state.celadonFirstReelView = false
    state.celadonSlotToken, state.celadonSlotView, state.celadonSlotSession = nil, nil, nil
end
function CeladonServicesController.advance(state)
    if not state.plan or state.plan.scene ~= "celadon-service" then
        return false
    end
    if not state:valid() or not state:isTop() then
        return true
    end
    if state.celadonStarted then
        return true
    end
    state.celadonStarted = true
    local service = state.plan.service
    if service == "vending" then
        vending(state)
    elseif service == "drink-girl" then
        drinks(state)
    elseif service == "eevee" then
        eevee(state)
    elseif service == "coin-exchange" then
        coins(state)
    elseif service == "coin-gift" then
        coinGift(state)
    elseif service == "prize" then
        prizes(state)
    elseif service == "hidden-coins" then
        hiddenCoins(state)
    elseif service == "elevator" then
        elevator(state)
    elseif service == "slots" then
        slots(state)
    else
        state:fail("unimplemented-Celadon-service")
    end
    return true
end
function CeladonServicesController.handleButton(state, button)
    if not state:valid() or not state:isTop() then
        return false
    end
    if state.phase == "celadon-slots" then
        return true
    end
    if state.phase ~= "celadon-menu" then
        return false
    end
    local count = #state.menu.options
    if button == "up" then
        state.menu.selectedIndex = (state.menu.selectedIndex - 2) % count + 1
    elseif button == "down" then
        state.menu.selectedIndex = state.menu.selectedIndex % count + 1
    elseif button == "a" then
        state.menu.onSelect(state.menu.selectedIndex)
    elseif button == "b" then
        state.menu.onCancel()
    end
    return true
end
function CeladonServicesController.draw(state)
    if not state:valid() or not state.plan or state.plan.scene ~= "celadon-service" then
        return
    end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    if state.celadonSlotView then
        drawSlots(state)
    end
    if state.phase == "celadon-menu" then
        state.menu:draw(168, 64, 228, math.min(128, #state.menu.options * 20 + 16))
    end
    if state.celadonSlotView then
        gfx.popContext()
        return
    end
    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect(196, 4, 200, 44)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect(196, 4, 200, 44)
    gfx.drawText("MONEY  ¥" .. state.session:inventory():money(), 204, 8)
    if type(state.session.coins) == "function" then
        gfx.drawText("COIN   " .. state.session:coins(), 204, 27)
    end
    gfx.popContext()
end

function CeladonServicesController.update(state)
    if not state:valid() or not state:isTop() or state.phase ~= "celadon-slots" then
        return
    end
    local accepted, result =
        state.session:tickCeladonSlots(state.celadonSlotToken, playdate.buttonJustPressed(playdate.kButtonA))
    if not accepted then
        state:fail(result)
        return
    end
    state.celadonSlotView = result
    if result.phase == "result" then
        slotResult(state)
    end
end
function CeladonServicesController.exit(state)
    closeSlots(state)
end
