-- Root applies inside GameSession. This is transient owner state, never codec
-- data. CeladonSlots is a pure reducer; the scene holds only an opaque token.
local function celadonSlotRecord(session, token)
    local current = state[session]
    local record = current.celadonSlot
    assert(record and record.token == token, "stale-slot-token")
    local owner = record.owner
    assert(owner.epoch == record.epoch and owner.game.session == session and owner.session == session
        and owner.player == record.player and owner.zone == record.zone and owner:valid() and owner:isTop(),
        "stale-slot-owner")
    assert(GameSession.activeRNGSession() == session and session:fieldWorldEpoch() == record.fieldEpoch,
        "stale-slot-session")
    assert(current.coins == record.coins and FieldMoves.same(RulesRNG.snapshot(), record.rng), "stale-slot-economy")
    return current, record
end
function GameSession:celadonCornerLuck()
    return state[self].celadonLucky
end
function GameSession:enterCeladonCorner(expectedEpoch)
    if self:fieldWorldEpoch() ~= expectedEpoch or GameSession.activeRNGSession() ~= self then
        return false, "stale-Game-Corner-entry"
    end
    local stream = RulesRNG.new(1)
    stream:restore(RulesRNG.snapshot())
    local lucky = CeladonSlots.luckyIndex(stream:random(0,255))
    state[self].celadonLucky = lucky
    RulesRNG.restore(stream:snapshot())
    return true, lucky
end
function GameSession:openCeladonSlots(owner, machineID)
    local current = state[self]
    local called, record = pcall(function()
        assert(not current.celadonSlot and owner.session == self and owner.game.session == self
            and owner.id == machineID and owner:valid() and owner:isTop(), "invalid-slot-owner")
        assert(owner.zone.stableID == "pokered:GAME_CORNER", "slots-outside-Game-Corner")
        assert(owner.player.facing == "left" or owner.player.facing == "right", "source-slot-facing-required")
        local machine = assert(CeladonServices.machine(machineID), "source slot machine required")
        assert(machine.condition == "ANY_FACING", "source-slot-unavailable")
        local x,y = owner.player:getFacingTile()
        assert(x == machine.x and y == machine.y, "source slot position required")
        assert(current.inventory:quantity("coinCase") > 0, "no-coin-case")
        assert(CoinWallet.normalize(current.coins) > 0, "no-coins")
        assert(GameSession.activeRNGSession() == self, "inactive-slot-session")
        local lucky = current.celadonLucky
        if lucky == nil then
            local initialized, reason = self:enterCeladonCorner(self:fieldWorldEpoch())
            assert(initialized, reason)
            lucky = reason
        end
        return {token={},owner=owner,epoch=owner.epoch,player=owner.player,zone=owner.zone,
            fieldEpoch=self:fieldWorldEpoch(),coins=current.coins,rng=RulesRNG.snapshot(),
            value=CeladonSlots.open(machine.index,lucky)}
    end)
    if not called then return nil,tostring(record) end
    current.celadonSlot = record
    return record.token, copy(record.value)
end
function GameSession:betCeladonSlots(token, bet)
    local called, result = pcall(function()
        local current, record = celadonSlotRecord(self,token)
        assert(current.inventory:quantity("coinCase") > 0, "no-coin-case")
        assert(Party._integer(bet,1,3), "source slot bet required")
        if current.coins < bet then error("insufficient-coins",0) end
        local stream = RulesRNG.new(1)
        stream:restore(record.rng)
        local candidate = CeladonSlots.bet(record.value,bet,stream)
        local afterCoins = CoinWallet.normalize(current.coins-bet)
        current.coins, record.value, record.coins = afterCoins, candidate, afterCoins
        RulesRNG.restore(stream:snapshot())
        record.rng = stream:snapshot()
        self:invalidateFieldWorldContext()
        record.fieldEpoch = self:fieldWorldEpoch()
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:startCeladonSpin(token)
    local called, result = pcall(function()
        local _,record = celadonSlotRecord(self,token)
        record.value = CeladonSlots.start(record.value)
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:tickCeladonSlots(token, pressedA)
    local called, result = pcall(function()
        local current,record = celadonSlotRecord(self,token)
        local stream = RulesRNG.new(1)
        stream:restore(record.rng)
        local candidate = CeladonSlots.tick(record.value,pressedA,stream)
        local afterCoins = current.coins
        if candidate.phase == "result" then
            afterCoins = CoinWallet.normalize(math.min(CoinWallet.limit(),afterCoins+candidate.payout))
        end
        current.coins, record.value, record.coins = afterCoins, candidate, afterCoins
        RulesRNG.restore(stream:snapshot())
        record.rng = stream:snapshot()
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:againCeladonSlots(token)
    local called, result = pcall(function()
        local _,record = celadonSlotRecord(self,token)
        record.value = CeladonSlots.again(record.value)
        return copy(record.value)
    end)
    if not called then return false,tostring(result) end
    return true,result
end
function GameSession:closeCeladonSlots(token)
    local current = state[self]
    if not current.celadonSlot or current.celadonSlot.token ~= token then return false end
    current.celadonSlot = nil
    return true
end
