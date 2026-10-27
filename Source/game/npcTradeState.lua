-- Extends the installed executor chain; SourceEvents remains the only dispatcher.
local gfx <const> = playdate.graphics
function NPCTrades.text(label)
    return NPCTrades.policy().texts[label]
end
function NPCTrades.install()
    local policy <const> = NPCTrades.policy()
    for id in pairs(policy.events) do
        assert(not SourceEvents.has(id) and not SourceEventHandlers[id], "duplicate-trade-event")
        SourceEventHandlers[id] = function()
            return {status="ready", scene="npc-trade", service="npc-trade", steps={}}
        end
    end
    SourceEvents.registerEventSource("npc-trades", policy.events)
    SourceEvents.registerTextSource("npc-trades", NPCTrades.text)
end
Class("NPCTradeState"):extends(DaycareState)
function NPCTradeState:enter(id, options)
    self.tradeStarted, self.tradeRequest = false, nil
    self.tradeContext = self.game
    NPCTradeState.super.enter(self, id, options)
end
function NPCTradeState:tradeText(branch, callback)
    local offer <const> = assert(NPCTrades.offer(self.id))
    self:serviceText({"_" .. branch .. offer.dialogue .. "Text"}, callback)
end
function NPCTradeState:advance()
    if not self.plan or self.plan.scene ~= "npc-trade" then
        return NPCTradeState.super.advance(self)
    end
    if not self:valid() or not self:isTop() then return end
    if self.tradeStarted then self:finish(); return end
    self.tradeStarted = true
    local offer <const> = assert(NPCTrades.offer(self.id))
    self.plan.ram = {wInGameTradeGiveMonName=offer.wantedName,
        wInGameTradeReceiveMonName=offer.offeredName}
    if self.session:questFlag(offer.flag) then
        self:tradeText("AfterTrade")
        return
    end
    self:tradeText("WannaTrade", function()
        self:serviceChoice({"YES", "NO"}, function(yes)
            if yes then self:tradeSelect() else self:tradeText("NoTrade") end
        end)
    end)
end
function NPCTradeState:tradeSelect()
    self.phase, self.waiting = "trade-party", "party"
    self.machine:push("party", {
        prompt="Trade which POKEMON?  B: Cancel",
        onSelect=self:guard(function(index)
            local mon <const> = self.session:party():get(index)
            local request, reason = NPCTrades.prepare(self.session, self.id, mon, self.tradeContext)
            if not request then
                if reason == "wrong-species" then self:tradeText("WrongMon")
                elseif reason == "take-held-item-first" then
                    self:dialog({{label="trade-held-item", text="Open POKEMON, choose ITEM, then TAKE its held item first."}}, function()
                        self:finish()
                    end)
                else self:fail(reason) end
                return
            end
            self.tradeRequest = request
            -- Source offers Yes/No before party selection. This final enhanced
            -- confirmation holds the exact selected intent through cable flavor.
            self:serviceChoice({"TRADE", "CANCEL"}, function(yes)
                if not yes then
                    NPCTrades.cancel(request)
                    self.tradeRequest = nil
                    self:tradeText("NoTrade")
                    return
                end
                self:serviceText({"_ConnectCableText"}, function()
                    local ok, result = self.session:resolveNPCTrade(request, self.tradeContext)
                    self.tradeRequest = nil
                    if not ok then self:fail(result); return end
                    self:serviceText({"_TradedForText"}, function()
                        self:tradeText("Thanks")
                    end)
                end)
            end)
        end),
        onCancel=self:guard(function() self:tradeText("NoTrade") end),
    })
end
function NPCTradeState:exit()
    if self.tradeRequest then NPCTrades.cancel(self.tradeRequest) end
    self.tradeRequest, self.tradeContext = nil, nil
    NPCTradeState.super.exit(self)
end
