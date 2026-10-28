-- Delegation only. Root keeps its existing MidgameServices/SourceEvents chain.
CeladonServicesController = {}
local gfx <const> = playdate.graphics
local function finishText(state, labels)
    state:source(labels, function() state:finish() end)
end
local function menu(state, options, selected, cancelled)
    state.phase, state.waiting = "celadon-menu", state.plan.service
    local choose = state:guard(function(index)
        state.menu:hide()
        state.menu.onSelect, state.menu.onCancel = nil, nil
        state.phase = "celadon-running"
        if index then selected(index) else cancelled() end
    end)
    state.menu:show(options, choose, function() choose(nil) end)
end
local function yesNo(state, selected, cancelled)
    menu(state, {"YES", "NO"}, function(index)
        if index == 1 then selected() else cancelled() end
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
    if accepted then state.committed = true end
    return accepted, result
end
local function vending(state)
    state:source({"_VendingMachineText1"}, function()
        local observation = observe(state)
        if not observation then return end
        local drinks = CeladonServices.policy().drinks
        local options = {}
        for _, drink in ipairs(drinks) do
            options[#options+1] = ItemData.definitions[drink.item].name .. "  ¥" .. drink.price
        end
        options[#options+1] = "CANCEL"
        local function cancel()
            finishText(state, {"_VendingMachineText7"})
        end
        menu(state, options, function(index)
            if index == #options then cancel(); return end
            local accepted, result = commit(state, observation, {kind="vending",choice=index})
            if accepted then
                state.plan.ram = {wStringBuffer=ItemData.definitions[drinks[index].item].name}
                finishText(state, {"_VendingMachineText5"})
            elseif result == "insufficient-money" then
                finishText(state, {"_VendingMachineText4"})
            elseif result == "bag-full" then
                finishText(state, {"_VendingMachineText6"})
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
            available[#available+1] = index
            options[#options+1] = ItemData.definitions[drink.item].name
        end
    end
    if #available == 0 then
        finishText(state, {"_CeladonMartRoofLittleGirlImThirstyText"})
        return
    end
    state:source({"_CeladonMartRoofLittleGirlGiveHerADrinkText"}, function()
        yesNo(state, function()
            state:source({"_CeladonMartRoofLittleGirlGiveHerWhichDrinkText"}, function()
                local observation = observe(state)
                if not observation then return end
                menu(state, options, function(selected)
                    local index = available[selected]
                    local drink = policy.drinks[index]
                    if state.session:questFlag(drink.flag) then
                        finishText(state, {"_CeladonMartRoofLittleGirlImNotThirstyText"})
                        return
                    end
                    local accepted, reason = commit(state, observation, {kind="drink-girl",choice=index})
                    if not accepted then
                        if reason == "bag-full" then
                            finishText(state, {"_CeladonMartRoofLittleGirlNoRoomText"})
                        elseif reason == "already-gave-drink" then
                            finishText(state, {"_CeladonMartRoofLittleGirlImNotThirstyText"})
                        else
                            state:fail(reason)
                        end
                        return
                    end
                    state.plan.ram = {wStringBuffer=ItemData.definitions[drink.tm].name}
                    local number = drink.tm:sub(3)
                    finishText(state, {"_CeladonMartRoofLittleGirlYay" .. drink.source_name .. "Text",
                        "_CeladonMartRoofLittleGirlReceivedTM" .. number .. "Text",
                        "_CeladonMartRoofLittleGirlTM" .. number .. "ExplanationText"})
                end, function() state:finish() end)
            end)
        end, function() state:finish() end)
    end)
end
local function eevee(state)
    local gift = CeladonServices.policy().eevee
    if state.session:questFlag(gift.flag) then state:finish(); return end
    local accepted, result = state.session:purchaseGiftPokemon({species=gift.species,level=gift.level,price=0,flag=gift.flag},
        state.session:inventory():money())
    if not accepted then
        if result == "box-full" then finishText(state, {"_BoxIsFullText"})
        else state:fail(result) end
        return
    end
    state.committed = true
    state.plan.ram = {wNameBuffer="EEVEE",wBoxMonNicks="EEVEE",wStringBuffer=tostring(result.box or 1)}
    local labels = {"_GotMonText"}
    if result.destination == "storage" then labels[#labels+1] = "_SentToBoxText" end
    state:source(labels, function()
        CeladonServices.reconcileActors(state.game)
        state:finish()
    end)
end
local function coins(state)
    local prefix = "_GameCornerClerk1"
    state:source({prefix .. "DoYouNeedSomeGameCoinsText"}, function()
        local observation = observe(state)
        if not observation then return end
        local function cancel()
            finishText(state, {prefix .. "PleaseComePlaySometimeText"})
        end
        yesNo(state, function()
            local accepted, result = commit(state, observation, {kind="coin-exchange"})
            if accepted then finishText(state, {prefix .. "ThanksHereAre50CoinsText"})
            elseif result == "no-coin-case" then finishText(state, {prefix .. "DontHaveCoinCaseText"})
            elseif result == "coin-case-full" then finishText(state, {prefix .. "CoinCaseIsFullText"})
            elseif result == "insufficient-money" then finishText(state, {prefix .. "CantAffordTheCoinsText"})
            else state:fail(result) end
        end, cancel)
    end)
end
local function coinGift(state)
    local gift = assert(CeladonServices.coinGift(state.id))
    if state.session:questFlag(gift.flag) then
        finishText(state, {gift.prefix .. gift.after})
        return
    end
    state:source({gift.prefix .. gift.before}, function()
        local observation = observe(state)
        if not observation then return end
        local accepted, reason = commit(state, observation, {kind="coin-gift",id=state.id})
        if accepted then finishText(state, {gift.prefix .. gift.received})
        elseif reason == "no-coin-case" then finishText(state, {"_GameCornerOopsForgotCoinCaseText"})
        elseif reason == "coin-case-full" then finishText(state, {gift.prefix .. gift.full})
        elseif reason == "already-complete" then finishText(state, {gift.prefix .. gift.after})
        else state:fail(reason) end
    end)
end
function CeladonServicesController.enter(state)
    state.celadonStarted = false
end
function CeladonServicesController.advance(state)
    if not state.plan or state.plan.scene ~= "celadon-service" then return false end
    if not state:valid() or not state:isTop() then return true end
    if state.celadonStarted then return true end
    state.celadonStarted = true
    local service = state.plan.service
    if service == "vending" then vending(state)
    elseif service == "drink-girl" then drinks(state)
    elseif service == "eevee" then eevee(state)
    elseif service == "coin-exchange" then coins(state)
    elseif service == "coin-gift" then coinGift(state)
    else state:fail("unimplemented-Celadon-service") end
    return true
end
function CeladonServicesController.handleButton(state, button)
    if state.phase ~= "celadon-menu" or not state:valid() or not state:isTop() then return false end
    local count = #state.menu.options
    if button == "up" then state.menu.selectedIndex = (state.menu.selectedIndex - 2) % count + 1
    elseif button == "down" then state.menu.selectedIndex = state.menu.selectedIndex % count + 1
    elseif button == "a" then state.menu.onSelect(state.menu.selectedIndex)
    elseif button == "b" then state.menu.onCancel() end
    return true
end
function CeladonServicesController.draw(state)
    if not state:valid() or not state.plan or state.plan.scene ~= "celadon-service" then return end
    gfx.pushContext()
    gfx.setDrawOffset(0, 0)
    gfx.clearClipRect()
    if state.phase == "celadon-menu" then
        state.menu:draw(168, 64, 228, math.min(128, #state.menu.options * 20 + 16))
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
