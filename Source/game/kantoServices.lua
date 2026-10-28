-- Three bespoke Blue services. SourceEvents selects, EventState guards UI,
-- and GameSession alone commits durable effects. Ordinary events stay separate.
KantoServices = {}
local gfx <const> = playdate.graphics
local CONTENT <const> = "kantoServices"
local REVISION <const> = "af519899719f0754965776faac0e836a3b906e6d"
local MUSEUM <const> = "pokered:MUSEUM_1F:objects:1"
local cached = {}
local function data(name)
    if not cached[name] then
        local value = assert(json.decodeFile("data/kantoServices/" .. name .. ".json"))
        assert(value.schema == 1 and value.source_revision == REVISION, "unverified Kanto service data")
        cached[name] = value
    end
    return cached[name]
end
function KantoServices.descriptors() return GameSession._copy(data("events").events) end
function KantoServices.policy() return GameSession._copy(data("policy")) end
function KantoServices.text(label)
    return GameSession._copy(assert(data("dialogue").texts[label], "missing service source text"))
end
function KantoServices.plan(id)
    local descriptor = assert(data("events").events[id], "unsupported service identity")
    return {status="ready", scene="kanto-service", service=descriptor.service, steps={}}
end
function KantoServices.install()
    local events = KantoServices.descriptors()
    for id in pairs(events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate Kanto service registration")
    end
    for id in pairs(events) do
        local stableID = id
        SourceEventHandlers[id] = function() return KantoServices.plan(stableID) end
    end
    SourceEvents.registerEventSource(CONTENT, events)
    SourceEvents.registerTextSource(CONTENT, KantoServices.text)
end

-- Blue's Pewter default script resets admission, including a Continue in town.
-- Never reset on Museum1F/2F entry or Continue there. No back-door access grant.
function KantoServices.onMapEnter(session, zoneID)
    local museum = data("policy").museum
    if zoneID == museum.reset_map and session:questFlag(museum.flag) then
        return session:setQuestFlag(museum.flag, false)
    end
    return true
end
function KantoServices.check(game)
    if game.machine:getCurrent() ~= "overworld" or game.session:getIntro().stage ~= "done"
        or not currentZone or currentZone.stableID ~= "pokered:MUSEUM_1F" then return false end
    local player = game.player
    if not player or player.isMoving or player.pendingEdgeDoor or player.pendingConnection then return false end
    local museum = data("policy").museum
    if game.session:questFlag(museum.flag) or player.gridY ~= museum.trigger_y then return false end
    local entry = SourceMaps.entry("Museum1F")
    local x = player.gridX - entry.padding
    for _, triggerX in ipairs(museum.trigger_x) do
        if x == triggerX then return SourceEvents.dispatch(game, MUSEUM) end
    end
    return false
end
function KantoServices.museumPurchase(session, expectedMoney)
    local offer = data("policy").museum
    return session:transact({flags={[offer.flag]=false}, items={}, money=expectedMoney},
        {flags={[offer.flag]=true}, items={}, money={op="debit", amount=offer.price}})
end
function KantoServices.bicycleExchange(session)
    local offer = data("policy").bicycle
    local bag = session:inventory()
    -- Source order matters: a full bag must fail even if removing the voucher
    -- first would make space. Session validates the whole detached transaction.
    return session:transact({flags={[offer.flag]=false},
        items={[offer.voucher]=bag:quantity(offer.voucher), [offer.item]=bag:quantity(offer.item)}},
        {flags={[offer.flag]=true}, items={{op="add", id=offer.item, quantity=1},
            {op="handoff", id=offer.voucher, quantity=1}}})
end
function KantoServices.magikarpPurchase(session, expectedMoney)
    return session:purchaseGiftPokemon(GameSession._copy(data("policy").magikarp), expectedMoney)
end

-- Import after the existing scene stack; every other event retains its owner.
Class("KantoServicesState"):extends(CeruleanRoutesState or CeruleanEventState or EventState)
function KantoServicesState:enter(id, options)
    self.serviceStarted = false
    self.serviceMoney = false
    KantoServicesState.super.enter(self, id, options)
end
function KantoServicesState:serviceText(labels, callback)
    self:source(labels, callback or function() self:finish() end)
end
function KantoServicesState:serviceChoice(options, callback)
    self.phase, self.waiting = "service-choice", self.plan.service
    local selected = self:guard(function(index)
        self.menu:hide()
        self.menu.onSelect, self.menu.onCancel = nil, nil
        callback(index == 1)
    end)
    self.menu:show(options, selected, function() selected(2) end)
end
function KantoServicesState:advance()
    if not self.plan or self.plan.scene ~= "kanto-service" then
        return KantoServicesState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then return end
    if self.serviceStarted then self:finish(); return end
    self.serviceStarted = true
    local service = self.plan.service
    if service == "museum" then self:museum()
    elseif service == "magikarp" then self:magikarp()
    elseif service == "bicycle" then self:bicycle()
    else self:fail("unsupported-kanto-service") end
end
function KantoServicesState:denyMuseum(labels)
    self:serviceText(labels, function() self:startMove("down") end)
end
function KantoServicesState:museum()
    local x = self.player.gridX - SourceMaps.entry("Museum1F").padding
    local y = self.player.gridY
    local prefix = "_Museum1FScientist1"
    if y == 4 and x == 13 or y == 3 and x == 12 then
        self:serviceText({prefix .. "DoYouKnowWhatAmberIsText"}, function()
            self:serviceChoice({"YES", "NO"}, function(yes)
                self:serviceText({prefix .. (yes and "TheresALabSomewhereText" or "AmberIsFossilizedTreeSapText")})
            end)
        end)
    elseif self.session:questFlag(data("policy").museum.flag) then
        self:serviceText({prefix .. "TakePlentyOfTimeText"})
    elseif y ~= 4 then
        self:serviceText({prefix .. "GoToOtherSideText"})
    else
        self.serviceMoney = true
        local money = self.session:inventory():money()
        self:serviceText({prefix .. "WouldYouLikeToComeInText"}, function()
            self:serviceChoice({"YES", "NO"}, function(yes)
                if not yes then self:denyMuseum({prefix .. "ComeAgainText"}); return end
                local ok, reason = KantoServices.museumPurchase(self.session, money)
                if ok then
                    self.committed = true
                    self:serviceText({prefix .. "ThankYouText"})
                elseif reason:find("insufficient-money", 1, true) then
                    self:denyMuseum({prefix .. "DontHaveEnoughMoneyText", prefix .. "ComeAgainText"})
                else self:fail(reason) end
            end)
        end)
    end
end
function KantoServicesState:magikarp()
    local prefix = "_MtMoonPokecenterMagikarpSalesman"
    if self.session:questFlag(data("policy").magikarp.flag) then
        self:serviceText({prefix .. "NoRefundsText"}); return
    end
    self.serviceMoney = true
    local money = self.session:inventory():money()
    self:serviceText({prefix .. "IGotADealText"}, function()
        self:serviceChoice({"YES", "NO"}, function(yes)
            if not yes then self:serviceText({prefix .. "NoText"}); return end
            local ok, result = KantoServices.magikarpPurchase(self.session, money)
            if ok then
                self.committed = true
                self.plan.ram = {wNameBuffer="MAGIKARP", wBoxMonNicks="MAGIKARP", wStringBuffer=tostring(result.box or 1)}
                self:serviceText({result.destination == "storage" and "_SentToBoxText" or "_GotMonText"})
            elseif result == "insufficient-money" then self:serviceText({prefix .. "NoMoneyText"})
            elseif result == "box-full" then self:serviceText({"_BoxIsFullText"})
            else self:fail(result) end
        end)
    end)
end
function KantoServicesState:bicycle()
    local offer = data("policy").bicycle
    if self.session:questFlag(offer.flag) then
        self:serviceText({"_BikeShopClerkHowDoYouLikeYourBicycleText"})
    elseif self.session:inventory():quantity(offer.voucher) > 0 then
        self:serviceText({"_BikeShopClerkOhThatsAVoucherText"}, function()
            local ok, reason = KantoServices.bicycleExchange(self.session)
            if ok then
                self.committed = true
                self:serviceText({"_BikeShopExchangedVoucherText"})
            elseif reason == "bag-full" then self:serviceText({"_BikeShopBagFullText"})
            else self:fail(reason) end
        end)
    else
        self:serviceText({"_BikeShopClerkWelcomeText", "_BikeShopClerkDoYouLikeItText"}, function()
            self:serviceChoice({"BICYCLE  ¥" .. offer.offer_price, "CANCEL"}, function(yes)
                self:serviceText(yes and {"_BikeShopCantAffordText", "_BikeShopComeAgainText"}
                    or {"_BikeShopComeAgainText"})
            end)
        end)
    end
end
function KantoServicesState:handleButton(button)
    if self:valid() and self:isTop() and self.phase == "service-choice" then
        if button == "up" or button == "down" then self.menu.selectedIndex = 3 - self.menu.selectedIndex
        elseif button == "a" then self.menu.onSelect(self.menu.selectedIndex)
        elseif button == "b" then self.menu.onCancel() end
        return
    end
    KantoServicesState.super.handleButton(self, button)
end
function KantoServicesState:draw()
    KantoServicesState.super.draw(self)
    if self:valid() and self.plan.scene == "kanto-service" and self.serviceMoney
        and (self.phase == "dialog" or self.phase == "service-choice") then
        gfx.pushContext()
        gfx.setDrawOffset(0, 0)
        gfx.clearClipRect()
        gfx.clearStencil()
        gfx.setFont(gfx.getSystemFont())
        gfx.setImageDrawMode(gfx.kDrawModeCopy)
        gfx.setLineWidth(1)
        gfx.setColor(gfx.kColorWhite)
        gfx.fillRect(236, 4, 160, 46)
        gfx.setColor(gfx.kColorBlack)
        gfx.drawRect(236, 4, 160, 46)
        gfx.drawText("MONEY", 246, 8)
        gfx.drawText("¥" .. self.session:inventory():money(), 246, 27)
        gfx.popContext()
    end
    if self:valid() and self.phase == "service-choice" then
        gfx.pushContext()
        gfx.setDrawOffset(0, 0)
        gfx.clearClipRect()
        self.menu:draw(self.plan.service == "bicycle" and 100 or 244, 120,
            self.plan.service == "bicycle" and 290 or 140, 56)
        gfx.popContext()
    end
end
